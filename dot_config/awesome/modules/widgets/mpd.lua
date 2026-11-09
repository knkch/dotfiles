-- MPD の再生中の曲をバーに表示する。クリックで操作パネル (アートワーク・曲名・操作ボタン) を開く
-- 曲情報は MPD のソケットに直接つないで受け取る。"idle" で待つので、曲や再生状態が変わったときだけ届く
-- (定期的にコマンドを起動しない)。操作とアートワークの取り出しは rmpc を使う
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local lgi   = require("lgi")
local theme = require("modules.theme")

local Gio, GLib = lgi.Gio, lgi.GLib
local C = theme.C
local esc, rounded, span = gears.string.xml_escape, theme.rounded, theme.span

local SOCKET    = (os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/mpd/socket"
local ART_CACHE = gears.filesystem.get_cache_dir() .. "mpd-art/"
local ART       = 240 -- アートワークの大きさ (px)

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
local connect -- 下で定義

-- 操作は rmpc に任せる。結果は MPD の "idle" で届くので、ここでは何もしない (未接続ならつなぎ直す)
local function rmpc(cmd)
    awful.spawn.easy_async({ "rmpc", cmd }, function() connect() end)
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
-- 変わったときだけ設定する (同じ値でもバー全体が描き直されるため)
local function set_markup(w, m)
    if w.markup ~= m then w.markup = m end
end

-- アートワーク: ~/.cache/awesome/mpd-art/<ファイル名の md5>.img にとっておき、無いときだけ rmpc で取り出す
local last_file
local function update_art(file)
    local path = ART_CACHE .. GLib.compute_checksum_for_string(GLib.ChecksumType.MD5, file, -1) .. ".img"
    local function show(p)
        if file ~= last_file then return end -- 取り出している間に曲が変わった
        art.visible = p ~= nil
        if p then art.image = p end
    end
    if gears.filesystem.file_readable(path) then return show(path) end
    gears.filesystem.make_directories(ART_CACHE)
    awful.spawn.easy_async({ "rmpc", "albumart", "-o", path }, function(_, _, _, code)
        show(code == 0 and gears.filesystem.file_readable(path) and path or nil)
    end)
end

-- 再生位置は MPD に聞き直さず、最後に受け取った位置から経過時間で進める
local function elapsed_now()
    local e = state.elapsed or 0
    if state.state == "play" and state.at then e = e + (GLib.get_monotonic_time() - state.at) / 1e6 end
    local dur = state.duration or 0
    return dur > 0 and math.min(e, dur) or e
end

local function render_progress()
    local dur = state.duration or 0
    local e = elapsed_now()
    progress.value = dur > 0 and e / dur or 0
    set_markup(t_elapsed, span(C.subtext, fmt_time(e)))
    set_markup(t_duration, span(C.subtext, fmt_time(dur)))
end

local function render()
    local s = state.state
    local has_song = (s == "play" or s == "pause") and state.title
    if not has_song then
        set_markup(bar_icon, theme.glyph(C.subtext, G.note))
        set_markup(bar_text, span(C.subtext, s == "offline" and "MPD に接続できません" or "再生していません"))
    else
        set_markup(bar_icon, s == "play" and theme.glyph(C.sky, G.note) or theme.glyph(C.subtext, G.pause))
        local t = "<b>" .. esc(state.title) .. "</b>"
        if state.artist ~= "" then t = t .. span(C.subtext, "  " .. esc(state.artist)) end
        set_markup(bar_text, t)
    end

    set_markup(title,  span(C.text, esc(has_song and state.title or "再生していません"), 13, true))
    set_markup(artist, span(C.text, esc(has_song and state.artist or "")))
    set_markup(album,  span(C.subtext, esc(has_song and state.album or "")))
    render_progress()
    set_play(s == "play" and G.pause or G.play)

    local file = has_song and state.file or nil
    if file ~= last_file then
        last_file = file
        if file then update_art(file) else art.visible = false end
    end
end

---------------------------------------------------------------- MPD との接続
-- 流れ: つなぐ → あいさつ ("OK MPD ...") → status + currentsong を聞く → "idle player" で変化を待つ
--       → 変化が届いたらまた聞く ... の繰り返し。切れたら 10 秒後につなぎ直す
local conn, out
local phase, reply = nil, {}

local retry = gears.timer { timeout = 10, single_shot = true, callback = function() connect() end }

local function send(s)
    local ok = out and out:put_string(s)
    if not ok and conn then conn:close() end -- 書けない = 切れている。読み込み側が終わって on_closed が呼ばれる
end

local function query()
    phase, reply = "query", {}
    send("command_list_begin\nstatus\ncurrentsong\ncommand_list_end\n")
end

local function apply(r)
    local file = r.file
    state = {
        state    = r.state or "stop",
        elapsed  = tonumber(r.elapsed) or 0,
        duration = tonumber(r.duration) or tonumber(r.time) or 0,
        at       = GLib.get_monotonic_time(),
        file     = file,
        title    = r.songid and file and (r.title or file:match("([^/]+)%.[^./]*$") or file),
        artist   = r.artist or r.albumartist or "",
        album    = r.album or "",
    }
    render()
end

local function on_line(line)
    if phase == "hello" then
        if line:match("^OK MPD") then query() end
    elseif line == "OK" or line:match("^ACK") then
        if phase == "query" then
            apply(reply)
            phase = "idle"
            send("idle player\n")
        else
            query() -- idle が終わった = 何か変わった
        end
    elseif phase == "query" then
        local k, v = line:match("^([^:]+): (.*)$")
        if k then
            k = k:lower()
            reply[k] = reply[k] and (reply[k] .. ", " .. v) or v -- Artist などは複数行で来る
        end
    end
end

local function on_closed()
    if conn then conn:close() end
    conn, out, phase = nil, nil, nil
    state = { state = "offline" }
    render()
    retry:again()
end

connect = function()
    if conn then return end
    local ok, c = pcall(Gio.SocketClient.connect, Gio.SocketClient.new(), Gio.UnixSocketAddress.new(SOCKET), nil)
    if not ok or not c then return on_closed() end
    conn, phase = c, "hello"
    out = Gio.DataOutputStream.new(c:get_output_stream())
    awful.spawn.read_lines(c:get_input_stream(), on_line, on_closed, true)
end

-- パネルを開いている間だけ、再生位置を 1 秒ごとに進める
local tick = gears.timer { timeout = 1, callback = render_progress }
popup:connect_signal("property::visible", function()
    if popup.visible then render_progress(); tick:again() else tick:stop() end
end)
popup:connect_signal("mouse::leave", function() popup.visible = false end)

bar:buttons(gears.table.join(
    awful.button({ }, 1, function()            -- 左クリック: 操作パネル
        -- move_next_to は表示もしてしまうので、開くときだけ使う
        if popup.visible then popup.visible = false
        else popup:move_next_to(theme.under_mouse()) end
    end),
    awful.button({ }, 2, function() rmpc("togglepause") end), -- 中クリック: 再生 / 一時停止
    awful.button({ }, 4, function() rmpc("prev") end),        -- ホイール上: 前の曲
    awful.button({ }, 5, function() rmpc("next") end)         -- ホイール下: 次の曲
))

render()
connect()

-- メディアキー用の操作も一緒に返す
return {
    widget = bar,
    popup  = popup,
    toggle = function() rmpc("togglepause") end,
    next   = function() rmpc("next") end,
    prev   = function() rmpc("prev") end,
}
