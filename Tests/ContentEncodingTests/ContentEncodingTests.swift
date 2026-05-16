// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

import Testing
@testable import ContentEncoding
import Bytes

private func bytes(_ raw: [UInt8]) -> Bytes {
    var b = Bytes(reservingCapacity: raw.count)
    for x in raw { b.append(x) }
    return b
}

private func string(_ b: Bytes) -> String {
    String(decoding: b.storage, as: UTF8.self)
}

/// Real gzip / zlib payloads of "abc" — same vectors the underlying
/// packages use, so this suite exercises the multiplexer dispatch
/// rather than the codecs' inflate logic (which has its own coverage).
private let gzipAbc: [UInt8] = [
    0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
    0x4B, 0x4C, 0x4A, 0x06, 0x00,
    0xC2, 0x41, 0x24, 0x35,  // CRC32
    0x03, 0x00, 0x00, 0x00,  // ISIZE = 3
]

private let zlibAbc: [UInt8] = [
    0x78, 0x9C, 0x4B, 0x4C, 0x4A, 0x06, 0x00, 0x02, 0x4D, 0x01, 0x27,
]

@Suite("Coding parsing")
struct ParseCodingsTests {
    @Test("empty header → empty list")
    func empty() {
        #expect(ContentEncoding.parseCodings("") == [])
        #expect(ContentEncoding.parseCodings("   ") == [])
    }

    @Test("single coding")
    func single() {
        #expect(ContentEncoding.parseCodings("gzip") == ["gzip"])
        #expect(ContentEncoding.parseCodings("  gzip  ") == ["gzip"])
    }

    @Test("multi-coding")
    func multi() {
        #expect(ContentEncoding.parseCodings("gzip, deflate") == ["gzip", "deflate"])
        #expect(ContentEncoding.parseCodings("gzip,deflate") == ["gzip", "deflate"])
        #expect(ContentEncoding.parseCodings("  gzip  ,  deflate  ") == ["gzip", "deflate"])
    }

    @Test("case insensitivity (lowercased)")
    func caseInsensitive() {
        #expect(ContentEncoding.parseCodings("GZIP") == ["gzip"])
        #expect(ContentEncoding.parseCodings("Gzip, DEFLATE") == ["gzip", "deflate"])
    }

    @Test("empty entries dropped")
    func emptyEntries() {
        #expect(ContentEncoding.parseCodings(",,gzip,,") == ["gzip"])
    }
}

@Suite("Decode — single coding")
struct SingleCodingTests {
    @Test("identity (passthrough)")
    func identity() throws {
        let payload = bytes([0x01, 0x02, 0x03])
        let out = try ContentEncoding.decode(payload, contentEncoding: "identity")
        #expect(out == payload)
    }

    @Test("empty header (passthrough)")
    func emptyHeader() throws {
        let payload = bytes([0x01, 0x02, 0x03])
        let out = try ContentEncoding.decode(payload, contentEncoding: "")
        #expect(out == payload)
    }

    @Test("gzip")
    func gzip() throws {
        let out = try ContentEncoding.decode(bytes(gzipAbc), contentEncoding: "gzip")
        #expect(string(out) == "abc")
    }

    @Test("x-gzip alias")
    func xGzip() throws {
        let out = try ContentEncoding.decode(bytes(gzipAbc), contentEncoding: "x-gzip")
        #expect(string(out) == "abc")
    }

    @Test("deflate (zlib-framed per RFC 7230)")
    func deflate() throws {
        let out = try ContentEncoding.decode(bytes(zlibAbc), contentEncoding: "deflate")
        #expect(string(out) == "abc")
    }

    @Test("x-deflate alias")
    func xDeflate() throws {
        let out = try ContentEncoding.decode(bytes(zlibAbc), contentEncoding: "x-deflate")
        #expect(string(out) == "abc")
    }

    @Test("uppercase header")
    func uppercase() throws {
        let out = try ContentEncoding.decode(bytes(gzipAbc), contentEncoding: "GZIP")
        #expect(string(out) == "abc")
    }

    @Test("whitespace tolerant")
    func whitespace() throws {
        let out = try ContentEncoding.decode(bytes(gzipAbc), contentEncoding: "  gzip  ")
        #expect(string(out) == "abc")
    }

    @Test("br (Brotli) decode via swift-brotli")
    func brotli() throws {
        // python brotli.compress(b"hello world") = 0x0B 0x05 0x80 ... 0x03
        let helloBrotli: [UInt8] = [
            0x0B, 0x05, 0x80, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x03,
        ]
        let out = try ContentEncoding.decode(bytes(helloBrotli), contentEncoding: "br")
        #expect(string(out) == "hello world")
    }

    @Test("br uppercase header")
    func brotliUppercase() throws {
        let helloBrotli: [UInt8] = [
            0x0B, 0x05, 0x80, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x03,
        ]
        let out = try ContentEncoding.decode(bytes(helloBrotli), contentEncoding: "BR")
        #expect(string(out) == "hello world")
    }
}

