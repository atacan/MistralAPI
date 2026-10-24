import Foundation
import HTTPTypes
import MistralAPI
import MistralAPIAsyncHTTPClient
import MistralAPITypes
import MistralAPIURLSession
import OpenAPIRuntime
import Testing

private struct FixtureMiddleware: ClientMiddleware {
    let expectedBoundary: String?

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(baseURL.absoluteString == "https://offline.invalid")
        #expect(operationID == "audio_api_v1_transcriptions_post")
        if let expectedBoundary {
            #expect(request.headerFields[.contentType]?.contains(expectedBoundary) == true)
        }
        let url = try #require(Bundle.module.url(forResource: "sample_response_with_service_tier", withExtension: "json"))
        return (.init(status: .ok, headerFields: [.contentType: "application/json"]), HTTPBody(try Data(contentsOf: url)))
    }
}

struct FactoryDefaultsTests {
    @Test(arguments: [false, true], [false, true])
    func decodeFixtureThroughEitherFactory(useAsyncHTTPClient: Bool, overrideConfiguration: Bool) async throws {
        let serverURL = URL(string: "https://offline.invalid")!
        let fixture = FixtureMiddleware(expectedBoundary: overrideConfiguration ? "offline-boundary" : nil)
        let client: Client
        if overrideConfiguration {
            let configuration = Configuration(
                dateTranscoder: .iso8601,
                multipartBoundaryGenerator: ConstantMultipartBoundaryGenerator(boundary: "offline-boundary")
            )
            client =
                useAsyncHTTPClient
                ? Client.asyncHTTPClient(serverURL: serverURL, configuration: configuration, middlewares: [fixture])
                : Client.urlSession(serverURL: serverURL, configuration: configuration, middlewares: [fixture])
        } else {
            client =
                useAsyncHTTPClient
                ? Client.asyncHTTPClient(serverURL: serverURL, middlewares: [fixture])
                : Client.urlSession(serverURL: serverURL, middlewares: [fixture])
        }
        let response = try await client.audio_api_v1_transcriptions_post(
            body: .multipartForm([
                .model(.init(payload: .init(body: HTTPBody("voxtral-mini-latest")))),
                .file(.init(payload: .init(body: HTTPBody("offline audio")), filename: "audio.wav")),
            ])
        )
        let decoded = try response.ok.body.json
        #expect(decoded.model == "voxtral-mini-latest")
        #expect(decoded.usage.service_tier == "standard")
        #expect(decoded.usage.total_tokens == 391)
    }

    @Test func customHelperKeepsTimeoutOverride() throws {
        let _: Client = try createClient(apiKey: "offline-placeholder", timeout: .seconds(2))
    }
}
