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

  hdiutil create \
    -volname "YTtoMusic" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$TMP_DMG" >/dev/null

  MOUNT_DIR="/Volumes/YTtoMusic"

  # 既存の同名マウントが残っていれば外す
  if mount | grep -q "$MOUNT_DIR"; then
    diskutil unmount force "$MOUNT_DIR" >/dev/null 2>&1 \
      || diskutil eject "$MOUNT_DIR" >/dev/null 2>&1 \
      || true
    sleep 1
  fi

  hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR" -noautoopen -quiet

  # アイテム認識待ち
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [[ -e "$MOUNT_DIR/YTtoMusic.app" && -L "$MOUNT_DIR/Applications" ]]; then
      break
    fi
    sleep 0.5
  done
  sleep 1

  /usr/bin/osascript <<'APPLESCRIPT' || true
tell application "Finder"
  activate
  tell disk "YTtoMusic"
    open
    delay 2
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {300, 180, 860, 540}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    delay 1
    set position of item "YTtoMusic.app" of container window to {150, 180}
    set position of item "Applications" of container window to {410, 180}
    delay 1
    update without registering applications
    delay 2
    close
  end tell
end tell
APPLESCRIPT

  # Finder に手を引かせる
  /usr/bin/osascript -e 'tell application "Finder" to eject disk "YTtoMusic"' >/dev/null 2>&1 || true

  sync
  sleep 1

  # 念のため複数手段でアンマウント
  for attempt in 1 2 3; do
    if ! mount | grep -q "$MOUNT_DIR"; then break; fi
    hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 \
      || hdiutil detach "$MOUNT_DIR" -force -quiet >/dev/null 2>&1 \
      || diskutil unmount force "$MOUNT_DIR" >/dev/null 2>&1 \
      || true
    sleep 1
  done

  if mount | grep -q "$MOUNT_DIR"; then
    echo "警告: ボリュームを取り出せませんでした。再起動するか、手動で取り出してから再実行してください。"
    exit 1
  fi

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
