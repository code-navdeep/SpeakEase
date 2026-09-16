#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=${1:-Release}

./dev-scripts/local_build.sh $CONFIG

# Run the app in the background and detach from terminal
build/Build/Products/$CONFIG/SpeakEase
