# Contributing to Kept

Thank you for helping improve Kept. The application code lives under
`KeptNative/` and its deterministic tests under `KeptTests/`.

## Development setup

- Apple Silicon Mac running macOS 26 or newer.
- Xcode 26 or newer.
- XcodeGen 2.44 or newer.

Generate the project after changing `project.yml`:

```bash
xcodegen generate
```

Run the deterministic test suite:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Kept.xcodeproj \
  -scheme Kept \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Pull requests

1. Keep changes focused and include tests for behavior changes.
2. Do not commit generated build products, personal Kept data, logs, screenshots
   containing reminders, certificates, provisioning profiles, or credentials.
3. Run `./Scripts/audit-secrets.sh` and the test suite before opening a PR.
4. Explain user-visible changes and any manual macOS checks still required.
5. Read and accept the
   [`CONTRIBUTOR_LICENSE_AGREEMENT.md`](CONTRIBUTOR_LICENSE_AGREEMENT.md) in the
   pull-request template. Do not submit code you are not authorized to license.

Pull requests from forks never receive release credentials. Maintainers publish
releases only from protected version tags.

## Licensing of contributions

Kept uses AGPL and commercial dual licensing. You retain ownership of your
contribution, while the contributor agreement grants the project owner the
rights needed to distribute it under both licensing alternatives. A pull
request cannot be merged until every contributor to it has accepted the
agreement.
