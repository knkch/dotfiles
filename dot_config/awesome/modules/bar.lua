-- 画面上部のバー: 背景は無く、タイルが浮いて並ぶ。左 = ロゴ・タグ・壁紙ボタン + 起動中のアプリ / 中央 = 再生中の曲 / 右 = トレイ・各種状態・時計
local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local beautiful = require("beautiful")
local config = require("modules.config")
local theme  = require("modules.theme")
local menu   = require("modules.menu")

local mpd        = require("modules.widgets.mpd")
local volume     = require("modules.widgets.volume")
local brightness = require("modules.widgets.brightness")
local battery    = require("modules.widgets.battery")
local vpn        = require("modules.widgets.vpn")
local indicators = require("modules.widgets.indicators")
local notifications = require("modules.widgets.notifications")
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

-- 起動中のアプリの一覧 (ボタンを押すと出るポップアップ) の中の操作
local function tasklist_buttons(close_list)
    return gears.table.join(
        awful.button({ }, 1, function(c)            -- 左: そのウィンドウへ (最小化していれば戻す)
            c:emit_signal("request::activate", "tasklist", { raise = true })
            close_list()
        end),
        awful.button({ }, 2, function(c) c:kill() end),                    -- 中: 閉じる
        awful.button({ }, 3, function(c) c.minimized = not c.minimized end) -- 右: 最小化の切り替え
    )
