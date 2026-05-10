# swift-content-encoding

HTTP `Content-Encoding` header multiplexer (identity, gzip, deflate) — Sendable, Foundation-free.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-content-encoding.git", from: "0.1.0")
```

Then depend on the `ContentEncoding` product:

```swift
.product(name: "ContentEncoding", package: "swift-content-encoding")
```

## Usage

```swift
import ContentEncoding
import Bytes

let body: Bytes = ...                 // raw HTTP response body
let header = "gzip"                   // from response Content-Encoding
let plain = try ContentEncoding.decode(body, contentEncoding: header)
```

## Scope

`swift-content-encoding` v0.1 routes HTTP `Content-Encoding` header values to swift-gzip / swift-zlib / passthrough:

- **`identity`** — passthrough.
- **`gzip`** and **`x-gzip`** (legacy alias) — RFC 1952 via swift-gzip.
- **`deflate`** and **`x-deflate`** (legacy alias) — zlib-framed DEFLATE per RFC 7230 § 4.2.2, via swift-zlib. **Not** raw DEFLATE; if a non-conformant origin sends raw DEFLATE under `deflate`, reach for swift-deflate directly.

Public API:

- `ContentEncoding.decode(_ bytes: Bytes, contentEncoding header: String) throws(ContentEncodingError) -> Bytes` — parses the header, dispatches to the right codec, returns the plaintext.
- `ContentEncodingError` typed-throws enum (`unsupportedEncoding(_:)`, `decodingFailed(_:)`).

**Multi-coding** values (`Content-Encoding: gzip, br`) are parsed and dispatched in reverse order per RFC 9110 § 8.4. An unsupported coding anywhere in the chain throws.

## Dependencies

- `swift-bytes` 0.1.0 — input/output buffer.
- `swift-gzip` 0.1.0 — RFC 1952 decoder.
- `swift-zlib` 0.1.0 — RFC 1950 decoder.

## Out of scope for v0.1

- **Brotli** (`br`) — different algorithm; would require a separate package. Throws `.unsupportedEncoding("br")` until that lands.
- **zstd** — defer.
- **`compress`** (LZW) — historical, rare; defer.
- **Encoder side.** Per RFC-0012's staging pattern, the encoder lands in v0.2 alongside swift-deflate's DEFLATE encoder.
- `Codable` bridging — same Foundation-free / non-Codable differentiator as the rest of the ecosystem.

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-content-encoding/>

## Source

No upstream Rust crate; this is a native bare-swift package composing swift-gzip + swift-zlib.

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
