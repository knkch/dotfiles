-- キーボードとマウスの操作 (一覧は Super+s)
-- Vim の操作を基本にしている:
--   Super + h/j/k/l          フォーカスを左/下/上/右へ
--   Super + Shift + h/j/k/l  ウィンドウを入れ替え (フローティングなら移動)
--   Super + Ctrl + h/j/k/l   大きさを変える
--   Super + [ / ]            前/次のタグ     Super + q  閉じる (:q)
--   Super + p  検索パネル (アプリ・ウィンドウ・電源・Web)     Super + /  ウィンドウを検索
local awful  = require("awful")
local gears  = require("gears")
local hotkeys_popup = require("awful.hotkeys_popup")
local config = require("modules.config")
local theme  = require("modules.theme")
local menu   = require("modules.menu")

local volume     = require("modules.widgets.volume")
local brightness = require("modules.widgets.brightness")
local mpd        = require("modules.widgets.mpd")
local nightlight = require("modules.widgets.nightlight")
local wallpaper  = require("modules.widgets.wallpaper")
local launchers  = require("modules.widgets.launchers")

local modkey = config.modkey
local SUPER, SHIFT, CTRL, ALT = { modkey }, { modkey, "Shift" }, { modkey, "Control" }, { modkey, "Mod1" }

-- awful.key の短縮形 (説明とグループは Super+s の一覧に出る)
local function key(mods, k, fn, desc, group)
    return awful.key(mods, k, fn, { description = desc, group = group })
end

local function raise_focused()
    if client.focus then client.focus:raise() end
end
-- その方向にウィンドウが無いとき (最大化レイアウトなど) は順番に切り替える
local function focus_dir(dir)
    return function()
        local before = client.focus
        awful.client.focus.bydirection(dir)
        if client.focus == before then
            awful.client.focus.byidx((dir == "right" or dir == "down") and 1 or -1)
        end
        raise_focused()
    end
end

local STEP = 40 -- フローティングのウィンドウを動かす・大きさを変える量 (px)
local function is_floating(c)
    return c.floating or awful.layout.get(c.screen) == awful.layout.suit.floating
end

-- Super+Shift+h/j/k/l: タイル中はその方向のウィンドウと入れ替え、フローティングなら移動
local DELTA = { left = { -1, 0 }, down = { 0, 1 }, up = { 0, -1 }, right = { 1, 0 } }
local function move_dir(dir)
    return function()
        local c = client.focus
        if not c then return end
        if is_floating(c) then
            c:relative_move(DELTA[dir][1] * STEP, DELTA[dir][2] * STEP, 0, 0)
        else
            awful.client.swap.bydirection(dir)
        end
    end
end

-- Super+Ctrl+h/l: 幅、j/k: 高さ (タイル中はメイン領域の幅・ウィンドウの高さの割合)
local function resize(dw, dh)
    return function()
        local c = client.focus
        if c and is_floating(c) then
            c:relative_move(0, 0, dw * STEP, dh * STEP)
        elseif dw ~= 0 then
            awful.tag.incmwfact(dw * 0.05)
        elseif c then
            awful.client.incwfact(dh * 0.05)
        end
    end
end

local keys = {}

