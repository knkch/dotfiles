-- XFCE の Whisker メニュー風のアプリランチャー
-- 上: ユーザー名と電源ボタン / 検索欄、左: カテゴリ、右: アプリ一覧
-- 使い方: local whisker = require("modules.widgets.whisker-menu"); whisker.toggle()
-- キー: 文字入力で検索、↑↓ で選択、←→ でカテゴリ切替、Enter で起動、Esc で閉じる
-- アプリを右クリックするとお気に入りに追加/削除 (whisker-favorites.txt に保存)
local awful    = require("awful")
local gears    = require("gears")
local wibox    = require("wibox")
local menu_gen = require("menubar.menu_gen")
local config   = require("modules.config")
local theme    = require("modules.theme")

local C = theme.C
local esc, rounded, span = gears.string.xml_escape, theme.rounded, theme.span

local ROWS     = 11   -- アプリ一覧に一度に並べる行数
local ROW_H    = 40
local SIDE_W   = 210  -- カテゴリ欄の幅
local LIST_W   = 400  -- アプリ一覧の幅
local FAV_FILE = gears.filesystem.get_configuration_dir() .. "whisker-favorites.txt"
local DEFAULT_FAVS = { "Firefox", "Ghostty", "Yazi File Manager", "音量調節" }

-- カテゴリの並び順・表示名・アイコン (中身が空のカテゴリは表示しない)
local CATS = {
    { key = "fav",         name = "お気に入り",     icon = "\u{f005}" },
    { key = "all",         name = "すべて",         icon = "\u{f00a}" },
    { key = "internet",    name = "インターネット", icon = "\u{f0ac}" },
    { key = "development", name = "開発",           icon = "\u{f121}" },
    { key = "apps",        name = "ツール",         icon = "\u{f0ad}" },
    { key = "multimedia",  name = "マルチメディア", icon = "\u{f001}" },
    { key = "graphics",    name = "グラフィック",   icon = "\u{f03e}" },
    { key = "office",      name = "オフィス",       icon = "\u{f15c}" },
    { key = "games",       name = "ゲーム",         icon = "\u{f11b}" },
    { key = "education",   name = "教育",           icon = "\u{f19d}" },
    { key = "system",      name = "システム",       icon = "\u{f108}" },
    { key = "settings",    name = "設定",           icon = "\u{f013}" },
    { key = "utility",     name = "アクセサリ",     icon = "\u{f12e}" },
    { key = "other",       name = "その他",         icon = "\u{f141}" },
}

-- .desktop ファイルの分類 (menubar の名前) → 上のカテゴリ
local CAT_MAP = { tools = "system" }

-- アプリごとの振り分け (アプリ名 → カテゴリ)。.desktop の分類より優先する
local OVERRIDES = {
    ["Neovim"]                   = "development",
    ["Vim"]                      = "development",
    ["Claude"]                   = "development",
    ["Ghostty"]                  = "apps",
    ["Yazi File Manager"]        = "apps",
    ["Htop"]                     = "system",
    ["btop++"]                   = "system",
    ["キーボードレイアウトビューアー"] = "system",
}

-- メニューに出さないアプリ (検索にも出ない。rofi からは起動できる)
local HIDDEN = {
    ["Qt V4L2 test Utility"]          = true,
    ["Qt V4L2 video capture utility"] = true,
    ["Fcitx 5 移行ウィザード"]        = true,
    ["Rofi"]                          = true,
    ["Rofi Theme Selector"]           = true,
}

-- 電源まわり (confirm = もう一度押したときだけ実行する)
local POWER = {
    { name = "ロック",     icon = "\u{f023}", cmd = config.lock_cmd },
    { name = "サスペンド", icon = "\u{f186}", cmd = "systemctl suspend" },
    { name = "ログアウト", icon = "\u{f08b}", run = function() awesome.quit() end, confirm = true },
    { name = "再起動",     icon = "\u{f021}", cmd = "systemctl reboot",           confirm = true },
    { name = "電源オフ",   icon = "\u{f011}", cmd = "systemctl poweroff",         confirm = true },
}

local HINT = span(C.subtext, "↑↓ 選択   Enter 起動   右クリック お気に入り   Esc 閉じる", 10)

---------------------------------------------------------------- 状態
local apps     = {}      -- { name, cmdline, icon, category }
local favs     = {}      -- お気に入りの名前 (並び順どおり)
local cat      = "fav"
local query    = ""
local list     = {}      -- 今表示しているアプリ
local sel      = 1       -- 選択中 (list の番号)
local offset   = 0       -- スクロール位置
local armed    = nil     -- 確認待ちの電源ボタン
local grabber  = nil
local popup

