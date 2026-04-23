#!/usr/bin/env bash
# Bundles paddleocr-js (+opencv-js + onnxruntime-web + clipper + yaml) into a
# single window.PaddleOCR script tag that the Flutter Web build loads from
# web/paddleocr_bundle.js.
#
# Required once (or whenever paddleocr-js is bumped). Requires Node.js.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PADDLEOCR_JS_VERSION="${PADDLEOCR_JS_VERSION:-0.3.2}"

cat > "$TMP/package.json" <<EOF
{"name":"bundle","type":"module","dependencies":{"@paddleocr/paddleocr-js":"${PADDLEOCR_JS_VERSION}"}}
EOF
cat > "$TMP/entry.js" <<'EOF'
import { PaddleOCR } from '@paddleocr/paddleocr-js';
window.PaddleOCR = PaddleOCR;
EOF

echo "Installing @paddleocr/paddleocr-js@${PADDLEOCR_JS_VERSION}..."
(cd "$TMP" && npm install --silent)

echo "Bundling into web/paddleocr_bundle.js..."
npx --yes esbuild "$TMP/entry.js" \
  --bundle --format=iife --target=es2020 --loader:.mjs=js \
  --define:process.env.NODE_ENV='"production"' \
  --external:fs --external:path --external:crypto \
  --external:node:fs --external:node:path --external:node:crypto \
  --outfile="$HERE/web/paddleocr_bundle.js"

echo "Done. Size: $(du -h "$HERE/web/paddleocr_bundle.js" | awk '{print $1}')"