@Suite("Decode — error paths")
struct ErrorPathsTests {
    @Test("unsupported coding throws")
    func unsupported() {
        // 'br' became supported in v0.3 (via swift-brotli). 'zstd' and
        // 'compress' remain unsupported.
        #expect(throws: ContentEncodingError.unsupportedEncoding("zstd")) {
            try ContentEncoding.decode(bytes([0, 1, 2]), contentEncoding: "zstd")
        }
        #expect(throws: ContentEncodingError.unsupportedEncoding("compress")) {
            try ContentEncoding.decode(bytes([0, 1, 2]), contentEncoding: "compress")
        }
    }

    @Test("malformed gzip payload surfaces as .decodingFailed")
    func malformedGzip() {
        let bad = bytes([0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00,
                         0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00, 0x00, 0x00])
        #expect(throws: (any Error).self) {
            try ContentEncoding.decode(bad, contentEncoding: "gzip")
        }
    }

    @Test("multi-coding with unsupported in chain throws")
    func multiCodingUnsupported() {
        // Even if the outer payload could decode, an unsupported
        // intermediate coding fails fast.
        #expect(throws: ContentEncodingError.unsupportedEncoding("zstd")) {
            try ContentEncoding.decode(bytes(gzipAbc), contentEncoding: "gzip, zstd")
        }
    }
}

@Suite("End-to-end")
struct EndToEndTests {
    /// Multi-coding round-trip: a payload that was first compressed with
    /// gzip, then re-compressed with zlib (so the encoder header would
    /// be `Content-Encoding: gzip, deflate`). We construct this by
    /// running the identity case in reverse — gzip(payload) wrapped in
    /// zlib's wrapper... but constructing it requires an encoder we
    /// don't have. Instead this test exercises the simpler
    /// gzip-after-identity case to verify multi-coding chaining.
    @Test("`identity, gzip` decodes via gzip path")
    func identityThenGzip() throws {
        // Decode order is reverse of encoding order — `identity, gzip`
        // means encoder applied identity (no-op) then gzip; decoder
        // applies gzip then identity. Result is the gzip-decoded payload.
        let out = try ContentEncoding.decode(bytes(gzipAbc), contentEncoding: "identity, gzip")
        #expect(string(out) == "abc")
    }
}

@Suite("ContentEncoding.encode API surface")
struct ContentEncodingEncodeAPITests {
    @Test("Level typealias exists and exposes the four levels")
    func levels() {
        let levels: [ContentEncoding.Level] = [.none, .fast, .default, .best]
        #expect(levels.count == 4)
    }

    @Test("encode with empty header is passthrough")
    func emptyHeaderPassthrough() throws {
        let input = Bytes([0x41, 0x42, 0x43])
        let out = try ContentEncoding.encode(input, contentEncoding: "")
        #expect(out.storage == input.storage)
    }

    @Test("encode with 'identity' is passthrough")
    func identityPassthrough() throws {
        let input = Bytes([0x41, 0x42, 0x43])
        let out = try ContentEncoding.encode(input, contentEncoding: "identity")
        #expect(out.storage == input.storage)
    }

    @Test("encode with 'gzip' starts with the gzip magic bytes")
    func gzipMagic() throws {
        let input = Bytes([0x41, 0x42, 0x43])
        let out = try ContentEncoding.encode(input, contentEncoding: "gzip")
        #expect(out.storage.count >= 3)
        #expect(out.storage[0] == 0x1F)
        #expect(out.storage[1] == 0x8B)
        #expect(out.storage[2] == 0x08)
    }

    @Test("encode with 'deflate' starts with the zlib CMF (0x78)")
    func deflateZlibFraming() throws {
        let input = Bytes([0x41, 0x42, 0x43])
        let out = try ContentEncoding.encode(input, contentEncoding: "deflate")
        #expect(out.storage.count >= 2)
        #expect(out.storage[0] == 0x78)
        let v = (UInt32(out.storage[0]) << 8) | UInt32(out.storage[1])
        #expect(v % 31 == 0)
    }
}

@Suite("ContentEncoding encode → decode round-trip")
struct ContentEncodingRoundTripTests {
    private static let sample = Bytes([
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x2C, 0x20, 0x62, 0x61, 0x72, 0x65,
        0x2D, 0x73, 0x77, 0x69, 0x66, 0x74, 0x21,
    ])

