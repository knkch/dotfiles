-- バー右側の状態アイコン: Wi-Fi・Bluetooth・日本語入力・クリップボード
-- トレイ (nm-applet / blueman / fcitx5) の代わり。トレイは透明にできないので、自分で描いてすりガラスのタイルに揃える
-- (元のトレイアイコンは scripts/sni-watcher.py が引き受けて隠している。アプリ自体は裏で動き続ける)
--
-- 更新は軽く: Wi-Fi と Bluetooth は D-Bus の変化の知らせを受けたときだけ確かめる。
-- 日本語入力は知らせが無いので 0.5 秒ごとに fcitx5 に聞く (プロセスを起動しない D-Bus 呼び出し)。
-- どれも表示が変わったときだけ描き直す。
local awful = require("awful")
local gears = require("gears")
local lgi   = require("lgi")
local theme = require("modules.theme")

local Gio, GLib = lgi.Gio, lgi.GLib
local C = theme.C
local ICON_SIZE = theme.BAR.icon

-- Nerd Font のアイコン
local G = {
    wifi     = "\u{f05a9}", -- 強さ別のアイコンは扇の一部しか描かず欠けて見えるので、全体の形 + 色で強さを出す
    wifi_off = "\u{f092e}",
    ethernet = "\u{f0200}",
    bt       = "\u{f00af}",
    bt_on    = "\u{f00b1}", -- 機器がつながっている
    bt_off   = "\u{f00b2}",
    clip     = "\u{f0147}",
}

-- アイコン 1 つ分の部品。set(markup, tooltip) は変わったときだけ描き直す
local function indicator(buttons)
    local tb = theme.ink_box() -- 絵の幅ぴったりで並べる (間隔を揃えるため)
    local tip = awful.tooltip { objects = { tb }, delay_show = 0.5 }
    tb:buttons(buttons)
    local last
    local function set(markup, text)
        if markup ~= last then last = markup; tb.markup = markup end
        tip.text = text
    end
    return tb, set
end

local function spawn(cmd) return function() awful.spawn(cmd) end end

-- 変化の知らせが続けて来ても、まとめて 1 回だけ確かめる
local function debounced(fn, delay)
    local t = gears.timer { timeout = delay or 0.5, single_shot = true, callback = fn }
    return function() t:again() end
end

local system_bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
local session_bus = Gio.bus_get_sync(Gio.BusType.SESSION)

-- skip_path: このパターンに合うオブジェクトからの知らせは無視する
local function on_dbus(bus, sender, fn, skip_path)
    bus:signal_subscribe(sender, nil, nil, nil, nil, Gio.DBusSignalFlags.NONE, function(_, _, path)
        if not (skip_path and path:find(skip_path)) then fn() end
    end)
end

---------------------------------------------------------------- Wi-Fi / 有線
local net, set_net = indicator(gears.table.join(
    awful.button({ }, 1, function() require("modules.widgets.launchers").wifi() end), -- 左: Wi-Fi を選ぶ
    awful.button({ }, 3, spawn("nm-connection-editor"))                        -- 右: 接続の設定
))

local function update_net()
    awful.spawn.easy_async_with_shell(
        "nmcli -t -f TYPE,STATE,CONNECTION device; echo '--'; nmcli -t -f IN-USE,SIGNAL device wifi list --rescan no",
        function(out)
            local devs, aps = out:match("^(.-)\n%-%-\n(.*)$")
            devs, aps = devs or out, aps or ""
            local wired, wifi
            for kind, state, name in devs:gmatch("([^:\n]+):([^:\n]+):([^\n]*)") do
                if state == "connected" then
                    if kind == "ethernet" then wired = name end
                    if kind == "wifi" then wifi = name end
                end
            end
            local signal = tonumber(aps:match("%*:(%d+)")) or 0
            if wired then
                set_net(theme.glyph(C.text, G.ethernet, ICON_SIZE), "有線: " .. wired .. "\n左クリック: Wi-Fi を選ぶ / 右クリック: 接続の設定")
            elseif wifi then
                local color = signal >= 50 and C.text or signal >= 25 and C.yellow or C.urgent
                set_net(theme.glyph(color, G.wifi, ICON_SIZE),
                        string.format("Wi-Fi: %s (%d%%)\n左クリック: Wi-Fi を選ぶ / 右クリック: 接続の設定", wifi, signal))
            else
                set_net(theme.glyph(C.subtext, G.wifi_off, ICON_SIZE), "ネットワークに接続していません\n左クリック: Wi-Fi を選ぶ")
            end
        end)
