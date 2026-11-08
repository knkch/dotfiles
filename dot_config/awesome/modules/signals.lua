-- ウィンドウの出現・タイトルバー・フォーカスまわりの動き
local awful     = require("awful")
local gears     = require("gears")
local wibox     = require("wibox")
local beautiful = require("beautiful")
local theme     = require("modules.theme")

-- 画面数が変わったときなどに、ウィンドウが画面の外に出ないようにする
client.connect_signal("manage", function(c)
    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

-- アプリ名 (例: com.mitchellh.ghostty → Ghostty)
local function app_name(c)
    local name = c.class or c.instance or c.name or "?"
    name = name:match("([^%.]+)$") or name
    return name:sub(1, 1):upper() .. name:sub(2)
end

-- タイトルバー: 普段は隠しておき、Super+Shift+t で表示する
client.connect_signal("request::titlebars", function(c)
    local function activate() c:emit_signal("request::activate", "titlebar", { raise = true }) end
    local buttons = gears.table.join(
        awful.button({ }, 1, function() activate(); awful.mouse.client.move(c) end),
        awful.button({ }, 3, function() activate(); awful.mouse.client.resize(c) end)
    )

    awful.titlebar(c, { size = 30 }):setup {
        { -- 左: アイコン
            { awful.titlebar.widget.iconwidget(c), margins = 4, widget = wibox.container.margin },
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal,
        },
        { -- 中央: アプリ名 (ウィンドウタイトルは tmux のバーなどと重なるため)
            { align = "center", text = app_name(c), font = theme.font(11),
              widget = wibox.widget.textbox },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal,
        },
        { -- 右: ボタン
            awful.titlebar.widget.floatingbutton(c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton(c),
            awful.titlebar.widget.ontopbutton(c),
            awful.titlebar.widget.closebutton(c),
            layout = wibox.layout.fixed.horizontal,
        },
        layout = wibox.layout.align.horizontal,
    }
    awful.titlebar.hide(c)
end)

-- マウスが乗ったウィンドウにフォーカスする
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", { raise = false })
end)

-- フォーカス中のウィンドウの枠を青くする
client.connect_signal("focus",   function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