---------------------------------------------------------------- 全体のキー
local globalkeys = gears.table.join(
    -- Awesome
    key(SUPER, "s",      hotkeys_popup.show_help,                        "ショートカット一覧", "Awesome"),
    key(SUPER, "w",      function() menu.main:show() end,                "右クリックメニュー", "Awesome"),
    key(SHIFT, "Escape", function() awful.spawn(config.lock_cmd) end,    "画面をロック",       "Awesome"),
    key(CTRL,  "r",      awesome.restart,                                "Awesome を再起動",   "Awesome"),
    -- すぐにログアウトすると危ないので、確認つきの電源メニューを開く
    key(SHIFT, "q",      launchers.power,                                "電源メニュー",       "Awesome"),
    key(SHIFT, "e",      launchers.power,                                "電源メニュー",       "Awesome"),
    key(SUPER, "x", function()
        awful.prompt.run {
            prompt       = "Lua を実行: ",
            textbox      = awful.screen.focused().mypromptbox.widget,
            exe_callback = awful.util.eval,
            history_path = awful.util.get_cache_dir() .. "/history_eval",
        }
    end, "Lua を実行", "Awesome"),

    -- 起動
    key(SUPER, "Return", function() awful.spawn(config.terminal_tmux) end,       "ターミナル (tmux)",       "起動"),
    key(SUPER, "a",      menu.toggle_whisker,                                    "アプリメニュー",          "起動"),
    -- アプリ・開いているウィンドウ・電源・Web 検索をタブで切り替える検索パネル
    key(SUPER, "p",      function() launchers.open() end,                        "検索 (アプリ・ウィンドウ・電源・Web)", "起動"),
    key(SUPER, "slash",  launchers.windows,                                      "ウィンドウを検索",        "起動"),
    key(SUPER, "r",      function() awful.screen.focused().mypromptbox:run() end, "コマンドを実行",         "起動"),
    key(SHIFT, "w",      wallpaper.open,                                          "壁紙を選ぶ",              "起動"),
    key(SUPER, "e",      function() awful.spawn(config.filemanager) end,         "ファイルマネージャー",    "起動"),
    key(SUPER, "v",      function() awful.spawn("copyq toggle") end,             "クリップボード履歴",      "起動"),

    -- スクリーンショット (保存先は config.screenshot_dir)
    key({ },         "Print", function() awful.spawn("flameshot gui") end, "範囲を選んで撮る", "スクリーンショット"),
    key({ "Shift" }, "Print", function() awful.spawn { "flameshot", "full", "-c", "-p", config.screenshot_dir } end,
        "画面全体を撮る (コピーも)", "スクリーンショット"),

    -- タグ
    key(SUPER, "bracketleft",  awful.tag.viewprev,   "前のタグ",         "タグ"),
    key(SUPER, "bracketright", awful.tag.viewnext,   "次のタグ",         "タグ"),
    key(SUPER, "Left",   awful.tag.viewprev,         "前のタグ",         "タグ"),
    key(SUPER, "Right",  awful.tag.viewnext,         "次のタグ",         "タグ"),
    key(SUPER, "Escape", awful.tag.history.restore,  "直前のタグに戻る", "タグ"),

    -- ウィンドウ
    key(SUPER, "h",     focus_dir("left"),                           "左のウィンドウへ",        "ウィンドウ"),
    key(SUPER, "j",     focus_dir("down"),                           "下のウィンドウへ",        "ウィンドウ"),
    key(SUPER, "k",     focus_dir("up"),                             "上のウィンドウへ",        "ウィンドウ"),
    key(SUPER, "l",     focus_dir("right"),                          "右のウィンドウへ",        "ウィンドウ"),
    key(SHIFT, "h",     move_dir("left"),                            "左と入れ替え / 左へ移動",  "ウィンドウ"),
    key(SHIFT, "j",     move_dir("down"),                            "下と入れ替え / 下へ移動",  "ウィンドウ"),
    key(SHIFT, "k",     move_dir("up"),                              "上と入れ替え / 上へ移動",  "ウィンドウ"),
    key(SHIFT, "l",     move_dir("right"),                           "右と入れ替え / 右へ移動",  "ウィンドウ"),
    key(CTRL,  "h",     resize(-1, 0),                               "幅を狭く",                "ウィンドウ"),
    key(CTRL,  "l",     resize( 1, 0),                               "幅を広く",                "ウィンドウ"),
    key(CTRL,  "j",     resize(0,  1),                               "高さを大きく",            "ウィンドウ"),
    key(CTRL,  "k",     resize(0, -1),                               "高さを小さく",            "ウィンドウ"),
    key(ALT,   "Right", focus_dir("right"),                          "右のウィンドウへ",        "ウィンドウ"),
    key(ALT,   "Left",  focus_dir("left"),                           "左のウィンドウへ",        "ウィンドウ"),
    key(ALT,   "Down",  focus_dir("down"),                           "下のウィンドウへ",        "ウィンドウ"),
    key(ALT,   "Up",    focus_dir("up"),                             "上のウィンドウへ",        "ウィンドウ"),
    key(SUPER, "u",     awful.client.urgent.jumpto,                  "通知のあるウィンドウへ",  "ウィンドウ"),
    key(SUPER, "Tab", function()
        awful.client.focus.history.previous()
        raise_focused()
    end, "直前のウィンドウに戻る", "ウィンドウ"),
    key(CTRL, "n", function()
        local c = awful.client.restore()
        if c then c:emit_signal("request::activate", "key.unminimize", { raise = true }) end
    end, "最小化を元に戻す", "ウィンドウ"),

    -- 画面
    key(SUPER, "period", function() awful.screen.focus_relative( 1) end, "次の画面へ", "画面"),
    key(SUPER, "comma",  function() awful.screen.focus_relative(-1) end, "前の画面へ", "画面"),

    -- レイアウト
    key(SUPER, "space", function() awful.layout.inc( 1) end,                "次のレイアウト",       "レイアウト"),
    key(SHIFT, "space", function() awful.layout.inc(-1) end,                "前のレイアウト",       "レイアウト"),
    key(ALT,   "l",     function() awful.tag.incnmaster( 1, nil, true) end, "メインの数を増やす",   "レイアウト"),
    key(ALT,   "h",     function() awful.tag.incnmaster(-1, nil, true) end, "メインの数を減らす",   "レイアウト"),
    key(ALT,   "j",     function() awful.tag.incncol( 1, nil, true) end,    "列を増やす",           "レイアウト"),
    key(ALT,   "k",     function() awful.tag.incncol(-1, nil, true) end,    "列を減らす",           "レイアウト"),

    -- 音量・再生・明るさ (キーボードの専用キー)
    key({ }, "XF86AudioRaiseVolume",  function() volume.up() end,       "音量を上げる",   "音量・明るさ"),
    key({ }, "XF86AudioLowerVolume",  function() volume.down() end,     "音量を下げる",   "音量・明るさ"),
    key({ }, "XF86AudioMute",         function() volume.mute() end,     "ミュート",       "音量・明るさ"),
    key({ }, "XF86MonBrightnessUp",   function() brightness.up() end,   "明るくする",     "音量・明るさ"),
    key({ }, "XF86MonBrightnessDown", function() brightness.down() end, "暗くする",       "音量・明るさ"),
    key({ }, "XF86AudioPlay",         mpd.toggle,                       "再生 / 一時停止", "音量・明るさ"),
    key({ }, "XF86AudioPause",        mpd.toggle,                       "再生 / 一時停止", "音量・明るさ"),
    key({ }, "XF86AudioNext",         mpd.next,                         "次の曲",         "音量・明るさ"),
    key({ }, "XF86AudioPrev",         mpd.prev,                         "前の曲",         "音量・明るさ"),
    key(SHIFT, "n", function() nightlight.toggle(true) end, "ブルーライトカットの切り替え", "音量・明るさ")
)

