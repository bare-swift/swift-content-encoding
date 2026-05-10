// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Gzip
import Zlib

/// HTTP `Content-Encoding` header multiplexer — Sendable, Foundation-free.
///
/// Composes swift-gzip and swift-zlib into a single header-driven API:
/// pass the raw response body and the `Content-Encoding` header value,
/// get back the decoded plaintext.
///
/// ```swift
/// import ContentEncoding
/// import Bytes
///
/// let body: Bytes = ...                 // raw HTTP response body
/// let header = "gzip"                   // from response Content-Encoding
/// let plain = try ContentEncoding.decode(body, contentEncoding: header)
/// ```
///
/// **Supported codings (case-insensitive):**
/// - `identity` — passthrough.
/// - `gzip` and the legacy alias `x-gzip` — RFC 1952 (via swift-gzip).
/// - `deflate` and the legacy alias `x-deflate` — zlib-framed DEFLATE
///   per RFC 7230 § 4.2.2 (via swift-zlib). **Not** raw DEFLATE; if a
///   non-conformant origin sends raw DEFLATE under the `deflate` name,
///   reach for swift-deflate directly instead.
///
/// **Unsupported codings:** `br` (Brotli), `zstd`, `compress` —
/// ``ContentEncodingError/unsupportedEncoding(_:)`` is thrown.
///
/// **Multi-coding** values (e.g. `Content-Encoding: gzip, br`) apply
/// codings in declaration order at encode time, so decoding applies
/// them in **reverse** order. v0.1 supports multi-coding parsing and
/// dispatch; an unsupported coding anywhere in the chain throws.
public enum ContentEncoding: Sendable {
    /// Decode `bytes` per the `Content-Encoding` header value. An empty
    /// or whitespace-only header is treated as `identity` (passthrough).
    public static func decode(
        _ bytes: Bytes,
        contentEncoding header: String
    ) throws(ContentEncodingError) -> Bytes {
        let codings = parseCodings(header)
        if codings.isEmpty {
            return bytes
        }
        // RFC 9110 § 8.4: codings are applied left-to-right at encode time;
        // decoding reverses the list.
        var current = bytes
        for coding in codings.reversed() {
            current = try apply(coding: coding, to: current)
        }
        return current
    }

    private static func apply(
        coding: String,
        to bytes: Bytes
    ) throws(ContentEncodingError) -> Bytes {
        switch coding {
        case "identity":
            return bytes
        case "gzip", "x-gzip":
            do {
                return try Gzip.decode(bytes)
            } catch {
                throw .decodingFailed("gzip: \(error)")
            }
        case "deflate", "x-deflate":
            do {
                return try Zlib.decode(bytes)
            } catch {
                throw .decodingFailed("deflate: \(error)")
            }
        default:
            throw .unsupportedEncoding(coding)
        }
    }

    /// Parse an HTTP token-list header into lowercase codings, dropping
    /// empty entries. RFC 9110 § 5.6.1 token grammar is permissive on
    /// whitespace around commas; we trim aggressively.
    static func parseCodings(_ header: String) -> [String] {
        var out: [String] = []
        for token in header.split(separator: ",", omittingEmptySubsequences: true) {
            let trimmed = trimASCIIWhitespace(String(token))
            if trimmed.isEmpty { continue }
            out.append(asciiLowercased(trimmed))
        }
        return out
    }

    private static func trimASCIIWhitespace(_ s: String) -> String {
        var start = s.startIndex
        var end = s.endIndex
        while start < end, isASCIIWS(s[start]) { start = s.index(after: start) }
        while end > start {
            let prev = s.index(before: end)
            if isASCIIWS(s[prev]) { end = prev } else { break }
        }
        return String(s[start..<end])
    }

    private static func isASCIIWS(_ c: Character) -> Bool {
        c == " " || c == "\t" || c == "\n" || c == "\r"
    }

    private static func asciiLowercased(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            if scalar.value >= 0x41 && scalar.value <= 0x5A {
                out.unicodeScalars.append(Unicode.Scalar(scalar.value + 0x20)!)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
        return out
    }
}
