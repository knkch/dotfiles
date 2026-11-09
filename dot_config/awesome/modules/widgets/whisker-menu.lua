-- XFCE の Whisker メニュー風のアプリランチャー
-- 上: ユーザー名と電源ボタン / 検索欄、左: カテゴリ、右: アプリ一覧
-- 使い方: local whisker = require("modules.widgets.whisker-menu"); whisker.toggle()
-- キー: 文字入力で検索、↑↓ で選択、←→ でカテゴリ切替、Enter で起動、Esc で閉じる
-- アプリを右クリックするとお気に入りに追加/削除 (whisker-favorites.txt に保存)
local awful    = require("awful")
local gears    = require("gears")
local wibox    = require("wibox")
local menu_gen = require("menubar.menu_gen")
local menubar_utils = require("menubar.utils")
local theme    = require("modules.theme")
local power    = require("modules.power")

local C = theme.C
local esc, rounded, span = gears.string.xml_escape, theme.rounded, theme.span

local ROWS     = 11   -- アプリ一覧に一度に並べる行数
local ROW_H    = 40
local SIDE_W   = 210  -- カテゴリ欄の幅
local LIST_W   = 400  -- アプリ一覧の幅
local FAV_FILE = gears.filesystem.get_configuration_dir() .. "whisker-favorites.txt"
local HISTORY  = gears.filesystem.get_cache_dir() .. "launch-history" -- 起動した回数 (検索パネルの並び順に使う)
local DEFAULT_FAVS = { "Firefox", "Ghostty", "Yazi File Manager", "音量調節" }

