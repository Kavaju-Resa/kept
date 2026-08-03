# Kept

Kept is a private, local macOS reminder and memory assistant implemented with
SwiftUI, AppKit, SwiftData, UserNotifications, Speech, ServiceManagement, Apple
Foundation Models, and Sparkle. Network access is only needed when a remote
update feed is configured.

Kept is available under a dual-licensing model: the complete source is
licensed under [GNU AGPL version 3 only](LICENSE), while separate commercial
terms are available for organizations that cannot use it under the AGPL.

## Requirements

- Apple Silicon Mac
- macOS 26.0 or newer
- Apple Intelligence enabled for chat features
- Xcode 26 or newer (the project uses Foundation Models and SwiftData macros)

Without Apple Intelligence, tasks, memories, settings, dictation, and scheduled notifications remain available manually.

## Open and run

1. Install Xcode and select it with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
2. Regenerate the project after changing `project.yml`: `xcodegen generate`.
3. Open `Kept.xcodeproj`, choose **Sign to Run Locally**, and run the `Kept` scheme.

No paid Apple Developer account is needed for local use.

## Create the local installer

Run:

```bash
./Scripts/package-dmg.sh
```

The Release build, locally signed `Instalar-Kept-<version>.dmg`, and ZIP are
written to `build/distribution/`. The DMG includes a branded background, large
icons, an Applications shortcut, and a drag-to-install arrow. Open the DMG and
drag Kept to Applications. This package is intended for local
testing: public distribution would additionally require a Developer ID signature
and Apple notarization.

## Updates

Kept uses Sparkle 2 with an EdDSA public key embedded in the app. The matching
private key is stored only in the macOS Keychain under the account
`com.kavaju.kept`; it is never stored in the repository.

`package-dmg.sh` also generates a signed Sparkle feed in `build/updates/` and
copies it to the private local channel at:

`~/Library/Application Support/com.kavaju.kept/Updates`

For personal use, Kept exposes that directory temporarily through a random
`127.0.0.1` port while it is running; it is not shared on the local network.

Install version 1.1.1 manually once. Future versions created on this Mac can be
detected and installed directly from Kept. Update preferences and the manual
check are available in Settings, the application menu, and the menu-bar menu.

On a new development Mac, initialize or import the signing key with:

```bash
./Scripts/setup-update-signing.sh
```

For a public HTTPS feed, package with the final appcast and download locations:

```bash
KEPT_UPDATE_FEED_URL="https://updates.example.com/kept/appcast.xml" \
KEPT_UPDATE_BASE_URL="https://updates.example.com/kept/" \
KEPT_CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./Scripts/package-dmg.sh
```

Upload the contents of `build/updates/` unchanged. Before public distribution,
replace local ad-hoc signing with Developer ID, enable Hardened Runtime, and
notarize the application. A Mac App Store target must use the store's updater
instead of Sparkle.

The prepared GitHub release workflow performs those steps from a protected
`release` environment when a maintainer pushes a `v*` tag. See
[`docs/RELEASING.md`](docs/RELEASING.md) and
[`docs/SECRETS.md`](docs/SECRETS.md) before enabling it.

## Local data

Native data is stored at:

`~/Library/Application Support/com.kavaju.kept/Kept.store`

## Project layout

- `KeptNative/`: active native application target.
- `KeptTests/`: deterministic temporal, validation, and update tests.
- `project.yml`: reproducible XcodeGen definition.

## Contributing and security

Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request. Report
security vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md);
do not include personal reminder data, credentials, signing keys, or diagnostic
archives in public issues.

Kept's local data and network behavior are described in
[`PRIVACY.md`](PRIVACY.md). Third-party attribution is listed in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

The project runs a read-only CI workflow for pull requests. Release credentials
are scoped to a protected GitHub environment and are never available to forked
pull requests.

## Licensing

Kept is offered under two alternatives:

1. **Community license:** [GNU Affero General Public License v3.0 only](LICENSE)
   (`AGPL-3.0-only`). If you distribute a modified version or let users interact
   with one over a network, you must comply with the AGPL source-availability
   requirements.
2. **Commercial license:** separate proprietary terms may be obtained from the
   project owner for uses where the AGPL is unsuitable — including distribution
   through channels whose terms conflict with the AGPL, such as the Mac App
   Store. See [`COMMERCIAL-LICENSING.md`](COMMERCIAL-LICENSING.md).

The Kept and Kavaju names, logos, and visual identity are not granted under the
software license. See [`TRADEMARKS.md`](TRADEMARKS.md). Contributions require
acceptance of the [`CONTRIBUTOR_LICENSE_AGREEMENT.md`](CONTRIBUTOR_LICENSE_AGREEMENT.md)
so the project can continue to offer both licensing alternatives.
