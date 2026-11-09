-- 画面下の Dock (普段は隠れていて、マウスを画面の一番下に当てると出てくる)
--   左クリック: 起動していなければ起動。起動中ならそのウィンドウへ移動 (何個かあれば順番に切り替え)
--   中クリック: もう 1 つ新しく起動
--   右クリック: メニュー (新しいウィンドウ / 左へ / 右へ / 区切りを入れる / Dock から外す / Dock に追加)
--   ドラッグ: Dock に固定したアプリと区切りは、左右にドラッグして並べ替えられる
--   右端の ＋: インストール済みのアプリを検索して Dock に追加 (選択パネル)
--   区切り線の右: Dock に無いけれど起動中のアプリ
--   アイコンの下の印: 起動中 = 短い線、使用中 = 長い線
-- 並びは ~/.config/awesome/dock-apps に保存する (Dock の右クリックメニューやドラッグで変えると書き換わる)
local awful         = require("awful")
local gears         = require("gears")
local wibox         = require("wibox")
local menubar_utils = require("menubar.utils")
local theme         = require("modules.theme")
local picker        = require("modules.widgets.picker")
local C = theme.C

local ICON_SIZE  = 56
local MARGIN     = 8    -- 画面の下端からのすき間
local HIDE_DELAY = 0.5  -- マウスが離れてから隠れるまでの秒数
local PIN_FILE   = gears.filesystem.get_configuration_dir() .. "dock-apps"

---------------------------------------------------------------- .desktop ファイル
local DESKTOP_DIRS = {
    os.getenv("HOME") .. "/.local/share/applications/",
    "/usr/share/applications/",
}

-- アイコンを探す (Awesome の検索は大きいサイズを見ないので、見つからなければ自分で探す)
local function find_icon(name)
    if not name or name == "" then return nil end
    if name:sub(1, 1) == "/" then return name end
    local found = menubar_utils.lookup_icon(name)
    if found then return found end
    for _, dir in ipairs { "scalable", "512x512", "256x256", "192x192", "128x128" } do
        for _, ext in ipairs { ".svg", ".png" } do
            local path = "/usr/share/icons/hicolor/" .. dir .. "/apps/" .. name .. ext
            if gears.filesystem.file_readable(path) then return path end
        end
    end
    for _, ext in ipairs { ".svg", ".png" } do
        local path = "/usr/share/pixmaps/" .. name .. ext
        if gears.filesystem.file_readable(path) then return path end
    end
end

-- .desktop の id (ファイル名) から、ウィンドウの種類名として使う文字を作る (例: org.xfce.mousepad → mousepad)
local function class_from_id(id)
    local base = id:gsub("%.desktop$", "")
    return (base:match("([^%.]+)$") or base):lower()
end

local function read_desktop(id)
    for _, dir in ipairs(DESKTOP_DIRS) do
        if gears.filesystem.file_readable(dir .. id) then
            local p = menubar_utils.parse_desktop_file(dir .. id)
            if p then
                return {
                    id     = id,
                    name   = p.Name or id,
                    icon   = p.icon_path or find_icon(p.Icon),
                    cmd    = p.cmdline,
                    class  = (p.StartupWMClass or class_from_id(id)):lower(),
                    hidden = p.NoDisplay or p.Hidden,
                }
            end
        end
    end
end

-- インストール済みのアプリの一覧 (メニューに出ないものは除く)
-- 読むのに少し時間がかかるので覚えておく。refresh = true で読み直す
local desktop_cache
local function all_desktops(refresh)
    if desktop_cache and not refresh then return desktop_cache end
    local seen, list = {}, {}
    for _, dir in ipairs(DESKTOP_DIRS) do
        local f = io.popen("ls -1 '" .. dir .. "' 2>/dev/null")
        if f then
            for id in f:lines() do
                if id:match("%.desktop$") and not seen[id] then
                    seen[id] = true
                    local d = read_desktop(id)
                    if d and not d.hidden and d.cmd then table.insert(list, d) end
                end
            end
            f:close()
        end
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    desktop_cache = list
    return list
