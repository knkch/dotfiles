-- Markdown の表示と、書くための道具
-- キーは <leader>m から: p=ブラウザでプレビュー t=表モード i=画像貼り付け x=チェックボックス (表示の切り替えは <leader>um)

-- Markdown を開いたら長い行は折り返して表示し、単語の途中では切らない
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("my_markdown", { clear = true }),
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.spelllang = { "en", "cjk" } -- :set spell したとき日本語に赤線を引かない
    -- 折り返した行の中でも見た目どおりに上下移動する
    vim.keymap.set({ "n", "x" }, "j", "gj", { buffer = true })
    vim.keymap.set({ "n", "x" }, "k", "gk", { buffer = true })
  end,
})

return {
  -- 見出しや表を見やすい形で表示
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    opts = {},
    keys = {
      { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", desc = "Markdown の表示 オン/オフ", ft = "markdown" },
    },
  },

  -- ブラウザでリアルタイムにプレビュー (スクロールも連動)
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    ft = "markdown",
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_theme = "dark"
      vim.g.mkdp_auto_close = 0 -- 別のバッファに移ってもプレビューを閉じない
    end,
    keys = {
      { "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", desc = "ブラウザでプレビュー オン/オフ", ft = "markdown" },
    },
  },

  -- 箇条書き・番号付きリストを Enter で続ける / Tab で字下げ
  {
    "bullets-vim/bullets.vim",
    ft = { "markdown", "text", "gitcommit" },
    init = function()
      vim.g.bullets_enabled_file_types = { "markdown", "text", "gitcommit" }
      vim.g.bullets_checkbox_markers = " x" -- チェックボックスは [ ] と [x] だけ
    end,
    keys = {
      { "<leader>mx", "<cmd>ToggleCheckbox<cr>", desc = "チェックボックス切り替え", ft = "markdown" },
    },
  },

  -- 表を打つとその場で列がそろう (| で区切って入力、|| で区切り線)
  {
    "dhruvasagar/vim-table-mode",
    cmd = { "TableModeToggle", "TableModeRealign", "Tableize" },
    init = function()
      vim.g.table_mode_corner = "|" -- Markdown 形式の表にする
      vim.g.table_mode_disable_mappings = 1 -- 元のキー (<leader>t…) は使わない
      vim.g.table_mode_disable_tableize_mappings = 1
    end,
    keys = {
      { "<leader>mt", "<cmd>TableModeToggle<cr>", desc = "表モード オン/オフ", ft = "markdown" },
      { "<leader>ma", "<cmd>TableModeRealign<cr>", desc = "表の列をそろえ直す", ft = "markdown" },
      { "<leader>mT", ":Tableize<cr>", mode = "x", desc = "選択した CSV を表にする", ft = "markdown" },
    },
  },

  -- クリップボードの画像 (スクショなど) を assets/ に保存してリンクを入れる
  {
    "HakonHarnes/img-clip.nvim",
    opts = {
      default = { dir_path = "assets", prompt_for_file_name = false },
    },
    keys = {
      { "<leader>mi", "<cmd>PasteImage<cr>", desc = "画像を貼り付け", ft = "markdown" },
    },
  },
}
