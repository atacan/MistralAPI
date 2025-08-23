import OpenAPIAsyncHTTPClient
import OpenAPIRuntime
import MistralAPITypes

public func createClient(apiKey: String) throws -> Client {

    let serverURL = try Servers.Server1.url()
    let client = Client(
        serverURL: serverURL,
        configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds),
        transport: AsyncHTTPClientTransport(),
        middlewares: [
            AuthenticationMiddleware(apiKey: apiKey),
        ]
    )

    return client
}
