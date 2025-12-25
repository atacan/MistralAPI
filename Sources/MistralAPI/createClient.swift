import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import MistralAPITypes
import NIOCore

public func createClient(apiKey: String, timeout: TimeAmount = .hours(1)) throws -> Client {

    let serverURL = try Servers.Server1.url()
    let client = Client(
        serverURL: serverURL,
        configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
        transport: AsyncHTTPClientTransport(configuration: .init(timeout: timeout)),
        middlewares: [
            AuthenticationMiddleware(apiKey: apiKey),
        ]
    )

    return client
}
