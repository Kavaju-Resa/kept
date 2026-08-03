#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Kavaju

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCAN_HISTORY="${1:-}"
TEMP_FILES="$(mktemp "${TMPDIR:-/tmp}/kept-secret-files.XXXXXX")"

cleanup() {
    rm -f "$TEMP_FILES"
}
trap cleanup EXIT

cd "$PROJECT_ROOT"

git ls-files -co --exclude-standard -z > "$TEMP_FILES"

unsafe_filename=0
while IFS= read -r -d '' file; do
    case "$file" in
        *.cer|*.crt|*.der|*.key|*.keychain|*.keychain-db|*.mobileprovision|*.p12|*.pem|*.pfx|*.provisionprofile|AuthKey_*.p8|sparkle-private-key*|notarytool-credentials*)
            echo "Archivo sensible no permitido: $file" >&2
            unsafe_filename=1
            ;;
        .env|.env.*)
            if [[ "$file" != ".env.example" ]]; then
                echo "Archivo de entorno no permitido: $file" >&2
                unsafe_filename=1
            fi
            ;;
    esac
done < "$TEMP_FILES"

if [[ "$unsafe_filename" -ne 0 ]]; then
    exit 1
fi

SECRET_PATTERN='-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|sk_live_[A-Za-z0-9]{20,}'

if command -v rg >/dev/null 2>&1; then
    matches="$(rg -l --hidden \
        -g '!.git/**' \
        -g '!build/**' \
        -g '!node_modules/**' \
        -g '!Scripts/audit-secrets.sh' \
        -e "$SECRET_PATTERN" . || true)"
else
    # Sin ripgrep, escanea la misma lista de archivos rastreados y sin rastrear.
    matches="$(xargs -0 grep -IlE -e "$SECRET_PATTERN" < "$TEMP_FILES" 2>/dev/null \
        | grep -v '^Scripts/audit-secrets.sh$' || true)"
fi

if [[ -n "$matches" ]]; then
    echo "Posibles secretos detectados en:" >&2
    echo "$matches" >&2
    exit 1
fi

if [[ "$SCAN_HISTORY" == "--history" ]]; then
    history_matches="$(
        git rev-list --all | while IFS= read -r commit; do
            git grep -IlE "$SECRET_PATTERN" "$commit" -- . \
                ':!Scripts/audit-secrets.sh' 2>/dev/null || true
        done | sort -u
    )"
    if [[ -n "$history_matches" ]]; then
        echo "Posibles secretos detectados en el historial:" >&2
        echo "$history_matches" >&2
        exit 1
    fi
fi

echo "Auditoría de secretos superada."
