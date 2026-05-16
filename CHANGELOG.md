# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.5.0] — 2026-05-16

### Added
- **Streaming encoder** — `ContentEncoding.Streaming.Encoder(contentEncoding:level:) throws` / `update(_:)` / `finish() throws -> Bytes`. Dispatches to the streaming encoders in swift-gzip / swift-zlib / swift-brotli (all v0.3+) per the configured coding. Empty / whitespace header and `identity` coding buffer and return verbatim at `finish()`.
- `ContentEncoding.Streaming` public namespace enum.
- `ContentEncodingError.multipleCodingsNotStreamable(String)` — thrown at init when the header contains multiple codings.
- `ContentEncodingError.encoderFinished` — thrown when `finish()` is called on an already-finished encoder.
- 18 new tests covering per-coding round-trip (identity / gzip / x-gzip / deflate / x-deflate / br), multi-chunk feeds, level coverage, multi-coding-throws, unsupported-coding errors, and double-finish / update-after-finish edge cases.

### Multi-coding limitation
- v0.5 streaming supports **single-coding only**. Multi-coding chains like `"gzip, br"` throw `ContentEncodingError.multipleCodingsNotStreamable` at init.
- The underlying streaming encoders in swift-gzip / swift-zlib / swift-brotli emit output bytes only at `finish()`, not during `update(_:)`. Composing them in a chain would require buffering each encoder's full output before feeding it to the next — defeating the streaming purpose. A coordinated codec-tier `drain() -> Bytes` API is a Phase 26+ candidate that would unblock multi-coding streaming in a future v0.6.
- For multi-coding bodies, callers should buffer the input and use the v0.4 one-shot `ContentEncoding.encode(_:contentEncoding:level:)` path.

### Dependencies
- swift-gzip dep bumped 0.2.0 → 0.3.0 (for `Gzip.Streaming.Encoder`).
- swift-zlib dep bumped 0.2.0 → 0.3.0 (for `Zlib.Streaming.Encoder`).
- swift-brotli dep bumped 0.2.0 → 0.3.0 (for `Brotli.Streaming.Encoder`).
- swift-deflate dep unchanged (not used directly).

### Migration (v0.4 → v0.5)
- **Additive only — non-breaking.** All v0.4 APIs unchanged.
- `ContentEncoding.encode(_:contentEncoding:level:)` continues byte-equal output.
- `ContentEncoding.decode(_:contentEncoding:)` unchanged from v0.1.
- `ContentEncodingError` adds 2 new cases (additive; existing cases unchanged).

### Out of scope (deferred to v0.6+)
- **Multi-coding streaming chains.** Requires Phase 26+ codec-tier `drain()` API.
- **Streaming decode.** No codec package has streaming decode yet.
- **`reset()` for encoder reuse.**
- **Explicit flush API.**
- **Level → brotli Quality mapping.** v0.5 `br` streaming ignores `level` (uses brotli `.default` quality), matching v0.4 one-shot behavior.

### Phase 25
- Tranche 25A of [RFC-0030](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0030-phase-25-anchor-swift-content-encoding-v0.5-streaming.md). Wires the codec-tier streaming sweep (Phase 22-24) through the HTTP `Content-Encoding` layer for single-coding bodies.

## [0.4.0] - 2026-05-13

### Added
- **`br` (Brotli) encode** via swift-brotli 0.2.0's encoder. `ContentEncoding.encode(_:contentEncoding:level:)` now accepts `br` (and multi-coding chains containing `br`). Closes symmetric encode/decode story across all five web codings (identity / gzip / deflate / br + raw deflate via swift-deflate direct).
- `ContentEncodingError.encodingFailed(String)` case for encoder-side errors (additive; existing switch consumers must extend their exhaustive match).
- 2 new tests covering `br` encode round-trip and `br` in encode chain.

### Changed
- swift-brotli dep bumped 0.1.0 → 0.2.0 (encoder added in upstream's v0.2).

### Notes
- The `level` parameter is ignored for `br` — v0.4 always uses brotli `.default` quality (level 6). Map Level → brotli Quality in a future v0.5 if adopter demand surfaces.
- swift-brotli v0.2's encoder produces valid brotli streams but does NOT match the reference encoder's compression ratio. See swift-brotli v0.2 CHANGELOG for the explicit non-goals list.

### Unchanged from v0.3
- Decode path bit-for-bit unchanged.

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
