# ``ContentEncoding``

HTTP `Content-Encoding` multiplexer — decoder (v0.1+) and encoder (v0.2+). Sendable, Foundation-free.

## Overview

`ContentEncoding` is a thin header-driven dispatch over the bare-swift compression tier (swift-gzip, swift-zlib). Pass a `Content-Encoding` header value and a `Bytes` payload; get back the encoded or decoded form.

```swift
import ContentEncoding
import Bytes

// Encode at server side.
let body = try ContentEncoding.encode(payload, contentEncoding: "gzip", level: .default)

// Decode at client side.
let back = try ContentEncoding.decode(body, contentEncoding: "gzip")
```

**Supported codings (case-insensitive):**

- `identity` — passthrough.
- `gzip` and the legacy alias `x-gzip` — RFC 1952.
- `deflate` and the legacy alias `x-deflate` — zlib-framed DEFLATE per RFC 7230 § 4.2.2. Not raw DEFLATE.

**`br` (Brotli) decode** is supported via swift-brotli (v0.3+); encoding `br` is not yet supported (waits on swift-brotli v0.2). **Unsupported codings** (`zstd`, `compress`) throw ``ContentEncodingError/unsupportedEncoding(_:)``.

**Multi-coding** values (e.g. `Content-Encoding: gzip, deflate`) apply codings in declaration order at encode time (RFC 9110 § 8.4); decoding reverses the order.

Per [RFC-0014](https://github.com/bare-swift/bare-swift/blob/main/rfcs/0014-phase-9-anchor-compression-encoder-sweep.md), v0.2 commits to **correctness** — zopfli-style size tuning lands as v0.2.x patch releases.

## Topics

### Decode (v0.1+)

- ``ContentEncoding/decode(_:contentEncoding:)``

### Encode (v0.2+)

- ``ContentEncoding/encode(_:contentEncoding:level:)``
- ``ContentEncoding/Level``

### Errors

- ``ContentEncodingError``
