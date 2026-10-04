import Foundation
import MistralAPITypes
import Testing

struct TranscriptionResponseDecodingTests {
    private func sampleResponse() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "sample_response_with_service_tier", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func decodeLiveResponse() throws {
        let response = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: sampleResponse())
        #expect(response.model == "voxtral-mini-latest")
        #expect(response.text == "They love vulnerability. It's very attractive when a woman is")
        #expect(response.language == nil)
        #expect(response.finish_reason == nil)
        #expect(response.usage.service_tier == "standard")
        #expect(response.usage.prompt_tokens_details?.audio_tokens == 375)
        #expect(response.usage.total_tokens == 391)
    }

    @Test(arguments: ["missing", "null", "priority", "future-tier"])
    func decodeServiceTierVariants(variant: String) throws {
        var json = try #require(JSONSerialization.jsonObject(with: sampleResponse()) as? [String: Any])
        var usage = try #require(json["usage"] as? [String: Any])
        switch variant {
        case "missing": usage.removeValue(forKey: "service_tier")
        case "null": usage["service_tier"] = NSNull()
        default: usage["service_tier"] = variant
        }
        json["usage"] = usage
        let data = try JSONSerialization.data(withJSONObject: json)
        let response = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: data)
        #expect(response.usage.service_tier == (variant == "missing" || variant == "null" ? nil : variant))
    }

    @Test func preserveAdditionalResponseProperties() throws {
        var json = try #require(JSONSerialization.jsonObject(with: sampleResponse()) as? [String: Any])
        json["future_response"] = ["items": [true, false], "value": NSNull()] as [String: Any]
        var usage = try #require(json["usage"] as? [String: Any])
        usage["future_usage"] = ["seconds": 1.5]
        var details = try #require(usage["prompt_tokens_details"] as? [String: Any])
        details["future_tokens"] = 7
        usage["prompt_tokens_details"] = details
        json["usage"] = usage

        let data = try JSONSerialization.data(withJSONObject: json)
        let response = try JSONDecoder().decode(Components.Schemas.TranscriptionResponse.self, from: data)
        #expect(response.usage.service_tier == "standard")
        #expect(response.usage.prompt_tokens_details?.cached_tokens == 0)
        let encoded = try JSONEncoder().encode(response)
        let roundTrip = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect((roundTrip["future_response"] as? NSDictionary) == (json["future_response"] as? NSDictionary))
        let roundTripUsage = try #require(roundTrip["usage"] as? [String: Any])
        #expect((roundTripUsage["future_usage"] as? NSDictionary) == (usage["future_usage"] as? NSDictionary))
        let roundTripDetails = try #require(roundTripUsage["prompt_tokens_details"] as? [String: Any])
        #expect(roundTripDetails["future_tokens"] as? Int == 7)
    }
}
