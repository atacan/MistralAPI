import Foundation
import HTTPTypes
import MistralAPI
import MistralAPITypes
import OpenAPIRuntime
import Testing

private struct RecordingTransport: ClientTransport {
    let check: @Sendable (HTTPRequest, HTTPBody?, String) async throws -> Void

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        try await check(request, body, operationID)
        let url = try #require(Bundle.module.url(forResource: "captured-error-unknown-model", withExtension: "json"))
        return (.init(status: .badRequest, headerFields: [.contentType: "application/json"]), HTTPBody(try Data(contentsOf: url)))
    }
}

private struct CallerMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(request.headerFields[.authorization] == nil)
        // Middleware must remain lazy: leave the body for the transport to consume.
        return try await next(request, body, baseURL)
    }
}

struct MultipartEncodingTests {
    @Test(arguments: [false, true], [false, true])
    func singleValueFieldsAndExactFraming(stream: Bool, upload: Bool) async throws {
        let transport = RecordingTransport { request, body, operationID in
            #expect(request.headerFields[.contentType] == "multipart/form-data; boundary=test")
            #expect(request.headerFields[.authorization] == "Bearer placeholder")
            #expect(operationID == (stream ? "audio_api_v1_transcriptions_post_stream" : "audio_api_v1_transcriptions_post"))
            let body = try #require(body)
            #expect(body.length == .unknown)
            let actual = try await Array(collecting: body, upTo: 10_000)
            func part(_ name: String, _ value: String, filename: String? = nil) -> String {
                let disposition = "form-data; " + (filename.map { "filename=\"\($0)\"; " } ?? "") + "name=\"\(name)\""
                return "--test\r\ncontent-disposition: \(disposition)\r\ncontent-length: \(value.utf8.count)\r\ncontent-type: text/plain\r\n\r\n\(value)\r\n"
            }
            let expected =
                part("model", "voxtral-mini-2602")
                + part("context_bias", "a,b")
                + part("timestamp_granularities", "segment")
                + (upload ? part("file", "audio\u{0}bytes", filename: "speech.wav") : part("file_url", "https://example.com/audio.mp3"))
                + "--test--\r\n"
            #expect(actual == Array(expected.utf8))
            let text = String(decoding: actual, as: UTF8.self)
            #expect(text.components(separatedBy: "name=\"context_bias\"").count == 2)
            #expect(text.components(separatedBy: "name=\"timestamp_granularities\"").count == 2)
        }
        let client = Client(
            serverURL: URL(string: "https://offline.invalid")!,
            configuration: .init(multipartBoundaryGenerator: ConstantMultipartBoundaryGenerator(boundary: "test")),
            transport: transport,
            authentication: .credentials(["ApiKey": .init("placeholder")]),
            middlewares: [CallerMiddleware()]
        )
        if stream {
            let parts: [Components.Schemas.AudioTranscriptionRequestStream] = [
                .model(.init(payload: .init(body: HTTPBody("voxtral-mini-2602")))),
                .context_bias(.init(payload: .init(body: HTTPBody("a,b")))),
                .timestamp_granularities(.init(payload: .init(body: HTTPBody(Components.Schemas.TimestampGranularity.segment.rawValue)))),
                upload
                    ? .file(.init(payload: .init(body: HTTPBody("audio\u{0}bytes")), filename: "speech.wav"))
                    : .file_url(.init(payload: .init(body: HTTPBody("https://example.com/audio.mp3")))),
            ]
            _ = try await client.audio_api_v1_transcriptions_post_stream(body: .multipartForm(.init(parts)))
        } else {
            let parts: [Components.Schemas.AudioTranscriptionRequest] = [
                .model(.init(payload: .init(body: HTTPBody("voxtral-mini-2602")))),
                .context_bias(.init(payload: .init(body: HTTPBody("a,b")))),
                .timestamp_granularities(.init(payload: .init(body: HTTPBody(Components.Schemas.TimestampGranularity.segment.rawValue)))),
                upload
                    ? .file(.init(payload: .init(body: HTTPBody("audio\u{0}bytes")), filename: "speech.wav"))
                    : .file_url(.init(payload: .init(body: HTTPBody("https://example.com/audio.mp3")))),
            ]
            _ = try await client.audio_api_v1_transcriptions_post(body: .multipartForm(.init(parts)))
        }
    }
}