local function load_favs()
    favs = {}
    local f = io.open(FAV_FILE)
    if not f then
        for _, n in ipairs(DEFAULT_FAVS) do table.insert(favs, n) end
        return
    end
    for line in f:lines() do
        if line ~= "" then table.insert(favs, line) end
    end
    f:close()
end
local function save_favs()
    local f = io.open(FAV_FILE, "w")
    if not f then return end
    f:write(table.concat(favs, "\n"), "\n")
    f:close()
end
local function fav_index(name)
    for i, n in ipairs(favs) do if n == name then return i end end
end
load_favs()

---------------------------------------------------------------- 部品
local status = wibox.widget { markup = HINT, widget = wibox.widget.textbox }

-- 検索欄
local search_text = wibox.widget { widget = wibox.widget.textbox }
local search = wibox.widget {
    {
        {
            { markup = span(C.sky, "\u{f0349}", 14), widget = wibox.widget.textbox },
            search_text,
            spacing = 12,
            layout  = wibox.layout.fixed.horizontal,
        },
        left = 14, right = 14, top = 8, bottom = 8,
        widget = wibox.container.margin,
    },
    bg     = C.surface,
    shape  = rounded(10),
    widget = wibox.container.background,
}
local function paint_search()
    if query == "" then
        search_text.markup = span(C.subtext, "検索...", 13)
    else
        search_text.markup = span(C.text, esc(query), 13) .. span(C.sky, "▏", 13)
    end
end

-- ヘッダー: ユーザー名と電源ボタン
local host = awesome.hostname or "localhost"
local face = os.getenv("HOME") .. "/.face"
local avatar
if gears.filesystem.file_readable(face) then
    avatar = wibox.widget {
        { image = face, resize = true, widget = wibox.widget.imagebox },
        forced_width = 42, forced_height = 42,
        shape = gears.shape.circle, widget = wibox.container.background,
    }
else
    avatar = wibox.widget {
        { markup = span(C.white, "\u{f007}", 16), align = "center", valign = "center",
          widget = wibox.widget.textbox },
        forced_width = 42, forced_height = 42, bg = C.accent,
        shape = gears.shape.circle, widget = wibox.container.background,
    }
end

local hide -- 下で定義
local power_buttons = { spacing = 6, layout = wibox.layout.fixed.horizontal }
local power_bgs = {}
for _, p in ipairs(POWER) do
    local b = wibox.widget {
        { markup = span(C.text, p.icon, 14), align = "center", valign = "center",
          widget = wibox.widget.textbox },
        forced_width = 38, forced_height = 38,
        shape = gears.shape.circle, widget = wibox.container.background,
    }
    power_bgs[p] = b
    b:connect_signal("mouse::enter", function()
        if armed ~= p then b.bg = C.overlay end
        if not armed then status.markup = span(C.text, p.name, 11) end
    end)
    b:connect_signal("mouse::leave", function()
        if armed ~= p then b.bg = nil end
        if not armed then status.markup = HINT end
    end)
    b:buttons(gears.table.join(awful.button({}, 1, function()
        if p.confirm and armed ~= p then
            if armed then power_bgs[armed].bg = nil end
            armed = p
            b.bg = C.urgent
            status.markup = span(C.urgent, "もう一度押すと" .. p.name .. "します", 11, true)
            return
        end
        hide()
        if p.run then p.run() else awful.spawn(p.cmd) end
    end)))
    table.insert(power_buttons, b)
end
power_buttons = wibox.widget(power_buttons)

local header = wibox.widget {
    {
        avatar,
        {
            { markup = span(C.text, esc(os.getenv("USER") or "user"), 14, true), widget = wibox.widget.textbox },
            { markup = span(C.subtext, "@" .. esc(host), 10), widget = wibox.widget.textbox },
            layout = wibox.layout.fixed.vertical,
        },
        spacing = 12,
        layout  = wibox.layout.fixed.horizontal,
    },
    nil,
    { power_buttons, valign = "center", widget = wibox.container.place },
    layout = wibox.layout.align.horizontal,
}

---------------------------------------------------------------- アプリ一覧
local function filter()
    list = {}
    if query ~= "" then
        local q = query:lower()
        local head, rest = {}, {}
        for _, a in ipairs(apps) do
            local n = a.name:lower()
            local pos = n:find(q, 1, true)
            if pos == 1 then table.insert(head, a)
            elseif pos or a.cmdline:lower():find(q, 1, true) then table.insert(rest, a) end
        end
        for _, a in ipairs(head) do table.insert(list, a) end
        for _, a in ipairs(rest) do table.insert(list, a) end
    elseif cat == "fav" then
        for _, n in ipairs(favs) do
            for _, a in ipairs(apps) do
                if a.name == n then table.insert(list, a); break end
            end
        end
    else
        for _, a in ipairs(apps) do
            if cat == "all" or (a.category or "other") == cat then table.insert(list, a) end
        end
    end
    sel, offset = 1, 0
