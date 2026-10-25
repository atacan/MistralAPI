import Foundation
import HTTPTypes
import MistralAPI
import OpenAPIRuntime
import Testing

private struct ChunkSequence: AsyncSequence, Sendable {
    typealias Element = ArraySlice<UInt8>
    let chunks: [Element]
    init(_ chunks: [Element]) { self.chunks = chunks }
    struct AsyncIterator: AsyncIteratorProtocol {
        var chunks: IndexingIterator<[Element]>
        mutating func next() async -> Element? { chunks.next() }
    }
    func makeAsyncIterator() -> AsyncIterator { .init(chunks: chunks.makeIterator()) }
}

struct MultipartEpilogueTrimmingTests {
    private func wrap(_ body: HTTPBody?, operationID: String = "audio_api_v1_transcriptions_post") async throws -> HTTPBody? {
        let (_, wrapped) = try await MultipartEpilogueTrimmingMiddleware()
            .intercept(
                .init(method: .post, scheme: "https", authority: "offline.invalid", path: "/"),
                body: body,
                baseURL: URL(string: "https://offline.invalid")!,
                operationID: operationID
            ) { _, body, _ in (.init(status: .ok), body) }
        return wrapped
    }

    @Test(arguments: ["audio_api_v1_transcriptions_post", "audio_api_v1_transcriptions_post_stream"])
    func trimsAcrossEveryChunkBoundary(operationID: String) async throws {
        let bytes = Array("payload\r\n--test--\r\n\r\n".utf8)
        for split in 0 ... bytes.count {
            let source = HTTPBody(ChunkSequence([bytes[..<split], [], bytes[split...]]), length: .unknown, iterationBehavior: .multiple)
            let body = try #require(try await wrap(source, operationID: operationID))
            #expect(body.length == .unknown)
            #expect(body.iterationBehavior == .multiple)
            #expect(try await Array(collecting: body, upTo: 100) == Array(bytes.dropLast(2)))
            #expect(try await Array(collecting: body, upTo: 100) == Array(bytes.dropLast(2)))
        }
        let source = HTTPBody(ChunkSequence(bytes.map { [$0][...] }), length: .unknown, iterationBehavior: .single)
        let body = try #require(try await wrap(source, operationID: operationID))
        #expect(body.iterationBehavior == .single)
        #expect(try await Array(collecting: body, upTo: 100) == Array(bytes.dropLast(2)))
    }

    @Test(arguments: ["", "x", "\r\n", "--test--\r\n", "data\r\n\r\n", "--test--\r\n\r\nextra"])
    func preservesBodiesWithoutEpilogue(value: String) async throws {
        let source = HTTPBody(ChunkSequence(Array(value.utf8).map { [$0][...] }), length: .unknown, iterationBehavior: .multiple)
        let body = try #require(try await wrap(source))
        #expect(try await Array(collecting: body, upTo: 100) == Array(value.utf8))
    }

    @Test func unrelatedOperationsAndNilBodyPassThrough() async throws {
        let source = HTTPBody("--test--\r\n\r\n")
        let body = try #require(try await wrap(source, operationID: "another_operation"))
        #expect(body === source)
        #expect(body.length == source.length)
        #expect(try await String(collecting: body, upTo: 100) == "--test--\r\n\r\n")
        #expect(try await wrap(nil) == nil)
    }

    @Test func largeChunksRetainTheirOriginalStorage() async throws {
        let bytes = [UInt8](repeating: 42, count: 64 * 1024)
        let source = HTTPBody(
            ChunkSequence([Array("ab".utf8)[...], bytes[...], Array("--test--\r\n\r\n".utf8)[...]]),
            length: .unknown,
            iterationBehavior: .single
        )
        let body = try #require(try await wrap(source))
        var iterator = body.makeAsyncIterator()
        #expect(try await iterator.next() == Array("ab".utf8)[...])
        let prefix = try #require(try await iterator.next())
        #expect(prefix.count == bytes.count - 2)
        let sharesStorage = bytes.withUnsafeBufferPointer { original in
            prefix.withUnsafeBufferPointer { $0.baseAddress == original.baseAddress }
        }
        #expect(sharesStorage)
        var remaining: [UInt8] = []
        while let chunk = try await iterator.next() { remaining.append(contentsOf: chunk) }
        #expect(remaining == Array(bytes.suffix(2)) + Array("--test--\r\n".utf8))
    }

    @Test func emitsBeforeEndAndPropagatesUpstreamError() async throws {
        struct FailingSequence: AsyncSequence, Sendable {
            typealias Element = ArraySlice<UInt8>
            struct UploadFailure: Error {}
            struct AsyncIterator: AsyncIteratorProtocol {
                var first = true
                mutating func next() async throws -> Element? {
                    if first {
                        first = false
                        return Array("large upload chunk".utf8)[...]
                    }
                    throw UploadFailure()
                }
            }
            func makeAsyncIterator() -> AsyncIterator { .init() }
        }
        let source = HTTPBody(FailingSequence(), length: .unknown, iterationBehavior: .single)
        let body = try #require(try await wrap(source))
        var iterator = body.makeAsyncIterator()
        #expect(try await iterator.next() == Array("large upload chu".utf8)[...])
        await #expect(throws: FailingSequence.UploadFailure.self) { try await iterator.next() }
    }
}
