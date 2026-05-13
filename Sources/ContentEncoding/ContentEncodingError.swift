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
}
