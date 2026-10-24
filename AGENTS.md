Generate the Swift code and operation security metadata with `make regenerate`.
The Python bootstrapper transforms `original_openapi.yaml`, applies
`openapi-overlay.yaml`, and preserves editable scaffold files. Dependency source
is available under `.build/checkouts/`.

The package exposes `MistralAPITypes`, `MistralAPI`, `MistralAPIURLSession`, and
`MistralAPIAsyncHTTPClient`. Keep transport imports and dependencies out of Types
and core. Shared authentication lives under `Sources/MistralAPI/Authentication/`;
never edit `Authentication/GeneratedSecurity/OperationSecurity.swift` manually.

The generator configurations intentionally select only `audio.transcriptions`.
Preserve their filters, the custom model identifiers and `createClient` helper,
UsefulThings, test resources, and custom decoding coverage.

Use exact scheme credentials: `ApiKey` for regular bearer authentication,
`AdminApiKey` for administration, `DashboardUserContextAuth` for the dashboard
`x-api-key` header. Multiple bearer schemes make `.bearer(...)` ambiguous.

URLSession example (import `MistralAPI` and `MistralAPIURLSession`):

```swift
let client = Client.urlSession(
    serverURL: URL(string: "https://api.mistral.ai")!,
    authentication: .credentials(["ApiKey": .init("YOUR_API_KEY")])
)
```

AsyncHTTPClient example (import `MistralAPI` and `MistralAPIAsyncHTTPClient`):

```swift
let client = Client.asyncHTTPClient(
    serverURL: URL(string: "https://api.mistral.ai")!,
    authentication: .credentials(["ApiKey": .init("YOUR_API_KEY")])
)
```

Both factories preserve `.iso8601WithFractionalSeconds` runtime date defaults and
forward explicit configuration overrides. AsyncHTTPClient defaults to one hour;
`createClient(apiKey:timeout:)` keeps its timeout override. If HTTP date decoding
fails, check the actual timestamp and runtime configuration. Direct `Client(...)`
initialization bypasses factory defaults; standalone JSONDecoder needs its own
strategy. The currently filtered transcription models have no date properties.

Verify with `swift build` and `make test-offline`. Do not run unfiltered tests
without authorization: `MistralAPITests` reads `.env` and sends live audio requests.
Offline fixture suites are separate to avoid that suite's eager credential access.
Check dependency tools-version headers after resolution; the current dependency
set requires Swift 6.2+, verified with Swift 6.4. Update generated files only by
regenerating, then repeat build and explicitly selected offline suites.
