#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Kavaju

set -euo pipefail

if [[ "$#" -ne 2 ]]; then
    echo "Uso: $0 <versión-semver> <build-entero>" >&2
    exit 1
fi

VERSION="$1"
BUILD="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST="$PROJECT_ROOT/KeptNative/Resources/Info.plist"
NOTES="$PROJECT_ROOT/ReleaseNotes/${VERSION}.md"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "La versión debe usar un formato SemVer, por ejemplo 1.2.0." >&2
    exit 1
fi
if [[ ! "$BUILD" =~ ^[1-9][0-9]*$ ]]; then
    echo "El build debe ser un entero positivo." >&2
    exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

if [[ ! -f "$NOTES" ]]; then
    printf '# Kept %s\n\n- Describe aquí los cambios de esta versión.\n' "$VERSION" > "$NOTES"
fi

echo "Versión preparada: $VERSION (build $BUILD)"
echo "Edita: $NOTES"
