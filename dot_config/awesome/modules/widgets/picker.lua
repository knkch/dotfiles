-- 選択パネル: 検索欄 + 一覧から 1 つ選ぶ。検索パネル (Super+p)・電源の確認・Wi-Fi のパスワード・Dock の追加で使う
--
--   picker.open {
--       prompt    = "アプリ",                 検索欄の薄い文字
--       items     = { item, ... } か function(done) done(items) end (時間のかかる読み込み用)
--       on_select = function(item) end,       選んだとき (Enter / クリック)
--       password  = true,                     入力を ● で隠し、一覧は出さない (Enter で on_select({ text = 入力 }))
--       dynamic   = function(query, count) return { item, ... } end,
--                                             入力に応じて一覧の最後に足す項目 (count = 一致した数)
--   }
--
--   タブつき: 上の prompt / items / on_select / dynamic を 1 つのタブとして並べる
--   picker.open {
--       tabs = { { name = "アプリ", glyph = "…", prompt = …, items = …, on_select = …, dynamic = … }, ... },
--       tab  = 2,                              最初に開くタブ (省略で 1)
--   タブには empty = "何も入力していないときに一覧の代わりに出す文字" も書ける
--   }
--   中身はタブを初めて開いたときに読み込む。入力した文字はタブを替えても残る
--
--   item = { text = "表示名", sub = "右に薄く出す説明", icon = 画像 / glyph = Nerd Font の文字,
--            color = glyph の色, keywords = "検索にだけ使う言葉" }
--   icon は画像ファイルのパスか cairo のサーフェス。c.icon のような生の値も渡せる (読み込むときに変換する)
--
-- 操作: 文字で絞り込み / ↑↓ か Ctrl+j/k (Ctrl+n/p) で選択 / Enter で決定 / Esc で閉じる / Ctrl+u で入力を消す
--       タブ: Ctrl+h/l か Tab / Shift+Tab で切り替え (クリック・ホイールでも)
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local cairo = require("lgi").cairo
local theme = require("modules.theme")

local C, span, esc = theme.C, theme.span, gears.string.xml_escape
local ROWS, ROW_H, WIDTH = 9, 40, 560

local picker = {}

---------------------------------------------------------------- 状態
-- opts = 開いているパネル全体, tab = 今のタブ (タブなしのときは opts 自身)
-- loaded[tab] = 読み込んだ項目 (読み込み中は false)。開くたびに作り直す
local opts, tabs, cur, tab = {}, {}, 1, {}
local loaded, items, list = {}, {}, {}
local query, sel, offset = "", 1, 0
local grabber, loading = nil, false

---------------------------------------------------------------- 見た目
local search_icon = theme.ink_box()
search_icon.markup = theme.glyph(C.subtext, "\u{f0349}", 14) -- nf-md-magnify
local search_text = wibox.widget { ellipsize = "start", widget = wibox.widget.textbox }
local search = wibox.widget {
    {
        { search_icon, search_text, spacing = 10, layout = wibox.layout.fixed.horizontal },
        left = 12, right = 12, widget = wibox.container.margin,
    },
    forced_height = 42, bg = C.surface .. "cc", shape = theme.rounded(10),
    widget = wibox.container.background,
}

-- タブの見出し (タブが 2 つ以上のときだけ出す)
local tab_bar = wibox.layout.flex.horizontal()
tab_bar.spacing = 6
local tab_box = wibox.widget { tab_bar, forced_height = 34, widget = wibox.container.background }

local rows = {}
local list_layout = wibox.layout.fixed.vertical()
local message = wibox.widget { align = "center", widget = wibox.widget.textbox }
local message_box = wibox.widget { message, top = 14, bottom = 14, widget = wibox.container.margin }

local paint, choose, switch -- 下で定義

for i = 1, ROWS do
    local r = {}
    r.icon  = wibox.widget { resize = true, forced_width = 24, forced_height = 24, widget = wibox.widget.imagebox }
    r.glyph = theme.ink_box()
    r.text  = wibox.widget { ellipsize = "end", widget = wibox.widget.textbox }
    r.sub   = wibox.widget { ellipsize = "end", widget = wibox.widget.textbox }
    r.bg = wibox.widget {
        {
            {
                {
                    { r.icon, r.glyph, layout = wibox.layout.stack },
                    forced_width = 26, halign = "center", valign = "center", widget = wibox.container.place,
                },
                r.text,
                { r.sub, left = 12, widget = wibox.container.margin },
                spacing = 12,
                layout  = wibox.layout.align.horizontal,
            },
            left = 12, right = 12, widget = wibox.container.margin,
        },
        forced_height = ROW_H, shape = theme.rounded(8), widget = wibox.container.background,
    }
    r.bg:connect_signal("mouse::enter", function()
        if list[offset + i] and sel ~= offset + i then sel = offset + i; paint() end
    end)
    r.bg:buttons(awful.button({ }, 1, function() sel = offset + i; choose() end))
    rows[i] = r
    list_layout:add(r.bg)
