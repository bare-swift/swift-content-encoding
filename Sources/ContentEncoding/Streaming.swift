// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import Bytes
import Brotli
import Deflate
import Gzip
import Zlib

extension ContentEncoding.Streaming {
    /// Streaming HTTP `Content-Encoding` encoder (v0.5+; v0.6 adds multi-coding).
    ///
    /// Dispatches to the streaming encoders in swift-gzip / swift-zlib /
    /// swift-brotli per the configured coding(s). v0.6+ supports
    /// **multi-coding chains** (e.g., `"gzip, br"`) via cascaded `drain()`
    /// calls on the underlying v0.4+ codec streaming encoders.
    ///
    /// Per RFC 9110 § 8.4, multi-coding values apply codings left-to-right
    /// at encode time. So `"gzip, br"` means input → gzip-encode → br-encode
    /// → output; decoding reverses to br-decode → gzip-decode.
    ///
    /// Usage:
    /// ```swift
    /// var encoder = try ContentEncoding.Streaming.Encoder(
    ///     contentEncoding: "gzip, br", level: .default
    /// )
    /// encoder.update(chunk1)
    /// encoder.update(chunk2)
    /// let compressed = try encoder.finish()
    /// let plain = try ContentEncoding.decode(compressed, contentEncoding: "gzip, br")
    /// // plain == chunk1 + chunk2
    /// ```
    ///
    /// **Supported codings (case-insensitive):**
    /// - empty / whitespace header — identity passthrough.
    /// - `identity` — passthrough.
    /// - `gzip`, `x-gzip` — RFC 1952 (via swift-gzip v0.4+).
    /// - `deflate`, `x-deflate` — zlib-framed DEFLATE (via swift-zlib v0.4+).
    /// - `br` — Brotli (via swift-brotli v0.4+). The `level` parameter is
    ///   ignored for `br`; the inner brotli encoder always uses
    ///   `Brotli.Quality.default`.
    ///
    /// After ``finish()`` the encoder is in the finished state.
    /// ``update(_:)`` after finish is a silent no-op; double-finish throws
    /// ``ContentEncodingError/encoderFinished``.
    ///
    /// **Migration from v0.5 single-coding:** v0.5 threw
    /// ``ContentEncodingError/multipleCodingsNotStreamable(_:)`` at init for
    /// multi-coding headers. v0.6 supports them via the cascaded `drain()`
    /// pipeline. The error case is kept in the enum for backwards
    /// compatibility but is no longer thrown.
    public struct Encoder: Sendable {
        public typealias Level = Deflate.Encoder.Level

        private enum State: Sendable {
            case open
            case finished
        }

        /// One stage of the multi-coding pipeline. Identity is implemented as
        /// a buffering passthrough so the cascade composes uniformly.
        private enum InnerCoding: Sendable {
            case identity(Bytes)
            case gzip(Gzip.Streaming.Encoder)
            /// "deflate" Content-Encoding is zlib-framed DEFLATE per RFC 7230 § 4.2.2.
            case deflate(Zlib.Streaming.Encoder)
            case brotli(Brotli.Streaming.Encoder)

            mutating func update(_ chunk: Bytes) {
                switch self {
                case .identity(var acc):
                    acc.append(contentsOf: chunk.storage)
                    self = .identity(acc)
                case .gzip(var enc):
                    enc.update(chunk)
                    self = .gzip(enc)
                case .deflate(var enc):
                    enc.update(chunk)
                    self = .deflate(enc)
                case .brotli(var enc):
                    enc.update(chunk)
                    self = .brotli(enc)
                }
            }

            mutating func drain() -> Bytes {
                switch self {
                case .identity(let acc):
                    self = .identity(Bytes())
                    return acc
                case .gzip(var enc):
                    let d = enc.drain()
                    self = .gzip(enc)
                    return d
                case .deflate(var enc):
                    let d = enc.drain()
                    self = .deflate(enc)
                    return d
                case .brotli(var enc):
                    let d = enc.drain()
                    self = .brotli(enc)
                    return d
                }
            }

            mutating func finish() throws(ContentEncodingError) -> Bytes {
                switch self {
                case .identity(let acc):
                    self = .identity(Bytes())
                    return acc
                case .gzip(var enc):
                    do {
                        let f = try enc.finish()
                        self = .gzip(enc)
                        return f
                    } catch {
                        throw .encodingFailed("gzip: \(error)")
                    }
                case .deflate(var enc):
                    do {
                        let f = try enc.finish()
                        self = .deflate(enc)
                        return f
                    } catch {
                        throw .encodingFailed("deflate: \(error)")
                    }
                case .brotli(var enc):
                    do {
                        let f = try enc.finish()
                        self = .brotli(enc)
                        return f
                    } catch {
                        throw .encodingFailed("br: \(error)")
                    }
                }
            }
        }

        public let header: String
        public let level: Level

        private var pipeline: [InnerCoding]
        private var outputBuffer: ContiguousArray<UInt8>
        private var state: State

        public init(
            contentEncoding header: String,
            level: Level = .default
        ) throws(ContentEncodingError) {
            self.header = header
            self.level = level

            let codings = ContentEncoding.parseCodings(header)
            var stages: [InnerCoding] = []
            if codings.isEmpty {
                // Empty / whitespace header → single identity stage (passthrough).
                stages.append(.identity(Bytes()))
            } else {
                stages.reserveCapacity(codings.count)
                for coding in codings {
                    switch coding {
                    case "identity":
                        stages.append(.identity(Bytes()))
                    case "gzip", "x-gzip":
                        stages.append(.gzip(Gzip.Streaming.Encoder(level: level)))
                    case "deflate", "x-deflate":
                        stages.append(.deflate(Zlib.Streaming.Encoder(level: level)))
                    case "br":
                        // Brotli.Streaming.Encoder(quality:) only throws on out-of-range
                        // quality. `.default` is always valid. Wrap defensively.
                        do {
                            stages.append(.brotli(try Brotli.Streaming.Encoder(quality: .default)))
                        } catch {
                            throw .encodingFailed("br: \(error)")
                        }
                    default:
                        throw .unsupportedEncoding(coding)
                    }
                }
            }
            self.pipeline = stages
            self.outputBuffer = ContiguousArray<UInt8>()
            self.state = .open
        }

        /// Feed a chunk through the pipeline. Each stage's drained output
        /// feeds into the next stage; the final stage's drained output
        /// accumulates in the internal output buffer. Empty chunk = no-op.
        /// Silent no-op when called after ``finish()``.
        public mutating func update(_ chunk: Bytes) {
            guard case .open = state else { return }
            if chunk.isEmpty { return }
            var current = chunk
            for i in 0..<pipeline.count {
                pipeline[i].update(current)
                current = pipeline[i].drain()
            }
            outputBuffer.append(contentsOf: current.storage)
        }

        /// Finalize the pipeline left-to-right. Each stage's `finish()`
        /// output feeds into the next stage's `update`; the next stage's
        /// `finish()` then flushes those bytes plus any internal terminator.
        /// The last stage's `finish()` output is appended to the output
        /// buffer. Throws ``ContentEncodingError/encoderFinished`` on
        /// double-call.
        public mutating func finish() throws(ContentEncodingError) -> Bytes {
            guard case .open = state else { throw .encoderFinished }
            state = .finished

            for i in 0..<pipeline.count {
                let finalBytes = try pipeline[i].finish()
                if i + 1 < pipeline.count {
                    pipeline[i + 1].update(finalBytes)
                } else {
                    outputBuffer.append(contentsOf: finalBytes.storage)
                }
            }
            return Bytes(outputBuffer)
        }
    }
}
