# YTtoMusic

YouTube から音声を抽出して、Apple Music ライブラリに自動追加する macOS ネイティブアプリ。

Mac で URL を貼って ⌘↩︎、メタデータを編集して「Apple Music に追加」を押すだけ。iCloud Music Library 経由で iPhone のミュージック.app にも自動で同期される。

## ダウンロード

ビルド済みの `.app` は [Releases](https://github.com/octopusv/YouTube-applamusic-auto-download/releases) から取得できます。

1. `YTtoMusic.dmg` をダウンロードしてダブルクリック
2. ウィンドウが開いたら `YTtoMusic.app` を `Applications` フォルダにドラッグ
3. 初回起動時に「"YTtoMusic"は壊れているため開けません」と表示される場合、ターミナルで：
   ```bash
   xattr -cr /Applications/YTtoMusic.app
   ```
   を実行。これで Gatekeeper の隔離属性が外れて起動できます（署名なしアプリの仕様）
4. 別途 `brew install yt-dlp ffmpeg` が必要

自分でビルドしたい場合は下の「セットアップ」へ。

## 必要なもの

- macOS 14 (Sonoma) 以降
- Xcode 15 以降（自分でビルドする場合）
- Apple Music の契約（iCloud Music Library 経由で同期するため）
- Homebrew

## セットアップ

### 1. 外部ツールのインストール

```bash
brew install yt-dlp ffmpeg
```

### 2. ミュージック.app の設定

- Mac: ミュージック.app → 設定 → 一般 → 「ライブラリを同期」を **ON**
- iPhone: 設定 → ミュージック → 「ライブラリを同期」を **ON**
- Mac と iPhone で同じ Apple ID にサインインしていること

### 3. ビルド

#### A. ワンコマンド（推奨）

```bash
brew install xcodegen
./scripts/build-release.sh --zip
```

`build/Build/Products/Release/YTtoMusic.app` と `build/YTtoMusic.zip` ができる。
GitHub Release まで一気に作るなら:

```bash
./scripts/build-release.sh --release v0.1.0
```

（`gh` CLI が必要 → `brew install gh && gh auth login`）

#### B. Xcode で開く

```bash
brew install xcodegen
xcodegen generate
open YTtoMusic.xcodeproj
```

⌘R で実行。

> `YTtoMusic.xcodeproj` は `xcodegen` で `project.yml` から生成される自動成果物。リポジトリには含まれない（`.gitignore` 済み）。

## 使い方

1. アプリを起動
2. ツールバーの URL 欄に YouTube の URL を貼り付ける（または ⌘V → ⌘↩︎）
3. ダウンロード進行中、サムネとタイトルがプレビュー表示される
4. 完了するとメタデータ編集画面に遷移
   - タイトル / アーティスト / アルバムを編集
   - アートワークが気に入らなければ画像をドラッグ&ドロップで差し替え可能
5. 「Apple Music に追加」を押すと、ミュージック.app の自動取り込みフォルダに保存される
6. 数秒〜数分で iPhone のライブラリにも反映（雲アイコン → タップでオフライン保存）

### キーボードショートカット

| ショートカット | 動作 |
|---|---|
| ⌘N | 新規ダウンロード |
| ⌘V | URL 欄にペースト |
| ⇧⌘V | URL をペーストして即ダウンロード開始 |
| ⌘↩︎ | ダウンロード開始 |
| Esc | 編集をキャンセル |

### その他のヒント

- ブラウザのアドレスバーから URL を **ウィンドウにドラッグ** しても受け付けます
- サイドバーで履歴項目を選ぶと詳細画面（保存先・追加日時・URL）と「ミュージックで開く」ボタンが出ます
- 履歴は `~/Library/Application Support/YTtoMusic/history.json` に保存

## 仕組み

```
YouTube URL
   ↓ yt-dlp -x --audio-format mp3 --write-info-json --write-thumbnail
一時フォルダに mp3 + info.json + サムネ
   ↓ メタデータ編集
   ↓ ffmpeg で ID3v2 タグ + アートワーク埋め込み
~/Music/Music/Media.localized/Automatically Add to Music.localized/
   ↓ ミュージック.app が自動取り込み
ローカルライブラリに追加
   ↓ iCloud アップロード
iPhone のミュージック.app に出現
```

## トラブルシューティング

### 「yt-dlp が見つかりません」

`brew install yt-dlp` 実行後、`/opt/homebrew/bin/yt-dlp` が存在することを確認:

```bash
which yt-dlp
```

Intel Mac の場合は `/usr/local/bin/yt-dlp` でも自動的に検出されます。

### 「自動取り込みフォルダが見つかりません」

ミュージック.app を一度起動して終了すれば作成されます。パスは:

```
~/Music/Music/Media.localized/Automatically Add to Music.localized/
```

### 進捗バーが動かない

`yt-dlp` のバージョン更新で出力フォーマットが変わった可能性があります:

```bash
brew upgrade yt-dlp
```

### Process 起動でエラー

App Sandbox が有効になっていないか確認してください。Signing & Capabilities から削除すれば解決します。

### iPhone に反映されない

- Mac と iPhone の両方で「ライブラリを同期」が ON か確認
- 同じ Apple ID か確認
- ミュージック.app のライブラリに曲は入ったが iCloud アップロードが終わっていない可能性。Mac のミュージック.app で右クリック → 「クラウドで利用可能にする」状態を確認

## 法的事項

YouTube の利用規約はサードパーティによる動画ダウンロードを原則として禁止しています。**自作コンテンツ、許諾済みコンテンツ、パブリックドメイン、CC ライセンスの動画にのみ使用してください**。

このリポジトリは個人利用を前提としており、再配布は想定していません。

## ライセンス

個人プロジェクト。ライセンスは未設定。
