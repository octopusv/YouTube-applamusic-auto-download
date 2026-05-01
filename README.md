# YTtoMusic

YouTube の動画を **Apple Music ライブラリ** に自動追加 / **任意のフォーマット** で保存 / **プレイリストごと 1 枚のアルバム** にできる macOS ネイティブアプリ。

メタデータ編集 UI、後追い編集、Sparkle 自動アップデート、yt-dlp 自動更新、エラー種別ごとの解決導線まで揃ってます。

---

## ダウンロード

最新の `.app` は **[Releases](https://github.com/octopusv/YouTube-applamusic-auto-download/releases)** から。

1. **`YTtoMusic.dmg` をダウンロード** してダブルクリック
2. ウィンドウで `YTtoMusic.app` を `Applications` フォルダにドラッグ
3. **「壊れているため開けません」** と出たらターミナルで以下を実行：
   ```bash
   xattr -cr /Applications/YTtoMusic.app
   ```
   署名なしアプリの Gatekeeper 隔離属性を外します。
4. 別途 **`brew install yt-dlp ffmpeg`** が必要

> 一度入れれば、以降のバージョンは Sparkle で **アプリ内から自動アップデート** できます。

---

## 機能

サイドバーで 3 つのモードを切り替え：

### 🎵 Apple Music に追加（メイン機能）
- URL 貼り付け → メタデータ編集 → ⌘↩︎ で Apple Music ライブラリに直接追加
- ID3 タグ（タイトル/アーティスト/アルバム/アルバムアーティスト）+ アートワーク自動埋め込み
- アートワーク差し替え（D&D で画像を放り込むだけ）
- iCloud Music Library 経由で **iPhone にも自動反映**

### 📥 ファイルとして保存
- MP4 最高画質 / 1080p / 720p / 480p / MP3 / M4A から選択
- 任意の保存先フォルダ（環境設定で記憶）

### 💿 プレイリスト → アルバム
- YouTube プレイリスト URL を入れるとアルバム名・アーティスト名で 1 枚のアルバムとして取り込み
- アーティスト固定 or 動画ごとに可変、を選択可能
- 全トラック共通アートワーク + トラック番号（N/M）自動付与

### 📜 履歴
- 全ダウンロードを 1 箇所に集約、種別バッジで Apple Music / ファイルを区別
- 検索 + 日付グループ化（今日 / 昨日 / 今週 / ...）
- **後追い編集**: 履歴項目を選んで「編集」 → タイトル / アーティスト / アルバム / アートワークをライブラリ反映後でも書き換え可能
  - Apple Music の曲 → AppleScript で Music.app のライブラリを直接修正
  - ファイル → ffmpeg で ID3 タグを書き換え

### ⚙️ その他
- **yt-dlp 自動更新**: 起動時に GitHub API で最新版チェック → ワンクリックで `brew upgrade yt-dlp`
- **Sparkle 自動更新**: アプリ自体も新バージョンを自動検知 → DL → 署名検証 → 置換 → 再起動まで完全自動
- **YouTube ボット検出回避**: ブラウザ Cookie（Safari/Chrome/Firefox/Edge/Brave）を yt-dlp に渡せる
- **エラー種別判定**: ボット検出 / Cookie アクセス拒否 / ディスクフル / ネットワーク障害 を画面で見分けて解決導線を表示

### キーボードショートカット

| | |
|---|---|
| ⌘N | Apple Music に追加 |
| ⇧⌘N | ファイルとして保存 |
| ⌥⌘N | プレイリスト → アルバム |
| ⌘↩︎ | ダウンロード開始 |
| ⌘V | URL ペースト |
| ⇧⌘V | URL ペーストして即開始 |
| ⌘, | 環境設定 |
| Esc | 編集キャンセル |

---

## 必要環境

- **macOS 14 (Sonoma) 以降**
- **Apple Music サブスクリプション**（Apple Music タブ機能のみ）
- **Homebrew** + `yt-dlp` + `ffmpeg`
- 自分でビルドする場合: Xcode 15+

### ミュージック.app の設定（Apple Music タブを使う場合）

- Mac: ミュージック.app → 設定 → 一般 → **「ライブラリを同期」ON**
- iPhone: 設定 → ミュージック → **「ライブラリを同期」ON**
- 両端末で同じ Apple ID

---

## 使い方

### Apple Music に追加

1. URL 欄に YouTube の URL を貼り付け
2. ⌘↩︎（or「ダウンロード」ボタン）
3. 進捗中にサムネ/タイトルがプレビュー表示される
4. 完了したらメタデータ編集画面：タイトル/アーティスト/アルバム編集、アートワーク D&D 差し替え
5. 「Apple Music に追加」ボタン
6. 数秒〜数分で iPhone のライブラリにも反映

### ファイル保存

1. サイドバー「ファイルとして保存」
2. フォーマット選択（MP4 / MP3 / M4A 等）+ 保存先フォルダ
3. URL 入力 → ダウンロード開始
4. 完了後 Finder で表示 / 開く

### プレイリスト → アルバム

1. サイドバー「プレイリスト → アルバム」
2. プレイリスト URL + アルバム名 + アーティスト固定/可変
3. ダウンロード開始 → 全トラックを 1 アルバムとして Apple Music に追加
4. 失敗トラックは続行 → 完了後にサマリ表示

### URL のドラッグ&ドロップ

ブラウザのアドレスバーからウィンドウに直接ドラッグでも URL を受け付けます。

---

## ビルド（自分でいじりたい場合）

### ワンコマンド

```bash
brew install xcodegen yt-dlp ffmpeg
./scripts/build-release.sh --dmg
```

`build/YTtoMusic.dmg` ができます。

### 自動アップデート付きでリリース

```bash
./scripts/build-release.sh --release v0.X.Y
```

裏でやっていること：
1. XcodeGen で `.xcodeproj` 生成
2. `xcodebuild` で Release ビルド
3. ad-hoc 署名（Sparkle 検証要件）
4. DMG 化（hdiutil + osascript でアイコン配置）
5. Sparkle `sign_update` で Ed25519 署名
6. `appcast.xml` に `<item>` 追記
7. `gh release create` で GitHub Releases にアップロード
8. git log から変更履歴を抽出してリリースノート生成
9. `appcast.xml` を commit & push（既存ユーザーへの自動配信開始）

事前要件: `gh` CLI 認証 + Sparkle EdDSA 鍵（初回 `./.sparkle/bin/generate_keys`）

### Xcode で開く

```bash
xcodegen generate
open YTtoMusic.xcodeproj
```

`YTtoMusic.xcodeproj` は `project.yml` から生成される自動成果物（gitignored）。

---

## 仕組み（簡略図）

```
YouTube URL
   │
   ▼ yt-dlp（PATH 拡張で Deno/EJS 連携、Cookie ブラウザ対応）
   │
mp3 / mp4 / m4a + サムネ + info.json
   │
   ▼ メタデータ編集 UI
   │
   ├─[Apple Music タブ]──▶ ffmpeg で ID3 + アートワーク埋め込み
   │                       → ~/Music/Music/Media.localized/
   │                          Automatically Add to Music.localized/
   │                       → ミュージック.app 自動取り込み
   │                       → iCloud → iPhone
   │
   ├─[ファイル保存]──────▶ 任意フォルダに保存
   │
   └─[プレイリスト]──────▶ 全トラックに同じアルバム/トラック番号
                          → ループで Apple Music タブと同じ経路
```

---

## トラブルシューティング

### 「壊れているため開けません」
署名なしアプリの Gatekeeper 隔離属性。
```bash
xattr -cr /Applications/YTtoMusic.app
```

### 「Sign in to confirm you're not a bot」
YouTube のボット検出。エラー画面で **ブラウザの Cookie ピッカー** から Safari/Chrome/Firefox/Edge/Brave を選んでリトライ。

### 「Cookie の読み取りが拒否されました」
Safari の Cookie は macOS のフルディスクアクセス保護下にあるため、エラー画面の「フルディスクアクセスを許可…」ボタンから設定 → アプリ再起動。または Chrome / Firefox を選べば回避可能。

### 「ディスクの空き容量が不足しています」
保存先か起動ディスクの容量不足。エラー画面に空き容量が表示されます。

### 「ネットワークに接続できません」
Wi-Fi / VPN / プロキシ設定を確認。エラー画面の「ネットワーク設定を開く」ボタンから直接システム設定へ。

### 「yt-dlp が見つかりません」
```bash
brew install yt-dlp
```
インストール後 `which yt-dlp` で `/opt/homebrew/bin/yt-dlp` か `/usr/local/bin/yt-dlp` にあれば自動検出。

### 進捗が固まった
yt-dlp が刷新されて出力フォーマットが変わった可能性。アプリ内バナーから「更新」ボタン、または手動で `brew upgrade yt-dlp`。

### iPhone に反映されない
- Mac/iPhone 両方で「ライブラリを同期」が ON か確認
- 同じ Apple ID か確認
- iCloud アップロードが完了するまで待つ（環境次第で数分）

### 自動アップデートが「最新です」と言うのにバージョンが違う
通常は再起動で解決。それでもおかしければ：
```bash
rm -rf ~/Library/Caches/com.octopusv.YTtoMusic
defaults delete com.octopusv.YTtoMusic SULastCheckTime 2>/dev/null
defaults delete com.octopusv.YTtoMusic SUSkippedVersion 2>/dev/null
```

---

## アーキテクチャ

SwiftUI + Sparkle + AppleScript + ffmpeg + yt-dlp。

詳細は [`CLAUDE.md`](CLAUDE.md)（リポジトリには含まれない開発者向けメモ）か `Sources/` 内のコードを直接参照。

主要コンポーネント：
- `DownloadManager` / `FileDownloadManager` / `PlaylistDownloadManager` — yt-dlp ラッパー
- `MusicLibrary` / `MusicLibraryEditor` — ffmpeg / AppleScript で Music.app と連携
- `AppUpdater` — Sparkle ラッパー
- `YtDlpUpdater` — yt-dlp 自身の更新チェック
- `HistoryStore` / `AppSettings` — JSON / UserDefaults 永続化

---

## 法的事項

YouTube の利用規約はサードパーティによる動画ダウンロードを原則として禁止しています。**自作コンテンツ、許諾済みコンテンツ、パブリックドメイン、CC ライセンスの動画にのみ使用してください**。

本リポジトリは個人利用を前提とした実験的プロジェクトです。再配布や商用利用は想定していません。

## ライセンス

未設定（個人プロジェクト）。
