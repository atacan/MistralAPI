import Foundation
import MistralAPI
import MistralAPIAsyncHTTPClient
import MistralAPITypes
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import Testing

#if os(Linux)
@preconcurrency import struct Foundation.URL
@preconcurrency import struct Foundation.Data
@preconcurrency import struct Foundation.Date
#else
import struct Foundation.URL
import struct Foundation.Data
import struct Foundation.Date
#endif

struct MistralAPITests {
    @Test(arguments: [
        MistralModelID.Transcription.voxtralMini2507,
        MistralModelID.Transcription.voxtralMini2602,
    ])
    func transcription(model: String) async throws {
        let apiKey = try #require(ProcessInfo.processInfo.environment["MISTRAL_API_KEY"])
        let client = try createClient(apiKey: apiKey)
        let audioURL = try #require(Bundle.module.url(forResource: "speech", withExtension: "wav"))
        let audioData = try Data(contentsOf: audioURL)
        let response = try await client.audio_api_v1_transcriptions_post(
            body: .multipartForm([
                .model(
                    .init(
                        payload: .init(
                            body: HTTPBody(
                                model
                            )
                        )
                    )
                ),
                .file(
                    .init(
                        payload: .init(
                            body: HTTPBody(
                                audioData
                            )
                        ),
                        filename: "speech.wav"
                    )
                ),
                .timestamp_granularities(
                    .init(
                        payload: .init(
                            body: HTTPBody(Components.Schemas.TimestampGranularity.segment.rawValue)
                        )
                    )
                ),
            ])
        )
        switch response {
        case .ok(let ok):
            dump(ok)
        case .badRequest(let badRequest):
            dump(badRequest)
        case .unauthorized(let unauthorized):
            dump(unauthorized)
        case .unprocessableContent(let unprocessableContent):
            dump(unprocessableContent)
        case .undocumented(let statusCode, let payload):
            print("statusCode", statusCode)
            let collected = try await payload.body?.collect(upTo: .max, using: .init())
            let string = String(buffer: collected!)
            print(string)
        }
    }

}
