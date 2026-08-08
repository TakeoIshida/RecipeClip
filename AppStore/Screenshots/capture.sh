#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h:h}"
DERIVED_DATA="${TMPDIR:-/tmp}/RecipeClip-AppStoreScreenshots-DerivedData"
DEVICE_NAME="${1:-iPhone 16 Pro Max}"
OUTPUT_SET="${2:-}"
LANGUAGE="${3:-ja}"
LOCALE="${4:-ja_JP}"
OUTPUT_DIR="${SCRIPT_DIR}/output${OUTPUT_SET:+/$OUTPUT_SET}"
BUNDLE_ID="com.ishidatakeo.RecipeClip"

mkdir -p "$OUTPUT_DIR"

DEVICE_ID="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" '
    index($0, name) > 0 && $0 !~ /unavailable/ {
        for (fieldIndex = 1; fieldIndex <= NF; fieldIndex++) {
            candidate = $fieldIndex
            gsub(/[()]/, "", candidate)
            if (length(candidate) == 36 && candidate ~ /^[0-9A-F-]+$/) {
                print candidate
                exit
            }
        }
    }
')"
if [[ -z "$DEVICE_ID" ]]; then
    print -u2 "Simulator '$DEVICE_NAME' が見つからないよ。"
    print -u2 "xcrun simctl list devices available で表示される名前を第1引数に渡してね。"
    exit 1
fi

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl ui "$DEVICE_ID" appearance light
xcrun simctl status_bar "$DEVICE_ID" override \
    --time 9:41 \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4

xcodebuild build \
    -quiet \
    -project "$PROJECT_DIR/RecipeClip.xcodeproj" \
    -scheme RecipeClip \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/RecipeClip.app"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

scenes=(
    "recipes:01-recipes.png"
    "organized-editor:02-organized-editor.png"
    "detail:03-detail.png"
    "shopping:04-shopping.png"
    "cooking:05-cooking.png"
)

for item in "${scenes[@]}"; do
    scene="${item%%:*}"
    filename="${item#*:}"
    xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID" \
        --app-store-screenshot "$scene" \
        -AppleLanguages "($LANGUAGE)" \
        -AppleLocale "$LOCALE"
    # コールド起動時も最初のSwiftUIレイアウトが完了するまで待つ。
    sleep 8
    xcrun simctl io "$DEVICE_ID" screenshot --type=png "$OUTPUT_DIR/$filename"
done

xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl status_bar "$DEVICE_ID" clear

print "\n5枚の撮影が完了したよ: $OUTPUT_DIR"
for image in "$OUTPUT_DIR"/*.png; do
    width="$(sips -g pixelWidth "$image" | awk '/pixelWidth/ { print $2 }')"
    height="$(sips -g pixelHeight "$image" | awk '/pixelHeight/ { print $2 }')"
    print -- "- ${image:t}: ${width}x${height}"
done
