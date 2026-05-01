#!/usr/bin/env bash
set -euo pipefail

# YTtoMusic リリースビルドスクリプト
# 必要なもの: Xcode, xcodegen, create-dmg (DMG 化する場合)
#
# 使い方:
#   ./scripts/build-release.sh                    ビルドのみ
#   ./scripts/build-release.sh --dmg              .app を DMG 化
#   ./scripts/build-release.sh --release v0.1.0   DMG を GitHub Release 作成

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen が必要です。brew install xcodegen を実行してください。"
  exit 1
fi

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

echo "==> Xcode プロジェクトを生成"
xcodegen generate --quiet

echo "==> Release ビルド"
xcodebuild \
  -project YTtoMusic.xcodeproj \
  -scheme YTtoMusic \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build \
  | grep -E "^(\*\*|error:|warning:)" || true

APP="$ROOT/build/Build/Products/Release/YTtoMusic.app"

if [[ ! -d "$APP" ]]; then
  echo "ビルドに失敗しました"
  exit 1
fi

echo "==> ビルド完了: $APP"
du -sh "$APP"

# 隔離属性を外す（自分の Mac で右クリック開きが不要になる）
xattr -cr "$APP" 2>/dev/null || true

DMG="$ROOT/build/YTtoMusic.dmg"

build_dmg() {
  echo "==> DMG 化"
  rm -f "$DMG"

  STAGE="$ROOT/build/dmg-stage"
  rm -rf "$STAGE"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"

  TMP_DMG="$ROOT/build/YTtoMusic.tmp.dmg"
  rm -f "$TMP_DMG"

  # 書き込み可能な DMG として一旦作成
  hdiutil create \
    -volname "YTtoMusic" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$TMP_DMG" >/dev/null

  # マウントしてレイアウト設定
  MOUNT_DIR="/Volumes/YTtoMusic"
  hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet
  sleep 1

  osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "YTtoMusic"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 760, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set position of item "YTtoMusic.app" of container window to {150, 180}
    set position of item "Applications" of container window to {410, 180}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

  sync
  hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet

  # 圧縮された読み取り専用 DMG に変換
  hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
  rm -f "$TMP_DMG"
  rm -rf "$STAGE"

  if [[ ! -f "$DMG" ]]; then
    echo "DMG 生成に失敗しました"
    exit 1
  fi

  echo "DMG: $DMG ($(du -sh "$DMG" | cut -f1))"
}

if [[ "${1:-}" == "--dmg" || "${1:-}" == "--release" ]]; then
  build_dmg
fi

if [[ "${1:-}" == "--release" ]]; then
  TAG="${2:-}"
  if [[ -z "$TAG" ]]; then
    echo "使い方: $0 --release v0.1.0"
    exit 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI が必要です。brew install gh を実行してください。"
    exit 1
  fi
  echo "==> GitHub Release 作成: $TAG"
  gh release create "$TAG" "$DMG" \
    --title "$TAG" \
    --notes "macOS 用 YTtoMusic.app

## インストール
1. \`YTtoMusic.dmg\` をダウンロードしてダブルクリック
2. 表示されるウィンドウで YTtoMusic.app を Applications フォルダにドラッグ
3. 初回起動は右クリック → 開く（署名なしのため Gatekeeper 警告が出る）

## 必要環境
- macOS 14+
- Apple Music サブスクリプション
- \`brew install yt-dlp ffmpeg\`
"
fi

echo "==> 完了"
