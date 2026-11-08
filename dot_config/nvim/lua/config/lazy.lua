-- プラグインマネージャ lazy.nvim を (なければ) 取ってきて起動する
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "lazy.nvim を取得できませんでした:\n" .. out, "ErrorMsg" } }, true, {})
    return
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },  -- lua/plugins/*.lua を全部読む
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = true, notify = false },  -- 更新があれば :Lazy に表示 (通知はしない)
  change_detection = { notify = false },
  rocks = { enabled = false },  -- luarocks は使わない
  ui = { border = "rounded" },
})
