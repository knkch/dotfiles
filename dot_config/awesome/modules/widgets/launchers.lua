-- 検索パネル (Super+p): 選択パネル (picker.lua) にタブを並べたもの。コマンドの実行はしない
--   アプリ     起動する。よく使うアプリほど上に出る。見つからなければ Web 検索を出す
--   ウィンドウ 開いているウィンドウへ移動 (直前に使った順)
--   電源       ロック・再起動・電源オフなど。危ないものは確認してから
--   Web        既定のブラウザで検索 (URL ならそのページを開く)
--
--   M.open(name)  name のタブで開く ("apps" / "windows" / "power" / "web"。省略で apps)
--   M.windows()   ウィンドウタブで開く (Super+/)
--   M.power()     電源タブで開く (Super+Shift+q / Super+Shift+e)
--   M.wifi()      Wi-Fi を選ぶパネル (バーの Wi-Fi アイコンから。検索パネルのタブには入れない)
--   M.power_action(p)  modules/power.lua の操作を実行する (危ないものは確認してから)
local awful   = require("awful")
local gears   = require("gears")
local naughty = require("naughty")
local theme   = require("modules.theme")
local config  = require("modules.config")
local power   = require("modules.power")
local picker  = require("modules.widgets.picker")
local whisker = require("modules.widgets.whisker-menu")

local C = theme.C
local M = {}

---------------------------------------------------------------- アプリ
local TAB = {}

TAB.apps = {
    name = "アプリ", glyph = "\u{f003b}",
    prompt = "アプリを検索",
    -- よく起動するアプリほど上に (回数は whisker-menu.lua が数えている)
    items = function(done)
        whisker.list_apps(function(apps)
            local h = whisker.launch_counts()
            table.sort(apps, function(a, b)
                local ha, hb = h[a.name] or 0, h[b.name] or 0
                if ha ~= hb then return ha > hb end
                return a.name:lower() < b.name:lower()
            end)
            local items = {}
            for _, a in ipairs(apps) do
                table.insert(items, {
                    text = a.name, sub = whisker.category_name(a.category),
                    icon = a.icon, glyph = not a.icon and "\u{f08c6}" or nil, -- アイコンが無いアプリ
                    keywords = a.cmdline, app = a,
                })
            end
            done(items)
        end)
    end,
    on_select = function(it)
        if it.url then return M.open_url(it.url) end
        whisker.run_app(it.app)
    end,
    -- 見つからなければ Web 検索を出す (TAB.web は下で定義)
    dynamic = function(query, count) if count == 0 then return TAB.web.dynamic(query) end end,
}

---------------------------------------------------------------- ウィンドウ
TAB.windows = {
    name = "ウィンドウ", glyph = "\u{f05b2}",
    prompt = "ウィンドウを検索",
    empty = "開いているウィンドウはありません",
    items = function(done)
        local items = {}
        for _, c in ipairs(client.get()) do
            if c.valid and not c.skip_taskbar and c.type == "normal" then
                local tag = c.first_tag and ("タグ " .. c.first_tag.name) or ""
                -- c.icon は参照が 1 つ付いた生の値。サーフェスにして持ち主を 1 つにする (picker.lua の prepare 参照)
                local raw = c.icon -- 読むたびに参照が増えるので 1 回だけ
                local icon = raw and gears.surface(raw) or nil
                table.insert(items, {
                    text = c.name or c.class or "?",
                    sub  = (c.class or "") .. (tag ~= "" and ("  ·  " .. tag) or "") .. (c.minimized and "  ·  最小化中" or ""),
                    icon = icon, glyph = not icon and "\u{f05b2}" or nil,
                    client = c,
                })
            end
        end
        -- 直前に使っていたものから並べる
        local order = {}
        for i, c in ipairs(awful.client.focus.history.list) do order[c] = i end
        table.sort(items, function(a, b) return (order[a.client] or 1e9) < (order[b.client] or 1e9) end)
        done(items)
    end,
    on_select = function(it) if it.client.valid then it.client:jump_to() end end,
}

---------------------------------------------------------------- 電源
-- 危ないもの (再起動・電源オフ・ログアウト) は確認してから
function M.power_action(p)
    if not p.confirm then return power.run(p) end
    picker.open {
        prompt = p.name .. "しますか？",
        items = {
            { text = "はい、" .. p.name .. "する", glyph = p.glyph, color = C.urgent, yes = true },
            { text = "キャンセル", glyph = "\u{f0156}" },
        },
        on_select = function(it) if it.yes then power.run(p) end end,
    }
end

local power_items = {}
for _, p in ipairs(power.actions) do
    table.insert(power_items, { text = p.name, glyph = p.glyph, action = p })
end

TAB.power = {
    name = "電源", glyph = "\u{f0425}",
    prompt = "電源",
    items = power_items,
    on_select = function(it) M.power_action(it.action) end,
}