end

-- ウィンドウから、そのアプリの .desktop を探す
local function desktop_for_client(c)
    local class = (c.class or ""):lower()
    local instance = (c.instance or ""):lower()
    local best
    for _, d in ipairs(all_desktops()) do
        if d.class == class or d.class == instance then return d end
        if not best and (class:find(d.class, 1, true) or instance:find(d.class, 1, true)) then best = d end
    end
    return best
end

---------------------------------------------------------------- 固定したアプリの保存
-- 1 行 1 アプリ: desktop<TAB>class<TAB>cmd (cmd は空なら .desktop の Exec)。区切りは "---" の 1 行
local SEPARATOR = "---"
local pins = {}

local function load_pins()
    pins = {}
    local f = io.open(PIN_FILE)
    if not f then return end
    for line in f:lines() do
        if line == SEPARATOR then table.insert(pins, { separator = true }) end
        local desktop, class, cmd = line:match("^([^\t]*)\t([^\t]*)\t?(.*)$")
        if class and class ~= "" then
            table.insert(pins, { desktop = desktop, class = class, cmd = cmd ~= "" and cmd or nil })
        end
    end
    f:close()
end

local function save_pins()
    local f = io.open(PIN_FILE, "w")
    if not f then return end
    for _, p in ipairs(pins) do
        if p.separator then
            f:write(SEPARATOR, "\n")
        else
            f:write(p.desktop or "", "\t", p.class, "\t", p.cmd or "", "\n")
        end
    end
    f:close()
end

---------------------------------------------------------------- アプリの操作
local function matches(app, c)
    local s = ((c.class or "") .. " " .. (c.instance or "")):lower()
    return s:find(app.class, 1, true) ~= nil
end

-- そのアプリのウィンドウを、最近使った順に
local function clients_of(app)
    local list, seen = {}, {}
    for _, c in ipairs(awful.client.focus.history.list) do
        if c.valid and matches(app, c) then table.insert(list, c) seen[c] = true end
    end
    for _, c in ipairs(client.get()) do
        if not seen[c] and matches(app, c) then table.insert(list, c) end
    end
    return list
end

local function launch(app)
    if app.cmd then awful.spawn(app.cmd) end
end

