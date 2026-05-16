// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
import Bytes
@testable import ContentEncoding

@Suite("Streaming encoder")
struct StreamingTests {
    // MARK: - Helpers

    private static func bytesFromString(_ s: String) -> Bytes {
        var b = Bytes()
        b.append(contentsOf: Array(s.utf8))
        return b
    }

    // MARK: - Per-coding round-trip

    @Test("empty header → identity passthrough round-trips")
    func emptyHeaderIdentity() throws {
        let payload = Self.bytesFromString("hello")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "")
        encoder.update(payload)
        let compressed = try encoder.finish()
        #expect(Array(compressed.storage) == Array(payload.storage))
    }

    @Test("identity coding round-trips")
    func identityRoundTrip() throws {
        let payload = Self.bytesFromString("hello world")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "identity")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "identity")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("gzip coding round-trips")
    func gzipRoundTrip() throws {
        let payload = Self.bytesFromString("hello world hello world")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("x-gzip coding round-trips")
    func xGzipRoundTrip() throws {
        let payload = Self.bytesFromString("legacy gzip alias")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "x-gzip")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "x-gzip")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("deflate coding round-trips")
    func deflateRoundTrip() throws {
        let payload = Self.bytesFromString("zlib-framed deflate")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "deflate")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "deflate")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("x-deflate coding round-trips")
    func xDeflateRoundTrip() throws {
        let payload = Self.bytesFromString("legacy deflate alias")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "x-deflate")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "x-deflate")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("br coding round-trips")
    func brRoundTrip() throws {
        let payload = Self.bytesFromString("brotli streaming test payload")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "br")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "br")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    // MARK: - Multi-chunk + boundary

    @Test("two chunks → concatenation under gzip")
    func twoChunkGzip() throws {
        let chunk1 = Self.bytesFromString("hel")
        let chunk2 = Self.bytesFromString("lo")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip")
        encoder.update(chunk1)
        encoder.update(chunk2)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip")
        #expect(Array(plain.storage) == Array("hello".utf8))
    }

    @Test("empty chunk in middle is a no-op (br)")
    func emptyChunkInMiddleBr() throws {
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "br")
        encoder.update(Self.bytesFromString("a"))
        encoder.update(Bytes())
        encoder.update(Self.bytesFromString("b"))
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "br")
        #expect(Array(plain.storage) == Array("ab".utf8))
    }

    @Test("single-byte stream (deflate)")
    func singleByteDeflate() throws {
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "deflate")
        encoder.update(Self.bytesFromString("x"))
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "deflate")
        #expect(Array(plain.storage) == Array("x".utf8))
    }

    // MARK: - Level coverage

    @Test(".fast level with gzip")
    func fastLevelGzip() throws {
        let payload = Self.bytesFromString("The quick brown fox jumps over the lazy dog.")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip", level: .fast)
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test(".best level with deflate")
    func bestLevelDeflate() throws {
        let payload = Self.bytesFromString("compressible compressible compressible")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "deflate", level: .best)
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "deflate")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    // MARK: - Multi-coding throws

    @Test("multi-coding 'gzip, br' throws multipleCodingsNotStreamable at init")
    func multiCodingGzipBrThrows() {
        do {
            _ = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip, br")
            Issue.record("expected throw")
        } catch ContentEncodingError.multipleCodingsNotStreamable(let header) {
            #expect(header == "gzip, br")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("multi-coding 'deflate, gzip' throws")
    func multiCodingDeflateGzipThrows() {
        do {
            _ = try ContentEncoding.Streaming.Encoder(contentEncoding: "deflate, gzip")
            Issue.record("expected throw")
        } catch ContentEncodingError.multipleCodingsNotStreamable {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: - Unsupported / error cases

    @Test("unsupported coding 'zstd' throws unsupportedEncoding")
    func unsupportedZstdThrows() {
        do {
            _ = try ContentEncoding.Streaming.Encoder(contentEncoding: "zstd")
            Issue.record("expected throw")
        } catch ContentEncodingError.unsupportedEncoding(let coding) {
            #expect(coding == "zstd")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("double-finish throws encoderFinished")
    func doubleFinishThrows() throws {
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip")
        encoder.update(Self.bytesFromString("data"))
        _ = try encoder.finish()
        do {
            _ = try encoder.finish()
            Issue.record("expected throw")
        } catch ContentEncodingError.encoderFinished {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("update after finish is silent no-op (then double-finish throws)")
    func updateAfterFinishNoOp() throws {
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip")
        encoder.update(Self.bytesFromString("first"))
        let compressed = try encoder.finish()
        encoder.update(Self.bytesFromString("second"))
        do {
            _ = try encoder.finish()
            Issue.record("expected throw")
        } catch ContentEncodingError.encoderFinished {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip")
        #expect(Array(plain.storage) == Array("first".utf8))
    }

    // MARK: - Header parsing

    @Test("whitespace-tolerant header '  gzip  ' is accepted")
    func whitespaceTolerantHeader() throws {
        let payload = Self.bytesFromString("ws")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "  gzip  ")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip")
        #expect(Array(plain.storage) == Array(payload.storage))
    }
}
