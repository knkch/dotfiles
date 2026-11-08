-- 画面の明るさ: バーのアイコン + クリックで出るスライダーのポップアップ (brightnessctl)
local awful = require("awful")
local gears = require("gears")
local theme = require("modules.theme")
local slider_popup = require("modules.widgets.slider-popup")
local nightlight   = require("modules.widgets.nightlight")

local ICON = gears.filesystem.get_configuration_dir() .. "icons/brightness.svg"
local GET  = "brightnessctl -m"
local SET  = "brightnessctl -m --min-value=1% set " -- 真っ暗にならないよう最低 1%

local bar = theme.vcenter(theme.icon(ICON, 28))

local popup = slider_popup {
    icon    = theme.icon(ICON, 28),
    minimum = 1,
    get_cmd = GET,
    set_cmd = function(v) return SET .. v .. "%" end,
    -- 出力の例: intel_backlight,backlight,62400,65%,96000
    parse   = function(out) return tonumber(out:match(",(%d+)%%,")) end,
    -- スライダーの下にブルーライトカットのオン/オフ
    extra   = nightlight.row(),
    on_show = nightlight.refresh,
}

local brightness = { widget = bar }
function brightness.up(geo)   popup.run(SET .. "5%+", true, geo) end
function brightness.down(geo) popup.run(SET .. "5%-", true, geo) end

local here = theme.under_mouse
bar:buttons(gears.table.join(
    awful.button({ }, 1, popup.toggle),                          -- 左クリック: ポップアップ
    awful.button({ }, 4, function() brightness.up(here()) end),  -- ホイール上: 明るく
    awful.button({ }, 5, function() brightness.down(here()) end) -- ホイール下: 暗く
))

return brightness
