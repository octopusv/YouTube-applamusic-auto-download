#!/usr/bin/env bash
# クラウドライブラリ更新メニューを叩く（または構造を確認する）。
#
# 使い方:
#   ./debug-cloud-sync.sh           # メニュー構造を表示するだけ
#   ./debug-cloud-sync.sh --run     # 実際に「クラウドライブラリをアップデート」をクリック

set -e

MODE="${1:-inspect}"

if [[ "$MODE" == "--run" ]]; then
    echo "==> クラウドライブラリをアップデート を実行"
    osascript <<'APPLESCRIPT'
tell application "Music" to activate
delay 0.4
tell application "System Events"
    tell process "Music"
        set fileMenu to missing value
        try
            set fileMenu to menu bar item "ファイル" of menu bar 1
        end try
        if fileMenu is missing value then
            set fileMenu to menu bar item "File" of menu bar 1
        end if
        click fileMenu
        delay 0.2

        set libraryItem to missing value
        try
            set libraryItem to menu item "ライブラリ" of menu 1 of fileMenu
        end try
        if libraryItem is missing value then
            set libraryItem to menu item "Library" of menu 1 of fileMenu
        end if
        click libraryItem
        delay 0.2

        set candidates to {"クラウドライブラリをアップデート", "クラウドミュージックライブラリを更新", "iCloud ミュージックライブラリを更新", "Update Cloud Library", "Update iCloud Music Library"}
        set updateItem to missing value
        repeat with c in candidates
            try
                set updateItem to menu item (c as string) of menu 1 of libraryItem
                exit repeat
            end try
        end repeat
        if updateItem is missing value then
            error "クラウドライブラリ更新メニューが見つかりません"
        end if
        click updateItem
        return "clicked: " & (name of updateItem)
    end tell
end tell
APPLESCRIPT
    exit 0
fi

echo "==> ミュージック.app のメニュー構造を確認"
osascript <<'APPLESCRIPT'
tell application "Music" to activate
delay 0.4
tell application "System Events"
    tell process "Music"
        set output to "menu bar items:" & linefeed
        repeat with mbi in (every menu bar item of menu bar 1)
            set output to output & "  - " & (name of mbi) & linefeed
        end repeat

        try
            set fileMenu to menu bar item "ファイル" of menu bar 1
        on error
            set fileMenu to menu bar item "File" of menu bar 1
        end try

        click fileMenu
        delay 0.3
        set output to output & linefeed & "ファイル menu items:" & linefeed
        repeat with mi in (every menu item of menu 1 of fileMenu)
            set nm to name of mi
            if nm is missing value then
                set output to output & "  - (separator)" & linefeed
            else
                set output to output & "  - " & nm & linefeed
                try
                    set subItems to every menu item of menu 1 of mi
                    repeat with si in subItems
                        set sn to name of si
                        if sn is missing value then
                            set output to output & "      * (separator)" & linefeed
                        else
                            set output to output & "      * " & sn & linefeed
                        end if
                    end repeat
                end try
            end if
        end repeat

        key code 53 -- ESC
        return output
    end tell
end tell
APPLESCRIPT
