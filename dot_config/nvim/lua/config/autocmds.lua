local autocmd = vim.api.nvim_create_autocmd
local group = vim.api.nvim_create_augroup("my_config", { clear = true })

-- コピーした範囲を一瞬光らせる
autocmd("TextYankPost", {
  group = group,
  callback = function() vim.hl.on_yank() end,
})

-- 前回閉じたときの位置から開く
autocmd("BufReadPost", {
  group = group,
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lines = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lines then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- ヘルプや一覧のウィンドウは q で閉じる
autocmd("FileType", {
  group = group,
  pattern = { "help", "qf", "man", "checkhealth", "lspinfo" },
  callback = function(args)
    vim.bo[args.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = args.buf, silent = true })
  end,
})

-- ウィンドウの大きさが変わったら分割を均等にし直す
autocmd("VimResized", {
  group = group,
  command = "tabdo wincmd =",
})

-- 診断の表示 (行末に短く、記号はアイコンで)
vim.diagnostic.config({
  severity_sort = true,
  virtual_text = { spacing = 2, prefix = "●" },
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "\u{f057} ",
      [vim.diagnostic.severity.WARN] = "\u{f071} ",
      [vim.diagnostic.severity.INFO] = "\u{f05a} ",
      [vim.diagnostic.severity.HINT] = "󰌵 ",
    },
  },
})
