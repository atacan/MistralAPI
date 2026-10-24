import MistralAPI
import MistralAPITypes
import NIOCore
import OpenAPIAsyncHTTPClient
import OpenAPIRuntime

/// Creates a transcription client with the specification server and a configurable timeout.
public func createClient(apiKey: String, timeout: TimeAmount = .hours(1)) throws -> Client {

    let serverURL = try Servers.Server1.url()
    let client = Client.asyncHTTPClient(
        serverURL: serverURL,
        authentication: .credentials(["ApiKey": .init(apiKey)]),
        transportConfiguration: .init(timeout: timeout)
    )

    return client
}
