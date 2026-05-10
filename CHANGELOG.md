# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-05-10

### Added
- `ContentEncoding.decode(_:contentEncoding:)` — header-driven multiplexer that parses an HTTP `Content-Encoding` value and dispatches to swift-gzip / swift-zlib / passthrough.
- Supported codings (case-insensitive): `identity`, `gzip`, `x-gzip`, `deflate`, `x-deflate`. The `deflate` coding routes through swift-zlib because HTTP `Content-Encoding: deflate` actually means zlib-framed DEFLATE per RFC 7230 § 4.2.2 — not raw DEFLATE.
- Multi-coding parsing per RFC 9110 § 8.4: comma-separated codings apply right-to-left at decode time.
- `ContentEncodingError` typed-throws enum (`unsupportedEncoding(String)` for `br`/`zstd`/`compress`/etc.; `decodingFailed(String)` for inner-codec failures).
- 17 tests across 4 suites covering: header parsing (empty, single, multi, case-insensitivity, empty entries dropped), single-coding decode (identity, gzip, x-gzip, deflate, x-deflate, uppercase, whitespace), error paths (unsupported, malformed payload, multi-coding with unsupported in chain), and multi-coding chaining.

### Dependencies
- `swift-bytes` 0.1.0 — input/output buffer.
- `swift-gzip` 0.1.0 — RFC 1952 decoder.
- `swift-zlib` 0.1.0 — RFC 1950 decoder.

### Limitations (out of scope for v0.1)
- **Brotli (`br`)** — different algorithm; throws `.unsupportedEncoding("br")` until the brotli package lands.
- **zstd**, **compress** (LZW) — defer.
- **Encoder side.** v0.1 decodes only; the v0.2 minor release adds an `encode(_:contentEncoding:)` method once the underlying codecs ship their encoders.
- `Codable` bridging — same Foundation-free / non-Codable differentiator as the rest of the ecosystem.
