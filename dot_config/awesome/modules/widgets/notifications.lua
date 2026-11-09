-- 通知センター: バーのベルのボタン
-- 通知は Awesome の naughty が受け取って画面右上に出している。ここでは届いた通知を覚えておき、あとから一覧で見られるようにする
--   左クリック      一覧を開く (開くと未読の数が消える)
--   右クリック      おやすみモード (通知を画面に出さず、一覧にだけためる) の切り替え
-- 一覧は Awesome を再起動すると消える
local awful   = require("awful")
local gears   = require("gears")
local wibox   = require("wibox")
local naughty = require("naughty")
local theme   = require("modules.theme")

local C, span, esc = theme.C, theme.span, gears.string.xml_escape
local MAX     = 50  -- 覚えておく数
local SHOWN   = 8   -- 一覧に一度に並べる数 (ホイールで送る)
local WIDTH   = 380
local ICON_SIZE = theme.BAR.icon

local G = { bell = "\u{f009a}", bell_off = "\u{f009b}", clear = "\u{f0156}" }

local history = {}                         -- 新しい順 { title, message, app, time, icon, urgent }
local recorded = setmetatable({}, { __mode = "k" }) -- 記録済みの通知 (同じものを 2 回入れない)
local unread, offset = 0, 0
local dnd = false

---------------------------------------------------------------- バーのボタン
local icon  = theme.ink_box()
-- 未読があるときだけ、ベルの右上に小さな赤い点 (数は出さない)
local DOT = 13
local badge = wibox.widget {
    forced_width = DOT, forced_height = DOT,
    bg = C.urgent, shape = gears.shape.circle,
    shape_border_width = 2, shape_border_color = C.base, -- ベルと重なっても点の形が分かるように縁取る
    visible = false,
    widget = wibox.container.background,
}
-- ベルの左右に同じだけ置き場を取り、点はベルの右上の角から外へはみ出すように置く。
-- 未読の有無で幅を変えない (バーがずれない) / 左右同じなので未読が無いときもベルは中央
local ROOM = math.floor(DOT * 0.6)
local icon_room = wibox.container.margin(icon, ROOM, ROOM)
local button = wibox.widget {
    icon_room,
    { badge, halign = "right", valign = "top", widget = wibox.container.place },
    layout = wibox.layout.stack,
}
local tooltip = awful.tooltip { objects = { button }, delay_show = 0.5 }

local function update_button()
    icon.markup = dnd and theme.glyph(C.subtext, G.bell_off, ICON_SIZE) or theme.glyph(C.text, G.bell, ICON_SIZE)
    badge.visible = unread > 0
    tooltip.text = (dnd and "おやすみモード中 (通知は一覧にだけたまる)" or "通知")
        .. (unread > 0 and ("\n未読 " .. unread .. " 件") or "")
        .. "\n左クリック: 一覧 / 右クリック: おやすみモードの切り替え"
end

---------------------------------------------------------------- 一覧
local list_layout = wibox.layout.fixed.vertical()
list_layout.spacing = 6

local function header_button(glyph, label, fn)
    local w = wibox.widget {
        { { markup = span(C.text, glyph .. "  " .. label, 11), widget = wibox.widget.textbox },
          left = 10, right = 10, top = 4, bottom = 4, widget = wibox.container.margin },
        shape = theme.rounded(8), widget = wibox.container.background,
    }
    theme.hover(w, C.overlay, C.surface)
    w:buttons(awful.button({ }, 1, fn))
    return w
end

local render -- 下で定義
local dnd_button_label = wibox.widget { widget = wibox.widget.textbox }
local dnd_button = wibox.widget {
    { dnd_button_label, left = 10, right = 10, top = 4, bottom = 4, widget = wibox.container.margin },
    shape = theme.rounded(8), widget = wibox.container.background,
}
theme.hover(dnd_button, C.overlay, C.surface)

local function set_dnd(on)
    dnd = on
    naughty.suspended = on
    if not on then
        -- おやすみ中にたまった通知はもう一覧に入っているので、まとめて画面に出さずに捨てる
        for _, n in ipairs(gears.table.clone(naughty.notifications.suspended, false)) do n:destroy() end
    end
    update_button()
    if render then render() end
end
dnd_button:buttons(awful.button({ }, 1, function() set_dnd(not dnd) end))

