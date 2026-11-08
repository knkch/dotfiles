-- LSP: エラーの表示・定義へ移動・名前の変更など
-- 言語ごとのサーバーやフォーマッタは Mason が自動で入れる (:Mason で追加・削除できる)
-- Rust だけは rustaceanvim (lang.lua) が rustup の rust-analyzer を使う

-- 自動で入れる LSP サーバー
local servers = {
  "lua_ls",               -- Lua
  "pyright",              -- Python (型チェック・補完)
  "ruff",                 -- Python (lint・整形)
  "gopls",                -- Go (go が要る)
  "clangd",               -- C / C++
  "bashls",               -- シェルスクリプト
  "jsonls",               -- JSON
  "yamlls",               -- YAML
  "ansiblels",            -- Ansible
  "marksman",             -- Markdown
  "emmet_language_server", -- Emmet (HTML / CSS / JSX)
}

-- 自動で入れるフォーマッタ・リンタ・デバッガ
local tools = {
  "stylua", "shfmt", "shellcheck", "prettier",  -- Lua / シェル / Web・YAML
  "gofumpt", "goimports", "golangci-lint", "delve", -- Go
  "debugpy",                                    -- Python のデバッガ
  "clang-format", "codelldb",                   -- C の整形 / C・Rust のデバッガ
  "ansible-lint", "yamllint",                   -- Ansible / YAML のチェック
}

return {
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    event = "VeryLazy",
    build = ":MasonUpdate",
    opts = { ui = { border = "rounded" } },
    config = function(_, opts)
      require("mason").setup(opts)
      -- まだ入っていないツールを入れる (go や npm が無いものは失敗するので、入れたあと次の起動で再挑戦)
      local registry = require("mason-registry")
      registry.refresh(function()
        for _, name in ipairs(tools) do
          local ok, pkg = pcall(registry.get_package, name)
          if ok and not pkg:is_installed() and not pkg:is_installing() then pkg:install() end
        end
      end)
    end,
  },

  -- JSON / YAML のスキーマ集 (docker-compose・GitHub Actions・k8s などを補完・チェック)
  { "b0o/SchemaStore.nvim", lazy = true },

  {
    "mason-org/mason-lspconfig.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig", "b0o/SchemaStore.nvim" },
    opts = {
      ensure_installed = servers,
      -- 入っているサーバーは自動で有効に (Rust は rustaceanvim に任せる)
      automatic_enable = { exclude = { "rust_analyzer" } },
    },
    config = function(_, opts)
      local lsp = vim.lsp.config

      lsp("lua_ls", {
        settings = { Lua = { workspace = { checkThirdParty = false }, completion = { callSnippet = "Replace" } } },
      })

      lsp("jsonls", {
        settings = { json = { schemas = require("schemastore").json.schemas(), validate = { enable = true } } },
      })

      lsp("yamlls", {
        settings = {
          yaml = {
            schemaStore = { enable = false, url = "" }, -- SchemaStore.nvim の方を使う
            schemas = require("schemastore").yaml.schemas(),
            keyOrdering = false,
          },
        },
      })

      lsp("gopls", {
        settings = {
          gopls = {
            gofumpt = true,
            usePlaceholders = true,
            staticcheck = true,
            analyses = { unusedparams = true, unusedwrite = true, nilness = true },
            hints = {
              assignVariableTypes = true, compositeLiteralFields = true, constantValues = true,
              functionTypeParameters = true, parameterNames = true, rangeVariableTypes = true,
            },
          },
        },
      })

      lsp("clangd", {
        cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu", "--completion-style=detailed" },
      })

      -- Python: 説明表示は pyright に任せ、ruff は lint と整形だけ
      lsp("ruff", {
        on_attach = function(client) client.server_capabilities.hoverProvider = false end,
      })

      -- Emmet を使うファイルの種類
      lsp("emmet_language_server", {
        filetypes = {
          "html", "css", "scss", "sass", "less", "javascriptreact", "typescriptreact",
          "vue", "svelte", "astro", "php", "templ", "htmldjango", "eruby",
        },
      })

      -- サーバーがつながったファイルでだけ使うキー
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("my_lsp", { clear = true }),
        callback = function(args)
          local map = function(keys, fn, desc, mode)
            vim.keymap.set(mode or "n", keys, fn, { buffer = args.buf, desc = desc })
          end
          map("<leader>ca", vim.lsp.buf.code_action, "修正の候補", { "n", "x" })
          map("<leader>cr", vim.lsp.buf.rename, "名前を変更")
          map("<leader>uh", function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
          end, "型などのヒント オン/オフ")
        end,
      })

      require("mason-lspconfig").setup(opts)
    end,
  },
}
