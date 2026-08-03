# Release secrets

No private key, certificate, password, token, exported Keychain item, or
provisioning profile may be committed to this repository. Store release values
only in the protected GitHub environment named `release`.

## Required environment secrets

| Secret | Content |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | Base64-encoded Developer ID Application certificate and private key exported as `.p12`. |
| `DEVELOPER_ID_APPLICATION_P12_PASSWORD` | Strong password used for that `.p12`. |
| `RELEASE_KEYCHAIN_PASSWORD` | Random, CI-only password for the temporary Keychain. |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded App Store Connect API private key (`.p8`) authorized for notarization. |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID. |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer UUID. |
| `SPARKLE_PRIVATE_KEY` | Exact contents exported by Sparkle's `generate_keys -x`; it must match `SUPublicEDKey` in `Info.plist`. |

The `.p12`, `.p8`, and Sparkle export should be transferred directly to GitHub
Secrets, then securely deleted from disk. Never paste secret values into an
issue, pull request, workflow file, release note, terminal recording, or chat.

## Optional repository variables

The workflow derives the standard GitHub Pages URL automatically. These
non-secret variables are needed only for a custom update host:

| Variable | Example |
| --- | --- |
| `KEPT_UPDATE_FEED_URL` | `https://updates.example.com/kept/appcast.xml` |
| `KEPT_UPDATE_BASE_URL` | `https://updates.example.com/kept/` |

Both URLs must use HTTPS. The base URL must end in `/`.

## Local checks

Run before every publication:

```bash
./Scripts/audit-secrets.sh --history
```

GitHub secret scanning and push protection should also be enabled. These checks
complement each other; none is a reason to place a secret in Git history.