    @Test("gzip round-trip at all four levels")
    func gzipAllLevels() throws {
        for level: ContentEncoding.Level in [.none, .fast, .default, .best] {
            let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: "gzip", level: level)
            let back = try ContentEncoding.decode(encoded, contentEncoding: "gzip")
            #expect(back.storage == Self.sample.storage,
                    "gzip failed at \(level)")
        }
    }

    @Test("x-gzip alias round-trips")
    func xGzipAlias() throws {
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: "x-gzip")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "x-gzip")
        #expect(back.storage == Self.sample.storage)
    }

    @Test("deflate round-trip at all four levels")
    func deflateAllLevels() throws {
        for level: ContentEncoding.Level in [.none, .fast, .default, .best] {
            let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: "deflate", level: level)
            let back = try ContentEncoding.decode(encoded, contentEncoding: "deflate")
            #expect(back.storage == Self.sample.storage,
                    "deflate failed at \(level)")
        }
    }

    @Test("x-deflate alias round-trips")
    func xDeflateAlias() throws {
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: "x-deflate")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "x-deflate")
        #expect(back.storage == Self.sample.storage)
    }

    @Test("empty input round-trips through gzip")
    func emptyGzip() throws {
        let empty = Bytes()
        let encoded = try ContentEncoding.encode(empty, contentEncoding: "gzip")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "gzip")
        #expect(back.storage == empty.storage)
    }

    @Test("empty input round-trips through deflate")
    func emptyDeflate() throws {
        let empty = Bytes()
        let encoded = try ContentEncoding.encode(empty, contentEncoding: "deflate")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "deflate")
        #expect(back.storage == empty.storage)
    }

    @Test("case-insensitive coding match on encode")
    func caseInsensitive() throws {
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: "GZIP")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "gzip")
        #expect(back.storage == Self.sample.storage)
    }
}

@Suite("ContentEncoding multi-coding")
struct ContentEncodingMultiCodingTests {
    private static let sample = Bytes([0x48, 0x69])

    @Test("'gzip, deflate' encode then decode round-trips")
    func gzipThenDeflate() throws {
        let header = "gzip, deflate"
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: header)
        let back = try ContentEncoding.decode(encoded, contentEncoding: header)
        #expect(back.storage == Self.sample.storage)
    }

    @Test("'deflate, gzip' encode then decode round-trips")
    func deflateThenGzip() throws {
        let header = "deflate, gzip"
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: header)
        let back = try ContentEncoding.decode(encoded, contentEncoding: header)
        #expect(back.storage == Self.sample.storage)
    }

    @Test("'identity, gzip' encode then decode round-trips")
    func identityThenGzip() throws {
        let header = "identity, gzip"
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: header)
        let back = try ContentEncoding.decode(encoded, contentEncoding: header)
        #expect(back.storage == Self.sample.storage)
    }

    @Test("RFC 9110 § 8.4 ordering: encode left-to-right matches decoder reverse")
    func leftToRightOrdering() throws {
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: "gzip, deflate")
        #expect(encoded.storage[0] == 0x78,
                "expected outer zlib framing; got 0x\(String(encoded.storage[0], radix: 16))")
    }

    @Test("whitespace-tolerant multi-coding parsing")
    func whitespaceTolerant() throws {
        let header = "  gzip  ,   deflate  "
        let encoded = try ContentEncoding.encode(Self.sample, contentEncoding: header)
        let back = try ContentEncoding.decode(encoded, contentEncoding: header)
        #expect(back.storage == Self.sample.storage)
    }
}

@Suite("ContentEncoding encode errors")
struct ContentEncodingEncodeErrorTests {
    @Test("'zstd' throws .unsupportedEncoding")
    func zstdRejected() {
        #expect(throws: ContentEncodingError.unsupportedEncoding("zstd")) {
            try ContentEncoding.encode(Bytes([0x41]), contentEncoding: "zstd")
        }
    }

    @Test("unsupported coding anywhere in chain throws")
    func unsupportedInChain() {
        #expect(throws: ContentEncodingError.unsupportedEncoding("compress")) {
            try ContentEncoding.encode(Bytes([0x41]), contentEncoding: "gzip, compress")
        }
    }
}

@Suite("ContentEncoding br encode (v0.4)")
struct ContentEncodingBrEncodeTests {
    @Test("br encode produces a valid brotli stream that decodes back")
    func brRoundTrip() throws {
        let input = Bytes(Array("Lorem ipsum dolor sit amet. ".utf8))
        let encoded = try ContentEncoding.encode(input, contentEncoding: "br")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "br")
        #expect(back.storage == input.storage)
    }

    @Test("br appears at end of chain (gzip, br) round-trips")
    func brInChain() throws {
        let input = Bytes(Array("Hello, world!".utf8))
        let encoded = try ContentEncoding.encode(input, contentEncoding: "gzip, br")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "gzip, br")
        #expect(back.storage == input.storage)
    }
}

@Suite("v0.1 API stability — additive only")
struct ContentEncodingV01StabilityTests {
    @Test("decode round-trips with v0.2 encoder")
    func decodeUnchanged() throws {
        let input = Bytes([0x68, 0x65, 0x6C, 0x6C, 0x6F])
        let encoded = try ContentEncoding.encode(input, contentEncoding: "gzip")
        let back = try ContentEncoding.decode(encoded, contentEncoding: "gzip")
        #expect(back.storage == input.storage)
    }

    @Test("ContentEncodingError cases (v0.4 adds encodingFailed)")
    func errorCasesPresent() {
        let e: ContentEncodingError = .unsupportedEncoding("test")
        switch e {
        case .unsupportedEncoding, .decodingFailed, .encodingFailed,
             .multipleCodingsNotStreamable, .encoderFinished:
            #expect(true)
        }
    }
}