-- カテゴリの並び順・表示名・アイコン (中身が空のカテゴリは表示しない)
local CATS = {
    { key = "fav",         name = "お気に入り",     icon = "\u{f005}" },
    { key = "all",         name = "すべて",         icon = "\u{f00a}" },
    { key = "internet",    name = "インターネット", icon = "\u{f0ac}" },
    { key = "development", name = "開発",           icon = "\u{f121}" },
    { key = "security",    name = "セキュリティ",   icon = "\u{f132}" },
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

---------------------------------------------------------------- 分類
-- .desktop ファイルの Categories をすべて見て、いちばん具体的なものでカテゴリを決める。
-- 値は { カテゴリ, 強さ }。強さ 3 = 具体的 (WebBrowser など) / 2 = 大分類 (Network など) / 1 = あいまい (Utility など)
local CATEGORY_RULES = {
    -- インターネット
    Network = { "internet", 2 }, WebBrowser = { "internet", 3 }, Email = { "internet", 3 },
    InstantMessaging = { "internet", 3 }, Chat = { "internet", 3 }, IRCClient = { "internet", 3 },
    VideoConference = { "internet", 3 }, Telephony = { "internet", 3 }, RemoteAccess = { "internet", 3 },
    FileTransfer = { "internet", 3 }, P2P = { "internet", 3 }, News = { "internet", 3 }, Feed = { "internet", 3 },
    -- 開発
    Development = { "development", 2 }, IDE = { "development", 3 }, RevisionControl = { "development", 3 },
    Building = { "development", 3 }, GUIDesigner = { "development", 3 }, Profiling = { "development", 3 },
    Translation = { "development", 3 }, WebDevelopment = { "development", 3 },
    -- セキュリティ
    Security = { "security", 3 },
    -- マルチメディア
    AudioVideo = { "multimedia", 2 }, Audio = { "multimedia", 2 }, Video = { "multimedia", 2 },
    Player = { "multimedia", 3 }, Recorder = { "multimedia", 3 }, Music = { "multimedia", 3 },
    TV = { "multimedia", 3 }, DiscBurning = { "multimedia", 3 },
    -- グラフィック
    Graphics = { "graphics", 2 }, ["2DGraphics"] = { "graphics", 3 }, ["3DGraphics"] = { "graphics", 3 },
    RasterGraphics = { "graphics", 3 }, VectorGraphics = { "graphics", 3 }, Photography = { "graphics", 3 },
    Scanning = { "graphics", 3 },
    -- オフィス
    Office = { "office", 2 }, WordProcessor = { "office", 3 }, Spreadsheet = { "office", 3 },
    Presentation = { "office", 3 }, Calendar = { "office", 3 }, ContactManagement = { "office", 3 },
    Dictionary = { "office", 3 }, Finance = { "office", 3 },
    -- ゲーム・教育
    Game = { "games", 3 }, Education = { "education", 2 }, Science = { "education", 3 },
    -- システム (ターミナル・ファイル・監視・バックアップ)
    System = { "system", 2 }, TerminalEmulator = { "system", 3 }, FileManager = { "system", 3 },
    Monitor = { "system", 3 }, PackageManager = { "system", 3 }, Emulator = { "system", 3 },
    -- 設定
    Settings = { "settings", 3 }, DesktopSettings = { "settings", 3 }, HardwareSettings = { "settings", 3 },
    -- アクセサリ
    Utility = { "utility", 1 }, TextEditor = { "utility", 2 }, Archiving = { "utility", 3 },
    Compression = { "utility", 3 }, Calculator = { "utility", 3 }, Clock = { "utility", 3 },
    Accessibility = { "utility", 3 },
}
-- 同じ強さで並んだときに優先するカテゴリ (具体的な用途を先に)
local TIE_ORDER = { "security", "development", "internet", "settings", "multimedia", "graphics",
                    "office", "games", "education", "system", "utility" }

-- 分類だけでは決めにくいアプリ (実行ファイル名で判断)
local EXEC_RULES = {
    -- セキュリティ診断・解析のツール (分類が「開発」「ネットワーク」になっているもの)
    wireshark = "security", ghidra = "security", ["jadx-gui"] = "security", burpsuite = "security",
    zaproxy = "security", msfconsole = "security", armitage = "security", maltego = "security",
    bloodhound = "security", ["cutter"] = "security",
    -- 会議・リモート (分類が Utility だけのもの)
    CiscoCollabHost = "internet", webex = "internet", zoom = "internet", teams = "internet",
    ["horizon-client"] = "internet",
    -- Java の付属ツール、エディタの Vim (分類が TextEditor だけ)
    jconsole = "development", jshell = "development", vim = "development", gvim = "development",
}

-- アプリ名での振り分け (最後の手段)
local OVERRIDES = {
    ["キーボードレイアウトビューアー"] = "settings",
    ["Xfce について"]                 = "system",
}

local function classify(e)
    local exec = (e.Exec or e.cmdline or ""):match("^%s*(%S+)") or ""
    exec = exec:match("([^/]+)$") or exec
    if OVERRIDES[e.Name] then return OVERRIDES[e.Name] end
    if EXEC_RULES[exec] then return EXEC_RULES[exec] end
    local best, score = {}, 0
    for _, c in ipairs(e.categories or {}) do
        -- BlackArch のツールは独自の分類 (X-BlackArch-…) を持っている
        local rule = c:match("^X%-BlackArch") and { "security", 3 } or CATEGORY_RULES[c]
        if rule then
            if rule[2] > score then best, score = { [rule[1]] = true }, rule[2]
            elseif rule[2] == score then best[rule[1]] = true end
        end
    end
    for _, k in ipairs(TIE_ORDER) do if best[k] then return k end end
    return "other"
end

-- メニューに出さないアプリ (検索にも出ない)
local HIDDEN = {
    ["Qt V4L2 test Utility"]          = true,
    ["Qt V4L2 video capture utility"] = true,
    ["Fcitx 5 移行ウィザード"]        = true,
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

-- 起動した回数 { [アプリ名] = 回数 }
local function launch_counts()
    local h = {}
    local f = io.open(HISTORY)
    if f then
        for line in f:lines() do
            local n, name = line:match("^(%d+)\t(.+)$")
            if n then h[name] = tonumber(n) end
        end
        f:close()
    end
    return h
end

-- アプリを起動して、回数を数える (このメニューからも検索パネルからも)
local function run_app(a)
    local h = launch_counts()
    h[a.name] = (h[a.name] or 0) + 1
    local f = io.open(HISTORY, "w")
    if f then
        for k, v in pairs(h) do f:write(v, "\t", k, "\n") end
        f:close()
    end
    awful.spawn(a.cmdline)
end

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
-- 電源ボタン (modules/power.lua。confirm のものはもう一度押したときだけ実行する)
local power_buttons = { spacing = 6, layout = wibox.layout.fixed.horizontal }
local power_bgs = {}
for _, p in ipairs(power.actions) do
    -- アイコンは「見えている絵」の中心で丸の中央に置く (普通の文字として置くと、見えない余白の分ずれる)
    local glyph = theme.ink_box()
    glyph.markup = theme.glyph(C.text, p.glyph, 14)
    local b = wibox.widget {
        { glyph, halign = "center", valign = "center", widget = wibox.container.place },
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
        power.run(p)
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
    run_app(a)
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
    -- 幅を決めておく (Nerd Font のアイコンは文字幅より大きく、そのままだと右が切れる)
    r.star  = wibox.widget { valign = "center", align = "center", forced_width = 22, widget = wibox.widget.textbox }
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

-- .desktop ファイルを読む (menubar の読み込みを使うが、分類は全部の Categories を見て自分で決める)
local function scan(callback)
    local dirs, done, entries = {}, 0, {}
    for _, dir in ipairs(menu_gen.all_menu_dirs) do -- 無いフォルダ (/usr/local/share/applications など) は飛ばす
        if gears.filesystem.dir_readable(dir) then table.insert(dirs, dir) end
    end
    if #dirs == 0 then return callback(entries) end
    for _, dir in ipairs(dirs) do
        menubar_utils.parse_dir(dir, function(list)
            for _, e in ipairs(list or {}) do
                if e.show and e.Name and e.cmdline then
                    table.insert(entries, {
                        name     = menubar_utils.rtrim(e.Name),
                        cmdline  = menubar_utils.rtrim(e.cmdline),
                        icon     = e.icon_path,
                        category = classify(e),
                    })
                end
            end
            done = done + 1
            if done == #dirs then callback(entries) end
        end)
    end
end

-- 表示するアプリの一覧 (名前の重複と HIDDEN を除いて、名前順)。検索パネルなどほかの場所でも使う
local function list_apps(callback)
    scan(function(entries)
        local seen, out = {}, {}
        for _, e in ipairs(entries) do
            if not seen[e.name] and not HIDDEN[e.name] then
                seen[e.name] = true
                table.insert(out, e)
            end
        end
        table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
        callback(out)
    end)
end

-- 読み直す (新しく入れたアプリも出るように、開くたびに更新)
local function reload()
    list_apps(function(new)
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
            if m == "Control" then
                if key == "u" then query = ""; redraw()          -- 検索語を消す
                elseif key == "j" or key == "n" then move(1)      -- Vim 風に上下
                elseif key == "k" or key == "p" then move(-1)
                elseif key == "h" and query == "" then step_cat(-1) -- カテゴリを切り替え
                elseif key == "l" and query == "" then step_cat(1)
                end
            end
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

-- ウィンドウをクリックしたら閉じる (デスクトップのクリックは keys.lua の root.buttons で閉じる)
client.connect_signal("button::press", function() hide() end)

reload()

return {
    show      = show,
    hide      = hide,
    toggle    = function() if popup.visible then hide() else show() end end,
    list_apps = list_apps,
    run_app   = run_app,       -- 起動して回数を数える
    launch_counts = launch_counts,
    category_name = function(key)
        for _, c in ipairs(CATS) do if c.key == key then return c.name end end
        return ""
    end,
}
