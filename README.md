# YTtoMusic

YouTube から音声を抽出して、Apple Music ライブラリに自動追加する macOS ネイティブアプリ。

Mac で URL を貼って ⌘↩︎、メタデータを編集して「Apple Music に追加」を押すだけ。iCloud Music Library 経由で iPhone のミュージック.app にも自動で同期される。

## 必要なもの

- macOS 14 (Sonoma) 以降
- Xcode 15 以降
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

### 3. Xcode プロジェクトを作る

1. Xcode → File → New → Project → **macOS → App**
2. Product Name: `YTtoMusic` / Interface: **SwiftUI** / Language: **Swift**
3. Deployment Target を **macOS 14.0** 以上に設定
4. 自動生成された `YTtoMusicApp.swift` と `ContentView.swift` を削除
5. このリポジトリの `Sources/` 内の `.swift` ファイルすべてを Xcode のプロジェクトナビゲータにドラッグ
   - "Copy items if needed" にチェック
   - ターゲット `YTtoMusic` を選択
6. プロジェクト設定 → **Signing & Capabilities → App Sandbox を削除**
   - 理由: `yt-dlp` / `ffmpeg` の起動と `~/Music/...` への書き込みが必要なため
   - 個人利用で配布しないので無効で問題なし

### 4. ビルド

⌘R で実行。

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
