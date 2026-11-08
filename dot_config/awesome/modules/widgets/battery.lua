-- バッテリー: アイコン + 残量%。/sys/class/power_supply から直接読む
-- ・ツールチップに状態と残り時間
-- ・クリックで電源モード (power-profiles-daemon) を切り替え
-- ・AC を抜いたら省電力、挿したらバランスに自動で切り替え
-- ・残量 15% と 5% で通知
local awful   = require("awful")
local gears   = require("gears")
local wibox   = require("wibox")
local naughty = require("naughty")
local theme   = require("modules.theme")

local BAT_DIR  = "/sys/class/power_supply/BAT0/"
local AC_FILE  = "/sys/class/power_supply/AC/online"
local ICON_DIR = gears.filesystem.get_configuration_dir() .. "icons/battery/"

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

---------------------------------------------------------------- ウィジェット
local icon = theme.icon(nil, 30)
local text = wibox.widget { widget = wibox.widget.textbox }
local widget = wibox.widget {
    theme.vcenter(icon),
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

local function icon_name(status, ac, cap)
    local level = math.floor((cap + 5) / 10) * 10 -- 10% 刻み
    if status == "Charging" then
        return level == 100 and "battery-level-100-charged-symbolic"
                             or ("battery-level-" .. level .. "-charging-symbolic")
    elseif ac then
        return "battery-level-" .. level .. "-plugged-in-symbolic"
    elseif level <= 20 then
        return "battery-level-" .. level .. "-low-symbolic" -- 残り少ないときは赤
    end
    return "battery-level-" .. level .. "-symbolic"
end

local function switch_profile_on_ac_change(ac)
    if last_ac ~= nil and ac ~= last_ac then
        local id = ac and "balanced" or "power-saver"
        awful.spawn.easy_async("powerprofilesctl set " .. id, function()
            profile = id
            naughty.notify { title = "電源モード", timeout = 3,
                text = (ac and "AC 接続: " or "バッテリー駆動: ") .. profile_label(id) .. " に切り替えました" }
        end)
    end
    last_ac = ac
end

local function warn_low(status, cap)
    if status ~= "Discharging" then
        warned = 0 -- 充電を始めたらリセット
    elseif cap <= 5 and warned < 2 then
        warned = 2
        naughty.notify { preset = naughty.config.presets.critical,
            title = "バッテリー残量がほとんどありません", text = cap .. "% です。すぐに充電してください" }
    elseif cap <= 15 and warned < 1 then
        warned = 1
        naughty.notify { title = "バッテリー残量が少なくなっています", text = cap .. "% です" }
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
    icon.image = ICON_DIR .. icon_name(status, ac, cap) .. ".svg"
    text.text  = cap .. "%"

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

local function update_profile(after)
    awful.spawn.easy_async("powerprofilesctl get", function(out)
        profile = out:match("^%s*(%S+)") or profile
        update()
        if after then after() end
    end)
end

gears.timer { timeout = 10, autostart = true, call_now = true, callback = function() update_profile() end }
-- AC の抜き差しはすぐ反映したいので 2 秒ごとに確認する (ファイルを読むだけなので軽い)
gears.timer { timeout = 2, autostart = true, callback = update }

---------------------------------------------------------------- 電源モードのメニュー
local menu
local function toggle_menu()
    if menu and menu.wibox.visible then
        menu:hide()
        return
    end
    update_profile(function()
        local items = {}
        for _, p in ipairs(PROFILES) do
            table.insert(items, { ((p.id == profile) and "● " or "　 ") .. p.label, function()
                awful.spawn.easy_async("powerprofilesctl set " .. p.id, function() update_profile() end)
            end })
        end
        if menu then menu:hide() end
        menu = awful.menu { items = items }
        menu:show()
    end)
end
widget:buttons(awful.button({ }, 1, toggle_menu))

return { widget = widget }
