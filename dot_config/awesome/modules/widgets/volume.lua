-- 音量: バーのアイコン (awesome-wm-widgets) + クリックで出るスライダーのポップアップ
-- PipeWire 環境なので device は "default" (pulse だと amixer が動かない)
-- 更新は pactl subscribe で音量の変化を知らされたときだけ (定期的な確認は 60 秒ごとの念のため)
local awful = require("awful")
local gears = require("gears")
local theme = require("modules.theme")
local slider_popup = require("modules.widgets.slider-popup")
local volume_widget = require("awesome-wm-widgets.volume-widget.volume")

local ICON_DIR = gears.filesystem.get_configuration_dir() .. "awesome-wm-widgets/volume-widget/icons/"
local GET      = "amixer -D default sget Master -M"
local SET      = "amixer -D default sset Master -M "
local TOGGLE   = "amixer -D default sset Master toggle"

local bar = volume_widget { widget_type = "icon", device = "default", step = 5, refresh_rate = 60 }
do -- バーのアイコンは画像ではなく、ほかと同じフォントのアイコンで描く
    local C = theme.C
    local G = { high = "\u{f057e}", medium = "\u{f0580}", low = "\u{f057f}", off = "\u{f075f}" }
    -- スピーカーの絵がほかのアイコンより小さいので少し大きく描き、
    -- (幅は絵どおり。音の波の数で少し変わる)
    local glyph = theme.bar_glyph(nil, nil, theme.BAR.icon + 3)
    local function set(color, g) glyph:set(color, g) end
    set(C.text, G.high)
    bar.widget = glyph
    function bar:mute() self.is_muted = true; set(C.subtext, G.off) end
    function bar:unmute() self.is_muted = false end
    function bar:set_volume_level(v)
        if self.is_muted then return set(C.subtext, G.off) end
        v = tonumber(v) or 0
        set(C.text, v >= 66 and G.high or v >= 33 and G.medium or G.low)
    end
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
    popup.run(cmd, autohide, geo, volume_widget.refresh)
end

-- 音量・ミュートの変化を PipeWire (pulse 互換) から知らされたら読み直す。
-- スライダーを動かすと続けて来るので 0.2 秒まとめる。pactl が終わったら 5 秒後に起動し直す
do
    local soon = gears.timer { timeout = 0.2, single_shot = true, callback = function() volume_widget.refresh() end }
    local pid
    local function watch_events()
        pid = awful.spawn.with_line_callback({ "pactl", "subscribe" }, {
            stdout = function(line)
                if line:find("on sink #", 1, true) or line:find("on server", 1, true) then soon:again() end
            end,
            exit = function()
                pid = nil
                gears.timer.start_new(5, function() watch_events() end)
            end,
        })
        if type(pid) ~= "number" then pid = nil end
    end
    watch_events()
    -- Awesome の再起動で pactl が増えていかないように止める
    awesome.connect_signal("exit", function() if pid then awesome.kill(pid, awesome.unix_signal.SIGTERM) end end)
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
