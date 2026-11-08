-- 言語ごとの追加プラグイン: Ansible / Python / Rust / Emmet / デバッガ
local mason_bin = vim.fn.stdpath("data") .. "/mason/packages"

return {
  ---------------------------------------------------------------- Ansible
  -- playbooks/ roles/ などの中の YAML を Ansible として扱う (ft = yaml.ansible)
  {
    "mfussenegger/nvim-ansible",
    ft = { "yaml" },
    keys = {
      { "<leader>ar", function() require("ansible").run() end, desc = "この playbook を実行", ft = "yaml.ansible" },
    },
  },

  ---------------------------------------------------------------- Python
  -- 仮想環境 (venv / poetry / uv など) を選んで pyright やデバッガに使わせる
  {
    "linux-cultist/venv-selector.nvim",
    ft = "python",
    cmd = "VenvSelect",
    opts = { options = { notify_user_on_venv_activation = true } },
    keys = { { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Python の仮想環境を選ぶ", ft = "python" } },
  },

  ---------------------------------------------------------------- Rust
  -- rust-analyzer の設定とデバッグ・テスト実行をまとめたもの (rustup の rust-analyzer を使う)
  {
    "mrcjkb/rustaceanvim",
    lazy = false, -- 自分で ft を見て読み込まれる
    init = function()
      vim.g.rustaceanvim = {
        server = {
          on_attach = function(_, buf)
            local map = function(keys, cmd, desc)
              vim.keymap.set("n", keys, cmd, { buffer = buf, desc = desc })
            end
            map("<leader>cR", function() vim.cmd.RustLsp("runnables") end, "実行 (Rust)")
            map("<leader>cT", function() vim.cmd.RustLsp("testables") end, "テスト (Rust)")
            map("<leader>dr", function() vim.cmd.RustLsp("debuggables") end, "デバッグ実行 (Rust)")
            map("<leader>ce", function() vim.cmd.RustLsp("explainError") end, "エラーの説明 (Rust)")
          end,
          default_settings = {
            ["rust-analyzer"] = {
              cargo = { allFeatures = true },
              check = { command = "clippy" },
            },
          },
        },
      }
    end,
  },

  -- Cargo.toml でクレートのバージョン補完・更新チェック
  {
    "saecki/crates.nvim",
    event = "BufRead Cargo.toml",
    opts = {
      lsp = { enabled = true, actions = true, completion = true, hover = true },
      completion = { crates = { enabled = true } },
    },
  },

  ---------------------------------------------------------------- Emmet
  -- 補完は emmet-language-server (lsp.lua)。こちらは選んだ範囲を Emmet の書き方で囲む
  -- 例: 数行を選んで <leader>cw → ul>li* と打つと各行が <li> になり <ul> で囲まれる
  {
    "olrtg/nvim-emmet",
    keys = {
      { "<leader>cw", function() require("nvim-emmet").wrap_with_abbreviation() end, mode = { "n", "x" }, desc = "Emmet で囲む" },
    },
  },

  ---------------------------------------------------------------- デバッガ
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
      { "theHamsta/nvim-dap-virtual-text", opts = {} }, -- 変数の値を行末に表示
      { "leoluz/nvim-dap-go", opts = {} },              -- Go (delve)
      {
        "mfussenegger/nvim-dap-python",                 -- Python (debugpy)
        config = function()
          require("dap-python").setup(mason_bin .. "/debugpy/venv/bin/python")
        end,
      },
    },
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "デバッグ: 開始 / 続行" },
      { "<F10>", function() require("dap").step_over() end, desc = "デバッグ: 次の行へ" },
      { "<F11>", function() require("dap").step_into() end, desc = "デバッグ: 関数の中へ" },
      { "<S-F11>", function() require("dap").step_out() end, desc = "デバッグ: 関数から出る" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "ブレークポイント" },
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("条件: ")) end, desc = "条件付きブレークポイント" },
      { "<leader>dc", function() require("dap").continue() end, desc = "開始 / 続行" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "終了" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "デバッグ画面 オン/オフ" },
      { "<leader>de", function() require("dapui").eval() end, mode = { "n", "x" }, desc = "式の値を見る" },
    },
    config = function()
      local dap, dapui = require("dap"), require("dapui")

      -- デバッグを始めたら画面を開き、終わったら閉じる
      dap.listeners.after.event_initialized.dapui = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui = function() dapui.close() end
      dap.listeners.before.event_exited.dapui = function() dapui.close() end

      -- C: codelldb で、ビルドした実行ファイルを指定して起動
      dap.adapters.codelldb = {
        type = "executable",
        command = mason_bin .. "/codelldb/extension/adapter/codelldb",
      }
      dap.configurations.c = {
        {
          name = "実行ファイルを起動 (codelldb)",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("実行ファイル: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
      }
      dap.configurations.cpp = dap.configurations.c

      vim.fn.sign_define("DapBreakpoint", { text = "\u{f111}", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapStopped", { text = "\u{f061}", texthl = "DiagnosticWarn", linehl = "Visual" })
    end,
  },
}
