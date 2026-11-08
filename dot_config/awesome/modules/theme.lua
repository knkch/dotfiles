-- 見た目の設定 (配色・フォント・各部品のテーマ) と、共通で使う見た目の部品
-- ほかのモジュールより先に読み込むこと (beautiful の値は部品を作るときに読まれる)
local awful     = require("awful")
local gears     = require("gears")
local wibox     = require("wibox")
local beautiful = require("beautiful")
local naughty   = require("naughty")

beautiful.init(gears.filesystem.get_themes_dir() .. "default/theme.lua")

local theme = {}

-- 配色 (Catppuccin Mocha + 青のアクセント)
local C = {
    base        = "#1e1e2e", -- バー・ポップアップの地の色
    surface     = "#313244", -- ボタン・選択中の地
    overlay     = "#45475a", -- 枠線・ホバー
    text        = "#cdd6f4",
    subtext     = "#7f849c",
    accent      = "#1e66f5", -- アクティブな枠・選択中
    sky         = "#89b4fa", -- アイコンの差し色
    yellow      = "#f9e2af",
    green       = "#a6e3a1",
    peach       = "#fab387",
    mauve       = "#cba6f7",
    teal        = "#94e2d5",
    urgent      = "#f38ba8",
    white       = "#ffffff",
    transparent = "#00000000",
}
theme.C = C
theme.font_name = "Hack Nerd Font" -- 日本語は自動で Noto CJK が使われる
theme.TILE_RADIUS = 12

function theme.font(size, bold)
    return string.format("%s %s%d", theme.font_name, bold and "Bold " or "", size)
end

function theme.rounded(radius)
    return function(cr, w, h) gears.shape.rounded_rect(cr, w, h, radius) end
end
local rounded = theme.rounded

-- 色 (と大きさ) を指定した Pango マークアップ
function theme.span(color, text, size, bold)
    local font = size and string.format(" font='%s'", theme.font(size, bold)) or ""
    return string.format("<span foreground='%s'%s>%s</span>", color, font, text)
end

-- クリックされた部品の位置 (ポップアップをその下に出すとき用)
function theme.under_mouse() return mouse.current_widget_geometry end

---------------------------------------------------------------- beautiful (Awesome 標準部品の見た目)
gears.table.crush(beautiful, {
    font              = theme.font(14),
    useless_gap       = 2,
    gap_single_client = true,
    border_width      = 3,
    border_focus      = C.accent,
    border_normal     = C.surface,

    bg_normal   = C.base,    fg_normal   = C.text,
    bg_focus    = C.accent,  fg_focus    = C.white,
    bg_urgent   = C.urgent,  fg_urgent   = C.base,
    bg_minimize = C.surface, fg_minimize = C.subtext,
    bg_systray  = C.base, -- トレイは透明にできないので、タイルと近い地の色で不透明に塗る
    systray_icon_spacing = 6,

    -- タグ (丸) と起動中のアプリ (アイコンだけ)
    taglist_shape         = gears.shape.circle,
    taglist_spacing       = 4,
    taglist_bg_focus      = C.accent,         taglist_fg_focus    = C.white,
    taglist_bg_occupied   = C.surface .. "99", taglist_fg_occupied = C.text,
    taglist_bg_empty      = C.transparent,
    taglist_fg_empty      = "#a6adc8", -- 明るい壁紙の上でも読める明るさ
    taglist_bg_urgent     = C.urgent,         taglist_fg_urgent   = C.base,
    tasklist_shape        = rounded(8),
    tasklist_spacing      = 6,
    tasklist_bg_normal    = C.surface .. "99",
    tasklist_bg_focus     = C.overlay .. "cc",
    tasklist_fg_focus     = C.white,
    tasklist_bg_minimize  = C.transparent,
    tasklist_disable_task_name = true,

    -- メニュー
    menu_bg_normal    = C.base,   menu_fg_normal = C.text,
    menu_bg_focus     = C.accent, menu_fg_focus  = C.white,
    menu_border_color = C.overlay,
    menu_border_width = 1,
    menu_width        = 220,
    menu_height       = 34,

    -- タイトルバー (Super+Shift+t で表示)
    titlebar_bg_focus  = C.surface, titlebar_fg_focus  = C.text,
    titlebar_bg_normal = C.base,    titlebar_fg_normal = C.subtext,

    -- ツールチップ
    tooltip_bg           = C.base,
    tooltip_fg           = C.text,
    tooltip_border_color = C.overlay,
    tooltip_border_width = 1,
    tooltip_shape        = rounded(8),
    tooltip_font         = theme.font(12),

    -- ショートカット一覧 (Super+s。見出しの色は keys.lua)
    hotkeys_font             = theme.font(14, true),
    hotkeys_description_font = theme.font(13),
    hotkeys_bg               = C.base,
    hotkeys_fg               = C.text,
    hotkeys_border_color     = C.overlay,
    hotkeys_border_width     = 1,
    hotkeys_shape            = rounded(14),
    hotkeys_modifiers_fg     = C.subtext,
    hotkeys_label_bg         = C.sky,
    hotkeys_label_fg         = C.base,
    hotkeys_group_margin     = 24,

    -- 通知
    notification_bg           = C.base,
    notification_fg           = C.text,
    notification_border_color = C.overlay,
    notification_border_width = 1,
    notification_shape        = rounded(12),
    notification_margin       = 14,
    notification_max_width    = 460,
    notification_icon_size    = 64,
    notification_font         = theme.font(12),
})
-- 標準テーマのタグの四角い印を消す (nil は上の表では渡せないので個別に)
beautiful.taglist_squares_sel   = nil
beautiful.taglist_squares_unsel = nil