end

local list_box = wibox.widget {
    list_layout, message_box,
    layout = wibox.layout.stack,
}
list_box:buttons(gears.table.join(
    awful.button({ }, 4, function() picker.move(-1) end),
    awful.button({ }, 5, function() picker.move( 1) end)
))

local HINT      = "↑↓ / Ctrl+j・k 選択   Enter 決定   Esc 閉じる"
local HINT_TABS = "Ctrl+h・l / Tab 切替   ↑↓ / Ctrl+j・k 選択   Enter 決定   Esc 閉じる"
local hint = wibox.widget { align = "center", widget = wibox.widget.textbox }

local popup = theme.popup({
    tab_box,
    search,
    list_box,
    hint,
    spacing      = 10,
    forced_width = WIDTH,
    layout       = wibox.layout.fixed.vertical,
})

---------------------------------------------------------------- 絞り込み
-- c.icon などの生の値 (cairo のポインタ) は、ここで 1 回だけ cairo のサーフェスにする。
-- 生のまま imagebox に渡すと、渡すたびに「持ち主」として包まれて参照が余分に減り、
-- 解放されたあとの画像を読んで Awesome ごと落ちる (一覧を描き直すたびに渡すので起きやすい)
local function prepare(list)
    for _, it in ipairs(list) do
        if type(it.icon) == "userdata" and not cairo.Surface:is_type_of(it.icon) then
            it.icon = gears.surface(it.icon)
        end
    end
    return list
end

-- 一致の強さ: 先頭 > 単語の先頭 > どこか > 文字が順に含まれる (あいまい)。どれでもなければ除外
local function rank(item, q)
    if q == "" then return 0 end
    local hay = (item.text .. " " .. (item.sub or "") .. " " .. (item.keywords or "")):lower()
    local pos = hay:find(q, 1, true)
    if pos == 1 then return 0 end
    if pos then
        local before = hay:sub(pos - 1, pos - 1)
        return (before == " " or before == "-" or before == "_" or before == ".") and 1 or 2
    end
    local i = 1
    for ch in q:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local found = hay:find(ch, i, true)
        if not found then return nil end
        i = found + #ch
    end
    return 3
end