local function activate(app)
    local list = clients_of(app)
    if #list == 0 then return launch(app) end
    local target = list[1]
    -- もう使っている最中なら、同じアプリの次のウィンドウへ
    if client.focus and matches(app, client.focus) and #list > 1 then
        for i, c in ipairs(list) do
            if c == client.focus then target = list[i % #list + 1] break end
        end
    end
    target:jump_to(false)
end

-- Dock の候補にするウィンドウ (普通のウィンドウだけ。壁紙の一覧などは除く)
local function is_app_window(c)
    return c.valid and c.type == "normal" and not c.skip_taskbar and c.class and c.class ~= ""
        and c.class ~= "feh-wallpaper"
end

-- 起動中のウィンドウのコマンド (.desktop が見つからないとき用)
local function cmdline_of(c)
    if not c.pid then return nil end
    local f = io.open("/proc/" .. c.pid .. "/cmdline", "rb")
    if not f then return nil end
    local raw = f:read("*a") f:close()
    local args = {}
    for a in raw:gmatch("[^%z]+") do table.insert(args, "'" .. a:gsub("'", "'\\''") .. "'") end
    return #args > 0 and table.concat(args, " ") or nil
end

---------------------------------------------------------------- Dock 本体
local row = wibox.layout.fixed.horizontal()
row.spacing = 4

local content = theme.glass(wibox.container.margin(row, 6, 6, 6, 6), 20)

local dock = wibox {
    type    = "dock",       -- picom のすりガラスがかかる
    ontop   = true,
    visible = false,
    bg      = C.transparent,
    shape   = theme.rounded(20),
    widget  = content,
}

-- 画面の一番下 1 ピクセルの見えない帯。マウスが当たったら Dock を出す
local trigger = wibox {
    type    = "utility",
    ontop   = true,
    visible = true,
    bg      = C.transparent,
    height  = 1,
}

local function place()
    local s = screen.primary
    local g = s.geometry
    local w, h = wibox.widget.base.fit_widget(content, { dpi = s.dpi }, content, g.width, g.height)
    dock.screen = s
    dock.width, dock.height = math.max(1, w), math.max(1, h)
    dock.x = g.x + math.floor((g.width - dock.width) / 2)
    dock.y = g.y + g.height - dock.height - MARGIN
    trigger.screen = s
    trigger.x, trigger.y, trigger.width = g.x, g.y + g.height - 1, g.width
end

local menu_open = false
local hide_timer = gears.timer {
    timeout     = HIDE_DELAY,
    single_shot = true,
    callback    = function() if not menu_open then dock.visible = false end end,
}

local function show()
    -- 全画面で動画などを見ているときは出さない
    if client.focus and client.focus.fullscreen then return end
    hide_timer:stop()
    if not dock.visible then
        place()
        dock.visible = true
    end
end

trigger:connect_signal("mouse::enter", show)
trigger:connect_signal("mouse::leave", function() hide_timer:again() end)
dock:connect_signal("mouse::enter", function() hide_timer:stop() end)
dock:connect_signal("mouse::leave", function() hide_timer:again() end)

-- 右クリックのメニュー。開いている間は Dock を隠さない
local current_menu
local function open_menu(items)
    if current_menu then current_menu:hide() end
    current_menu = awful.menu { items = items, theme = { width = 220 } }
    menu_open = true
    current_menu.wibox:connect_signal("property::visible", function(w)
        if not w.visible then
            menu_open = false
            hide_timer:again()
        end
    end)
    current_menu:show()
end

---------------------------------------------------------------- 並べ直し
local items = {}
local rebuild -- 下で定義

-- 並びを保存して Dock を作り直す
local function commit()
    save_pins()
    rebuild()
end

local function move_pin(from, to)
    if to < 1 or to > #pins or from == to then return end
    table.insert(pins, to, table.remove(pins, from))
    commit()
end

-- 右クリックメニューの「左へ / 右へ / 外す」
local function pin_menu_entries(index, remove_label)
    local entries = {}
    if index > 1 then table.insert(entries, { "← 左へ移動", function() move_pin(index, index - 1) end }) end
    if index < #pins then table.insert(entries, { "右へ移動 →", function() move_pin(index, index + 1) end }) end
    table.insert(entries, { remove_label, function() table.remove(pins, index) commit() end })
    return entries
end

-- ドラッグで並べ替え
-- 押してから少し動かすとドラッグ、動かさずに離すとクリック (on_click) になる
local slot_of = {}  -- Dock の部品 → pins の何番目か
local dragging      -- ドラッグ中の pins の番号 (その部品を半透明にする)

local function slot_at(x)
    local hits = dock:find_widgets(x - dock.x, math.floor(dock.height / 2))
    for i = #hits, 1, -1 do
        local index = slot_of[hits[i].widget]
        if index then return index end
    end
end

local function start_drag(index, on_click)
    local start = mouse.coords()
    local moved, current = false, index
    mousegrabber.run(function(m)
        if not m.buttons[1] then -- 離した
            if moved then
                dragging = nil
                commit()
            else
                on_click()
            end
            -- Dock の外で離したときは隠す
            local g = dock:geometry()
            if m.x < g.x or m.x > g.x + g.width or m.y < g.y then hide_timer:again() end
            return false
        end
        if not moved and math.abs(m.x - start.x) + math.abs(m.y - start.y) > 6 then
            moved, dragging = true, current
            rebuild()
        end
        if moved then
            local target = slot_at(m.x)
            if target and target ~= current then
                table.insert(pins, target, table.remove(pins, current))
                current, dragging = target, target
                rebuild()
            end
        end
        return true
    end, "fleur")
end

local function make_item(app, pinned, index)
    -- 起動中の印 (中身が空だと大きさ 0 になって描かれないので、空の文字を入れておく)
    local indicator = wibox.widget {
        wibox.widget.textbox(),
        forced_height = 5,
        forced_width  = 8,
        shape         = gears.shape.rounded_bar,
        widget        = wibox.container.background,
    }
    local icon = app.icon and theme.icon(app.icon, ICON_SIZE)
        or wibox.widget {
            app.client and awful.widget.clienticon(app.client) or theme.icon(find_icon("application-x-executable"), ICON_SIZE),
            forced_width = ICON_SIZE, forced_height = ICON_SIZE,
            widget = wibox.container.constraint,
        }
    local item = wibox.widget {
        {
            {
                icon,
                { indicator, halign = "center", widget = wibox.container.place },
                spacing = 4,
                layout  = wibox.layout.fixed.vertical,
            },
            left = 8, right = 8, top = 8, bottom = 4,
            widget = wibox.container.margin,
        },
        shape  = theme.rounded(14),
        widget = wibox.container.background,
    }

    function item.update()
        local list = clients_of(app)
        local focused = client.focus and matches(app, client.focus)
        indicator.bg           = #list == 0 and C.transparent or (focused and C.sky or C.subtext)
        indicator.forced_width = focused and 22 or 10
    end

    local function menu()
        local entries = pinned and pin_menu_entries(index, "Dock から外す") or {}
        if pinned then
            table.insert(entries, #entries, { "右に区切りを入れる", function()
                table.insert(pins, index + 1, { separator = true })
                commit()
            end })
        else
            table.insert(entries, { "Dock に追加", function()
                table.insert(pins, { desktop = app.desktop, class = app.class, cmd = app.desktop == nil and app.cmd or nil })
                commit()
            end })
        end
        if app.cmd then table.insert(entries, 1, { "新しいウィンドウ", function() launch(app) end }) end
        open_menu(entries)
    end

    theme.hover(item, C.overlay .. "99")
    if pinned then
        slot_of[item] = index
        if index == dragging then item.opacity = 0.4 end
    end
    item:buttons(gears.table.join(
        awful.button({ }, 1, function()
            if pinned then start_drag(index, function() activate(app) end) else activate(app) end
        end),
        awful.button({ }, 2, function() launch(app) end),
        awful.button({ }, 3, menu)
    ))
    awful.tooltip { objects = { item }, text = app.name, delay_show = 0.4 }
    table.insert(items, item)
    return item
