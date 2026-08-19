#!/bin/bash
set -euo pipefail

project_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
output_dir="${1:-$project_dir/dist}"
version="${2:-test}"

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
mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/KZSCMacOS"
chmod 755 "$app/Contents/MacOS/KZSCMacOS"

cat > "$app/Contents/Info.plist" <<'PLIST'
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
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KZSC macOS</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0-test</string>
    <key>CFBundleVersion</key>
    <string>0.1.0</string>
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

# Ad-hoc signing makes the bundle launchable while keeping this test artifact
# free of developer certificates. macOS may still require right-click > Open.
codesign --force --deep --sign - "$app"
ditto -c -k --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"
echo "Built: $archive"
