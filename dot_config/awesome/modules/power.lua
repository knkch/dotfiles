-- 電源の操作 (ロック・再起動・電源オフなど)
-- 検索パネルの電源タブ・Whisker メニューの電源ボタン・右クリックメニューで同じものを使う
--   confirm = true のものは、使う側で確認してから power.run を呼ぶ
local awful  = require("awful")
local config = require("modules.config")

local power = {}

power.actions = {
    { name = "ロック",       glyph = "\u{f033e}", cmd = config.lock_cmd },
    { name = "再起動",       glyph = "\u{f0709}", cmd = "systemctl reboot",   confirm = true },
    { name = "電源オフ",     glyph = "\u{f0425}", cmd = "systemctl poweroff", confirm = true },
    { name = "サスペンド",   glyph = "\u{f0904}", cmd = "systemctl suspend" },
    { name = "ハイバネート", glyph = "\u{f0717}", cmd = "systemctl hibernate" },
    { name = "ログアウト",   glyph = "\u{f0343}", run = function() awesome.quit() end, confirm = true },
}

-- 名前で探す (例: power.get("ログアウト"))
function power.get(name)
    for _, p in ipairs(power.actions) do
        if p.name == name then return p end
    end
end

function power.run(p)
    if p.run then p.run() else awful.spawn(p.cmd, false) end
end

return power
