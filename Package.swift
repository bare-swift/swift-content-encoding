// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Copyright (c) 2026 The bare-swift Project Authors.

import PackageDescription

let package = Package(
    name: "swift-content-encoding",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ContentEncoding", targets: ["ContentEncoding"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.0"),
        .package(url: "https://github.com/bare-swift/swift-bytes.git", from: "0.1.0"),
        .package(url: "https://github.com/bare-swift/swift-deflate.git", from: "0.6.0"),
        .package(url: "https://github.com/bare-swift/swift-gzip.git", from: "0.6.0"),
        .package(url: "https://github.com/bare-swift/swift-zlib.git", from: "0.6.0"),
        // swift-brotli intentionally pinned at 0.5 for v0.8 — true memory-streaming
        // requires brotli v0.6 (state-machine refactor; Phase 36+ candidate).
        // Partial-propagation acknowledgment: v0.8 is true-memory-streaming for
        // deflate/gzip/zlib chains; brotli chains remain buffering-wrap until
        // content-encoding v0.9 (post-brotli-v0.6).
        .package(url: "https://github.com/bare-swift/swift-brotli.git", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "ContentEncoding",
            dependencies: [
                .product(name: "Bytes", package: "swift-bytes"),
                .product(name: "Deflate", package: "swift-deflate"),
                .product(name: "Brotli", package: "swift-brotli"),
                .product(name: "Gzip", package: "swift-gzip"),
                .product(name: "Zlib", package: "swift-zlib")
            ]
        ),
        .testTarget(
            name: "ContentEncodingTests",
            dependencies: ["ContentEncoding"]
        )
    ]
)
