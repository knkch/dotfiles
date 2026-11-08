-- snacks.nvim: 起動画面・ファイル検索・ファイルツリー・通知・lazygit などをまとめたもの
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  opts = {
    bigfile = { enabled = true },    -- 大きいファイルは重い機能を切って開く
    quickfile = { enabled = true },  -- ファイルを指定して起動したとき速く表示
    dashboard = {
      enabled = true,
      preset = {
        keys = {
          { icon = "\u{f002} ", key = "f", desc = "ファイルを探す", action = ":lua Snacks.picker.files()" },
          { icon = "\u{f15b} ", key = "n", desc = "新しいファイル", action = ":ene | startinsert" },
          { icon = "\u{f0b0} ", key = "g", desc = "中身を検索", action = ":lua Snacks.picker.grep()" },
          { icon = "\u{f1da} ", key = "r", desc = "最近のファイル", action = ":lua Snacks.picker.recent()" },
          { icon = "\u{f013} ", key = "c", desc = "設定を開く", action = ":lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })" },
          { icon = "󰒲 ", key = "l", desc = "プラグイン (Lazy)", action = ":Lazy" },
          { icon = "\u{f011} ", key = "q", desc = "終了", action = ":qa" },
        },
      },
    },
    explorer = { enabled = true },   -- ファイルツリー
    picker = { enabled = true },     -- あいまい検索
    indent = { enabled = true },     -- インデントの縦線
    input = { enabled = true },      -- 入力欄を見やすく
    notifier = { enabled = true },   -- 通知を右上にポップアップ
    statuscolumn = { enabled = true },
    words = { enabled = true },      -- カーソル下の単語と同じものを強調
    lazygit = { enabled = true },
  },
  keys = {
    -- よく使うもの
    { "<leader><space>", function() Snacks.picker.smart() end, desc = "ファイルを探す (賢く)" },
    { "<leader>/", function() Snacks.picker.grep() end, desc = "中身を検索 (grep)" },
    { "<leader>,", function() Snacks.picker.buffers() end, desc = "開いているバッファ" },
    { "<leader>e", function() Snacks.explorer() end, desc = "ファイルツリー" },
    { "<leader>n", function() Snacks.picker.notifications() end, desc = "通知の履歴" },
    -- ファイル
    { "<leader>ff", function() Snacks.picker.files() end, desc = "ファイル" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "最近のファイル" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "設定ファイル" },
    { "<leader>bd", function() Snacks.bufdelete() end, desc = "バッファを閉じる" },
    -- 検索
    { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "カーソル下の単語で検索", mode = { "n", "x" } },
    { "<leader>sh", function() Snacks.picker.help() end, desc = "ヘルプ" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "キー操作の一覧" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "診断" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "関数・変数の一覧" },
    { "<leader>sr", function() Snacks.picker.resume() end, desc = "前回の検索を再開" },
    { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "配色を選ぶ" },
    -- Git
    { "<leader>gg", function() Snacks.lazygit() end, desc = "lazygit" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "コミット履歴" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "変更のあるファイル" },
    { "<leader>gb", function() Snacks.git.blame_line() end, desc = "この行を書いたコミット" },
    -- LSP (定義へ移動など)
    { "gd", function() Snacks.picker.lsp_definitions() end, desc = "定義へ移動" },
    { "gr", function() Snacks.picker.lsp_references() end, nowait = true, desc = "使われている場所" },
    { "gI", function() Snacks.picker.lsp_implementations() end, desc = "実装へ移動" },
    -- その他
    { "<C-/>", function() Snacks.terminal() end, desc = "ターミナル", mode = { "n", "t" } },
    { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "次の同じ単語", mode = { "n", "t" } },
    { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "前の同じ単語", mode = { "n", "t" } },
  },
}
