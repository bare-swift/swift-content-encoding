// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Brotli
import Deflate
import Gzip
import Zlib

extension ContentEncoding.Streaming {
    /// Streaming HTTP `Content-Encoding` encoder (v0.5+). Dispatches to
    /// the streaming encoders in swift-gzip / swift-zlib / swift-brotli
    /// per the configured coding.
    ///
    /// **Single-coding only.** Multi-coding headers (e.g.
    /// `"gzip, br"`) throw ``ContentEncodingError/multipleCodingsNotStreamable(_:)``
    /// at init. Callers needing multi-coding streaming must fall back to
    /// ``ContentEncoding/encode(_:contentEncoding:level:)`` one-shot.
    /// (Multi-coding streaming requires a codec-tier `drain()` API that
    /// is a Phase 26+ candidate.)
    ///
    /// Usage:
    /// ```swift
    /// var encoder = try ContentEncoding.Streaming.Encoder(
    ///     contentEncoding: "gzip", level: .default
    /// )
    /// encoder.update(chunk1)
    /// encoder.update(chunk2)
    /// let compressed = try encoder.finish()
    /// let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip")
    /// // plain == chunk1 + chunk2
    /// ```
    ///
    /// **Supported codings (case-insensitive, single only):**
    /// - empty / whitespace header — identity passthrough.
    /// - `identity` — passthrough.
    /// - `gzip`, `x-gzip` — RFC 1952 (via swift-gzip v0.3+).
    /// - `deflate`, `x-deflate` — zlib-framed DEFLATE (via swift-zlib v0.3+).
    /// - `br` — Brotli (via swift-brotli v0.3+). The `level` parameter is
    ///   ignored for `br`; the inner brotli encoder always uses
    ///   `Brotli.Quality.default`.
    ///
    /// After ``finish()`` the encoder is in the finished state.
    /// ``update(_:)`` after finish is a silent no-op; double-finish throws
    /// ``ContentEncodingError/encoderFinished``.
    public struct Encoder: Sendable {
        public typealias Level = Deflate.Encoder.Level

        private enum State: Sendable {
            case open
            case finished
        }

        private enum InnerEncoder: Sendable {
            /// Identity coding: bytes accumulate verbatim and are returned
            /// at `finish()`.
            case identity(Bytes)
            case gzip(Gzip.Streaming.Encoder)
            /// "deflate" Content-Encoding is zlib-framed DEFLATE per RFC 7230 § 4.2.2.
            case deflate(Zlib.Streaming.Encoder)
            case brotli(Brotli.Streaming.Encoder)
        }

        public let header: String
        public let level: Level

        private var inner: InnerEncoder
        private var state: State

        public init(
            contentEncoding header: String,
            level: Level = .default
        ) throws(ContentEncodingError) {
            self.header = header
            self.level = level

            let codings = ContentEncoding.parseCodings(header)
            if codings.isEmpty {
                // Empty / whitespace header → identity passthrough.
                self.inner = .identity(Bytes())
                self.state = .open
                return
            }
            if codings.count > 1 {
                throw .multipleCodingsNotStreamable(header)
            }
            let coding = codings[0]
            switch coding {
            case "identity":
                self.inner = .identity(Bytes())
            case "gzip", "x-gzip":
                self.inner = .gzip(Gzip.Streaming.Encoder(level: level))
            case "deflate", "x-deflate":
                self.inner = .deflate(Zlib.Streaming.Encoder(level: level))
            case "br":
                // Brotli.Streaming.Encoder(quality:) only throws on out-of-range
                // quality. `.default` is always valid. Wrap defensively.
                do {
                    self.inner = .brotli(try Brotli.Streaming.Encoder(quality: .default))
                } catch {
                    throw .encodingFailed("br: \(error)")
                }
            default:
                throw .unsupportedEncoding(coding)
            }
            self.state = .open
        }

        /// Feed a chunk to the inner streaming encoder. Empty chunk = no-op.
        /// Silent no-op when called after ``finish()``.
        public mutating func update(_ chunk: Bytes) {
            guard case .open = state else { return }
            if chunk.isEmpty { return }
            switch inner {
            case .identity(var acc):
                acc.append(contentsOf: chunk.storage)
                inner = .identity(acc)
            case .gzip(var enc):
                enc.update(chunk)
                inner = .gzip(enc)
            case .deflate(var enc):
                enc.update(chunk)
                inner = .deflate(enc)
            case .brotli(var enc):
                enc.update(chunk)
                inner = .brotli(enc)
            }
        }

        /// Finalize the inner streaming encoder and return the encoded
        /// bytes. Throws ``ContentEncodingError/encoderFinished`` on
        /// double-call.
        public mutating func finish() throws(ContentEncodingError) -> Bytes {
            guard case .open = state else { throw .encoderFinished }
            state = .finished

            switch inner {
            case .identity(let acc):
                return acc
            case .gzip(var enc):
                do {
                    return try enc.finish()
                } catch {
                    throw .encodingFailed("gzip: \(error)")
                }
            case .deflate(var enc):
                do {
                    return try enc.finish()
                } catch {
                    throw .encodingFailed("deflate: \(error)")
                }
            case .brotli(var enc):
                do {
                    return try enc.finish()
                } catch {
                    throw .encodingFailed("br: \(error)")
                }
            }
        }
    }
}
