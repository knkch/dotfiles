-- メニュー: 右クリックメニュー、Whisker 風アプリメニュー、バーの Arch ロゴ
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local hotkeys_popup = require("awful.hotkeys_popup")
local config = require("modules.config")

local menu = {}

-- 右クリックメニュー (デスクトップ・ロゴの右クリック、Super+w)
menu.main = awful.menu { items = {
    { "ショートカット一覧", function() hotkeys_popup.show_help(nil, awful.screen.focused()) end },
    { "マニュアル",         config.terminal .. " -e man awesome" },
    { "設定を編集",         config.editor_cmd .. " " .. awesome.conffile },
    { "Awesome を再起動",   awesome.restart },
    { "ログアウト",         function() awesome.quit() end },
    { "ターミナルを開く",   config.terminal_tmux },
} }

-- XFCE の Whisker メニュー風アプリメニュー (左クリック、Super+a)
menu.whisker = require("modules.widgets.whisker-menu")

function menu.toggle_whisker() menu.main:hide(); menu.whisker.toggle() end
function menu.toggle_main()    menu.whisker.hide(); menu.main:toggle() end

-- バーの Arch ロゴ: 左クリックで Whisker 風メニュー、右クリックで右クリックメニュー
menu.launcher = wibox.widget { image = config.launcher_icon, resize = true, widget = wibox.widget.imagebox }
menu.launcher:buttons(gears.table.join(
    awful.button({ }, 1, menu.toggle_whisker),
    awful.button({ }, 3, menu.toggle_main)
))

return menu
