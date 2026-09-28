#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP_DIR="$PROJECT_DIR/Build/Harbor Gallery.app"
CACHE_DIR="$PROJECT_DIR/.build"

mkdir -p "$CACHE_DIR/module-cache" "$CACHE_DIR/cache" "$CACHE_DIR/config" "$CACHE_DIR/security"

CLANG_MODULE_CACHE_PATH="$CACHE_DIR/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$CACHE_DIR/module-cache" \
swift build \
    --disable-sandbox \
    --cache-path "$CACHE_DIR/cache" \
    --config-path "$CACHE_DIR/config" \
    --security-path "$CACHE_DIR/security"

mkdir -p "$APP_DIR/Contents/MacOS"
cp "$PROJECT_DIR/AppBundle/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/.build/debug/HarborGallery" "$APP_DIR/Contents/MacOS/HarborGallery"
chmod 755 "$APP_DIR/Contents/MacOS/HarborGallery"

SIGNING_IDENTITY=${HARBOR_GALLERY_SIGNING_IDENTITY:-}
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY=$(
        security find-identity -v -p codesigning \
            | sed -n 's/^[[:space:]]*[0-9]*) \([0-9A-F][0-9A-F]*\) ".*"$/\1/p' \
            | sed -n '1p'
    )
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_DIR"
    echo "Signed with persistent identity: $SIGNING_IDENTITY"
else
    codesign --force --deep --sign - "$APP_DIR"
    echo "No persistent code-signing identity found; using an ad-hoc signature."
fi

echo "$APP_DIR"
