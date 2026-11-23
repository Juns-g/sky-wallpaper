#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Sky"
BUNDLE_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
INSTALL_TO_APPS=false

if [[ "${1:-}" == "--install" ]]; then
    INSTALL_TO_APPS=true
fi

echo "==> Building SkyWallpaper (release)..."
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/SkyWallpaper"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "Error: Binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling ${BUNDLE_DIR}..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS" "$BUNDLE_DIR/Contents/Resources"

cp "$BIN_PATH" "$BUNDLE_DIR/Contents/MacOS/SkyWallpaper"
chmod +x "$BUNDLE_DIR/Contents/MacOS/SkyWallpaper"

cat > "$BUNDLE_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>Sky</string>
    <key>CFBundleExecutable</key>
    <string>SkyWallpaper</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>local.bian.SkyWallpaper</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Sky</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSLocationUsageDescription</key>
    <string>Sky 使用你的大概位置以精确计算当地太阳轨迹、日出日落时间与真实星空。</string>
</dict>
</plist>
PLIST

echo "==> Generating AppIcon.icns..."
ICON_TMP="$(mktemp -d)"
trap 'rm -rf "$ICON_TMP"' EXIT

swift - <<SWIFT "$ICON_TMP/icon_1024.png"
import AppKit
import CoreGraphics

let outPath = CommandLine.arguments[1]
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }

let rect = CGRect(x: 0, y: 0, width: size, height: size)
let pad: CGFloat = 96
let iconRect = rect.insetBy(dx: pad, dy: pad)
let path = CGPath(roundedRect: iconRect, cornerWidth: 196, cornerHeight: 196, transform: nil)
ctx.addPath(path)
ctx.clip()

// Twilight-to-starry-night sky dome gradient
let colors = [
    CGColor(red: 0.99, green: 0.67, blue: 0.42, alpha: 1.0),
    CGColor(red: 0.68, green: 0.44, blue: 0.54, alpha: 1.0),
    CGColor(red: 0.16, green: 0.28, blue: 0.56, alpha: 1.0),
    CGColor(red: 0.05, green: 0.10, blue: 0.24, alpha: 1.0)
] as CFArray
let locations: [CGFloat] = [0.0, 0.30, 0.64, 1.0]
if let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: 512, y: iconRect.minY),
        end: CGPoint(x: 512, y: iconRect.maxY),
        options: []
    )
}

// Luminous rising sun glow near horizon
let sunCenter = CGPoint(x: 512, y: iconRect.minY + 190)
let glowColors = [
    CGColor(red: 1.0, green: 0.94, blue: 0.78, alpha: 0.95),
    CGColor(red: 1.0, green: 0.78, blue: 0.46, alpha: 0.45),
    CGColor(red: 1.0, green: 0.68, blue: 0.36, alpha: 0.0)
] as CFArray
if let sunGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 0.38, 1.0]) {
    ctx.drawRadialGradient(sunGrad, startCenter: sunCenter, startRadius: 20, endCenter: sunCenter, endRadius: 340, options: [])
}
ctx.setFillColor(CGColor(red: 1.0, green: 0.97, blue: 0.88, alpha: 0.98))
ctx.fillEllipse(in: CGRect(x: sunCenter.x - 68, y: sunCenter.y - 68, width: 136, height: 136))

// Crisp stars in upper night sky
let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (290, 740, 7, 0.95), (365, 680, 4.5, 0.75), (430, 795, 5.5, 0.85),
    (520, 725, 8, 1.00), (615, 780, 5, 0.80), (695, 710, 6.5, 0.92),
    (755, 765, 4, 0.70), (240, 635, 4, 0.65), (650, 625, 4.5, 0.70),
    (475, 640, 3.8, 0.65), (570, 830, 4.2, 0.75), (340, 825, 3.6, 0.60)
]
for (sx, sy, r, a) in stars {
    ctx.setFillColor(CGColor(red: 0.92, green: 0.96, blue: 1.0, alpha: a * 0.32))
    ctx.fillEllipse(in: CGRect(x: sx - r * 2.2, y: sy - r * 2.2, width: r * 4.4, height: r * 4.4))
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: a))
    ctx.fillEllipse(in: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2))
}

guard let img = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: img)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: outPath))
SWIFT

ICONSET="$ICON_TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for sz in 16 32 128 256 512; do
    sips -z "$sz" "$sz" "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
    sz2=$((sz * 2))
    sips -z "$sz2" "$sz2" "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"

echo "==> Ad-hoc code signing..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "==> Built: $BUNDLE_DIR"

if [[ "$INSTALL_TO_APPS" == "true" ]]; then
    echo "==> Installing to /Applications/${APP_NAME}.app..."
    pkill -x SkyWallpaper >/dev/null 2>&1 || true
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "$BUNDLE_DIR" "/Applications/${APP_NAME}.app"
    echo "==> Installed: /Applications/${APP_NAME}.app"
fi