naughty.config.padding = 10
naughty.config.spacing = 8
naughty.config.defaults.margin       = 14
naughty.config.defaults.border_width = 1
naughty.config.presets.critical.bg = C.urgent
naughty.config.presets.critical.fg = C.base

---------------------------------------------------------------- 共通の部品

-- マウスが乗っている間だけ背景の色を変える (normal_bg は離れているときの色。省略すると透明)
function theme.hover(widget, hover_bg, normal_bg)
    widget.bg = normal_bg
    widget:connect_signal("mouse::enter", function() widget.bg = hover_bg end)
    widget:connect_signal("mouse::leave", function() widget.bg = normal_bg end)
    return widget
end

-- すりガラスの板 (バーのタイルと Dock 共通)。半透明の地 + 細い枠。ぼかしは picom がかける
function theme.glass(widget, radius)
    return wibox.widget {
        widget,
        bg                 = C.base .. "a6", -- 明るい壁紙でも文字が読める濃さ
        shape              = rounded(radius),
        shape_border_width = 1,
        shape_border_color = C.overlay .. "99",
        widget             = wibox.container.background,
    }
end

-- バーに浮かぶタイル。bg を渡すとその色で不透明に塗る (トレイ用)
function theme.tile(widget, hpad, bg)
    local tile = theme.glass({ widget, left = hpad, right = hpad, top = 3, bottom = 3, widget = wibox.container.margin },
                             theme.TILE_RADIUS)
    if bg then tile.bg = bg end
    tile.is_bar_tile = true -- バーの形をタイルの形に切り抜くときの目印 (bar.lua)
    return tile
end

-- 統一デザインのポップアップ (地の色・枠・角丸・余白をそろえる)
function theme.popup(widget, props)
    return awful.popup(gears.table.crush({
        widget       = { widget, margins = 14, widget = wibox.container.margin },
        bg           = C.base,
        border_color = C.overlay,
        border_width = 1,
        shape        = rounded(14),
        ontop        = true,
        visible      = false,
        offset       = { y = 6 },
    }, props or {}))
end

-- 統一デザインのスライダー
function theme.slider(props)
    return wibox.widget(gears.table.crush({
        bar_shape        = gears.shape.rounded_rect,
        bar_height       = 6,
        bar_color        = C.surface,
        bar_active_color = C.accent,
        handle_color     = C.white,
        handle_shape     = gears.shape.circle,
        handle_width     = 16,
        minimum          = 0,
        maximum          = 100,
        value            = 0,
        forced_width     = 220,
        forced_height    = 22,
        widget           = wibox.widget.slider,
    }, props or {}))
end

-- アイコン画像 (正方形)
function theme.icon(image, size)
    return wibox.widget {
        image = image, resize = true,
        forced_width = size, forced_height = size,
        widget = wibox.widget.imagebox,
    }
end

-- 縦方向の中央に置く
function theme.vcenter(widget)
    return wibox.widget { widget, valign = "center", widget = wibox.container.place }
end

return theme
