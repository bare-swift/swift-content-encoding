// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Errors thrown by ``ContentEncoding/decode(_:contentEncoding:)`` and
/// ``ContentEncoding/encode(_:contentEncoding:level:)``.
public enum ContentEncodingError: Error, Equatable, Sendable {
    /// Header carried a coding name not supported (e.g. `zstd`, `compress`).
    /// The string is the offending coding.
    case unsupportedEncoding(String)

    /// Underlying decoder rejected the payload. The string is a
    /// best-effort description.
    case decodingFailed(String)

    /// Underlying encoder rejected the input. The string is a
    /// best-effort description (added in v0.4 alongside `br` encode).
    case encodingFailed(String)

    /// Streaming encoder: header carried multiple codings (e.g. "gzip, br").
    /// v0.5 streaming supports single-coding only. Fall back to
    /// ``ContentEncoding/encode(_:contentEncoding:level:)`` one-shot for
    /// multi-coding chains.
    case multipleCodingsNotStreamable(String)

    /// Encoder: ``ContentEncoding/Streaming/Encoder/finish()`` was called
    /// twice on the same encoder.
    case encoderFinished
}
