import Foundation
import MistralAPITypes
import Testing

struct ResponseDecodingTests {
    @Test func decodeResponse() async throws {
        let jsonFileUrl = Bundle.module.url(forResource: "sample_response", withExtension: "json")!
        let response = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: try Data(contentsOf: jsonFileUrl))
        #expect(response.model == "voxtral-mini-2507")
        #expect(response.usage.prompt_tokens == 4)
    }

    @Test func decodeResponseWithFinishReason() async throws {
        let jsonFileUrl = Bundle.module.url(forResource: "sample_response_with_finish_reason", withExtension: "json")!
        let response = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: try Data(contentsOf: jsonFileUrl))
        #expect(response.model == "voxtral-mini-latest")
        #expect(response.finish_reason == nil)
        #expect(response.usage.prompt_tokens_details == nil)
    }

    @Test func decodeResponse422() async throws {
        let jsonFileUrl = Bundle.module.url(forResource: "sample_422_response", withExtension: "json")!
        let response = try JSONDecoder().decode(Components.Schemas.APIError.self, from: try Data(contentsOf: jsonFileUrl))
        #expect(response.object == .error)
    }
}
