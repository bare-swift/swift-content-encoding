// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

/// Errors thrown by ``ContentEncoding/decode(_:contentEncoding:)``.
public enum ContentEncodingError: Error, Equatable, Sendable {
    /// Header carried a coding name not supported in v0.1 (e.g. `br`,
    /// `zstd`, `compress`). The string is the offending coding.
    case unsupportedEncoding(String)

    /// Underlying decoder rejected the payload. The string is a
    /// best-effort description; structured errors live in swift-gzip /
    /// swift-zlib for callers who want to pattern-match.
    case decodingFailed(String)
}
