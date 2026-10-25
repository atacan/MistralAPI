import Foundation
import MistralAPI
import MistralAPIAsyncHTTPClient
import MistralAPITypes
import MistralAPIURLSession
import NIOCore
import NIOHTTP1
import NIOPosix
import OpenAPIRuntime
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private struct RecordedStreamRequest: Sendable {
    let uri: String
    let body: [UInt8]
}

/// Records the actual HTTP request target and responds with a synthetic SSE fixture.
private final class StreamFixtureHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let promise: EventLoopPromise<RecordedStreamRequest>
    let response: String
    var uri = ""
    var body: [UInt8] = []

    init(promise: EventLoopPromise<RecordedStreamRequest>, response: String) {
        self.promise = promise
        self.response = response
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head): uri = head.uri
        case .body(var buffer): body.append(contentsOf: buffer.readBytes(length: buffer.readableBytes) ?? [])
        case .end:
            promise.succeed(.init(uri: uri, body: body))
            let headers = HTTPHeaders([
                ("Content-Type", "text/event-stream"),
                ("Content-Length", String(response.utf8.count)),
                ("Connection", "close"),
            ])
            context.write(wrapOutboundOut(.head(.init(version: .http1_1, status: .ok, headers: headers))), promise: nil)
            // Write small pieces so transport buffering can split event payloads.
            let bytes = Array(response.utf8)
            for offset in stride(from: 0, to: bytes.count, by: 17) {
                let chunk = bytes[offset ..< min(offset + 17, bytes.count)]
                context.write(wrapOutboundOut(.body(.byteBuffer(context.channel.allocator.buffer(bytes: chunk)))), promise: nil)
            }
            let channel = context.channel
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in channel.close(promise: nil) }
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        promise.fail(error)
        context.close(promise: nil)
    }
}

struct StreamingTransportTests {
    @Test(arguments: [false, true], [false, true])
    func actualRequestPathAndStreamingEvents(useAsyncHTTPClient: Bool, explicitStreamPart: Bool) async throws {
        let url = try #require(Bundle.module.url(forResource: "synthetic-transcription-stream", withExtension: "sse"))
        let fixture = try String(contentsOf: url, encoding: .utf8)
        let group = MultiThreadedEventLoopGroup.singleton
        let recorded = group.next().makePromise(of: RecordedStreamRequest.self)
        let server = try await ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline()
                    .flatMapThrowing {
                        try channel.pipeline.syncOperations.addHandler(StreamFixtureHandler(promise: recorded, response: fixture))
                    }
            }
            .bind(host: "127.0.0.1", port: 0).get()
        do {
            let port = try #require(server.localAddress?.port)
            let serverURL = try #require(URL(string: "http://127.0.0.1:\(port)"))
            let sessionConfiguration = URLSessionConfiguration.ephemeral
            sessionConfiguration.timeoutIntervalForRequest = 5
            sessionConfiguration.timeoutIntervalForResource = 5
            let session = URLSession(configuration: sessionConfiguration)
            defer { session.invalidateAndCancel() }
            let client =
                useAsyncHTTPClient
                ? Client.asyncHTTPClient(serverURL: serverURL, authentication: .credentials(["ApiKey": .init("offline")]), transportConfiguration: .init(timeout: .seconds(5)))
                : Client.urlSession(serverURL: serverURL, authentication: .credentials(["ApiKey": .init("offline")]), transportConfiguration: .init(session: session))
            var parts: [Components.Schemas.AudioTranscriptionRequestStream] = [
                .model(.init(payload: .init(body: HTTPBody("offline-fixture")))),
                .file(.init(payload: .init(body: HTTPBody("synthetic audio")), filename: "audio.wav")),
            ]
            if explicitStreamPart { parts.append(.stream(.init(payload: .init(body: HTTPBody("true"))))) }
            let response = try await client.audio_api_v1_transcriptions_post_stream(body: .multipartForm(.init(parts)))
            let body = try response.ok.body.text_event_hyphen_stream
            let sequence = body.asDecodedServerSentEventsWithJSONData(of: Components.Schemas.TranscriptionStreamEvents.dataPayload.self)
            var events: [ServerSentEventWithJSONData<Components.Schemas.TranscriptionStreamEvents.dataPayload>] = []
            for try await event in sequence { events.append(event) }
            #expect(events.map(\.event) == ["transcription.language", "transcription.text.delta", "transcription.segment", "transcription.done"])
            try #require(events.count == 4)
            if case .transcription_period_language(let data) = events[0].data { #expect(data.audio_language == "en") } else { Issue.record("Expected language payload") }
            if case .transcription_period_text_period_delta(let data) = events[1].data { #expect(data.text == "Hello") } else { Issue.record("Expected text delta payload") }
            if case .transcription_period_segment(let data) = events[2].data {
                #expect(data.start == 0.1)
                #expect(data.end == 0.5)
                #expect(data.speaker_id == "speaker_1")
            } else {
                Issue.record("Expected segment payload")
            }
            if case .transcription_period_done(let data) = events[3].data { #expect(data.text == "Hello") } else { Issue.record("Expected done payload") }
            let request = try await recorded.futureResult.get()
            #expect(request.uri == "/v1/audio/transcriptions")
            let requestBody = String(decoding: request.body, as: UTF8.self)
            // Defaults in the schema do not synthesize a multipart part.
            #expect(requestBody.contains("name=\"stream\"") == explicitStreamPart)
            if explicitStreamPart { #expect(requestBody.contains("\r\n\r\ntrue\r\n")) }
            try await server.close().get()
        } catch {
            try? await server.close().get()
            throw error
        }
    }
}
