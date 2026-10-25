import Foundation
import HTTPTypes
import MistralAPI
import MistralAPITypes
import OpenAPIRuntime
import Testing

private func capture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private struct CapturedErrorTransport: ClientTransport {
    let name: String
    let status: Int
    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        (.init(status: .init(code: status), headerFields: [.contentType: "application/json"]), HTTPBody(try capture(name)))
    }
}

struct CapturedResponseDecodingTests {
    @Test(arguments: [
        "captured-mini-transcribe-3", "captured-small-transcribe-3", "captured-2507-retired", "captured-2602-context-bias-comma", "captured-latest-context-bias",
        "captured-2602-segment", "captured-2602-word", "captured-2602-language-segment",
        "captured-2602-language-en", "captured-2602-diarize-segment-remote",
        "captured-2602-file-url-text-plain", "captured-2602-file-url-bisect-curl",
        "captured-2602-file-url-bisect-sdk-file-url", "captured-2602-file-url-bisect-sdk-others",
    ])
    func decodesCapturedSuccess(name: String) throws {
        let response = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: capture(name))
        #expect(!response.text.isEmpty)
        #expect(response.usage.prompt_audio_seconds != nil)
    }

    @Test func wordChunksAndDiarizedSegments() throws {
        let word = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: capture("captured-2602-word"))
        let words = try #require(word.segments)
        #expect(words.count == 11)
        #expect(words.allSatisfy { $0._type == .transcription_segment && $0.start != nil && $0.end != nil })
        #expect(words.dropFirst().allSatisfy { $0.text.hasPrefix(" ") })
        let segment = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: capture("captured-2602-segment"))
        #expect(segment.segments?.count == 2)
        let diarized = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: capture("captured-2602-diarize-segment-remote"))
        #expect(diarized.segments?.count == 4)
        #expect(Set(diarized.segments?.compactMap(\.speaker_id) ?? []) == ["speaker_1", "speaker_2"])
    }

    @Test func segmentUnknownFieldsRoundTrip() throws {
        var json = try #require(JSONSerialization.jsonObject(with: capture("captured-2602-segment")) as? [String: Any])
        var segments = try #require(json["segments"] as? [[String: Any]])
        segments[0]["future_field"] = ["confidence": 0.9]
        json["segments"] = segments
        let response = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: JSONSerialization.data(withJSONObject: json))
        let encoded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(response)) as? [String: Any])
        let roundTrip = try #require(encoded["segments"] as? [[String: Any]])
        #expect(roundTrip[0]["future_field"] as? NSDictionary == segments[0]["future_field"] as? NSDictionary)
    }

    @Test(
        arguments: [
            ("captured-error-unknown-model", 400), ("captured-voxtral-mini", 400),
            ("captured-2602-context-bias-phrase", 400), ("captured-2602-segment-word", 422),
            ("captured-error-temperature", 422), ("captured-2602-diarize-remote", 422),
            ("captured-2602-diarize-word-remote", 422), ("captured-2602-file-url-bisect-trailer", 422),
            ("captured-2602-file-url-bisect-sdk", 422), ("captured-error-401", 401),
        ],
        [false, true]
    )
    func decodesErrorsThroughClient(fixture: (String, Int), stream: Bool) async throws {
        let (name, status) = fixture
        let client = Client(serverURL: URL(string: "https://offline.invalid")!, transport: CapturedErrorTransport(name: name, status: status))
        let error: Components.Schemas.APIError
        if stream {
            let response = try await client.audio_api_v1_transcriptions_post_stream(
                body: .multipartForm([
                    .model(.init(payload: .init(body: HTTPBody("placeholder"))))
                ])
            )
            if status == 401 {
                #expect(try response.unauthorized.body.json.detail == "Invalid API Key")
                return
            }
            error = try status == 400 ? response.badRequest.body.json : response.unprocessableContent.body.json
        } else {
            let response = try await client.audio_api_v1_transcriptions_post(
                body: .multipartForm([
                    .model(.init(payload: .init(body: HTTPBody("placeholder"))))
                ])
            )
            if status == 401 {
                #expect(try response.unauthorized.body.json.detail == "Invalid API Key")
                return
            }
            error = try status == 400 ? response.badRequest.body.json : response.unprocessableContent.body.json
        }
        #expect(error.raw_status_code == status)
        if status == 400 {
            guard case .case1(let message) = error.message else {
                Issue.record("Expected string message")
                return
            }
            #expect(!message.isEmpty)
            if name == "captured-error-unknown-model" { #expect(error.code == .case1("1500")) }
        } else {
            guard case .case2(let message) = error.message else {
                Issue.record("Expected object message")
                return
            }
            if name.contains("bisect") {
                #expect(message.detail == nil)
                #expect(message._type == "invalid_request_no_input")
                #expect(message.code == .case2(3050))
                #expect(message.message?.contains("Either file") == true)
            } else {
                #expect(message.detail?.isEmpty == false)
                // Verify arbitrary input values survive decoding and re-encoding.
                let original = try #require(JSONSerialization.jsonObject(with: capture(name)) as? NSDictionary)
                let roundTrip = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(error)) as? NSDictionary)
                #expect(roundTrip["message"] as? NSDictionary == original["message"] as? NSDictionary)
            }
        }
    }

    @Test func numericAndNullableErrorCodesAndUntypedContext() throws {
        for code in ["3050", "null", "\"1500\""] {
            let data = Data(
                "{\"object\":\"error\",\"type\":\"invalid_request_error\",\"code\":\(code),\"message\":{\"detail\":[{\"type\":\"error\",\"msg\":\"invalid\",\"input\":[true,3,\"x\"],\"ctx\":\"arbitrary context\"}]}}"
                    .utf8
            )
            let error = try JSONDecoder().decode(Components.Schemas.APIError.self, from: data)
            let decoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(error)) as? NSDictionary
            let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary
            if code == "null" { #expect(error.code == nil) } else { #expect(decoded == original) }
        }
    }
}
