# ``ContentEncoding``

HTTP `Content-Encoding` header multiplexer (identity, gzip, deflate) — Sendable, Foundation-free.

## Overview

`ContentEncoding.decode(_:contentEncoding:)` composes swift-gzip and
swift-zlib behind a single header-driven entry point. Pass the raw HTTP
response body and the `Content-Encoding` header value; the multiplexer
parses the header, dispatches to the right codec, and returns the
plaintext.

```swift
import ContentEncoding
import Bytes

let body: Bytes = ...                 // raw HTTP response body
let header = "gzip"                   // from response Content-Encoding
let plain = try ContentEncoding.decode(body, contentEncoding: header)
```

Supported codings (case-insensitive):

- `identity` — passthrough.
- `gzip` and the legacy alias `x-gzip` — RFC 1952 (via swift-gzip).
- `deflate` and the legacy alias `x-deflate` — zlib-framed DEFLATE per
  RFC 7230 § 4.2.2 (via swift-zlib).

Unsupported codings (`br`, `zstd`, `compress`) throw
``ContentEncodingError/unsupportedEncoding(_:)``.

Per RFC 9110 § 8.4, `Content-Encoding` is a comma-separated list with
left-to-right encoding order, so decoding applies the codings in
**reverse** order. Multi-coding is supported in v0.1; an unsupported
coding anywhere in the chain throws.

## Topics

### Essentials

- ``ContentEncodingError``
