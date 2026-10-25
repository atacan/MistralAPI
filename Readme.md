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

Add `.package(url: "https://github.com/atacan/MistralAPI", from: "2.0.0")` to your
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
Caller middleware runs first, followed by `MultipartEpilogueTrimmingMiddleware`,
then authentication on outgoing requests. Injected
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

## Transcription multipart fields and compatibility

Version 2 changes the public multipart cardinality and error types. Both regular
and streaming transcription requests accept **one** `context_bias` part containing
comma-separated terms (for example `a,b`) and **one** `timestamp_granularities` part
containing `segment` or `word`. Repeating these parts makes Mistral concatenate their
values. For `voxtral-mini-2602`, use at most 100 bias terms without whitespace or
commas inside a term. Temperature ranges from 0 to 1.5. Non-streaming diarization
requires `timestamp_granularities=segment`.

```swift
// Within .multipartForm([...]), alongside model and file/file_url:
.context_bias(.init(payload: .init(body: HTTPBody("Speechall,TranscriptionKit")))),
.timestamp_granularities(.init(payload: .init(body: HTTPBody("segment")))),
```

Import `OpenAPIRuntime` for `HTTPBody`. Word timestamps arrive in `segments`, one
`transcription_segment` per word; subsequent words include a leading space.
Diarized segments use `speaker_1`, `speaker_2`, and so on. Unknown segment properties
are preserved. The captured 2602 response accepts `language=en` with segment
timestamps despite the older documented restriction.

`MultipartEpilogueTrimmingMiddleware` streams the request while holding back its
last two bytes. It removes only the extra CRLF from a body ending in
`--\r\n\r\n`, which Mistral's `file_url` parser rejects, and preserves iteration
behavior with unknown length. It applies to both transcription operation IDs,
including file uploads. Both factories and the initializer with `authentication:`
install it automatically after caller middleware and before authentication.
When using the generated initializer without `authentication:`, add
`MultipartEpilogueTrimmingMiddleware()` to `middlewares:` explicitly.

`APIError.message` is now a generated union: `.case1(String)` or
`.case2(...)` with optional `detail`, `message`, `type`, and `code`. Validation
`input` and `ctx` accept arbitrary JSON; codes accept nullable strings or integers.
A 401 produces `.unauthorized` with a typed `detail` string. See the offline
capture tests for examples and the resource README for request provenance.

`MistralModelID.Transcription.voxtralMiniTranscribe3` and
`.voxtralSmallTranscribe3` use `voxtral-mini-transcribe-3-0` and
`voxtral-small-transcribe-3-0`, the public-preview identifiers from the
[official audio overview](https://docs.mistral.ai/studio/audio/overview). Each
returned 200 in a fixture upload on 2026-10-25. The 2507 constants are deprecated;
the retired transcription ID still routed to `voxtral-mini-latest` in the capture.

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

`swift test` / `make test` also run live transcription tests which read
`MISTRAL_API_KEY` from the process environment and upload the bundled `speech.wav`.
Run them only when API calls are intended. Keep real credentials
out of examples and test output.

## License

MIT
