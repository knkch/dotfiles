-- 新しいウィンドウに当てるルール
local awful     = require("awful")
local beautiful = require("beautiful")

return function(keys)
    awful.rules.rules = {
        -- すべてのウィンドウ
        { rule = { },
          properties = {
              border_width = beautiful.border_width,
              border_color = beautiful.border_normal,
              focus        = awful.client.focus.filter,
              raise        = true,
              keys         = keys.client,
              buttons      = keys.client_buttons,
              screen       = awful.screen.preferred,
              placement    = awful.placement.no_overlap + awful.placement.no_offscreen,
          } },

        -- 常にフローティングにするウィンドウ
        { rule_any = {
              instance = { "pinentry" },
              class    = { "Blueman-manager", "Pavucontrol", "Nm-connection-editor" },
              role     = { "pop-up" }, -- Chrome の切り離した開発者ツールなど
          },
          properties = { floating = true } },

        -- flameshot の撮影画面: 画面全体を枠なしで覆う (配置ルールでずらさない)
        { rule = { class = "flameshot", name = "flameshot" },
          properties = { floating = true, ontop = true, border_width = 0,
                         titlebars_enabled = false, placement = awful.placement.no_offscreen } },
        -- flameshot の設定画面など
        { rule = { class = "flameshot" }, except = { name = "flameshot" },
          properties = { floating = true, placement = awful.placement.centered } },

        -- 壁紙ボタンで開く feh の一覧
        { rule = { class = "feh%-wallpaper" },
          properties = { floating = true, ontop = true, placement = awful.placement.centered } },

        -- 小さな画面は中央に浮かせる (パスワード入力・クリップボード履歴)
        { rule_any = { class = { "Polkit-gnome-authentication-agent-1", "Gcr-prompter" },
                       instance = { "copyq" } },
          properties = { floating = true, ontop = true, placement = awful.placement.centered } },

        -- タイトルバーは作っておき、signals.lua で隠す (Super+Shift+t で出し入れ)
        { rule_any = { type = { "normal", "dialog" } },
          properties = { titlebars_enabled = true } },
    }
end
