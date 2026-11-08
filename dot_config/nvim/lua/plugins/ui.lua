-- 見た目: 配色・ステータスライン・タブ・アイコン
return {
  -- 配色: Ghostty や tmux と同じ Catppuccin Mocha。背景は透過して Ghostty のすりガラスを活かす
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      float = { transparent = true, solid = false },
      integrations = {
        blink_cmp = true,
        flash = true,
        gitsigns = true,
        mason = true,
        mini = { enabled = true },
        snacks = { enabled = true },
        which_key = true,
        render_markdown = true,
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- アイコン (ほかのプラグインが使う)
  {
    "echasnovski/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      -- nvim-web-devicons を使うプラグインにも mini.icons のアイコンを渡す
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- 下のステータスライン
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = {
      options = {
        theme = "catppuccin",
        globalstatus = true,
        component_separators = "",
        section_separators = { left = "\u{e0b4}", right = "\u{e0b6}" },
        disabled_filetypes = { statusline = { "snacks_dashboard" } },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff" },
        lualine_c = { { "filename", path = 1 }, "diagnostics" },
        lualine_x = { "lsp_status", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },

  -- 上のバッファ (開いているファイル) 一覧
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<cmd>BufferLineTogglePin<cr>", desc = "ピン留め" },
      { "<leader>bo", "<cmd>BufferLineCloseOthers<cr>", desc = "ほかのバッファを閉じる" },
    },
    opts = {
      options = {
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        close_command = function(n) Snacks.bufdelete(n) end,
        offsets = { { filetype = "snacks_layout_box", text = "ファイル", highlight = "Directory" } },
      },
    },
    config = function(_, opts)
      -- catppuccin の配色に合わせる (バージョンで関数名が違うので両方試す)
      local ok, bl = pcall(require, "catppuccin.groups.integrations.bufferline")
      if ok then
        local get = bl.get_theme or bl.get
        if get then opts.highlights = get() end
      end
      require("bufferline").setup(opts)
    end,
  },

  -- スペースを押すと、続けて押せるキーの一覧を出す
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      spec = {
        { "<leader>a", group = "Ansible" },
        { "<leader>b", group = "バッファ" },
        { "<leader>d", group = "デバッグ" },
        { "<leader>c", group = "コード" },
        { "<leader>f", group = "ファイル / 検索" },
        { "<leader>g", group = "Git" },
        { "<leader>m", group = "Markdown" },
        { "<leader>q", group = "終了" },
        { "<leader>s", group = "検索" },
        { "<leader>u", group = "表示の切り替え" },
        { "<leader>x", group = "診断 / 一覧" },
      },
    },
  },
}
