import Foundation
import MistralAPI
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
    let audioData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/atacan/Developer/Repositories/GoogleGenerativeLanguage/assets/speech.mp3"))

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let response = try await client.audio_api_v1_transcriptions_post(body: .multipartForm([
            .model(.init(payload: .init(body: HTTPBody("abc")))),
            
        ]))
    }
}
