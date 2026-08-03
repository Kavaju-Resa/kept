#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Kavaju

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVELOPER_ROOT="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
SOURCE_PACKAGES_DIR="$PROJECT_ROOT/build/SourcePackages"
SPARKLE_SIGNING_ACCOUNT="${KEPT_SPARKLE_ACCOUNT:-com.kavaju.kept}"

cd "$PROJECT_ROOT"
xcodegen generate
DEVELOPER_DIR="$DEVELOPER_ROOT" xcodebuild \
    -resolvePackageDependencies \
    -project Kept.xcodeproj \
    -scheme Kept \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR"

GENERATE_KEYS="$SOURCE_PACKAGES_DIR/artifacts/sparkle/Sparkle/bin/generate_keys"
if [[ ! -x "$GENERATE_KEYS" ]]; then
    echo "No se encontró generate_keys de Sparkle." >&2
    exit 1
fi

"$GENERATE_KEYS" --account "$SPARKLE_SIGNING_ACCOUNT"
