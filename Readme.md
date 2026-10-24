# MistralAPI

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2FMistralAPI%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/atacan/MistralAPI)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2FMistralAPI%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/atacan/MistralAPI)

A Swift client for the [Mistral AI](https://mistral.ai) API, generated from the official OpenAPI specification using [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator).

## Requirements

- Swift 6.2 or newer (verified with Apple Swift 6.4).
- macOS 13+ / iOS 16+ / tvOS 16+ / watchOS 9+.

The resolved generator and several dependencies require Swift 6.2. The package
retains its original platform settings.

## Installation

Add `.package(url: "https://github.com/atacan/MistralAPI", from: "0.1.0")` to your
package dependencies, then select the products your target imports:

| Product | Contents |
| --- | --- |
| `MistralAPITypes` | Transcription models and operation inputs/outputs |
| `MistralAPI` | Shared client, model identifiers, and authentication |
| `MistralAPIURLSession` | `Client.urlSession(...)` factory for URLSession |
| `MistralAPIAsyncHTTPClient` | `Client.asyncHTTPClient(...)` and `createClient(apiKey:timeout:)` |

For example, depend on `MistralAPI` and `MistralAPIURLSession`. Add
`MistralAPITypes` when importing models directly. Declare `OpenAPIRuntime` directly
if your application imports it for multipart `HTTPBody` values.

## Usage

```swift
import Foundation
import MistralAPI
import MistralAPIURLSession

let client = Client.urlSession(
    serverURL: URL(string: "https://api.mistral.ai")!,
    authentication: .credentials(["ApiKey": .init("YOUR_API_KEY")])
)
```

For AsyncHTTPClient:

```swift
import Foundation
import MistralAPI
import MistralAPIAsyncHTTPClient

let client = Client.asyncHTTPClient(
    serverURL: URL(string: "https://api.mistral.ai")!,
    authentication: .credentials(["ApiKey": .init("YOUR_API_KEY")])
)
// Uses the specification's server URL and accepts a timeout override:
let convenientClient = try createClient(apiKey: "YOUR_API_KEY", timeout: .minutes(10))
```

Both factories return the same client and use fractional-second ISO8601 date
decoding. The AsyncHTTPClient factory and helper default to a one-hour timeout.
Explicit `configuration:` and `transportConfiguration:` arguments override defaults.
Additional middleware runs before authentication on outgoing requests. Injected
sessions/clients remain owned by the application; do not shut down shared clients.

The specification declares separate bearer schemes: `ApiKey` for regular API
operations and `AdminApiKey` for administration. Use their exact names with
`Authentication.credentials`; the shorthand `.bearer(...)` is ambiguous here.
Dashboard operations use `DashboardUserContextAuth` in the `x-api-key` header.
The preserved generator configs currently select only `audio.transcriptions`.
Authentication metadata follows the entire final specification, but it does not
add generated methods for excluded operations.

For custom transports use the core initializer
`Client(serverURL:configuration:transport:authentication:middlewares:)`.
Authentication selects credentials per operation and fails before transport when
required credentials are missing. Factories default to `.none`; authenticated
transcription operations require an `ApiKey` credential.

## Generation and tests

```bash
make regenerate
swift build
make test-offline
```

`original_openapi.yaml` and `openapi-overlay.yaml` produce `openapi.yaml`, generated
Swift code, and operation security metadata. Keep manual edits outside
`GeneratedSources/` and `Authentication/GeneratedSecurity/`. Regeneration preserves
factory defaults, helpers, configuration, custom tests, documentation, and resources.
`make download-openapi` updates the original specification when explicitly wanted.

`make test-offline` selects fixture, factory, and authentication suites explicitly.
Factory tests return fixtures from middleware without contacting Mistral. The
transcription-only models contain no dates, so those fixtures do not exercise date
decoding. For a date decoding failure, check whether a custom runtime configuration
replaced the factory's fractional-second transcoder. Standalone `JSONDecoder`
instances need their own date strategy.

`swift test` / `make test` also run live transcription tests which read `.env` and
an audio file. Run them only when API calls are intended. Keep real credentials
out of examples and test output.

## License

MIT
