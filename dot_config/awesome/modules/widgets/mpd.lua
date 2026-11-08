-- MPD の再生中の曲をバーに表示する。クリックで操作パネル (アートワーク・曲名・操作ボタン) を開く
-- 曲情報は scripts/mpd-now.py、操作は rmpc を使う
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local theme = require("modules.theme")

local C = theme.C
local esc, rounded, span = gears.string.xml_escape, theme.rounded, theme.span

local SCRIPT = gears.filesystem.get_configuration_dir() .. "scripts/mpd-now.py"
local ART    = 240 -- アートワークの大きさ (px)

-- Nerd Font のアイコン
local G = { note = "\u{f001}", prev = "\u{f048}", play = "\u{f04b}", pause = "\u{f04c}", next = "\u{f051}" }

local function fmt_time(t)
    t = tonumber(t) or 0
    return string.format("%d:%02d", math.floor(t / 60), math.floor(t % 60))
end

---------------------------------------------------------------- バー
local bar_icon = wibox.widget { widget = wibox.widget.textbox }
local bar_text = wibox.widget { ellipsize = "end", widget = wibox.widget.textbox }
local bar = wibox.widget {
    bar_icon,
    { bar_text, width = 420, strategy = "max", widget = wibox.container.constraint },
    spacing = 8,
    layout  = wibox.layout.fixed.horizontal,
}

---------------------------------------------------------------- 操作パネル
local art = wibox.widget {
    resize = true, forced_width = ART, forced_height = ART,
    clip_shape = rounded(10), visible = false,
    widget = wibox.widget.imagebox,
}
local art_placeholder = wibox.widget {
    { markup = span(C.subtext, G.note, 56), align = "center", valign = "center", widget = wibox.widget.textbox },
    forced_width = ART, forced_height = ART,
    bg = C.surface, shape = rounded(10),
    widget = wibox.container.background,
}
local title  = wibox.widget { align = "center", ellipsize = "end", forced_height = 26, widget = wibox.widget.textbox }
local artist = wibox.widget { align = "center", ellipsize = "end", widget = wibox.widget.textbox }
local album  = wibox.widget { align = "center", ellipsize = "end", widget = wibox.widget.textbox }
local progress = wibox.widget {
    max_value = 1, value = 0, forced_height = 6,
    color = C.accent, background_color = C.surface,
    shape = rounded(3), bar_shape = rounded(3),
    widget = wibox.widget.progressbar,
}
local t_elapsed  = wibox.widget { widget = wibox.widget.textbox }
local t_duration = wibox.widget { align = "right", widget = wibox.widget.textbox }

local state = { state = "offline" }
local refresh -- 下で定義

local function rmpc(cmd)
    awful.spawn.easy_async({ "rmpc", cmd }, function() refresh() end)
end

-- 丸いボタン。戻り値の set(glyph) でアイコンを変えられる
local function button(glyph, size, d, bg, cmd)
    local label = wibox.widget { align = "center", valign = "center", widget = wibox.widget.textbox }
    local w = wibox.widget {
        label, forced_width = d, forced_height = d,
        bg = bg, shape = gears.shape.circle,
        widget = wibox.container.background,
    }
    local function set(g) label.markup = span(C.white, g, size) end
    set(glyph)
    theme.hover(w, C.overlay, bg)
    w:buttons(awful.button({ }, 1, function() rmpc(cmd) end))
    return w, set
end
local btn_prev = button(G.prev, 14, 44, C.surface, "prev")
local btn_play, set_play = button(G.play, 18, 56, C.accent, "togglepause")
local btn_next = button(G.next, 14, 44, C.surface, "next")

local popup = theme.popup({
    { art_placeholder, art, layout = wibox.layout.stack },
    { title, artist, album, spacing = 2, layout = wibox.layout.fixed.vertical },
    {
        progress,
        { t_elapsed, nil, t_duration, layout = wibox.layout.align.horizontal },
        spacing = 4,
        layout  = wibox.layout.fixed.vertical,
    },
    {
        {
            theme.vcenter(btn_prev),
            btn_play,
            theme.vcenter(btn_next),
            spacing = 20,
            layout  = wibox.layout.fixed.horizontal,
        },
        halign = "center",
        widget = wibox.container.place,
    },
    spacing      = 12,
    forced_width = ART,
    layout       = wibox.layout.fixed.vertical,
}, { preferred_positions = "bottom", preferred_anchors = "middle" })

---------------------------------------------------------------- 表示の更新
local last_file
local function update_art()
    awful.spawn.easy_async({ "python3", SCRIPT, "art" }, function(out)
        local path = out:match("^(/[^\n]+)")
        art.visible = path ~= nil and gears.filesystem.file_readable(path)
        if art.visible then art.image = path end
    end)
end

local function render()
    local s = state.state
    local has_song = (s == "play" or s == "pause") and state.title
    if not has_song then
        bar_icon.markup = span(C.subtext, G.note)
        bar_text.markup = span(C.subtext, s == "offline" and "MPD に接続できません" or "再生していません")
    else
        bar_icon.markup = s == "play" and span(C.sky, G.note) or span(C.subtext, G.pause)
        local t = "<b>" .. esc(state.title) .. "</b>"
        if state.artist ~= "" then t = t .. span(C.subtext, "  " .. esc(state.artist)) end
        bar_text.markup = t
    end

    title.markup  = span(C.text, esc(has_song and state.title or "再生していません"), 13, true)
    artist.markup = span(C.text, esc(has_song and state.artist or ""))
    album.markup  = span(C.subtext, esc(has_song and state.album or ""))
    local dur = tonumber(state.duration) or 0
    progress.value    = dur > 0 and (tonumber(state.elapsed) or 0) / dur or 0
    t_elapsed.markup  = span(C.subtext, fmt_time(state.elapsed))
    t_duration.markup = span(C.subtext, fmt_time(dur))
    set_play(s == "play" and G.pause or G.play)

    local file = has_song and state.file or nil
    if file ~= last_file then
        last_file = file
        if file then update_art() else art.visible = false end
    end
end

local busy = false
refresh = function()
    if busy then return end
    busy = true
    awful.spawn.easy_async({ "python3", SCRIPT }, function(out)
        busy = false
        local new = {}
        for k, v in out:gmatch("([^\t\n]+)\t([^\n]*)") do new[k] = v end
        new.state = new.state or "offline"
        new.artist, new.album = new.artist or "", new.album or ""
        state = new
        render()
    end)
end

-- パネルを開いている間は 1 秒ごと、閉じているときは 3 秒ごとに更新
local timer = gears.timer { timeout = 3, autostart = true, call_now = true, callback = refresh }
popup:connect_signal("property::visible", function()
    timer.timeout = popup.visible and 1 or 3
    timer:again()
    if popup.visible then refresh() end
end)
popup:connect_signal("mouse::leave", function() popup.visible = false end)

bar:buttons(gears.table.join(
    awful.button({ }, 1, function()            -- 左クリック: 操作パネル
        if not popup.visible then popup:move_next_to(theme.under_mouse()) end
        popup.visible = not popup.visible
    end),
    awful.button({ }, 2, function() rmpc("togglepause") end), -- 中クリック: 再生 / 一時停止
    awful.button({ }, 4, function() rmpc("prev") end),        -- ホイール上: 前の曲
    awful.button({ }, 5, function() rmpc("next") end)         -- ホイール下: 次の曲
))

render()

-- メディアキー用の操作も一緒に返す
return {
    widget = bar,
    toggle = function() rmpc("togglepause") end,
    next   = function() rmpc("next") end,
    prev   = function() rmpc("prev") end,
}
