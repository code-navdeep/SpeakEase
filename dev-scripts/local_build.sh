#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=${1:-Release}

xcodebuild \
  -scheme SpeakEase \
  -configuration $CONFIG \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath ./build \
  ARCHS=arm64 \
  build
