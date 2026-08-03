# Security Policy

## Supported versions

Security fixes target the latest published version of Kept.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature for this repository. Do
not open a public issue for a suspected vulnerability and do not attach personal
Kept databases, reminders, memories, signing material, or credentials.

Include the affected version, impact, reproduction steps, and the smallest safe
proof of concept. A maintainer will acknowledge the report and coordinate a fix
and disclosure timeline privately.

## Release trust

Official releases must be signed with Developer ID, notarized by Apple, and
signed with the Sparkle EdDSA key whose public half is embedded in Kept. Private
keys belong only in the protected GitHub `release` environment or an authorized
maintainer's Keychain.
