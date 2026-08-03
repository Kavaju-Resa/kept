#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Kavaju

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST="$PROJECT_ROOT/KeptNative/Resources/Info.plist"
EXPECTED_TAG="${1:-}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
NOTES="$PROJECT_ROOT/ReleaseNotes/${VERSION}.md"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "CFBundleShortVersionString no es SemVer: $VERSION" >&2
    exit 1
fi
if [[ ! "$BUILD" =~ ^[1-9][0-9]*$ ]]; then
    echo "CFBundleVersion debe ser un entero positivo: $BUILD" >&2
    exit 1
fi
if [[ -n "$EXPECTED_TAG" && "$EXPECTED_TAG" != "v$VERSION" ]]; then
    echo "La etiqueta $EXPECTED_TAG no coincide con la versión v$VERSION." >&2
    exit 1
fi
if [[ ! -s "$NOTES" ]]; then
    echo "Faltan las notas de versión: $NOTES" >&2
    exit 1
fi

"$PROJECT_ROOT/Scripts/audit-secrets.sh"
echo "Release válida: v$VERSION (build $BUILD)"
