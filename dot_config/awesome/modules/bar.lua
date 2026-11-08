-- 画面上部のバー: 背景は無く、タイルが浮いて並ぶ。左 = ロゴ・タグ・壁紙ボタン + 起動中のアプリ / 中央 = 再生中の曲 / 右 = トレイ・各種状態・時計
local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local config = require("modules.config")
local theme  = require("modules.theme")
local menu   = require("modules.menu")

local mpd        = require("modules.widgets.mpd")
local volume     = require("modules.widgets.volume")
local brightness = require("modules.widgets.brightness")
local battery    = require("modules.widgets.battery")
local vpn        = require("modules.widgets.vpn")
local clock      = require("modules.widgets.clock")
local wallpaper  = require("modules.widgets.wallpaper")

local modkey = config.modkey

local taglist_buttons = gears.table.join(
    awful.button({ }, 1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t) if client.focus then client.focus:move_to_tag(t) end end),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, function(t) if client.focus then client.focus:toggle_tag(t) end end),
    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
)

local tasklist_buttons = gears.table.join(
    awful.button({ }, 1, function(c)
        if c == client.focus then
            c.minimized = true
        else
            c:emit_signal("request::activate", "tasklist", { raise = true })
        end
    end),
    awful.button({ }, 3, function() awful.menu.client_list { theme = { width = 250 } } end),
    awful.button({ }, 4, function() awful.client.focus.byidx(1) end),
    awful.button({ }, 5, function() awful.client.focus.byidx(-1) end)
)

-- 画面ごとにバーを作る
return function(s)
    s.mypromptbox = awful.widget.prompt()

    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({ }, 1, function() awful.layout.inc( 1) end),
        awful.button({ }, 3, function() awful.layout.inc(-1) end),
        awful.button({ }, 4, function() awful.layout.inc( 1) end),
        awful.button({ }, 5, function() awful.layout.inc(-1) end)
    ))

    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        -- 縦長にならないよう、幅と高さをそろえた丸にする
        widget_template = {
            {
                { id = "text_role", align = "center", valign = "center", widget = wibox.widget.textbox },
                id            = "background_role",
                forced_width  = 30,
                forced_height = 30,
                widget        = wibox.container.background,
            },
            valign = "center",
            widget = wibox.container.place,
        },
    }

    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        -- アイコンだけなので横に引き伸ばさず、詰めて並べる
        layout  = { spacing = 6, layout = wibox.layout.fixed.horizontal },
    }

    -- 起動中のアプリのタイル: アプリが 1 つも無いときは空のタイルにならないよう隠す
    local tasks = theme.tile(s.mytasklist, 6)
    local function update_tasks()
        for _, c in ipairs(s.all_clients) do
            if awful.widget.tasklist.filter.currenttags(c, s) then tasks.visible = true return end
        end
        tasks.visible = false
    end
    for _, sig in ipairs { "manage", "unmanage", "tagged", "untagged", "property::screen" } do
        client.connect_signal(sig, update_tasks)
    end
    tag.connect_signal("property::selected", update_tasks)
    update_tasks()

    local left = {
        layout  = wibox.layout.fixed.horizontal,
        spacing = 8,
        theme.tile({
            wibox.container.margin(menu.launcher, 0, 0, 1, 1),
            s.mytaglist,
            wibox.container.margin(wallpaper.widget, 0, 0, 1, 1),
            spacing = 8,
            layout  = wibox.layout.fixed.horizontal,
        }, 6),
        tasks,
        s.mypromptbox,
    }

    local right = {
        {
            layout  = wibox.layout.fixed.horizontal,
            spacing = 8,
            -- 幅が変わるトレイを左端に置いて、ほかのアイコンの位置がずれないようにする
            -- トレイは透明にできないので、タイルごと bg_systray と同じ色で不透明に塗る
            theme.tile(wibox.container.margin(wibox.widget.systray(), 0, 0, 1, 1), 12, theme.C.base),
            vpn.widget, -- VPN 接続中だけ出るタイル
            theme.tile({
                brightness.widget,
                volume.widget,
                battery.widget,
                spacing = 12,
                layout  = wibox.layout.fixed.horizontal,
            }, 12),
            theme.tile(clock.widget, 14),
            theme.tile(wibox.container.margin(s.mylayoutbox, 0, 0, 3, 3), 8),
        },
        halign = "right",
        widget = wibox.container.place,
    }

    -- バー本体は透明。タイルだけを画面の端から少し離して浮かせる
    s.mywibox = awful.wibar { position = "top", screen = s, height = 50, bg = theme.C.transparent }
    local root = wibox.widget {
        {
            left,
            theme.tile(mpd.widget, 14),
            right,
            expand = "outside", -- 真ん中のウィジェットを画面の中央に置く
            layout = wibox.layout.align.horizontal,
        },
        left = 8, right = 8, top = 6, bottom = 0,
        widget = wibox.container.margin,
    }
    s.mywibox.widget = root

    -- バーのウィンドウをタイルの形に切り抜く。
    -- picom のすりガラス (ぼかし) がタイルの後ろだけにかかり、タイルの間はクリックが下の画面に通る
    local last_key
    local function update_shape()
        local hierarchy = s.mywibox._drawable._widget_hierarchy
        if not hierarchy then return end
        local rects = {}
        local function walk(node)
            if node:get_widget().is_bar_tile then
                local x, y, w, h = gears.matrix.transform_rectangle(node:get_matrix_to_device(), 0, 0, node:get_size())
                table.insert(rects, { math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5) })
                return
            end
            for _, child in ipairs(node:get_children()) do walk(child) end
        end
        walk(hierarchy)
        local parts = {}
        for _, r in ipairs(rects) do table.insert(parts, table.concat(r, ",")) end
        local key = table.concat(parts, ";")
        if key == last_key or #rects == 0 then return end -- 位置が変わったときだけ作り直す
        last_key = key
        s.mywibox.shape = function(cr)
            for _, r in ipairs(rects) do
                cr:save()
                cr:translate(r[1], r[2])
                gears.shape.rounded_rect(cr, r[3], r[4], theme.TILE_RADIUS)
                cr:restore()
            end
        end
    end
    -- 描き直すたびに (曲名や時計で幅が変わったときも) タイルの位置を確かめる
    function root:after_draw_children() gears.timer.delayed_call(update_shape) end
end