end
-- 電波の強さ (AccessPoint) の知らせは頻繁なので無視し、30 秒ごとの見直しに任せる
on_dbus(system_bus, "org.freedesktop.NetworkManager", debounced(update_net, 1), "/AccessPoint/")
gears.timer { timeout = 30, autostart = true, call_now = true, callback = update_net }

---------------------------------------------------------------- Bluetooth
local bt, set_bt = indicator(gears.table.join(
    awful.button({ }, 1, spawn("blueman-manager")), -- 左: 機器の管理
    awful.button({ }, 3, function()                 -- 右: オン / オフ
        awful.spawn.with_shell("bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on")
    end)
))

local function update_bt()
    awful.spawn.easy_async_with_shell("bluetoothctl show; echo '--'; bluetoothctl devices Connected", function(out)
        local show, conn = out:match("^(.-)\n%-%-\n(.*)$")
        show, conn = show or out, conn or ""
        local hint = "\n左クリック: 機器の管理 / 右クリック: オン・オフ"
        if not show:match("Powered: yes") then
            set_bt(theme.glyph(C.subtext, G.bt_off, ICON_SIZE), "Bluetooth: オフ" .. hint)
            return
        end
        local names = {}
        for name in conn:gmatch("Device %S+ ([^\n]+)") do table.insert(names, name) end
        if #names > 0 then
            set_bt(theme.glyph(C.sky, G.bt_on, ICON_SIZE), "Bluetooth: " .. table.concat(names, ", ") .. hint)
        else
            set_bt(theme.glyph(C.text, G.bt, ICON_SIZE), "Bluetooth: オン (接続なし)" .. hint)
        end
    end)
end
on_dbus(system_bus, "org.bluez", debounced(update_bt, 1))
update_bt()

---------------------------------------------------------------- 日本語入力 (fcitx5)
local ime, set_ime = indicator(gears.table.join(
    awful.button({ }, 1, spawn("fcitx5-remote -t")),     -- 左: 日本語 / 英字の切り替え
    awful.button({ }, 3, spawn("fcitx5-configtool"))     -- 右: 入力の設定
))

local function fcitx(method, vtype)
    local ok, res = pcall(session_bus.call_sync, session_bus, "org.fcitx.Fcitx5", "/controller",
        "org.fcitx.Fcitx.Controller1", method, nil, GLib.VariantType(vtype), Gio.DBusCallFlags.NONE, 200, nil)
    if ok and res then return res:get_child_value(0).value end
end

local function update_ime()
    local state = fcitx("State", "(i)")
    local hint = "\n左クリック: 切り替え (Ctrl+` / 半角/全角) / 右クリック: 入力の設定"
    if not state then
        set_ime(theme.span(C.subtext, "×", 16), "fcitx5 が動いていません")
    elseif state == 2 then
        set_ime(theme.span(C.peach, "あ", 16, true), "日本語入力 (" .. (fcitx("CurrentInputMethod", "(s)") or "") .. ")" .. hint)
    else
        set_ime(theme.span(C.text, "A", 16, true), "英字入力" .. hint)
    end
end
gears.timer { timeout = 0.5, autostart = true, call_now = true, callback = update_ime }

---------------------------------------------------------------- クリップボード (CopyQ)
local clip, set_clip = indicator(gears.table.join(
    awful.button({ }, 1, spawn("copyq toggle")), -- 左: 履歴の画面
    awful.button({ }, 3, spawn("copyq menu"))    -- 右: 最近の項目をすぐ選ぶメニュー
))
set_clip(theme.glyph(C.text, G.clip, ICON_SIZE), "クリップボード履歴 (Super+v)\n左クリック: 履歴を開く / 右クリック: 最近の項目")

---------------------------------------------------------------- まとめ
-- 並べ方は bar.lua で決める (アプリ系: クリップボード・入力 / 状態系: Bluetooth・Wi-Fi)
return { net = net, bt = bt, ime = ime, clip = clip }
