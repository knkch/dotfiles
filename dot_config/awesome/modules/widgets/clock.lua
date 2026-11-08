-- 時計 + クリックで出るカレンダー (ホイールで月を移動)
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local theme = require("modules.theme")
local C = theme.C

local clock = wibox.widget.textclock(
    "<span foreground='" .. C.sky .. "'>\u{f017}</span>  %m/%d (%a)  <b>%H:%M</b>")

local function cell(props)
    return gears.table.crush({ border_width = 0, padding = 6 }, props)
end

local calendar = awful.widget.calendar_popup.month {
    font          = theme.font_name .. " 12",
    spacing       = 4,
    start_sunday  = true,
    long_weekdays = false,
    style_month   = { bg_color = C.base, border_color = C.overlay, border_width = 1,
                      shape = theme.rounded(14), padding = 14 },
    style_header  = cell { fg_color = C.text, markup = function(t) return "<b>" .. t .. "</b>" end },
    style_weekday = cell { fg_color = C.subtext },
    style_normal  = cell { fg_color = C.text },
    style_focus   = cell { fg_color = C.white, bg_color = C.accent, shape = gears.shape.circle,
                           markup = function(t) return "<b>" .. t .. "</b>" end },
}
calendar:attach(clock, "tr", { on_hover = false })

return { widget = clock, calendar = calendar }
