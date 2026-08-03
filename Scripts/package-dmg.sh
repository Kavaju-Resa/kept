#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Kavaju

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVELOPER_ROOT="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_ROOT/KeptNative/Resources/Info.plist")"
OUTPUT_DIR="$PROJECT_ROOT/build/distribution"
SOURCE_PACKAGES_DIR="$PROJECT_ROOT/build/SourcePackages"
UPDATE_STAGING_DIR="$PROJECT_ROOT/build/updates"
LOCAL_UPDATE_DIR="$HOME/Library/Application Support/com.kavaju.kept/Updates"
DMG_PATH="$OUTPUT_DIR/Instalar-Kept-${VERSION}.dmg"
ZIP_PATH="$OUTPUT_DIR/Kept-${VERSION}-macOS-Apple-Silicon.zip"
BACKGROUND_PATH="$PROJECT_ROOT/Installer/DMGBackground.png"
PACKAGE_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/kept-package.XXXXXX")"
ARCHIVE_PATH="$PACKAGE_TEMP/Kept.xcarchive"
VOLUME_NAME="Instalar Kept"
UPDATE_FEED_URL="${KEPT_UPDATE_FEED_URL:-}"
UPDATE_BASE_URL="${KEPT_UPDATE_BASE_URL:-}"
SPARKLE_SIGNING_ACCOUNT="${KEPT_SPARKLE_ACCOUNT:-com.kavaju.kept}"
CODE_SIGN_IDENTITY="${KEPT_CODE_SIGN_IDENTITY:--}"
HARDENED_RUNTIME="${KEPT_HARDENED_RUNTIME:-NO}"
NOTARY_PROFILE="${KEPT_NOTARY_PROFILE:-}"
NOTARY_KEYCHAIN="${KEPT_NOTARY_KEYCHAIN:-}"
PUBLISH_LOCAL_FEED="${KEPT_PUBLISH_LOCAL_FEED:-YES}"
LOCAL_DESIGNATED_REQUIREMENT='=designated => identifier "com.kavaju.kept"'

cleanup() {
    rm -rf "$PACKAGE_TEMP"
}
trap cleanup EXIT

if [[ ! -d "$DEVELOPER_ROOT" ]]; then
    echo "Xcode no está disponible en /Applications/Xcode.app" >&2
    exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen no está instalado. Instálalo con: brew install xcodegen" >&2
    exit 1
fi

if ! python3 -c 'import dmgbuild' >/dev/null 2>&1; then
    echo "Falta dmgbuild. Instálalo con: python3 -m pip install --user dmgbuild" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mkdir -p "$SOURCE_PACKAGES_DIR" "$UPDATE_STAGING_DIR"
if [[ "$PUBLISH_LOCAL_FEED" == "YES" ]]; then
    mkdir -p "$LOCAL_UPDATE_DIR"
fi
rm -f "$DMG_PATH" "$ZIP_PATH"

cd "$PROJECT_ROOT"
xcodegen generate

DEVELOPER_DIR="$DEVELOPER_ROOT" xcrun swift \
    "$PROJECT_ROOT/Scripts/create-dmg-background.swift" \
    "$BACKGROUND_PATH"

DEVELOPER_DIR="$DEVELOPER_ROOT" xcodebuild \
    -project Kept.xcodeproj \
    -scheme Kept \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
    -archivePath "$ARCHIVE_PATH" \
    KEPT_UPDATE_FEED_URL="$UPDATE_FEED_URL" \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
    ENABLE_HARDENED_RUNTIME="$HARDENED_RUNTIME" \
    archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/Kept.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "No se encontró Kept.app dentro del archivo de Xcode." >&2
    exit 1
fi

# Ad-hoc signatures otherwise derive a different designated requirement on
# every build. A stable local requirement lets Sparkle validate future personal
# updates; public builds should supply a Developer ID identity instead.
if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - \
        --requirements "$LOCAL_DESIGNATED_REQUIREMENT" \
        "$APP_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