end

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

    -- 起動中のアプリ: バーには「アイコン + 数」のボタンだけを置き、押すと一覧を出す
    local task_popup
    local function close_list() if task_popup then task_popup.visible = false end end
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons(close_list),
        style   = { disable_task_name = false }, -- 一覧ではウィンドウ名も出す
        layout  = { spacing = 4, layout = wibox.layout.fixed.vertical },
        widget_template = { -- 1 行: アイコン + ウィンドウ名
            {
                {
                    {
                        { id = "icon_role", forced_width = 24, forced_height = 24, widget = wibox.widget.imagebox },
                        valign = "center", widget = wibox.container.place,
                    },
                    { id = "text_role", ellipsize = "end", widget = wibox.widget.textbox },
                    spacing = 10,
                    layout  = wibox.layout.fixed.horizontal,
                },
                left = 10, right = 10,
                widget = wibox.container.margin,
            },
            id            = "background_role",
            forced_width  = 320,
            forced_height = 38,
            shape         = theme.rounded(8),
            widget        = wibox.container.background,
        },
    }
    task_popup = theme.popup(s.mytasklist, { screen = s, preferred_positions = "bottom", preferred_anchors = "front" })
    task_popup:connect_signal("mouse::leave", close_list)

    local task_count = wibox.widget { widget = wibox.widget.textbox }
    local tasks_button = wibox.widget {
        theme.bar_glyph(theme.C.text, "\u{f05b2}"),
        task_count,
        spacing = 6,
        layout  = wibox.layout.fixed.horizontal,
    }
    tasks_button:buttons(gears.table.join(
        awful.button({ }, 1, function()  -- 左: 一覧を開く / 閉じる
            if task_popup.visible then close_list()
            else task_popup:move_next_to(mouse.current_widget_geometry) end
        end),
        awful.button({ }, 4, function() awful.client.focus.byidx(-1) end), -- ホイール: ウィンドウを順に切り替え
        awful.button({ }, 5, function() awful.client.focus.byidx( 1) end)
    ))

    -- アプリが 1 つも無いときは空のタイルにならないよう隠す
    local tasks = theme.tile(tasks_button)
    local function update_tasks()
        local n = 0
        for _, c in ipairs(s.all_clients) do
            if awful.widget.tasklist.filter.currenttags(c, s) then n = n + 1 end
        end
        tasks.visible = n > 0
        task_count.markup = theme.span(theme.C.text, tostring(n))
        if n == 0 then close_list() end
    end
    for _, sig in ipairs { "manage", "unmanage", "tagged", "untagged", "property::screen" } do
        client.connect_signal(sig, update_tasks)
    end
    tag.connect_signal("property::selected", update_tasks)
    update_tasks()

    local G = theme.BAR
    local left = {
        layout  = wibox.layout.fixed.horizontal,
        spacing = G.tile_gap,
        theme.tile({
            wibox.container.margin(menu.launcher, 0, 0, 1, 1),
            s.mytaglist,
            wibox.container.margin(wallpaper.widget, 0, 0, 1, 1),
            spacing = 8,
            layout  = wibox.layout.fixed.horizontal,
        }, 6), -- タグの丸がタイルの端に近いほうが揃って見えるので、ここだけ余白を小さく
        tasks,
        s.mypromptbox,
    }

    ---------------------------------------------------------------- トレイ (ほかのアプリのアイコン)
    -- Discord などが出すアイコン。透明にできず bg_systray の色で塗られるので、無いときは隠す。
    -- 数が増えて中央の曲名のタイルにぶつかりそうになったら、Windows の「隠れているインジケーター」のように
    -- 「⌄」ボタンにたたむ。押すとアイコンが格子状に並んだ小窓が下に開く (開いている間は「⌃」)
    local systray = wibox.widget.systray()
    local TRAY_ICON, BAR_SPACING, FLYOUT_SPACING, FLYOUT_COLS = 24, 6, 12, 4
    systray:set_base_size(TRAY_ICON) -- アイコンの大きさ。決めておかないと、高さの制限が無い小窓で並ばない
    local tray_slot  = wibox.container.place(systray, "center", "center")         -- バーに並べるときの置き場 (縦は中央)
    -- たたんだときの置き場。小窓は大きさを測るときに画面の情報を渡さず、トレイが幅 0 と答えてしまうので、
    -- 大きさはアイコンの数から自分で決める
    local popup_slot = wibox.container.constraint(nil, "exact", TRAY_ICON, TRAY_ICON)
    local tray_popup = theme.popup(popup_slot, { screen = s, preferred_positions = "bottom",
                                                 preferred_anchors = "middle" })
    tray_popup:connect_signal("mouse::leave", function() tray_popup.visible = false end)

    local CHEVRON_DOWN, CHEVRON_UP = "\u{f0140}", "\u{f0143}"
    local overflow_icon = theme.bar_glyph(theme.C.text, CHEVRON_DOWN)
    local overflow = wibox.widget { -- マウスを乗せると地が明るくなるボタン
        { overflow_icon, left = 4, right = 4, widget = wibox.container.margin },
        shape = theme.rounded(6), widget = wibox.container.background,
    }
    theme.hover(overflow, theme.C.overlay .. "99", nil)
    local overflow_tip = awful.tooltip { objects = { overflow }, delay_show = 0.5 }
    overflow:buttons(awful.button({ }, 1, function()
        if tray_popup.visible then tray_popup.visible = false
        else overflow_tip:hide(); tray_popup:move_next_to(mouse.current_widget_geometry) end
    end))
    tray_popup:connect_signal("property::visible", function()
        overflow_icon:set(theme.C.text, tray_popup.visible and CHEVRON_UP or CHEVRON_DOWN)
    end)

    local collapsed = false
    local function update_systray()
        local n = awesome.systray()
        tray_slot.visible = not collapsed and n > 0
        overflow.visible = collapsed and n > 0
        overflow_tip.text = "隠れているアイコンを表示"
        -- トレイの並べ方は全体で 1 つの設定なので、たたんでいるときだけ小窓用 (格子・広めの間隔) にする
        local cols = math.min(math.max(n, 1), FLYOUT_COLS)
        local rows = math.max(1, math.ceil(n / FLYOUT_COLS))
        beautiful.systray_max_rows     = collapsed and rows or 1
        beautiful.systray_icon_spacing = collapsed and FLYOUT_SPACING or BAR_SPACING
        popup_slot.width  = cols * (TRAY_ICON + FLYOUT_SPACING) - FLYOUT_SPACING
        popup_slot.height = rows * (TRAY_ICON + FLYOUT_SPACING) - FLYOUT_SPACING
        systray:emit_signal("widget::layout_changed")
        if n == 0 then tray_popup.visible = false end
    end
    local function set_collapsed(c)
        if c == collapsed then return end
        collapsed = c
        if c then tray_slot.widget = nil; popup_slot.widget = systray
        else popup_slot.widget = nil; tray_slot.widget = systray; tray_popup.visible = false end
        update_systray()
    end
    awesome.connect_signal("systray::update", update_systray)
    gears.timer.delayed_call(update_systray)

    ---------------------------------------------------------------- 右側
    -- トレイと状態のアイコンは 1 つのタイルにまとめる (Windows の通知領域のような並び):
    --   [ほかのアプリ (多いと ⌄ にたたむ)] [クリップボード] [あ] [VPN] [Bluetooth] [Wi-Fi] [明るさ] [音量]
    -- 文字 (残量%) が付く電池、日時、通知はそれぞれ別のタイル
    -- アイコンは絵の幅ぴったりで並ぶ (theme.ink_box) ので、間隔 G.gap がそのまま見た目の間隔になる
    local status_tile = theme.tile(theme.hbox {
        tray_slot, overflow,
        indicators.clip, indicators.ime,
        vpn.widget, -- VPN 接続中だけ出る
        indicators.bt, indicators.net,
        brightness.widget, volume.widget,
    })
    status_tile.is_tray_tile = true
    local right = {
        {
            layout  = wibox.layout.fixed.horizontal,
            spacing = G.tile_gap,
            status_tile,
            theme.tile(battery.widget),
            theme.tile(clock.widget),
            theme.tile(notifications.widget),
            theme.tile(wibox.container.margin(s.mylayoutbox, 0, 0, 3, 3), 8),
        },
        halign = "right",
        widget = wibox.container.place,
    }

    -- バー本体は透明。タイルだけを画面の端から少し離して浮かせる
    s.mywibox = awful.wibar { position = "top", screen = s, height = 50, bg = theme.C.transparent }
    local mpd_tile = theme.tile(mpd.widget)
    mpd_tile.is_mpd_tile = true
    local root = wibox.widget {
        {
            left,
            mpd_tile,
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
    -- トレイを並べる余裕があるかを確かめ、中央の曲名のタイルにぶつかるならたたむ / 余裕ができたら戻す
    local MIN_GAP, HYSTERESIS = 8, 24
    local per_icon = 34 -- トレイのアイコン 1 個分の幅 (並べているときに測り直す)
    local function check_tray_room(hierarchy)
        local found = {}
        local function find(node)
            local w = node:get_widget()
            local key = (w.is_mpd_tile and "mpd") or (w.is_tray_tile and "tray")
                     or (w == tray_slot and "slot") or (w == overflow and "overflow")
            if key then
                local x, _, width = gears.matrix.transform_rectangle(node:get_matrix_to_device(), 0, 0, node:get_size())
                found[key] = { x = x, w = width }
            end
            for _, child in ipairs(node:get_children()) do find(child) end
        end
        find(hierarchy)
        local n = awesome.systray()
        if not found.mpd or n == 0 then return end
        local mpd_right = found.mpd.x + found.mpd.w
        -- タイルが入りきらずに消えているときも「ぶつかっている」とみなす
        local free = (found.tray and found.tray.w >= 1) and (found.tray.x - mpd_right) or -math.huge
        if not collapsed then
            if found.slot and found.slot.w >= 1 then per_icon = (found.slot.w + G.gap) / n end
            if free < MIN_GAP then set_collapsed(true) end
        else
            local extra = n * per_icon - ((found.overflow and found.overflow.w or 0) + G.gap)
            if free - extra >= MIN_GAP + HYSTERESIS then set_collapsed(false) end
        end
    end

    local function update_shape()
        local hierarchy = s.mywibox._drawable._widget_hierarchy
        if not hierarchy then return end
        local rects = {}
        local function walk(node)
            local widget = node:get_widget()
            if widget.is_bar_tile then
                local x, y, w, h = gears.matrix.transform_rectangle(node:get_matrix_to_device(), 0, 0, node:get_size())
                -- 隠れているタイル (幅 0) は入れない。入れると後ろのタイルがクリックできなくなる
                if widget.visible and w >= 1 and h >= 1 then
                    table.insert(rects, { math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5) })
                end
                return
            end
            for _, child in ipairs(node:get_children()) do walk(child) end
        end
        walk(hierarchy)
        check_tray_room(hierarchy)
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
    -- 描いた直後はタイルの位置がまだ古いことがあるので、少し待ってからもう一度確かめる
    -- (形が古いままだと、タイルの一部がクリックに反応しなくなる)
    local settle = gears.timer { timeout = 0.3, single_shot = true, callback = update_shape }
    function root:after_draw_children()
        gears.timer.delayed_call(update_shape)
        settle:again()
    end
    awesome.connect_signal("systray::update", function() settle:again() end)
end
