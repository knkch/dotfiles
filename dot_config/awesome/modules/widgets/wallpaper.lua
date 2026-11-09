-- 壁紙 (feh だけで管理する)
--   バー左側のボタン
--     左クリック: 壁紙フォルダの一覧を開く。画像をクリックするとその壁紙になる
--     右クリック: 壁紙フォルダを選ぶ (feh にはフォルダを選ぶ画面が無いので、Awesome のメニューで選ぶ)
--     中クリック: フォルダからランダムに 1 枚選ぶ
--   feh --bg-fill で貼ると ~/.fehbg に記録されるので、次に起動したときも同じ壁紙に戻る
local awful   = require("awful")
local gears   = require("gears")
local wibox   = require("wibox")
local naughty = require("naughty")
local theme   = require("modules.theme")
local C = theme.C

local HOME           = os.getenv("HOME")
local DEFAULT_FOLDER = "/usr/share/backgrounds/arch-wallpapers"
local DEFAULT        = DEFAULT_FOLDER .. "/keep-it-simple-stupid.png" -- ~/.fehbg が無いときの壁紙
local FOLDER_FILE    = gears.filesystem.get_configuration_dir() .. "wallpaper-folder" -- 選んだフォルダを覚えておくファイル

-- 一覧の画面はタイトルを変えられないので、ウィンドウの種類名 (class) で見分ける
local CLASS = "feh-wallpaper"

local wallpaper = { class = CLASS }

-- 今の壁紙フォルダ (選んだことが無ければ既定のフォルダ)
function wallpaper.folder()
    local f = io.open(FOLDER_FILE)
    local dir = f and f:read("*l")
    if f then f:close() end
    if dir and gears.filesystem.dir_readable(dir) then return dir end
    return DEFAULT_FOLDER
end

-- 一覧を開く (%F は feh がクリックした画像のパスに置き換える)
function wallpaper.open()
    awful.spawn {
        "feh", "--thumbnails", "--cache-thumbnails", "--class", CLASS, -- 2 回目からは縮小画像を使い回して速く開く
        "--thumb-width", "224", "--thumb-height", "140", "--limit-width", "1400",
        "--index-info", "", "--image-bg", C.base,
        "--action", "feh --bg-fill %F", wallpaper.folder(),
    }
end

-- ランダムに 1 枚
function wallpaper.random()
    awful.spawn { "feh", "--bg-fill", "--randomize", wallpaper.folder() }
end

-- 記録してある壁紙を貼り直す (起動時・画面サイズが変わったとき)
function wallpaper.restore()
    awful.spawn.with_shell("[ -x ~/.fehbg ] && ~/.fehbg || feh --bg-fill '" .. DEFAULT .. "'")
end

-- フォルダを覚えて、すぐ一覧を開く
local function use_folder(dir)
    local f = io.open(FOLDER_FILE, "w")
    if f then f:write(dir, "\n") f:close() end
    wallpaper.open()
end

-- 一覧に無いフォルダを選ぶ (zenity のフォルダ選択ダイアログ)
local function pick_other()
    awful.spawn.easy_async({ "sh", "-c",
        "command -v zenity >/dev/null || exit 127; " ..
        "zenity --file-selection --directory --title='壁紙フォルダを選ぶ' --filename=\"$1/\"", "sh", wallpaper.folder() },
        function(out, _, _, code)
            local dir = out:gsub("%s+$", "")
            if code == 127 then
                naughty.notification { title   = "壁紙フォルダ",
                                       message = "フォルダ選択には zenity が必要です\nsudo pacman -S zenity" }
            elseif code == 0 and dir ~= "" then
                use_folder(dir)
            end
        end)
end

-- フォルダのメニュー: ~/Pictures の中と /usr/share/backgrounds の中のフォルダ
local folder_menu
function wallpaper.choose_folder()
    if folder_menu then folder_menu:hide() end
    local cmd = { "sh", "-c",
        "find \"$HOME/Pictures\" -maxdepth 2 -type d 2>/dev/null; " ..
        "find /usr/share/backgrounds -mindepth 1 -maxdepth 2 -type d 2>/dev/null" }
    awful.spawn.easy_async(cmd, function(out)
        local current = wallpaper.folder()
        local items = {}
        for dir in out:gmatch("[^\n]+") do
            local label = dir:gsub("^" .. HOME:gsub("%p", "%%%0"), "~")
            table.insert(items, { label .. (dir == current and "   (使用中)" or ""), function() use_folder(dir) end })
        end
        table.insert(items, { "別のフォルダを選ぶ…", pick_other })
        folder_menu = awful.menu { items = items, theme = { width = 640 } }
        folder_menu:show()
    end)
end

local icon = wibox.widget {
    markup = theme.span(C.sky, "󰸉", 18),
    align  = "center",
    widget = wibox.widget.textbox,
}
local button = wibox.widget {
    { icon, left = 8, right = 8, widget = wibox.container.margin },
    bg     = C.surface .. "99",
    shape  = theme.rounded(10),
    widget = wibox.container.background,
}

theme.hover(button, C.overlay .. "cc", C.surface .. "99")
button:buttons(gears.table.join(
    awful.button({ }, 1, wallpaper.open),
    awful.button({ }, 2, wallpaper.random),
    awful.button({ }, 3, wallpaper.choose_folder)
))
awful.tooltip { objects = { button }, text = "左クリック: 壁紙を選ぶ / 右クリック: フォルダを選ぶ / 中クリック: ランダム" }

wallpaper.widget = button
return wallpaper
