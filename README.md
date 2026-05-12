# swift-content-encoding

HTTP `Content-Encoding` multiplexer — decoder (v0.1+) and encoder (v0.2+). Sendable, Foundation-free.

Part of the [bare-swift](https://github.com/bare-swift) ecosystem.

## Install

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/bare-swift/swift-content-encoding.git", from: "0.2.0")
```

Then depend on the `ContentEncoding` product:

```swift
.product(name: "ContentEncoding", package: "swift-content-encoding")
```

## Usage

### Decode (v0.1+)

```swift
import ContentEncoding
import Bytes

let body: Bytes = ...                 // raw HTTP response body
let header = "gzip"                   // from response Content-Encoding
let plain = try ContentEncoding.decode(body, contentEncoding: header)
```

### Encode (v0.2+)

```swift
import ContentEncoding
import Bytes

let payload: Bytes = ...
let body = try ContentEncoding.encode(payload, contentEncoding: "gzip", level: .default)
// Round-trip: ContentEncoding.decode(body, contentEncoding: "gzip") == payload
```

Multi-coding works in both directions (encode applies left-to-right; decode reverses):

```swift
let body = try ContentEncoding.encode(payload, contentEncoding: "gzip, deflate")
let back = try ContentEncoding.decode(body, contentEncoding: "gzip, deflate")
```

## Supported codings (case-insensitive)

- `identity` — passthrough.
- `gzip` / `x-gzip` — RFC 1952 via swift-gzip.
- `deflate` / `x-deflate` — zlib-framed DEFLATE per RFC 7230 § 4.2.2 via swift-zlib. **Not** raw DEFLATE.
- `br` — Brotli (RFC 7932) **decode-only** via swift-brotli. Encoding `br` throws `.unsupportedEncoding("br")` (the encoder ships with swift-brotli v0.2).

Unsupported codings (`zstd`, `compress`) throw `ContentEncodingError.unsupportedEncoding`.

## Public API

- `ContentEncoding.decode(_:contentEncoding:) throws(ContentEncodingError) -> Bytes`
- `ContentEncoding.encode(_:contentEncoding:level:) throws(ContentEncodingError) -> Bytes`
- `ContentEncoding.Level` — typealias for `Deflate.Encoder.Level` (`.none` / `.fast` / `.default` / `.best`).
- `ContentEncodingError` typed-throws enum (2 cases).

## Dependencies

- `swift-deflate` 0.2.0 — for the `Level` typealias.
- `swift-gzip` 0.2.0 — gzip codec.
- `swift-zlib` 0.2.0 — zlib codec.
- `swift-brotli` 0.1.0 — Brotli decoder (v0.3+).
- `swift-bytes` 0.1.0 — buffer.

## Out of scope for v0.3

- Brotli encoding. Lands when swift-brotli v0.2 ships.
- zstd, compress.
- Streaming encoding.
- `Accept-Encoding` negotiation.

## Documentation

Full DocC documentation: <https://bare-swift.github.io/swift-content-encoding/>

## License

Apache 2.0 with LLVM exception. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
