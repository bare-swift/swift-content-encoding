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

    // MARK: - Multi-coding streaming (v0.6+)

    @Test("multi-coding 'gzip, br' round-trips via cascaded decode")
    func multiCodingGzipBr() throws {
        let payload = Self.bytesFromString("hello multi-coding world hello multi-coding world")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip, br")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip, br")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("multi-coding 'br, gzip' round-trips")
    func multiCodingBrGzip() throws {
        let payload = Self.bytesFromString("hello multi-coding")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "br, gzip")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "br, gzip")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("multi-coding 'deflate, gzip' round-trips")
    func multiCodingDeflateGzip() throws {
        let payload = Self.bytesFromString("zlib then gzip chain")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "deflate, gzip")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "deflate, gzip")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("3-coding chain 'gzip, deflate, br' round-trips")
    func multiCodingThreeStage() throws {
        let payload = Self.bytesFromString("three-stage cascade test payload")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip, deflate, br")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip, deflate, br")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("'identity, gzip' equals pure gzip decoded output")
    func multiCodingIdentityGzip() throws {
        let payload = Self.bytesFromString("identity-then-gzip test")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "identity, gzip")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "identity, gzip")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("'gzip, identity' equals pure gzip decoded output")
    func multiCodingGzipIdentity() throws {
        let payload = Self.bytesFromString("gzip-then-identity test")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip, identity")
        encoder.update(payload)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip, identity")
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("multi-coding with two chunks round-trips to concatenation")
    func multiCodingTwoChunks() throws {
        let chunk1 = Self.bytesFromString("hel")
        let chunk2 = Self.bytesFromString("lo")
        var encoder = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip, br")
        encoder.update(chunk1)
        encoder.update(chunk2)
        let compressed = try encoder.finish()
        let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip, br")
        #expect(Array(plain.storage) == Array("hello".utf8))
    }

    @Test("multi-coding 'gzip, zstd' (unsupported in pipeline) throws unsupportedEncoding")
    func multiCodingUnsupportedInPipeline() {
        do {
            _ = try ContentEncoding.Streaming.Encoder(contentEncoding: "gzip, zstd")
            Issue.record("expected throw")
        } catch ContentEncodingError.unsupportedEncoding(let coding) {
            #expect(coding == "zstd")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("multipleCodingsNotStreamable case is still defined (backwards-compat)")
    func multipleCodingsNotStreamableCaseStillDefined() {
        // The error case is kept in the enum for backwards-compat with v0.5
        // callers; v0.6 does not throw it. This test just verifies the case
        // is still pattern-matchable.
        let e: ContentEncodingError = .multipleCodingsNotStreamable("test")
        switch e {
        case .multipleCodingsNotStreamable(let header):
            #expect(header == "test")
        default:
            Issue.record("expected .multipleCodingsNotStreamable")
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

@Suite("Streaming decoder (v0.7)")
struct StreamingDecoderTests {
    private static func bytesFromString(_ s: String) -> Bytes {
        var b = Bytes()
        b.append(contentsOf: Array(s.utf8))
        return b
    }

    // MARK: - Single-coding round-trip

    @Test("empty header → identity passthrough round-trips")
    func emptyHeaderIdentity() throws {
        let payload = Self.bytesFromString("hello world")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "")
        decoder.update(payload)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("identity coding round-trips")
    func identityRoundTrip() throws {
        let payload = Self.bytesFromString("hello world")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "identity")
        decoder.update(payload)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("gzip coding decodes one-shot-encoded input")
    func gzipRoundTrip() throws {
        let payload = Self.bytesFromString(
            "The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "gzip")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("x-gzip alias decodes")
    func xGzipAlias() throws {
        let payload = Self.bytesFromString("alias")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "x-gzip")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("deflate coding decodes one-shot-encoded input (zlib-framed)")
    func deflateRoundTrip() throws {
        let payload = Self.bytesFromString(
            "The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "deflate")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "deflate")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("x-deflate alias decodes")
    func xDeflateAlias() throws {
        let payload = Self.bytesFromString("alias")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "deflate")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "x-deflate")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("br coding decodes one-shot-encoded input")
    func brRoundTrip() throws {
        let payload = Self.bytesFromString(
            "The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "br")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "br")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    // MARK: - Multi-coding round-trip

    @Test("gzip, br multi-coding decodes (reverse-order cascade)")
    func gzipBrMultiCoding() throws {
        let payload = Self.bytesFromString(
            "The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip, br")
        var decoder = try ContentEncoding.Streaming.Decoder(
            contentEncoding: "gzip, br")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("br, gzip multi-coding decodes (reverse-order cascade)")
    func brGzipMultiCoding() throws {
        let payload = Self.bytesFromString(
            "The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "br, gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(
            contentEncoding: "br, gzip")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("deflate, gzip multi-coding decodes")
    func deflateGzipMultiCoding() throws {
        let payload = Self.bytesFromString(
            "pangram: The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "deflate, gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(
            contentEncoding: "deflate, gzip")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("identity, gzip multi-coding decodes (identity stage in chain)")
    func identityGzipMultiCoding() throws {
        let payload = Self.bytesFromString("identity passthrough then gzip")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "identity, gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(
            contentEncoding: "identity, gzip")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("three-coding chain gzip, deflate, br decodes")
    func threeCodingChain() throws {
        let payload = Self.bytesFromString(
            "three-stage cascade through all three compression codings")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip, deflate, br")
        var decoder = try ContentEncoding.Streaming.Decoder(
            contentEncoding: "gzip, deflate, br")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    // MARK: - Multi-chunk input

    @Test("two-chunk split of compressed gzip input decodes")
    func twoChunkSplitGzip() throws {
        let payload = Self.bytesFromString(
            "The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip")
        let bytes = Array(compressed.storage)
        let mid = bytes.count / 2
        let chunk1 = Bytes(Array(bytes[0..<mid]))
        let chunk2 = Bytes(Array(bytes[mid..<bytes.count]))
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "gzip")
        decoder.update(chunk1)
        decoder.update(chunk2)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("tiny 1-byte chunks of br input decode")
    func tinyOneByteChunksBr() throws {
        let payload = Self.bytesFromString("hello world")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "br")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "br")
        for byte in compressed.storage {
            decoder.update(Bytes([byte]))
        }
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("empty chunk in middle is no-op")
    func emptyChunkInMiddle() throws {
        let payload = Self.bytesFromString("hello world")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "deflate")
        let bytes = Array(compressed.storage)
        let mid = bytes.count / 2
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "deflate")
        decoder.update(Bytes(Array(bytes[0..<mid])))
        decoder.update(Bytes())
        decoder.update(Bytes(Array(bytes[mid..<bytes.count])))
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    // MARK: - Edge cases

    @Test("empty stream + gzip header decodes via one-shot encoder")
    func emptyStreamGzip() throws {
        let compressed = try ContentEncoding.encode(
            Bytes(), contentEncoding: "gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "gzip")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(plain.storage.isEmpty)
    }

    @Test("single-byte payload via br decodes")
    func singleBytePayloadBr() throws {
        let payload = Bytes([0x5A])
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "br")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "br")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    @Test("whitespace-tolerant header '  gzip  ' is accepted")
    func whitespaceTolerantHeaderDec() throws {
        let payload = Self.bytesFromString("ws")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(
            contentEncoding: "  gzip  ")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
    }

    // MARK: - Error cases

    @Test("unsupported coding throws at init")
    func unsupportedCodingThrows() throws {
        do {
            _ = try ContentEncoding.Streaming.Decoder(contentEncoding: "zstd")
            Issue.record("expected throw on unsupported coding")
        } catch ContentEncodingError.unsupportedEncoding(let name) {
            #expect(name == "zstd")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("unsupported coding in multi-coding chain throws at init")
    func unsupportedCodingInChain() throws {
        do {
            _ = try ContentEncoding.Streaming.Decoder(
                contentEncoding: "gzip, zstd")
            Issue.record("expected throw on unsupported coding in chain")
        } catch ContentEncodingError.unsupportedEncoding(let name) {
            #expect(name == "zstd")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("truncated gzip input throws decodingFailed")
    func truncatedGzipInput() throws {
        let payload = Self.bytesFromString(
            "The quick brown fox jumps over the lazy dog.")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip")
        let bytes = Array(compressed.storage)
        let truncated = Bytes(Array(bytes[0..<(bytes.count - 4)]))
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "gzip")
        decoder.update(truncated)
        do {
            _ = try decoder.finish()
            Issue.record("expected throw on truncated input")
        } catch ContentEncodingError.decodingFailed {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("double-finish throws decoderFinished")
    func doubleFinishThrows() throws {
        let payload = Self.bytesFromString("hello")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "gzip")
        decoder.update(compressed)
        _ = try decoder.finish()
        do {
            _ = try decoder.finish()
            Issue.record("expected throw on second finish")
        } catch ContentEncodingError.decoderFinished {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("update after finish is silent no-op (then double-finish throws)")
    func updateAfterFinishNoOp() throws {
        let payload = Self.bytesFromString("first")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip")
        var decoder = try ContentEncoding.Streaming.Decoder(contentEncoding: "gzip")
        decoder.update(compressed)
        let plain = try decoder.finish()
        #expect(Array(plain.storage) == Array(payload.storage))
        decoder.update(Self.bytesFromString("garbage"))
        do {
            _ = try decoder.finish()
            Issue.record("expected throw on second finish")
        } catch ContentEncodingError.decoderFinished {
            // expected
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: - Equivalence with one-shot

    @Test("streaming decode equals ContentEncoding.decode one-shot (multi-coding)")
    func streamingEqualsOneShotMultiCoding() throws {
        let payload = Self.bytesFromString(
            "equivalence check for multi-coding decode path")
        let compressed = try ContentEncoding.encode(
            payload, contentEncoding: "gzip, br")
        let oneShot = try ContentEncoding.decode(
            compressed, contentEncoding: "gzip, br")
        var decoder = try ContentEncoding.Streaming.Decoder(
            contentEncoding: "gzip, br")
        decoder.update(compressed)
        let streamed = try decoder.finish()
        #expect(Array(streamed.storage) == Array(oneShot.storage))
    }
}
