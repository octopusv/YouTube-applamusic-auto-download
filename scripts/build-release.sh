#!/usr/bin/env bash
set -euo pipefail

# YTtoMusic リリースビルドスクリプト
# 必要なもの: Xcode, xcodegen
#
# 使い方:
#   ./scripts/build-release.sh              ビルドのみ
#   ./scripts/build-release.sh --zip        .app を zip 化
#   ./scripts/build-release.sh --release v0.1.0   GitHub Release 作成

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

ZIP="$ROOT/build/YTtoMusic.zip"

if [[ "${1:-}" == "--zip" || "${1:-}" == "--release" ]]; then
  echo "==> Zip 化"
  rm -f "$ZIP"
  ditto -c -k --keepParent "$APP" "$ZIP"
  echo "Zip: $ZIP ($(du -sh "$ZIP" | cut -f1))"
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
  gh release create "$TAG" "$ZIP" \
    --title "$TAG" \
    --notes "macOS 用 YTtoMusic.app

## インストール
1. YTtoMusic.zip を展開
2. YTtoMusic.app を /Applications にドラッグ
3. 初回起動は右クリック → 開く（署名なしのため）

## 必要環境
- macOS 14+
- Apple Music サブスクリプション
- \`brew install yt-dlp ffmpeg\`
"
fi

echo "==> 完了"
