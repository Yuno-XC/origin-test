#!/usr/bin/env bash
# asc-shots-pipeline: build, capture, frame, (optional) upload
# Requires: asc cli, koubou 0.14.0 (pip install koubou==0.14.0)
# Ensure kou is in PATH: export PATH="$HOME/Library/Python/3.9/bin:$PATH"

set -e
cd "$(dirname "$0")/.."

# iPhone 17 Pro Max
UDID="${UDID:-DACC5F8F-13A3-4D98-A117-11EC8E1BBF8D}"

# Ensure kou in PATH for framing
export PATH="${HOME}/Library/Python/3.9/bin:${PATH}"

echo "Boot simulator..."
xcrun simctl boot "$UDID" 2>/dev/null || true

echo "Build..."
xcodebuild \
  -project TVremote.xcodeproj \
  -scheme TVremote \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath ".build/DerivedData" \
  build

echo "Install..."
xcrun simctl install "$UDID" ".build/DerivedData/Build/Products/Debug-iphonesimulator/TVremote.app"

echo "Capture..."
asc screenshots run --plan ".asc/screenshots.json" --udid "$UDID" --output json

# Framing (requires kou in PATH; may need: export PATH="$HOME/Library/Python/3.9/bin:$PATH")
if command -v kou &>/dev/null; then
  echo "Frame..."
  asc screenshots frame \
    --input "./screenshots/raw/discovery.png" \
    --output-dir "./screenshots/framed" \
    --device "iphone-17-pro-max" \
    --output json 2>/dev/null || echo "Framing skipped (kou error). Raw screenshots in ./screenshots/raw/"
else
  echo "Skipping frame (kou not in PATH). Raw screenshots in ./screenshots/raw/"
fi

echo "Done."
