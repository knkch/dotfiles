-- 音量・明るさ共通: 「アイコン + スライダー + %表示」のポップアップ
-- クリックで開いたときは開いたまま、キーやホイールで開いたときは 2 秒で自動で閉じる
--
-- args:
--   icon       ポップアップ左端のウィジェット
--   minimum    スライダーの最小値 (既定 0)
--   get_cmd    今の値を読むコマンド
--   set_cmd    function(v) スライダーで v% にするコマンド
--   parse      function(out) コマンドの出力から % を読む
--   on_output  function(out) 出力を受け取ったとき (省略可)
--   on_slide   function(v)   スライダーを動かしたとき (省略可)
--   extra      スライダーの下に足すウィジェット (省略可)
--   on_show    function()    ポップアップを出すとき (省略可。extra の表示を更新するなど)
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local theme = require("modules.theme")
local C = theme.C

-- 同じ場所に出るので、どれか 1 つを開いたらほかは閉じる
local instances = {}

return function(args)
    local slider = theme.slider { minimum = args.minimum or 0 }
    local text   = wibox.widget { align = "right", forced_width = 52, widget = wibox.widget.textbox }
    local function set_text(v) text.markup = theme.span(C.text, v .. "%", 12, true) end
    set_text(0)

    local row = {
        theme.vcenter(args.icon),
        slider,
        theme.vcenter(text),
        spacing = 12,
        layout  = wibox.layout.fixed.horizontal,
    }
    local popup = theme.popup(args.extra
        and { row, args.extra, spacing = 10, layout = wibox.layout.fixed.vertical }
        or row)
    table.insert(instances, popup)

    local syncing = false -- 読み取った値を反映している間は、スライダーから値を書き換えない
    local hide_timer = gears.timer {
        timeout     = 2,
        single_shot = true,
        callback    = function() popup.visible = false end,
    }

    local self = { popup = popup }

    local function refresh(out)
        local v = args.parse(out)
        if v then
            syncing = true
            slider.value = v
            set_text(v)
            syncing = false
        end
        if args.on_output then args.on_output(out) end
    end

    local function show(autohide, geo)
        if args.on_show and not popup.visible then args.on_show() end
        if geo then
            popup:move_next_to(geo)
        elseif not popup.visible then
            -- キーで開いたときはマウス位置がないので、画面右上 (バーの下) に出す
            awful.placement.top_right(popup, { margins = { top = 6, right = 8 },
                honor_workarea = true, parent = awful.screen.focused() })
        end
        popup.visible = true
        if autohide then hide_timer:again() else hide_timer:stop() end
    end

    -- コマンドを実行して、結果をポップアップに反映して表示する
    -- after: 反映したあとに呼ぶ関数 (省略可)
    function self.run(cmd, autohide, geo, after)
        awful.spawn.easy_async(cmd, function(out)
            refresh(out)
            if after then after() end
            show(autohide, geo)
        end)
    end

    function self.toggle()
        if popup.visible then
            popup.visible = false
            hide_timer:stop()
        else
            self.run(args.get_cmd, false, theme.under_mouse())
        end
    end

    slider:connect_signal("property::value", function()
        local v = math.floor(slider.value)
        set_text(v)
        if not syncing then
            awful.spawn(args.set_cmd(v), false)
            if args.on_slide then args.on_slide(v) end
        end
    end)

    -- マウスが乗っている間は閉じない。離れたら閉じる
    popup:connect_signal("mouse::enter", function() hide_timer:stop() end)
    popup:connect_signal("mouse::leave", function() popup.visible = false end)
    popup:connect_signal("property::visible", function()
        if not popup.visible then return end
        for _, other in ipairs(instances) do
            if other ~= popup then other.visible = false end
        end
    end)

    return self
end
