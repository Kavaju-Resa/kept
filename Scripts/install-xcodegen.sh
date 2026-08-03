#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Kavaju
#
# Instala la versión fijada de XcodeGen para que el pbxproj generado en CI
# coincida byte a byte con el generado localmente. Actualiza XCODEGEN_VERSION
# aquí, regenera el proyecto con esa misma versión y commitea ambos cambios.

set -euo pipefail

XCODEGEN_VERSION="${XCODEGEN_VERSION:-2.46.0}"

if xcodegen version 2>/dev/null | grep -q "Version: ${XCODEGEN_VERSION}$"; then
    exit 0
fi

brew uninstall xcodegen 2>/dev/null || true

curl -fsSL -o /tmp/xcodegen.zip \
    "https://github.com/yonaskolb/XcodeGen/releases/download/${XCODEGEN_VERSION}/xcodegen.zip"
unzip -q -o /tmp/xcodegen.zip -d /tmp/xcodegen-dist
(cd /tmp/xcodegen-dist/xcodegen && sudo ./install.sh)

xcodegen version | grep -q "Version: ${XCODEGEN_VERSION}$"
