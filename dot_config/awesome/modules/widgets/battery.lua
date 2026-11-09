-- バッテリー: アイコン + 残量%。/sys/class/power_supply から直接読む
-- ・ツールチップに状態と残り時間
-- ・クリックで電源モード (power-profiles-daemon) を切り替え。D-Bus で直接読み書きし、変わったら知らせを受ける
-- ・AC を抜いたら省電力、挿したらバランスに自動で切り替え
-- ・残量 15% と 5% で通知
local awful   = require("awful")
local gears   = require("gears")
local wibox   = require("wibox")
local naughty = require("naughty")
local lgi     = require("lgi")
local theme   = require("modules.theme")

local Gio, GLib = lgi.Gio, lgi.GLib

local BAT_DIR  = "/sys/class/power_supply/BAT0/"
local AC_FILE  = "/sys/class/power_supply/AC/online"

local STATUS_JA = {
    Charging         = "充電中",
    Discharging      = "バッテリー駆動",
    Full             = "満充電",
    ["Not charging"] = "充電停止中 (AC 接続)",
}

local PROFILES = {
    { id = "power-saver", label = "省電力" },
    { id = "balanced",    label = "バランス" },
    { id = "performance", label = "パフォーマンス" },
}
local function profile_label(id)
    for _, p in ipairs(PROFILES) do if p.id == id then return p.label end end
    return id
end

local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local v = f:read("*l")
    f:close()
    return v
end
local function bat(name) return read(BAT_DIR .. name) end

---------------------------------------------------------------- 電源モード (power-profiles-daemon の D-Bus)
local bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
local PPD_NAME = "org.freedesktop.UPower.PowerProfiles"
local PPD_PATH = "/org/freedesktop/UPower/PowerProfiles"
local PROPS    = "org.freedesktop.DBus.Properties"

local function get_profile()
    local ok, res = pcall(bus.call_sync, bus, PPD_NAME, PPD_PATH, PROPS, "Get",
        GLib.Variant("(ss)", { PPD_NAME, "ActiveProfile" }), GLib.VariantType("(v)"),
        Gio.DBusCallFlags.NONE, 500, nil)
    if ok and res then return res:get_child_value(0).value.value end
end

-- 結果は PropertiesChanged の知らせで受け取る
local function set_profile(id, done)
    bus:call(PPD_NAME, PPD_PATH, PROPS, "Set",
        GLib.Variant("(ssv)", { PPD_NAME, "ActiveProfile", GLib.Variant("s", id) }), nil,
        Gio.DBusCallFlags.NONE, 2000, nil, function(conn, res)
            if pcall(conn.call_finish, conn, res) and done then done() end
        end)
end

---------------------------------------------------------------- ウィジェット
local icon = theme.bar_glyph()
local text = wibox.widget { widget = wibox.widget.textbox }
local widget = wibox.widget {
    icon,
    text,
    spacing = 4,
    layout  = wibox.layout.fixed.horizontal,
}
local tooltip = awful.tooltip { objects = { widget } }

---------------------------------------------------------------- 状態
local profile = nil   -- 今の電源モード
local last_ac = nil   -- 前回の AC 接続状態 (抜き差しの検出用)
local warned  = 0     -- 0: 未通知 / 1: 15% で通知済み / 2: 5% で通知済み

-- 残り時間 (時間)。charge_* か energy_* から計算する
local function hours_left(status)
    local now  = tonumber(bat("charge_now")  or bat("energy_now"))
    local full = tonumber(bat("charge_full") or bat("energy_full"))
    local rate = tonumber(bat("current_now") or bat("power_now"))
    if not (now and full and rate) or rate <= 0 then return nil end
    if status == "Discharging" then return now / rate end
    if status == "Charging" then return (full - now) / rate end
end

-- Nerd Font の電池アイコン (10% 刻み)。[0] は空、[100] は満タン
local G_BAT = { [0] = "\u{f008e}", "\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}",
                "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0079}" }
local G_CHG = { [0] = "\u{f089c}", "\u{f089c}", "\u{f0086}", "\u{f0087}", "\u{f0088}", "\u{f089d}",
                "\u{f0089}", "\u{f089e}", "\u{f008a}", "\u{f008b}", "\u{f0085}" }

-- アイコンと色: 充電中・AC 接続中は緑の稲妻つき、残り 20% 以下は赤
local function icon_of(status, ac, cap)
    local level = math.max(0, math.min(10, math.floor((cap + 5) / 10)))
    if status == "Charging" or ac then return theme.C.green, G_CHG[level] end
    if level <= 2 then return theme.C.urgent, G_BAT[level] end
    return theme.C.text, G_BAT[level]
end

local function switch_profile_on_ac_change(ac)
    if last_ac ~= nil and ac ~= last_ac then
        local id = ac and "balanced" or "power-saver"
        set_profile(id, function()
            naughty.notification { title = "電源モード", timeout = 3,
                message = (ac and "AC 接続: " or "バッテリー駆動: ") .. profile_label(id) .. " に切り替えました" }
        end)
    end
    last_ac = ac
end

local function warn_low(status, cap)
    if status ~= "Discharging" then
        warned = 0 -- 充電を始めたらリセット
    elseif cap <= 5 and warned < 2 then
        warned = 2
        naughty.notification { urgency = "critical",
            title = "バッテリー残量がほとんどありません", message = cap .. "% です。すぐに充電してください" }
    elseif cap <= 15 and warned < 1 then
        warned = 1
        naughty.notification { title = "バッテリー残量が少なくなっています", message = cap .. "% です" }
    end
end

local function update()
    local cap = tonumber(bat("capacity"))
    if not cap then
        widget.visible = false
        return
    end
    local status = bat("status") or "Unknown"
    local ac     = read(AC_FILE) == "1"

    switch_profile_on_ac_change(ac)
    -- 変わったときだけ設定する (同じ値でもバー全体が描き直されるため)
    icon:set(icon_of(status, ac, cap))
    if text.text ~= cap .. "%" then text.text = cap .. "%" end

    local lines = { (STATUS_JA[status] or status) .. "  " .. cap .. "%" }
    local h = hours_left(status)
    if h then
        table.insert(lines, string.format("%s 約 %d 時間 %02d 分",
            status == "Charging" and "満充電まで" or "残り", math.floor(h), math.floor((h % 1) * 60)))
    end
    if profile then table.insert(lines, "電源モード: " .. profile_label(profile)) end
    table.insert(lines, "クリックで電源モードを切り替え")
    tooltip.text = table.concat(lines, "\n")

    warn_low(status, cap)
end

local function update_profile()
    profile = get_profile() or profile
    update()
end

update_profile()
bus:signal_subscribe(PPD_NAME, PROPS, "PropertiesChanged", PPD_PATH, nil, Gio.DBusSignalFlags.NONE,
    function() update_profile() end)
-- AC の抜き差しはすぐ反映したいので 2 秒ごとに確認する (ファイルを読むだけなので軽い)
gears.timer { timeout = 2, autostart = true, callback = update }

---------------------------------------------------------------- 電源モードのメニュー
local menu
local function toggle_menu()
    if menu and menu.wibox.visible then
        menu:hide()
        return
    end
    update_profile()
    local items = {}
    for _, p in ipairs(PROFILES) do
        table.insert(items, { ((p.id == profile) and "● " or "　 ") .. p.label, function() set_profile(p.id) end })
    end
    if menu then menu:hide() end
    menu = awful.menu { items = items }
    menu:show()
end
widget:buttons(awful.button({ }, 1, toggle_menu))

return { widget = widget }
