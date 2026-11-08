-- Neovim の設定の入口
-- lua/config/ に基本設定、lua/plugins/ にプラグインごとの設定がある
-- プラグインの管理画面は :Lazy、LSP やフォーマッタの管理画面は :Mason

-- リーダーキーはスペース (プラグインより先に決める)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
