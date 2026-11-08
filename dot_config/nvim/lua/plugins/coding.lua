-- 書くのを助けるもの: 構文ハイライト・補完・整形・括弧・移動
return {
  -- Treesitter: 正確な構文ハイライトとインデント (パーサーの作成に tree-sitter-cli が要る)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "bash", "c", "cpp", "cmake", "css", "diff", "dockerfile", "html", "javascript",
        "json", "jinja", "jinja_inline", "lua", "luadoc", "make", "markdown", "markdown_inline",
        "query", "regex", "sql", "toml", "tsx", "typescript", "vim", "vimdoc", "yaml",
        "go", "gomod", "gosum", "gowork",                   -- Go
        "python", "requirements",                           -- Python
        "rust", "ron",                                      -- Rust
        "git_config", "gitcommit", "git_rebase", "gitignore", "gitattributes", -- Git
      })
      -- Ansible のファイル (yaml.ansible) も YAML のパーサーで色付け
      vim.treesitter.language.register("yaml", "yaml.ansible")
      -- パーサーがあるファイルでは Treesitter のハイライトとインデントを使う
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("my_treesitter", { clear = true }),
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },

  -- 補完 (Tab / Shift+Tab で選ぶ、Enter で決定)
  {
    "saghen/blink.cmp",
    version = "1.*",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "rafamadriz/friendly-snippets" },
    opts = {
      keymap = { preset = "super-tab", ["<CR>"] = { "accept", "fallback" } },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = true, auto_show_delay_ms = 300 },
        menu = { border = "rounded" },
        ghost_text = { enabled = true },
      },
      signature = { enabled = true, window = { border = "rounded" } },
      sources = {
        default = { "lazydev", "lsp", "path", "snippets", "buffer" },
        providers = {
          lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
        },
      },
      cmdline = { completion = { menu = { auto_show = true } } },
    },
  },

  -- 保存するたびに自動で整形 (フォーマッタは Mason で入れる)
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, desc = "整形" },
      {
        "<leader>uf",
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify("保存時の自動整形: " .. (vim.g.disable_autoformat and "オフ" or "オン"))
        end,
        desc = "保存時の自動整形 オン/オフ",
      },
    },
    opts = function()
      local by_ft = {
        lua = { "stylua" },
        python = { "ruff_format", "ruff_organize_imports" },
        go = { "goimports", "gofumpt" },
        rust = { "rustfmt" },  -- rustup の rustfmt
      }
      local shared = {
        ["clang-format"] = { "c", "cpp" },
        shfmt = { "sh", "bash", "zsh" },
        prettier = { "javascript", "typescript", "json", "yaml", "markdown", "html", "css" },
      }
      for formatter, fts in pairs(shared) do
        for _, ft in ipairs(fts) do by_ft[ft] = { formatter } end
      end
      return {
        formatters_by_ft = by_ft,
        format_on_save = function()
          if vim.g.disable_autoformat then return end
          return { timeout_ms = 1000, lsp_format = "fallback" }
        end,
      }
    end,
  },

  -- 括弧や引用符を自動で閉じる
  { "echasnovski/mini.pairs", event = "InsertEnter", opts = {} },

  -- 囲むものを足す・消す・変える (例: saiw" で単語を "" で囲む、sd" で外す、sr"' で置き換え)
  { "echasnovski/mini.surround", event = "VeryLazy", opts = {} },

  -- 「中身」の選択を増やす (例: vi( で括弧の中、daf で関数ごと削除)
  { "echasnovski/mini.ai", event = "VeryLazy", opts = {} },

  -- s を押して表示される文字を打つと、画面のどこへでも飛べる
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "どこへでも移動" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "構文の塊を選択" },
    },
  },

  -- TODO: FIXME: などのコメントを目立たせる
  {
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "TODO の一覧" },
    },
  },

  -- Neovim の設定 (Lua) を書くときの補完
  { "folke/lazydev.nvim", ft = "lua", opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } } } },
}
