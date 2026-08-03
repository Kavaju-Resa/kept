// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import XCTest
@testable import Kept

final class UpdateFeedLocatorTests: XCTestCase {
    func testAcceptsSecureRemoteFeed() {
        XCTAssertEqual(
            UpdateFeedLocator.validatedURL("https://updates.example.com/kept/appcast.xml")?.scheme,
            "https"
        )
    }

    func testAcceptsLocalPrivateFeed() {
        XCTAssertTrue(UpdateFeedLocator.validatedURL("file:///tmp/kept/appcast.xml")?.isFileURL == true)
    }

    func testRejectsInsecureOrMalformedFeed() {
        XCTAssertNil(UpdateFeedLocator.validatedURL("http://updates.example.com/appcast.xml"))
        XCTAssertNil(UpdateFeedLocator.validatedURL("not a url"))
        XCTAssertNil(UpdateFeedLocator.validatedURL(""))
    }

    func testRefreshPreservesRunningLoopbackFeed() {
        let fileFeed = URL(fileURLWithPath: "/tmp/kept/appcast.xml")
        let loopbackFeed = URL(string: "http://127.0.0.1:49152/appcast.xml")!

        XCTAssertEqual(
            UpdateFeedLocator.resolvedActiveURL(
                selectedURL: fileFeed,
                servedLocalFeedURL: fileFeed,
                currentURL: loopbackFeed
            ),
            loopbackFeed
        )
    }

    func testRefreshDoesNotReuseLoopbackForDifferentFile() {
        let selected = URL(fileURLWithPath: "/tmp/kept-new/appcast.xml")
        let served = URL(fileURLWithPath: "/tmp/kept-old/appcast.xml")
        let loopbackFeed = URL(string: "http://127.0.0.1:49152/appcast.xml")!

        XCTAssertEqual(
            UpdateFeedLocator.resolvedActiveURL(
                selectedURL: selected,
                servedLocalFeedURL: served,
                currentURL: loopbackFeed
            ),
            selected
        )
    }
}