local function row(item)
    local text = wibox.widget {
        {
            { markup = span(C.subtext, esc(item.app ~= "" and item.app or "通知") .. "  " .. item.time, 10),
              widget = wibox.widget.textbox },
            item.title ~= "" and { markup = span(item.urgent and C.urgent or C.text, "<b>" .. esc(item.title) .. "</b>"),
                                   ellipsize = "end", widget = wibox.widget.textbox } or nil,
            item.message ~= "" and { markup = span(C.text, esc(item.message), 11), wrap = "word_char",
                                     ellipsize = "end", forced_height = 40, widget = wibox.widget.textbox } or nil,
            spacing = 2,
            layout  = wibox.layout.fixed.vertical,
        },
        widget = wibox.container.constraint,
        strategy = "max",
        width = WIDTH - 70,
    }
    local w = wibox.widget {
        {
            {
                item.icon and { image = item.icon, resize = true, forced_width = 32, forced_height = 32,
                                valign = "top", widget = wibox.widget.imagebox } or nil,
                text,
                spacing = 10,
                layout  = wibox.layout.fixed.horizontal,
            },
            margins = 10, widget = wibox.container.margin,
        },
        forced_width = WIDTH,
        bg = C.surface, shape = theme.rounded(10),
        widget = wibox.container.background,
    }
    theme.hover(w, C.overlay, C.surface)
    -- クリックでその通知を一覧から消す
    w:buttons(awful.button({ }, 1, function()
        for i, h in ipairs(history) do if h == item then table.remove(history, i) break end end
        render()
    end))
    return w
end

local popup = theme.popup({
    {
        { markup = span(C.text, "<b>通知</b>", 13), widget = wibox.widget.textbox },
        nil,
        {
            dnd_button,
            header_button(G.clear, "すべて消す", function() history = {}; offset = 0; render() end),
            spacing = 6,
            layout  = wibox.layout.fixed.horizontal,
        },
        layout = wibox.layout.align.horizontal,
    },
    list_layout,
    spacing      = 12,
    forced_width = WIDTH,
    layout       = wibox.layout.fixed.vertical,
}, { preferred_positions = "bottom", preferred_anchors = "back" })

render = function()
    dnd_button_label.markup = span(dnd and C.yellow or C.text,
        (dnd and G.bell_off .. "  おやすみ中" or G.bell .. "  おやすみ"), 11)
    list_layout:reset()
    if #history == 0 then
        list_layout:add(wibox.widget {
            { markup = span(C.subtext, "通知はありません"), align = "center", widget = wibox.widget.textbox },
            top = 20, bottom = 20, widget = wibox.container.margin,
        })
        return
    end
    offset = math.max(0, math.min(offset, #history - SHOWN))
    for i = offset + 1, math.min(#history, offset + SHOWN) do list_layout:add(row(history[i])) end
    if #history > SHOWN then
        list_layout:add(wibox.widget {
            markup = span(C.subtext, string.format("%d〜%d 件目 / 全 %d 件 (ホイールで送る)",
                offset + 1, math.min(#history, offset + SHOWN), #history), 10),
            align = "center", widget = wibox.widget.textbox,
        })
    end
end

popup:buttons(gears.table.join(
    awful.button({ }, 4, function() offset = offset - 1; render() end),
    awful.button({ }, 5, function() offset = offset + 1; render() end)
))
popup:connect_signal("mouse::leave", function() popup.visible = false end)

---------------------------------------------------------------- 通知を覚える
local function record(n)
    if recorded[n] then return end
    recorded[n] = true
    -- アイコンは読めるものだけ使う (読めないと一覧に空白ができる)
    local ic = n.icon or n.app_icon
    ic = ic and gears.surface.load_silently(ic, false) or nil
    if ic and gears.surface.get_size(ic) == 0 then ic = nil end
    table.insert(history, 1, {
        title   = n.title or "",
        message = (n.message or ""):gsub("<[^>]+>", ""), -- 本文の簡単なタグは外す
        app     = n.app_name or "",
        time    = os.date("%H:%M"),
        icon    = ic,
        urgent  = n.urgency == "critical",
    })
    while #history > MAX do table.remove(history) end
    if not popup.visible then unread = unread + 1 end
    update_button()
    if popup.visible then render() end
end

naughty.connect_signal("added", record)
-- おやすみ中は "added" が来ないので、たまった通知を見て覚える
naughty.connect_signal("property::active", function()
    for _, n in ipairs(naughty.notifications.suspended) do record(n) end
end)

button:buttons(gears.table.join(
    awful.button({ }, 1, function()
        if popup.visible then popup.visible = false return end
        unread, offset = 0, 0
        update_button()
        render()
        popup:move_next_to(mouse.current_widget_geometry)
    end),
    awful.button({ }, 3, function() set_dnd(not dnd) end)
))

update_button()

return { widget = button, set_dnd = set_dnd }
