-- ブルーライトカット (gammastep): 動いていればオン、止めればオフ (止めると画面の色は元に戻る)
-- 明るさのポップアップに出す切り替え行と、Super+Shift+n から使う
local awful   = require("awful")
local gears   = require("gears")
local wibox   = require("wibox")
local naughty = require("naughty")
local theme   = require("modules.theme")
local C = theme.C

local nightlight = { on = false }
local listeners = {} -- 状態が変わったときに表示を更新する関数

local function update(on)
    nightlight.on = on
    for _, draw in ipairs(listeners) do draw(on) end
end

-- 今の状態を読み直す。after(on) は読み終わったあとに呼ぶ (省略可)
function nightlight.refresh(after)
    awful.spawn.easy_async("pgrep -x gammastep", function(_, _, _, code)
        update(code == 0)
        if after then after(nightlight.on) end
    end)
end

-- オン/オフを切り替える。notify が true なら通知も出す (キー操作用)
function nightlight.toggle(notify)
    nightlight.refresh(function(on)
        if on then
            -- 1 回目の合図だとゆっくり色を戻しながら終わるので、2 回送ってすぐ終わらせる (色はすぐ元に戻る)
            awful.spawn.with_shell("pkill -x gammastep; sleep 0.2; pkill -x gammastep")
        else
            awful.spawn("gammastep", false)
        end
        update(not on)
        if notify then
            naughty.notify { title = "ブルーライトカット",
                             text  = on and "オフ" or "オン (夜は暖色になります)" }
        end
    end)
end

-- ポップアップ用の行: 「月アイコン ブルーライトカット [オン]」。行のどこをクリックしても切り替わる
function nightlight.row()
    local label = wibox.widget {
        markup = theme.span(C.yellow, "󰖔", 16) .. "  " .. theme.span(C.text, "ブルーライトカット", 12),
        widget = wibox.widget.textbox,
    }
    local state = wibox.widget { align = "center", forced_width = 44, widget = wibox.widget.textbox }
    local switch = wibox.widget {
        { state, left = 8, right = 8, top = 2, bottom = 2, widget = wibox.container.margin },
        shape  = theme.rounded(10),
        widget = wibox.container.background,
    }
    local row = wibox.widget {
        {
            { theme.vcenter(label), nil, theme.vcenter(switch), layout = wibox.layout.align.horizontal },
            left = 6, right = 2, top = 4, bottom = 4,
            widget = wibox.container.margin,
        },
        shape  = theme.rounded(8),
        widget = wibox.container.background,
    }

    local function draw(on)
        switch.bg    = on and C.accent or C.surface
        state.markup = theme.span(on and C.white or C.subtext, on and "オン" or "オフ", 11, true)
    end
    table.insert(listeners, draw)
    draw(nightlight.on)

    theme.hover(row, C.surface)
    row:buttons(gears.table.join(awful.button({ }, 1, function() nightlight.toggle(false) end)))
    return row
end

nightlight.refresh()
return nightlight
