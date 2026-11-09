-- よく変える設定: アプリ・修飾キー・タグ・レイアウト
local awful = require("awful")

local config = {}

config.modkey   = "Mod4" -- Super キー
config.terminal = "ghostty"
-- Super+Enter で開くターミナル (毎回新しい tmux セッション。ウィンドウを閉じるとセッションも消える)
config.terminal_tmux = config.terminal .. " -e tmux new-session \\; set-option destroy-unattached on"
config.filemanager = "thunar"
config.editor     = os.getenv("EDITOR") or "nvim"
config.editor_cmd = config.terminal .. " -e " .. config.editor
config.screenshot_dir = os.getenv("HOME") .. "/Pictures/Screenshots"
config.lock_cmd   = "loginctl lock-session"
config.launcher_icon = "/usr/share/pixmaps/archlinux-logo.svg"
-- Super+p の検索パネルの「Web で検索」で開く検索ページ (%s に検索語が入る)。既定のブラウザで開く
config.web_search = "https://www.google.com/search?q=%s"

config.tags = { "1", "2", "3", "4", "5", "6", "7", "8", "9" }

-- Super+Space で切り替えるレイアウト (先頭がタグの初期レイアウト)
-- max.fullscreen は小さく戻せなくなりやすいので外している
config.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.fair,
    awful.layout.suit.max,
    awful.layout.suit.magnifier,
}

return config
