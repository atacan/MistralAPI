# MistralAPI

A Swift client for the [Mistral AI](https://mistral.ai) API, generated from the official OpenAPI specification using [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator).

## Requirements

- Swift 6.1+
- macOS 14+ / iOS 17+ / tvOS 17+

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atacan/MistralAPI", from: "0.1.0"),
]
```

Then add the target dependency. There are three library products to choose from:

| Library | Transport | Use case |
|---|---|---|
| `MistralAPI` | [AsyncHTTPClient](https://github.com/swift-server/swift-openapi-async-http-client) | Server-side Swift |
| `MistralAPIUrlSessionClient` | [URLSession](https://github.com/apple/swift-openapi-urlsession) | Apple platforms |
| `MistralAPITypes` | None | Types only (shared models) |

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "MistralAPI", package: "MistralAPI"),
    ]
),
```

## Usage

```swift
import MistralAPI
import MistralAPITypes

let client = try createClient(apiKey: "your-api-key")

// Audio transcription
let audioData: Data = // ... load your audio file
let response = try await client.audio_api_v1_transcriptions_post(
    body: .multipartForm([
        .model(.init(payload: .init(body: HTTPBody(MistralModelID.Transcription.voxtralMiniLatest)))),
        .file(.init(payload: .init(body: HTTPBody(audioData)), filename: "audio.mp3")),
    ])
)
```

## How It Works

The client code is generated from Mistral's OpenAPI specification (`openapi.yaml`), with fixes applied via an [OpenAPI Overlay](https://github.com/OAI/Overlay-Specification) (`overlay.json`). The generated Swift types and client code live in `GeneratedSources/` directories.

## License

MIT