end

local rows = {}
local list_layout = wibox.layout.fixed.vertical()
local function launch(a)
    if not a then return end
    hide()
    awful.spawn(a.cmdline)
end

local function paint_list()
    for i, r in ipairs(rows) do
        local a = list[offset + i]
        if a then
            r.icon.image = a.icon
            r.icon.visible = a.icon ~= nil
            r.glyph.visible = a.icon == nil
            local selected = (offset + i == sel)
            r.name.markup = span(selected and C.white or C.text, esc(a.name), 13)
            r.star.markup = fav_index(a.name) and span(selected and C.white or C.yellow, "\u{f005}", 10) or ""
            r.bg.bg = selected and C.accent or nil
            r.bg.visible = true
        else
            r.bg.visible = false
        end
    end
    if not armed then
        if #list == 0 then
            status.markup = span(C.subtext, query ~= "" and "見つかりませんでした" or "アプリがありません (右クリックでお気に入りに追加)", 11)
        else
            status.markup = HINT
        end
    end
end

local function scroll(d)
    offset = math.max(0, math.min(offset + d, math.max(0, #list - ROWS)))
    paint_list()
end
local function move(d)
    if #list == 0 then return end
    sel = math.max(1, math.min(sel + d, #list))
    if sel <= offset then offset = sel - 1 end
    if sel > offset + ROWS then offset = sel - ROWS end
    paint_list()
end
local function toggle_fav(a)
    if not a then return end
    local i = fav_index(a.name)
    if i then table.remove(favs, i) else table.insert(favs, a.name) end
    save_favs()
    if cat == "fav" and query == "" then
        local keep = sel
        filter()
        sel = math.max(1, math.min(keep, #list))
    end
    paint_list()
end

for i = 1, ROWS do
    local r = {}
    r.icon  = wibox.widget { resize = true, forced_width = 28, forced_height = 28, widget = wibox.widget.imagebox }
    r.glyph = wibox.widget { markup = span(C.subtext, "\u{f2d0}", 14), align = "center",
                             forced_width = 28, widget = wibox.widget.textbox }
    r.name  = wibox.widget { ellipsize = "end", valign = "center", widget = wibox.widget.textbox }
    r.star  = wibox.widget { valign = "center", widget = wibox.widget.textbox }
    r.bg = wibox.widget {
        {
            {
                { r.icon, r.glyph, layout = wibox.layout.stack },
                valign = "center", widget = wibox.container.place,
            },
            { r.name, left = 12, right = 8, widget = wibox.container.margin },
            r.star,
            layout = wibox.layout.align.horizontal,
        },
        left = 10, right = 12,
        widget = wibox.container.margin,
    }
    r.bg = wibox.widget { r.bg, forced_height = ROW_H, shape = rounded(8), widget = wibox.container.background }
    r.bg:connect_signal("mouse::enter", function()
        if list[offset + i] and sel ~= offset + i then sel = offset + i; paint_list() end
    end)
    r.bg:buttons(gears.table.join(
        awful.button({}, 1, function() launch(list[offset + i]) end),
        awful.button({}, 3, function() toggle_fav(list[offset + i]) end)
    ))
    rows[i] = r
    list_layout:add(r.bg)
end
local list_box = wibox.widget {
    list_layout,
    forced_width  = LIST_W,
    forced_height = ROWS * ROW_H,
    widget = wibox.container.constraint,
    strategy = "exact",
    width  = LIST_W,
    height = ROWS * ROW_H,
}
list_box:buttons(gears.table.join(
    awful.button({}, 4, function() scroll(-1) end),
    awful.button({}, 5, function() scroll(1) end)
))

---------------------------------------------------------------- カテゴリ欄
local side_layout = wibox.layout.fixed.vertical()
side_layout.spacing = 2
local side_rows = {}
local visible_cats = {}

local function paint_side()
    for _, s in ipairs(side_rows) do
        local on = (s.cat.key == cat and query == "")
        s.text.markup = span(on and C.sky or C.text, s.cat.icon, 12) .. "   "
                     .. span(on and C.white or C.text, s.cat.name, 12, on)
        s.bg.bg = on and C.surface or nil
    end
end
-- 検索語・カテゴリが変わったら、絞り込み直してすべて描き直す
local function redraw()
    filter(); paint_search(); paint_side(); paint_list()
end
local function set_cat(key)
    cat, query = key, ""
    redraw()
end
local function build_side()
    local used = { fav = true, all = true }
    for _, a in ipairs(apps) do used[a.category or "other"] = true end
    side_layout:reset()
    side_rows, visible_cats = {}, {}
    for _, c in ipairs(CATS) do
        if used[c.key] then
            local text = wibox.widget { valign = "center", widget = wibox.widget.textbox }
            local bg = wibox.widget {
                { text, left = 12, right = 8, widget = wibox.container.margin },
                forced_height = 36, shape = rounded(8), widget = wibox.container.background,
            }
            bg:connect_signal("mouse::enter", function() if c.key ~= cat or query ~= "" then bg.bg = C.overlay end end)
            bg:connect_signal("mouse::leave", function() paint_side() end)
            bg:buttons(gears.table.join(awful.button({}, 1, function() set_cat(c.key) end)))
            table.insert(side_rows, { cat = c, text = text, bg = bg })
            table.insert(visible_cats, c.key)
            side_layout:add(bg)
        end
    end
    paint_side()
end
local function step_cat(d)
    for i, k in ipairs(visible_cats) do
        if k == cat then
            set_cat(visible_cats[(i - 1 + d) % #visible_cats + 1])
            return
        end
    end
end

---------------------------------------------------------------- 本体
popup = theme.popup {
    header,
    search,
    {
        { side_layout, forced_width = SIDE_W, widget = wibox.container.background },
        { forced_width = 1, bg = C.overlay, widget = wibox.container.background },
        list_box,
        spacing = 10,
        layout  = wibox.layout.fixed.horizontal,
    },
    { status, halign = "center", widget = wibox.container.place },
    spacing = 12,
    layout  = wibox.layout.fixed.vertical,
}

-- .desktop ファイルを読み直す (新しく入れたアプリも出るように、開くたびに更新)
local function reload()
    menu_gen.generate(function(entries)
        local seen, new = {}, {}
        for _, e in ipairs(entries) do
            if e.name and e.cmdline and not seen[e.name] and not HIDDEN[e.name] then
                seen[e.name] = true
                e.category = OVERRIDES[e.name] or CAT_MAP[e.category] or e.category
                table.insert(new, e)
            end
        end
        table.sort(new, function(a, b) return a.name:lower() < b.name:lower() end)
        apps = new
        build_side()
        if query == "" then
            local keep_sel, keep_off = sel, offset
            filter()
            sel, offset = math.min(keep_sel, math.max(#list, 1)), math.min(keep_off, math.max(0, #list - ROWS))
        else
            filter()
        end
        paint_list()
    end)
end

hide = function()
    if not popup.visible then return end
    popup.visible = false
    if grabber then awful.keygrabber.stop(grabber); grabber = nil end
    if armed then power_bgs[armed].bg = nil; armed = nil end
    query = ""
end

local function on_key(mod, key, event)
    if event ~= "press" then return end
    for _, m in ipairs(mod) do
        if m == "Mod4" and key == "a" then hide(); return end -- Super+a でもう一度押したら閉じる
        if m == "Control" or m == "Mod4" or m == "Mod1" then
            if m == "Control" and key == "u" then query = ""; redraw() end
            return
        end
    end
    if key == "Escape" then hide()
    elseif key == "Return" or key == "KP_Enter" then launch(list[sel])
    elseif key == "Up" then move(-1)
    elseif key == "Down" then move(1)
    elseif key == "Prior" then move(-ROWS)
    elseif key == "Next" then move(ROWS)
    elseif key == "Left" and query == "" then step_cat(-1)
    elseif key == "Right" and query == "" then step_cat(1)
    elseif key == "Tab" then step_cat(1)
    elseif key == "BackSpace" then
        if query ~= "" then
            query = query:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
            redraw()
        end
    else
        local ch = (key == "space") and " " or key
        if utf8.len(ch) == 1 then
            query = query .. ch
            redraw()
        end
    end
end

local function show()
    local s = awful.screen.focused()
    popup.screen = s
    set_cat("fav")
    popup.visible = true
    awful.placement.top_left(popup, { margins = { top = 6, left = 8 }, honor_workarea = true, parent = s })
    grabber = awful.keygrabber.run(on_key)
    reload()
end

-- ウィンドウをクリックしたら閉じる (デスクトップのクリックは rc.lua の root.buttons で閉じる)
client.connect_signal("button::press", function() hide() end)

reload()

return {
    show   = show,
    hide   = hide,
    toggle = function() if popup.visible then hide() else show() end end,
}
