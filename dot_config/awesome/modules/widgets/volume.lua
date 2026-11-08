-- 音量: バーのアイコン (awesome-wm-widgets) + クリックで出るスライダーのポップアップ
-- PipeWire 環境なので device は "default" (pulse だと amixer が動かない)
local awful = require("awful")
local gears = require("gears")
local theme = require("modules.theme")
local slider_popup = require("modules.widgets.slider-popup")
local volume_widget = require("awesome-wm-widgets.volume-widget.volume")

local ICON_DIR = gears.filesystem.get_configuration_dir() .. "awesome-wm-widgets/volume-widget/icons/"
local GET      = "amixer -D default sget Master -M"
local SET      = "amixer -D default sset Master -M "
local TOGGLE   = "amixer -D default sset Master toggle"

local bar = volume_widget { widget_type = "icon", device = "default", step = 5 }
do -- バーに合わせてアイコンを大きくする
    local icon = bar:get_children_by_id("icon")[1]
    icon.resize, icon.forced_width, icon.forced_height = true, 30, 30
end

-- ポップアップ左端のミュートボタン
local mute_btn = theme.icon(ICON_DIR .. "audio-volume-high-symbolic.svg", 28)
local function set_muted(muted)
    mute_btn.image = ICON_DIR .. (muted and "audio-volume-muted-symbolic.svg" or "audio-volume-high-symbolic.svg")
end

local popup = slider_popup {
    icon      = mute_btn,
    get_cmd   = GET,
    set_cmd   = function(v) return SET .. v .. "% unmute" end, -- 動かしたらミュートも解除
    parse     = function(out) return tonumber(out:match("(%d+)%%")) end,
    on_output = function(out) set_muted(out:match("%[off%]") ~= nil) end,
    on_slide  = function() set_muted(false) end,
}

-- 実行後にバーのアイコンもすぐ更新する
local function run(cmd, autohide, geo)
    popup.run(cmd, autohide, geo, function() volume_widget:inc(0) end)
end

local volume = { widget = bar }
function volume.up(geo)   run(SET .. "5%+", true, geo) end
function volume.down(geo) run(SET .. "5%-", true, geo) end
function volume.mute(geo) run(TOGGLE, true, geo) end

mute_btn:buttons(awful.button({ }, 1, function() run(TOGGLE, false) end))

-- 右クリックの出力先一覧は pacmd が必要で PipeWire では動かないので、pavucontrol を開く
local here = theme.under_mouse
bar:buttons(gears.table.join(
    awful.button({ }, 1, popup.toggle),                           -- 左クリック: ポップアップ
    awful.button({ }, 2, function() volume.mute(here()) end),     -- 中クリック: ミュート
    awful.button({ }, 3, function() volume_widget:mixer() end),   -- 右クリック: pavucontrol
    awful.button({ }, 4, function() volume.up(here()) end),       -- ホイール上: 上げる
    awful.button({ }, 5, function() volume.down(here()) end)      -- ホイール下: 下げる
))

return volume
