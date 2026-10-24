import Foundation
import MistralAPI
import MistralAPIAsyncHTTPClient
import MistralAPITypes
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import Testing
import UsefulThings

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
    let client = {
        let envFileUrl = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".env")
        return try! createClient(apiKey: getEnvironmentVariable("MISTRAL_API_KEY", from: envFileUrl)!)
    }()
    let audioData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/atacan/Developer/Repositories/MistralAPI/60s_speech.wav"))

    @Test(arguments: [
        MistralModelID.Transcription.voxtralMini2507,
        MistralModelID.Transcription.voxtralMini2602,
    ])
    func transcription(model: String) async throws {
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
                        filename: "speech.mp3"
                    )
                ),
                .timestamp_granularities(
                    .init(
                        payload: .init(
                            body: HTTPBody(
                                MistralAPITypes.Components.Schemas.TimestampGranularity.segment.rawValue
                            )
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
