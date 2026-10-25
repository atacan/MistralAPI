import Foundation
import HTTPTypes
import OpenAPIRuntime

/// Removes the runtime's final multipart epilogue CRLF, which Mistral's file_url parser rejects.
/// Keeps uploads streaming and preserves the body's iteration behavior.
public struct MultipartEpilogueTrimmingMiddleware: ClientMiddleware {
    public init() {}

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard
            operationID == "audio_api_v1_transcriptions_post"
                || operationID == "audio_api_v1_transcriptions_post_stream",
            let body
        else { return try await next(request, body, baseURL) }

        let trimmed = HTTPBody(
            EpilogueTrimmingSequence(body: body),
            length: .unknown,
            iterationBehavior: body.iterationBehavior
        )
        return try await next(request, trimmed, baseURL)
    }
}

private struct EpilogueTrimmingSequence: AsyncSequence, Sendable {
    typealias Element = ArraySlice<UInt8>
    let body: HTTPBody

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(upstream: body.makeAsyncIterator())
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        var upstream: HTTPBody.AsyncIterator
        var pending: [UInt8] = []
        var suffix: [UInt8] = []
        var queued: Element?
        var finished = false

        mutating func next() async throws -> Element? {
            if let queued {
                self.queued = nil
                return queued
            }
            guard !finished else { return nil }
            while let chunk = try await upstream.next() {
                suffix =
                    chunk.count >= 6
                    ? Array(chunk.suffix(6))
                    : Array((suffix + chunk).suffix(6))
                if chunk.count >= 2 {
                    let previous = pending
                    pending = Array(chunk.suffix(2))
                    let prefix = chunk.dropLast(2)
                    // Return the held bytes separately, retaining the upstream slice without copying it.
                    if !previous.isEmpty {
                        if !prefix.isEmpty { queued = prefix }
                        return previous[...]
                    }
                    if !prefix.isEmpty { return prefix }
                } else {
                    // At most three bytes are copied when a chunk has fewer than two bytes.
                    var bytes = pending
                    bytes.append(contentsOf: chunk)
                    pending = Array(bytes.suffix(2))
                    if bytes.count > 2 { return bytes.dropLast(2) }
                }
            }
            finished = true
            guard suffix != Array("--\r\n\r\n".utf8), !pending.isEmpty else { return nil }
            return pending[...]
        }
    }
}
