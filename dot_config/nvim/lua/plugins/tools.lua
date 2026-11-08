-- Git の差分表示・エラーの一覧
return {
  -- 行の左に Git の変更 (追加・変更・削除) を表示
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        local map = function(keys, fn, desc)
          vim.keymap.set("n", keys, fn, { buffer = buf, desc = desc })
        end
        map("]h", function() gs.nav_hunk("next") end, "次の変更箇所")
        map("[h", function() gs.nav_hunk("prev") end, "前の変更箇所")
        map("<leader>gp", gs.preview_hunk, "変更箇所の差分を見る")
        map("<leader>gr", gs.reset_hunk, "変更箇所を元に戻す")
        map("<leader>gd", gs.diffthis, "ファイルの差分")
      end,
    },
  },

  -- 差分・ファイルの履歴・マージの衝突を並べて見る
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "差分を並べて見る (diffview)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "このファイルの履歴" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "リポジトリの履歴" },
      { "<leader>gq", "<cmd>DiffviewClose<cr>", desc = "diffview を閉じる" },
    },
    opts = {},
  },

  -- エラーや警告をまとめて一覧
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "診断の一覧" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "このファイルの診断" },
      { "<leader>xs", "<cmd>Trouble symbols toggle<cr>", desc = "関数・変数の一覧 (横)" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix" },
    },
  },
}