end

-- ＋ボタン: 選択パネルでインストール済みのアプリを検索して追加
local function pick_app()
    local choices = {}
    for _, d in ipairs(all_desktops(true)) do -- 新しく入れたアプリも出るように読み直す
        table.insert(choices, { text = d.name, icon = d.icon, glyph = not d.icon and "\u{f08c6}" or nil, desktop = d })
    end
    picker.open {
        prompt = "Dock に追加するアプリ",
        items = choices,
        on_select = function(it)
            local d = it.desktop
            for _, p in ipairs(pins) do
                if p.desktop == d.id then return end -- もう Dock にある
            end
            table.insert(pins, { desktop = d.id, class = d.class })
            commit()
            show()
        end,
    }
end

local function plus_button()
    local label = wibox.widget {
        markup = theme.span(C.subtext, "+", 28, true),
        align  = "center", valign = "center",
        forced_width = ICON_SIZE, forced_height = ICON_SIZE,
        widget = wibox.widget.textbox,
    }
    local button = wibox.widget {
        { label, left = 8, right = 8, top = 8, bottom = 13, widget = wibox.container.margin },
        shape  = theme.rounded(14),
        widget = wibox.container.background,
    }
    theme.hover(button, C.overlay .. "99")
    button:buttons(gears.table.join(awful.button({ }, 1, pick_app)))
    awful.tooltip { objects = { button }, text = "アプリを Dock に追加", delay_show = 0.4 }
    return button
end

