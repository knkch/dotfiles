-- VPN: 接続中のときだけバーに盾のアイコン + 接続名を出す (未接続なら何も出ない)
-- ・NetworkManager の VPN (OpenVPN / IPsec / L2TP) と WireGuard
-- ・Tailscale (tailscale0 があって IP が付いているとき)
-- ・NetworkManager を通さずに作った WireGuard (wg-quick など)
-- 接続処理中は黄色、つながったら緑。ツールチップに一覧、クリックで接続の編集画面
-- 更新は NetworkManager の D-Bus の知らせを受けたとき + NM の外の WireGuard / Tailscale 用に 30 秒ごと
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local Gio   = require("lgi").Gio
local theme = require("modules.theme")

local C = theme.C
local GLYPH = "\u{f099d}" -- nf-md-shield_lock

local icon = theme.bar_glyph() -- ほかのバーのアイコンと同じ並び方 (theme.ink_box)
local text = wibox.widget { widget = wibox.widget.textbox }
local widget = wibox.widget {
    icon,
    text,
    spacing = 6,
    layout  = wibox.layout.fixed.horizontal,
}
local tooltip = awful.tooltip { objects = { widget } }
widget.visible = false -- 未接続のときは隠す (バーの状態のタイルの中に並ぶ)

local TYPE_JA = { vpn = "VPN", wireguard = "WireGuard" }

-- /sys/class/net のインターフェース名 (コマンドを起動せずに読む)
local function interfaces()
    local list = {}
    local ok, e = pcall(Gio.File.enumerate_children, Gio.File.new_for_path("/sys/class/net"),
        "standard::name", Gio.FileQueryInfoFlags.NONE, nil)
    if not (ok and e) then return list end
    for info in function() return e:next_file(nil) end do table.insert(list, info:get_name()) end
    e:close(nil)
    return list
end

local function exists(path)
    local f = io.open(path)
    if f then f:close() return true end
    return false
end

local function show(conns)
    if #conns == 0 then
        widget.visible = false
        return
    end
    local connecting = false
    local lines = {}
    for _, c in ipairs(conns) do
        if c.connecting then connecting = true end
        table.insert(lines, string.format("%s %s (%s)", c.connecting and "…" or "●", c.name, c.kind))
    end
    local color = connecting and C.yellow or C.green
    icon:set(color, GLYPH)
    text.markup = theme.span(C.text, gears.string.xml_escape(conns[1].name) .. (#conns > 1 and (" +" .. (#conns - 1)) or ""))
    tooltip.text = (connecting and "VPN 接続処理中" or "VPN 接続中") .. "\n" .. table.concat(lines, "\n")
        .. "\nクリックで接続の編集"
    widget.visible = true
end

local function update()
    awful.spawn.easy_async({ "nmcli", "-t", "-f", "NAME,TYPE,STATE,DEVICE", "connection", "show", "--active" }, function(out)
        local conns, nm_devices = {}, {}
        for line in out:gmatch("[^\n]+") do
            -- nmcli -t は名前の中の ":" を "\:" にするので、先に置き換えてから区切る
            local name, kind, state, dev = line:gsub("\\:", "\1"):match("^(.*):([^:]*):([^:]*):([^:]*)$")
            if name then
                name = name:gsub("\1", ":")
                if dev ~= "" then nm_devices[dev] = true end
                if TYPE_JA[kind] and (state == "activated" or state == "activating") then
                    table.insert(conns, { name = name, kind = TYPE_JA[kind], connecting = state == "activating" })
                end
            end
        end

        -- NetworkManager 以外で作られた WireGuard
        for _, dev in ipairs(interfaces()) do
            if dev:match("^wg") and not nm_devices[dev] then
                table.insert(conns, { name = dev, kind = "WireGuard" })
            end
        end

        if not exists("/sys/class/net/tailscale0") then
            show(conns)
            return
        end
        -- tailscale0 があってもログアウト中は IP が無いので、それで接続中かを判断する
        awful.spawn.easy_async({ "tailscale", "ip", "-4" }, function(ip, _, _, code)
            if code == 0 and ip:match("%d") then
                table.insert(conns, { name = "Tailscale", kind = "Tailscale " .. ip:match("%S+") })
            end
            show(conns)
        end)
    end)
end

-- 知らせが続けて来ても 1 秒まとめて 1 回だけ確かめる
local soon = gears.timer { timeout = 1, single_shot = true, callback = update }
Gio.bus_get_sync(Gio.BusType.SYSTEM):signal_subscribe("org.freedesktop.NetworkManager", nil, nil, nil, nil,
    Gio.DBusSignalFlags.NONE, function(_, _, path)
        if not path:find("/AccessPoint/") then soon:again() end -- 電波の強さの知らせは関係ない
    end)
gears.timer { timeout = 30, autostart = true, call_now = true, callback = update }

widget:buttons(awful.button({ }, 1, function() awful.spawn("nm-connection-editor") end))

return { widget = widget }