-- Super+数字 (キーボード配列に関係なく、数字キーの位置で決める)
for i = 1, 9 do
    local code = "#" .. i + 9
    local function tag_of_screen(s) return s and s.tags[i] end
    globalkeys = gears.table.join(globalkeys,
        key(SUPER, code, function()
            local t = tag_of_screen(awful.screen.focused())
            if t then t:view_only() end
        end, "タグ " .. i .. " を表示", "タグ"),
        key(CTRL, code, function()
            local t = tag_of_screen(awful.screen.focused())
            if t then awful.tag.viewtoggle(t) end
        end, "タグ " .. i .. " も一緒に表示", "タグ"),
        key(SHIFT, code, function()
            local t = client.focus and tag_of_screen(client.focus.screen)
            if t then client.focus:move_to_tag(t) end
        end, "ウィンドウをタグ " .. i .. " へ送る", "タグ"),
        key({ modkey, "Control", "Shift" }, code, function()
            local t = client.focus and tag_of_screen(client.focus.screen)
            if t then client.focus:toggle_tag(t) end
        end, "ウィンドウをタグ " .. i .. " にも表示", "タグ")
    )
end

root.keys(globalkeys)

-- Super+s の一覧での見出しの色
for group, color in pairs {
    ["Awesome"]      = theme.C.sky,
    ["起動"]         = theme.C.green,
    ["タグ"]         = theme.C.yellow,
    ["ウィンドウ"]   = theme.C.peach,
    ["画面"]         = theme.C.teal,
    ["レイアウト"]   = theme.C.mauve,
    ["音量・明るさ"] = theme.C.urgent,
    ["スクリーンショット"] = theme.C.sky,
} do
    hotkeys_popup.widget.add_group_rules(group, { color = color })