---------------------------------------------------------------- Wi-Fi
local function wifi_notify(title, text, critical)
    naughty.notification { app_name = "Wi-Fi", title = title, message = text or "",
                           urgency = critical and "critical" or "normal" }
end

local function wifi_connect(ap)
    local function done(out, _, _, code)
        if code == 0 then wifi_notify(ap.ssid .. " に接続しました")
        else wifi_notify("接続できませんでした", out, true) end
    end
    if ap.known then
        awful.spawn.easy_async({ "nmcli", "connection", "up", "id", ap.ssid }, done)
    elseif ap.secured then
        picker.open {
            prompt = ap.ssid .. " のパスワード",
            password = true,
            on_select = function(it)
                awful.spawn.easy_async({ "nmcli", "device", "wifi", "connect", ap.ssid, "password", it.text }, done)
            end,
        }
    else
        awful.spawn.easy_async({ "nmcli", "device", "wifi", "connect", ap.ssid }, done)
    end
end

TAB.wifi = {
    name = "Wi-Fi", glyph = "\u{f05a9}",
    prompt = "Wi-Fi を検索",
    items = function(done)
        local cmd = "nmcli radio wifi; echo '--'; nmcli -t -f NAME connection show; echo '--';"
                 .. " nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan auto"
        awful.spawn.easy_async_with_shell(cmd, function(out)
            local radio, known_s, aps_s = out:match("^(%S*)\n%-%-\n(.-)\n?%-%-\n(.*)$")
            local known = {}
            for name in (known_s or ""):gmatch("[^\n]+") do known[name] = true end
            local items, seen = {}, {}
            for inuse, signal, security, ssid in (aps_s or ""):gmatch("([^:\n]*):(%d+):([^:\n]*):([^\n]+)") do
                ssid = ssid:gsub("\\:", ":")
                if not seen[ssid] then
                    seen[ssid] = true
                    local sig = tonumber(signal) or 0
                    local secured = security ~= "" and security ~= "--"
                    table.insert(items, {
                        text  = ssid,
                        sub   = (inuse == "*" and "接続中  ·  " or (known[ssid] and "保存済み  ·  " or ""))
                                .. sig .. "%" .. (secured and "  ·  \u{f033e}" or ""),
                        glyph = "\u{f05a9}",
                        color = inuse == "*" and C.sky or sig >= 50 and C.text or sig >= 25 and C.yellow or C.urgent,
                        ap    = { ssid = ssid, secured = secured, known = known[ssid] },
                        rank  = (inuse == "*" and 2000 or 0) + (known[ssid] and 1000 or 0) + sig,
                    })
                end
            end
            -- 接続中 → 保存済み → 電波の強い順
            table.sort(items, function(a, b) return a.rank > b.rank end)
            local on = radio == "enabled"
            table.insert(items, { text = on and "Wi-Fi をオフにする" or "Wi-Fi をオンにする",
                                  glyph = on and "\u{f05aa}" or "\u{f05a9}", toggle = on and "off" or "on" })
            table.insert(items, { text = "接続の詳しい設定", glyph = "\u{f0493}", editor = true })
            done(items)
        end)
    end,
    on_select = function(it)
        if it.toggle then awful.spawn({ "nmcli", "radio", "wifi", it.toggle })
        elseif it.editor then awful.spawn("nm-connection-editor")
        elseif it.ap then wifi_connect(it.ap) end
    end,
}

---------------------------------------------------------------- まとめて検索 (Super+p)
local function urlencode(str)
    return (str:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- 既定のブラウザで開く
function M.open_url(url) awful.spawn({ "xdg-open", url }, false) end

-- 入力に応じて最後に足す項目: Web 検索 (と、URL らしければそのページを開く)
local function web_items(query)
    local q = query:match("^%s*(.-)%s*$")
    if q == "" then return {} end
    local items = {}
    if not q:find("%s") and q:find("%.%a%a") then
        local url = q:find("^%a+://") and q or ("https://" .. q)
        table.insert(items, { text = url, sub = "ページを開く", glyph = "\u{f0337}", color = C.sky, url = url })
    end
    table.insert(items, { text = "「" .. q .. "」を Web で検索", sub = "ブラウザ", glyph = "\u{f0349}",
                          color = C.sky, url = config.web_search:format(urlencode(q)) })
    return items
end

TAB.web = {
    name = "Web", glyph = "\u{f059f}",
    prompt = "Web で検索する言葉か URL",
    empty = "入力すると既定のブラウザで検索します",
    items = {},
    dynamic = web_items,
    on_select = function(it) if it.url then M.open_url(it.url) end end,
}

---------------------------------------------------------------- 検索パネル
local ORDER = { "apps", "windows", "power", "web" }

function M.open(name)
    local tabs, start = {}, 1
    for i, key in ipairs(ORDER) do
        tabs[i] = TAB[key]
        if key == name then start = i end
    end
    picker.open { tabs = tabs, tab = start }
end

function M.windows() M.open("windows") end
function M.power()   M.open("power")   end
function M.wifi()    picker.open(TAB.wifi) end

return M
