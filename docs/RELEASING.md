# Releasing Kept

Releases are created from signed `vMAJOR.MINOR.PATCH` tags. Ordinary pushes and
pull requests never receive signing or notarization credentials.

## One-time GitHub configuration

1. Create the public repository from a clean initial history.
2. Enable GitHub Pages with **GitHub Actions** as its source.
3. Enable private vulnerability reporting, secret scanning, push protection,
   Dependabot alerts, and branch protection for `main`.
4. Require the `CI / Repository audit` and `CI / Build and test` checks on
   `main`.
5. Create an environment named `release`, restrict it to protected tags matching
   `v*.*.*`, and require maintainer approval before deployment.
6. Add the secrets listed in `docs/SECRETS.md` to that environment, not as
   repository-wide secrets.

The workflow grants read-only permissions by default. Only the publish job may
write GitHub Releases, and only the final deployment job may write GitHub Pages.
External pull requests do not execute any secret-bearing job.

The locally signed 1.1.1 build and the first Developer ID-signed public build
have different macOS code-signing identities. Install that first public build
manually once; all later public releases can use Sparkle normally.

## Prepare a version

From a clean `main` branch:

```bash
./Scripts/bump-version.sh 1.2.0 5
```

Edit `ReleaseNotes/1.2.0.md`, regenerate the project if necessary, then run:

```bash
./Scripts/verify-release.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Kept.xcodeproj \
  -scheme Kept \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Merge the version change into `main`, then create and push the signed tag:

```bash
git tag -s v1.2.0 -m "Kept 1.2.0"
git push origin v1.2.0
```

The workflow validates the tag/version match, tests, imports signing material
into an ephemeral Keychain, signs with Developer ID, enables Hardened Runtime,
notarizes and staples the app and DMG, signs the Sparkle archive, creates the
GitHub Release, and deploys the HTTPS appcast to GitHub Pages.

## Recovery and key rotation

Keep encrypted offline backups of the Developer ID certificate, App Store
Connect key, and Sparkle private key. Losing the Sparkle key breaks the trusted
update path for installed copies. If exposure is suspected, stop releases,
revoke affected Apple credentials, rotate GitHub secrets, and document the
manual migration path before publishing again.
