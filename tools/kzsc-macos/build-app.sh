#!/bin/bash
set -euo pipefail

project_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
output_dir="${1:-$project_dir/dist}"
version="${2:-0.1.0}"
bundle_version="${version%-generic}"
# Apple expects a three-part numeric bundle version. KZSC tags have a fourth
# build component (for example 0.11.2.39), which is retained in the archive
# name but normalized for the app bundle metadata.
bundle_version="$(printf '%s\n' "$bundle_version" | cut -d. -f1-3)"

case "$output_dir" in
  /*) ;;
  *) output_dir="$PWD/$output_dir" ;;
esac

cd "$project_dir"
swift build --configuration release --product KZSCMacOS

binary="$(find .build -type f -path '*/release/KZSCMacOS' -perm -111 -print -quit)"
if [ -z "$binary" ]; then
  echo "KZSCMacOS release binary was not produced" >&2
  exit 1
fi

app="$output_dir/KZSCMacOS.app"
archive="$output_dir/KZSCMacOS-v$version-macos.zip"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/KZSCMacOS"
chmod 755 "$app/Contents/MacOS/KZSCMacOS"

# Generate the shared Keenetic Manager Dock icon. Keep the generated fallback
# for local checkouts where the artwork asset is not present.
iconset="$(mktemp -d)/KZSCMacOS.iconset"
mkdir -p "$iconset"
icon_generator="$(mktemp -u)"
swiftc "$project_dir/generate-icon.swift" -framework AppKit -o "$icon_generator"
icon_source="$project_dir/../kzsc-assets/keenetic-manager.avif"
for spec in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
  icon_size="${spec%%:*}"
  icon_name="${spec#*:}"
  if [ -f "$icon_source" ]; then
    "$icon_generator" "$icon_size" "$iconset/$icon_name" "$icon_source"
  else
    "$icon_generator" "$icon_size" "$iconset/$icon_name"
  fi
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/KZSCMacOS.icns"
rm -f "$icon_generator"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>KZSC macOS</string>
    <key>CFBundleExecutable</key>
    <string>KZSCMacOS</string>
    <key>CFBundleIdentifier</key>
    <string>com.ssy1979.kzsc.macos</string>
    <key>CFBundleIconFile</key>
    <string>KZSCMacOS.icns</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KZSC macOS</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${bundle_version}</string>
    <key>CFBundleVersion</key>
    <string>${bundle_version}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
</dict>
</plist>
PLIST

# Ad-hoc signing makes the bundle launchable without a developer certificate.
# The package is not notarized, so macOS may still require right-click > Open.
codesign --force --deep --sign - "$app"
ditto -c -k --keepParent "$app" "$archive"
(
  cd "$output_dir"
  shasum -a 256 "$(basename "$archive")" > "$(basename "$archive").sha256"
)
echo "Built: $archive"