NOTARY_ARGUMENTS=()
if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_ARGUMENTS=(--keychain-profile "$NOTARY_PROFILE")
    if [[ -n "$NOTARY_KEYCHAIN" ]]; then
        NOTARY_ARGUMENTS+=(--keychain "$NOTARY_KEYCHAIN")
    fi

    NOTARY_ARCHIVE="$PACKAGE_TEMP/Kept-for-notarization.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$NOTARY_ARCHIVE"
    DEVELOPER_DIR="$DEVELOPER_ROOT" xcrun notarytool submit \
        "$NOTARY_ARCHIVE" \
        "${NOTARY_ARGUMENTS[@]}" \
        --wait \
        --timeout 30m
    DEVELOPER_DIR="$DEVELOPER_ROOT" xcrun stapler staple "$APP_PATH"
    DEVELOPER_DIR="$DEVELOPER_ROOT" xcrun stapler validate "$APP_PATH"
fi

python3 -m dmgbuild \
    --detach-retries 15 \
    -s "$PROJECT_ROOT/Installer/dmg-settings.py" \
    -Dapplication="$APP_PATH" \
    -Dbackground="$BACKGROUND_PATH" \
    -Dvolume_icon="$PROJECT_ROOT/app-icon.icns" \
    "$VOLUME_NAME" \
    "$DMG_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
    DEVELOPER_DIR="$DEVELOPER_ROOT" xcrun notarytool submit \
        "$DMG_PATH" \
        "${NOTARY_ARGUMENTS[@]}" \
        --wait \
        --timeout 30m
    DEVELOPER_DIR="$DEVELOPER_ROOT" xcrun stapler staple "$DMG_PATH"
    DEVELOPER_DIR="$DEVELOPER_ROOT" xcrun stapler validate "$DMG_PATH"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

SPARKLE_TOOLS_DIR="$SOURCE_PACKAGES_DIR/artifacts/sparkle/Sparkle/bin"
GENERATE_APPCAST="$SPARKLE_TOOLS_DIR/generate_appcast"
if [[ ! -x "$GENERATE_APPCAST" ]]; then
    echo "No se encontró generate_appcast de Sparkle." >&2
    exit 1
fi

UPDATE_ARCHIVE="$UPDATE_STAGING_DIR/$(basename "$ZIP_PATH")"
ditto "$ZIP_PATH" "$UPDATE_ARCHIVE"

RELEASE_NOTES_SOURCE="$PROJECT_ROOT/ReleaseNotes/${VERSION}.md"
if [[ -f "$RELEASE_NOTES_SOURCE" ]]; then
    ditto "$RELEASE_NOTES_SOURCE" "$UPDATE_STAGING_DIR/Kept-${VERSION}-macOS-Apple-Silicon.md"
fi

APPCAST_ARGUMENTS=(
    --account "$SPARKLE_SIGNING_ACCOUNT"
    --maximum-versions 5
    --maximum-deltas 5
)
if [[ -n "$UPDATE_BASE_URL" ]]; then
    APPCAST_ARGUMENTS+=(--download-url-prefix "$UPDATE_BASE_URL")
fi
"$GENERATE_APPCAST" "${APPCAST_ARGUMENTS[@]}" "$UPDATE_STAGING_DIR"

# The private local feed makes future builds installable from inside Kept on this Mac.
if [[ "$PUBLISH_LOCAL_FEED" == "YES" ]]; then
    ditto "$UPDATE_STAGING_DIR" "$LOCAL_UPDATE_DIR"
fi

hdiutil verify "$DMG_PATH"

echo
echo "Paquetes creados:"
echo "$DMG_PATH"
echo "$ZIP_PATH"
echo "$UPDATE_STAGING_DIR/appcast.xml"
if [[ "$PUBLISH_LOCAL_FEED" == "YES" ]]; then
    echo "$LOCAL_UPDATE_DIR/appcast.xml"
fi
shasum -a 256 "$DMG_PATH" "$ZIP_PATH"