local function filter()
    list = {}
    if opts.password then return end
    local q = query:lower()
    local ranked = {}
    for idx, it in ipairs(items) do
        local r = rank(it, q)
        if r then table.insert(ranked, { it = it, r = r, idx = idx }) end
    end
    table.sort(ranked, function(a, b) if a.r ~= b.r then return a.r < b.r end return a.idx < b.idx end)
    for _, x in ipairs(ranked) do table.insert(list, x.it) end
    if tab.dynamic and not loading then
        for _, it in ipairs(prepare(tab.dynamic(query, #list) or {})) do table.insert(list, it) end
    end
    sel, offset = 1, 0
end

paint = function()
    local shown = opts.password and string.rep("●", utf8.len(query) or #query) or esc(query)
    search_text.markup = (query == "" and span(C.subtext, esc(tab.prompt or "検索…"))
                                       or span(C.text, shown)) .. span(C.accent, "▏")
    list_box.visible = not opts.password
    hint.visible = not opts.password
    hint.markup = span(C.subtext, #tabs > 1 and HINT_TABS or HINT, 10)
    tab_box.visible = #tabs > 1
    for i, w in ipairs(tab_bar.children) do
        local on = i == cur
        w.bg = on and C.accent or C.surface .. "99"
        w.text.markup = (tabs[i].glyph and theme.glyph(on and C.white or C.subtext, tabs[i].glyph, 11) .. " " or "")
                     .. span(on and C.white or C.text, esc(tabs[i].name), 11)
    end
    message.markup = (loading and span(C.subtext, "読み込み中…"))
                  or (#list == 0 and span(C.subtext, esc(query == "" and tab.empty or "見つかりません"))) or ""
    message_box.visible = message.markup ~= ""
    for i, r in ipairs(rows) do
        local it = list[offset + i]
        r.bg.visible = it ~= nil
        if it then
            local selected = offset + i == sel
            r.bg.bg = selected and C.accent or nil
            r.icon.image = it.icon
            r.icon.visible = it.icon ~= nil
            r.glyph.visible = it.icon == nil
            r.glyph.markup = it.glyph and theme.glyph(selected and C.white or (it.color or C.text), it.glyph, 15) or ""
            r.text.markup = span(selected and C.white or C.text, esc(it.text))
            r.sub.markup = it.sub and span(selected and C.white or C.subtext, esc(it.sub), 11) or ""
        end
    end
end

function picker.move(d)
    if #list == 0 then return end
    sel = math.max(1, math.min(#list, sel + d))
    if sel <= offset then offset = sel - 1 end
    if sel > offset + ROWS then offset = sel - ROWS end
    paint()
end

---------------------------------------------------------------- 開く・閉じる
function picker.close()
    if grabber then awful.keygrabber.stop(grabber); grabber = nil end
    popup.visible = false
end

choose = function()
    local o, t = opts, tab
    local it = o.password and { text = query } or list[sel]
    if not it then return end
    picker.close()
    if t.on_select then t.on_select(it) end
end

-- タブ i を表示する。まだ読み込んでいなければ読み込む
local function show_tab(i)
    cur, tab = i, tabs[i]
    local o, t = opts, tab
    if loaded[t] == nil then
        if type(t.items) == "function" then
            loaded[t] = false
            t.items(function(result)
                if opts ~= o then return end -- 別の選択パネルに替わっていた
                loaded[t] = prepare(result or {})
                if tab == t then items, loading = loaded[t], false; filter() paint() end
            end)
        else
            loaded[t] = prepare(t.items or {})
        end
    end
    loading = loaded[t] == false
    items = loaded[t] or {}
    filter()
    paint()
end

-- d = 1 で右のタブ、-1 で左 (端から反対側へ回る)
switch = function(d)
    if #tabs < 2 then return end
    show_tab((cur - 1 + d) % #tabs + 1)
end
picker.switch = switch

local function on_key(mods, key, event)
    if event ~= "press" then return end
    local ctrl = false
    for _, m in ipairs(mods) do
        if m == "Control" then ctrl = true
        elseif m == "Mod4" or m == "Mod1" then return end
    end
    if ctrl then
        if key == "u" then query = "" filter() paint()
        elseif key == "j" or key == "n" then picker.move(1)
        elseif key == "k" or key == "p" then picker.move(-1)
        elseif key == "h" then switch(-1)
        elseif key == "l" then switch(1) end
        return
    end
    if key == "Escape" then picker.close()
    elseif key == "Tab" then switch(1)
    elseif key == "ISO_Left_Tab" then switch(-1) -- Shift+Tab
    elseif key == "Return" or key == "KP_Enter" then choose()
    elseif key == "Up" then picker.move(-1)
    elseif key == "Down" then picker.move(1)
    elseif key == "Prior" then picker.move(-ROWS)
    elseif key == "Next" then picker.move(ROWS)
    elseif key == "BackSpace" then
        if query ~= "" then
            query = query:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
            filter() paint()
        end
    else
        local ch = key == "space" and " " or key
        if utf8.len(ch) == 1 then query = query .. ch; filter() paint() end
    end
end

local function tab_button(i)
    local w = wibox.widget {
        { id = "text", align = "center", ellipsize = "none", widget = wibox.widget.textbox },
        shape = theme.rounded(8), widget = wibox.container.background,
    }
    w.text = w:get_children_by_id("text")[1]
    w:buttons(awful.button({ }, 1, function() show_tab(i) end))
    return w
end

function picker.open(o)
    picker.close()
    opts, query, loaded = o, "", {}
    tabs = o.tabs or { o }
    tab_bar:reset()
    if #tabs > 1 then
        for i = 1, #tabs do tab_bar:add(tab_button(i)) end
    end
    show_tab(math.max(1, math.min(#tabs, o.tab or 1)))
    local s = awful.screen.focused()
    popup.screen = s
    popup.visible = true
    awful.placement.top(popup, { margins = { top = s.geometry.height * 0.18 }, parent = s })
    grabber = awful.keygrabber.run(on_key)
end

tab_box:buttons(gears.table.join(
    awful.button({ }, 4, function() switch(-1) end),
    awful.button({ }, 5, function() switch( 1) end)
))

-- 外をクリックしたら閉じる
client.connect_signal("button::press", function() picker.close() end)

return picker