local function separator()
    return wibox.widget {
        {
            wibox.widget.textbox(),
            forced_width = 1, forced_height = ICON_SIZE - 8,
            bg = C.overlay, widget = wibox.container.background,
        },
        valign = "center", left = 4, right = 4,
        widget = wibox.container.place,
    }
end

-- 自分で入れた区切り (ドラッグで動かせる。右クリックで外す)
local function user_separator(index)
    local w = wibox.widget {
        {
            {
                wibox.widget.textbox(),
                forced_width = 2, forced_height = ICON_SIZE - 8,
                bg = C.subtext, shape = gears.shape.rounded_bar,
                widget = wibox.container.background,
            },
            valign = "center", halign = "center",
            widget = wibox.container.place,
        },
        forced_width = 16,
        shape  = theme.rounded(6),
        widget = wibox.container.background,
    }
    theme.hover(w, C.overlay .. "66")
    slot_of[w] = index
    if index == dragging then w.opacity = 0.4 end
    w:buttons(gears.table.join(
        awful.button({ }, 1, function() start_drag(index, function() end) end),
        awful.button({ }, 3, function() open_menu(pin_menu_entries(index, "区切りを外す")) end)
    ))
    return w
end

-- 固定したアプリ (pins) と、Dock に無い起動中のアプリから、並びを作る
local shown_key
function rebuild()
    items, slot_of = {}, {}
    row:reset()
    local pinned_apps = {}
    for i, p in ipairs(pins) do
        if p.separator then
            row:add(user_separator(i))
            goto continue
        end
        local d = p.desktop and p.desktop ~= "" and read_desktop(p.desktop)
        local app = {
            name    = d and d.name or p.class,
            icon    = d and d.icon or find_icon(p.class),
            cmd     = p.cmd or (d and d.cmd),
            class   = p.class:lower(),
            desktop = p.desktop,
        }
        table.insert(pinned_apps, app)
        row:add(make_item(app, true, i))
        ::continue::
    end

    -- Dock に無い起動中のアプリ (同じアプリのウィンドウは 1 つにまとめる)
    local extra, seen = {}, {}
    for _, c in ipairs(client.get()) do
        if is_app_window(c) then
            local is_pinned = false
            for _, app in ipairs(pinned_apps) do
                if matches(app, c) then is_pinned = true break end
            end
            local key = c.class:lower()
            if not is_pinned and not seen[key] then
                seen[key] = true
                local d = desktop_for_client(c)
                table.insert(extra, {
                    name    = d and d.name or c.class,
                    icon    = d and d.icon,
                    cmd     = d and d.cmd or cmdline_of(c),
                    class   = d and d.class or key,
                    desktop = d and d.id,
                    client  = c,
                })
            end
        end
    end
    if #extra > 0 then
        row:add(separator())
        for _, app in ipairs(extra) do row:add(make_item(app, false)) end
    end

    row:add(separator())
    row:add(plus_button())

    for _, item in ipairs(items) do item.update() end
    if dock.visible then place() end
end

-- Dock に無いアプリのウィンドウが増えた・減ったときだけ並べ直す
local function running_key()
    local keys = {}
    for _, c in ipairs(client.get()) do
        if is_app_window(c) then keys[c.class:lower()] = true end
    end
    local list = {}
    for k in pairs(keys) do table.insert(list, k) end
    table.sort(list)
    return table.concat(list, ",")
end

local function update_items()
    for _, item in ipairs(items) do item.update() end
end

local function on_clients_changed()
    local key = running_key()
    if key ~= shown_key then
        shown_key = key
        rebuild()
    else
        update_items()
    end
end

for _, sig in ipairs { "manage", "unmanage", "property::class" } do
    client.connect_signal(sig, function() gears.timer.delayed_call(on_clients_changed) end)
end
for _, sig in ipairs { "focus", "unfocus" } do
    client.connect_signal(sig, function()
        gears.timer.delayed_call(update_items)
    end)
end

screen.connect_signal("property::geometry", place)
load_pins()
shown_key = running_key()
rebuild()
place()

return { show = show, wibox = dock, rebuild = rebuild }
