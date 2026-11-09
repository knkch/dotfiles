-- 時計 + クリックで出るカレンダー (ホイールで月を移動)
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local theme = require("modules.theme")
local C = theme.C

-- 曜日は英語の 3 文字 (日本語の環境では %a が「月」になるので自分で組み立てる)
local WDAY = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
local clock = wibox.widget { widget = wibox.widget.textbox }
local function tick()
    local t = os.date("*t")
    -- 曜日と日付は控えめな色、時刻は太字。色で区切るのでカッコは付けない (例: Mon 11/09 18:24)
    clock.markup = string.format("<span foreground='%s'>%s %02d/%02d</span> <b>%02d:%02d</b>",
                                 C.subtext1, WDAY[t.wday], t.month, t.day, t.hour, t.min)
    return 60 - t.sec -- 次の分の始まりまで
end
local timer
timer = gears.timer { timeout = tick(), single_shot = true, autostart = true,
                     callback = function() timer.timeout = tick(); timer:again() end }

-- Awesome は 1 桁の日の前に空白を入れる (" 9")。中央寄せにしたときにずれるので外す
local function trim(t) return (t:gsub("^%s+", "")) end

-- 曜日は英語の 3 文字で出す (日本語の環境では os.date が「月」などを返すので置き換える)
local WEEKDAYS = { ["日"] = "Sun", ["月"] = "Mon", ["火"] = "Tue", ["水"] = "Wed",
                   ["木"] = "Thu", ["金"] = "Fri", ["土"] = "Sat" }

local function cell(props)
    -- マスの地は透明に (指定しないと各マスが標準の背景色で塗られ、すりガラスの上に四角が並ぶ)
    return gears.table.crush({ border_width = 0, padding = 6, bg_color = C.transparent }, props)
end

local calendar = awful.widget.calendar_popup.month {
    font          = theme.font_name .. " 12",
    spacing       = 4,
    start_sunday  = true,
    -- 曜日の名前を何バイトまで使うか。false だと 2 バイトで切られ、日本語の「月」(3 バイト) が消える
    long_weekdays = true,
    style_month   = { bg_color = theme.GLASS_BG, border_color = theme.GLASS_BORDER, border_width = 1,
                      shape = theme.rounded(14), padding = 14 },
    style_header  = cell { fg_color = C.text, markup = function(t) return "<b>" .. t .. "</b>" end },
    style_weekday = cell { fg_color = C.subtext, markup = function(t) return WEEKDAYS[t] or t end },
    style_normal  = cell { fg_color = C.text, markup = trim },
    style_focus   = cell { fg_color = C.white, bg_color = C.accent, shape = gears.shape.circle,
                           markup = function(t) return "<b>" .. trim(t) .. "</b>" end },
}
-- 日付は標準では右寄せで、今日の青丸 (枠の中央に描く) と数字がずれるので、中央寄せにする
do
    local month = calendar.widget
    local embed = month.fn_embed
    month.fn_embed = function(w, flag, date)
        if flag == "normal" or flag == "focus" then w.halign = "center" end
        return embed(w, flag, date)
    end
end
-- カレンダーの窓も角を丸める (四角いままだと、すりガラスのぼかしが角の外にもかかる)
calendar.shape = theme.rounded(14)
calendar:attach(clock, "tr", { on_hover = false })

return { widget = clock, calendar = calendar }
