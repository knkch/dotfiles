-- Awesome の設定の入口。中身は modules/ に分けてあり、ここでは読み込む順番だけを決める
--
--   modules/config.lua    アプリ・修飾キー・タグ・レイアウト (よく変える設定)
--   modules/theme.lua     配色・フォント・各部品の見た目、共通の部品
--   modules/menu.lua      右クリックメニュー・アプリメニュー・Arch ロゴ
--   modules/bar.lua       画面上部のバー
--   modules/keys.lua      キーボードとマウスの操作
--   modules/rules.lua     新しいウィンドウのルール
--   modules/signals.lua   タイトルバー・フォーカスまわり
--   modules/widgets/      バーと Dock の部品 (音量・明るさ・バッテリー・VPN・時計・MPD・壁紙・アプリメニュー・Dock)

-- LuaRocks で入れたライブラリ (lgi など) を使えるようにする。無ければ何もしない
pcall(require, "luarocks.loader")

local awful   = require("awful")
local naughty = require("naughty")
require("awful.autofocus")
require("awful.hotkeys_popup.keys") -- vim などのショートカットも Super+s の一覧に出す

---------------------------------------------------------------- エラー通知
-- 起動時のエラー (この場合は標準の設定で起動している)
if awesome.startup_errors then
    naughty.notify { preset = naughty.config.presets.critical,
                     title = "起動時にエラーが発生しました", text = awesome.startup_errors }
end
-- 動作中のエラー
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        if in_error then return end -- エラーの無限ループを防ぐ
        in_error = true
        naughty.notify { preset = naughty.config.presets.critical,
                         title = "エラーが発生しました", text = tostring(err) }
        in_error = false
    end)
end

---------------------------------------------------------------- 読み込み
local config = require("modules.config")
require("modules.theme") -- 見た目の設定は、部品を作るより先に読む

awful.layout.layouts = config.layouts
require("menubar").utils.terminal = config.terminal -- ターミナルで動くアプリをメニューから開くとき用

-- 壁紙は feh で管理する (~/.fehbg に記録)。起動時と画面サイズが変わったときに貼り直す
local restore_wallpaper = require("modules.widgets.wallpaper").restore
screen.connect_signal("property::geometry", restore_wallpaper)

local make_bar = require("modules.bar")
awful.screen.connect_for_each_screen(function(s)
    restore_wallpaper()
    awful.tag(config.tags, s, awful.layout.layouts[1])
    make_bar(s)
end)

require("modules.widgets.dock") -- 画面下の Dock (マウスを下端に当てると出る)

local keys = require("modules.keys")
require("modules.rules")(keys)
require("modules.signals")
