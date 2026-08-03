// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import XCTest
@testable import Kept

final class LocalUpdateHTTPServerTests: XCTestCase {
    func testServesPrivateAppcastOnlyThroughLoopback() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "kept-update-server-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let expected = Data("<rss version=\"2.0\"></rss>".utf8)
        try expected.write(to: directory.appending(path: "appcast.xml"))

        let server = LocalUpdateHTTPServer(rootDirectory: directory)
        defer { server.stop() }

        let feedURL = try await withCheckedThrowingContinuation { continuation in
            server.start { result in
                continuation.resume(with: result)
            }
        }

        XCTAssertEqual(feedURL.host, "127.0.0.1")
        let (received, response) = try await URLSession.shared.data(from: feedURL)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertEqual(received, expected)
    }
}
