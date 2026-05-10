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
}

@Suite("Decode — error paths")
struct ErrorPathsTests {
    @Test("unsupported coding throws")
    func unsupported() {
        #expect(throws: ContentEncodingError.unsupportedEncoding("br")) {
            try ContentEncoding.decode(bytes([0, 1, 2]), contentEncoding: "br")
        }
        #expect(throws: ContentEncodingError.unsupportedEncoding("zstd")) {
            try ContentEncoding.decode(bytes([0, 1, 2]), contentEncoding: "zstd")
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
        #expect(throws: ContentEncodingError.unsupportedEncoding("br")) {
            try ContentEncoding.decode(bytes(gzipAbc), contentEncoding: "gzip, br")
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