end

---------------------------------------------------------------- ウィンドウごとのキー
keys.client = gears.table.join(
    key(SUPER, "f", function(c) c.fullscreen = not c.fullscreen; c:raise() end,                 "全画面の切り替え",       "ウィンドウ"),
    key(SUPER, "m", function(c) c.maximized = not c.maximized; c:raise() end,                   "最大化の切り替え",       "ウィンドウ"),
    key(CTRL,  "m", function(c) c.maximized_vertical = not c.maximized_vertical; c:raise() end,     "縦だけ最大化",       "ウィンドウ"),
    key(SHIFT, "m", function(c) c.maximized_horizontal = not c.maximized_horizontal; c:raise() end, "横だけ最大化",       "ウィンドウ"),
    key(SUPER, "n", function(c) c.minimized = true end,                                          "最小化",                 "ウィンドウ"),
    key(SUPER, "q", function(c) c:kill() end,                                                    "閉じる (:q)",            "ウィンドウ"),
    key(SHIFT, "c", function(c) c:kill() end,                                                    "閉じる",                 "ウィンドウ"),
    key(CTRL,  "space", awful.client.floating.toggle,                                            "フローティングの切り替え", "ウィンドウ"),
    key(CTRL,  "Return", function(c) c:swap(awful.client.getmaster()) end,                       "メインと入れ替え",       "ウィンドウ"),
    key(SUPER, "o", function(c) c:move_to_screen() end,                                          "別の画面へ移動",         "ウィンドウ"),
    key(SUPER, "t", function(c) c.ontop = not c.ontop end,                                       "常に手前に表示",         "ウィンドウ"),
    key(SHIFT, "t", function(c) awful.titlebar.toggle(c) end,                                    "タイトルバーの表示",     "ウィンドウ")
)

---------------------------------------------------------------- マウス
local function activate(c) c:emit_signal("request::activate", "mouse_click", { raise = true }) end

-- ウィンドウ上: Super+左ドラッグで移動、Super+右ドラッグでサイズ変更
keys.client_buttons = gears.table.join(
    awful.button({ }, 1, activate),
    awful.button(SUPER, 1, function(c) activate(c); awful.mouse.client.move(c) end),
    awful.button(SUPER, 3, function(c) activate(c); awful.mouse.client.resize(c) end)
)

-- デスクトップ: 左クリックでメニューを閉じる、右クリックでメニュー、ホイールでタグ切り替え
root.buttons(gears.table.join(
    awful.button({ }, 1, function() menu.whisker.hide() end),
    awful.button({ }, 3, menu.toggle_main),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))

return keys
