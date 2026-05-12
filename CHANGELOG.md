# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.0] - 2026-05-12

### Added
- **`br` (Brotli) decode** routed through swift-brotli 0.1.0. `Content-Encoding: br` and case-insensitive variants now decode end-to-end. Multi-coding chains containing `br` (e.g. `gzip, br` for decode) work.
- 2 new tests covering `br` decode and case-insensitivity.

### Changed
- swift-brotli 0.1.0 added as a direct dep.

### Unchanged from v0.2
- `ContentEncoding.decode(_:contentEncoding:)` — bit-for-bit unchanged for non-`br` codings.
- `ContentEncoding.encode(_:contentEncoding:level:)` — `br` is NOT yet supported on encode (swift-brotli v0.1 ships decoder-only); encoding `br` throws `.unsupportedEncoding("br")`. Encoder support arrives when swift-brotli v0.2 ships.
- `ContentEncodingError` cases — both v0.1 cases preserved.

### Limitations (out of scope for v0.3)
- Brotli encoding. Lands when swift-brotli v0.2 ships.
- zstd, compress.
- Streaming encoding.

## [0.2.0] - 2026-05-12

### Added
- `ContentEncoding.encode(_:contentEncoding:level:)` — mirror of the v0.1 decoder. Parses the header into a coding list and applies them left-to-right per RFC 9110 § 8.4. Supports `identity`, `gzip` / `x-gzip` (via swift-gzip v0.2), and `deflate` / `x-deflate` (via swift-zlib v0.2). Empty / whitespace-only header → passthrough.
- `ContentEncoding.Level` typealias for `Deflate.Encoder.Level` — `.none` / `.fast` / `.default` / `.best`. Forwarded to the underlying codec; `identity` ignores it.
- 22 new tests across 4 suites covering API surface, per-coding round-trip (gzip/x-gzip/deflate/x-deflate × four levels each), multi-coding round-trips (`gzip, deflate` / `deflate, gzip` / `identity, gzip` / whitespace-tolerant parsing), unsupported-coding errors (`br`, `zstd`, unsupported in chain), and v0.1 stability.

### Changed
- swift-gzip dep bumped from 0.1.0 to 0.2.0.
- swift-zlib dep bumped from 0.1.0 to 0.2.0.
- swift-deflate 0.2.0 added as a direct dep so the public `Level` typealias resolves cleanly without forcing consumers to `import Deflate`.

### Unchanged from v0.1
- `ContentEncoding.decode(_:contentEncoding:)` — bit-for-bit unchanged.
- `ContentEncodingError` cases — both v0.1 cases preserved.
- Coding multiplex semantics (case-insensitivity, whitespace handling, comma-separated tokens, `identity` passthrough).

### Limitations (out of scope for v0.2)
- Brotli (`br`), zstd (`zstd`), legacy compress (`compress`). Brotli is a Phase 10 candidate per RFC-0014.
- Streaming encoding. v0.2 takes a single full `Bytes` input.
- `Accept-Encoding` negotiation — separate concern; consumers compose at the request layer.

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
