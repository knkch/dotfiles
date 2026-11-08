local opt = vim.opt

-- 行番号 (今いる行は実際の番号、ほかは相対)
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"   -- 左の記号欄を常に出して、表示がガタつかないように
opt.scrolloff = 8        -- 上下に 8 行の余裕を残してスクロール
opt.sidescrolloff = 8
opt.wrap = false
opt.termguicolors = true
opt.showmode = false     -- モードはステータスラインに出す
opt.laststatus = 3       -- ステータスラインは画面全体で 1 本
opt.pumheight = 12       -- 補完メニューの最大の高さ
opt.splitright = true
opt.splitbelow = true
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.fillchars = { eob = " " }  -- ファイル末尾の ~ を消す

-- インデント: 既定はスペース 4 つ (ファイルの種類ごとの設定やフォーマッタが優先)
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true

-- 検索: 小文字だけなら大小を区別しない、大文字が入ったら区別する
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"  -- :s の置換結果をその場でプレビュー

-- システムのクリップボードと共有 (y でコピーしたものを他のアプリに貼れる)
opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.undofile = true       -- 閉じても undo の履歴を残す
opt.swapfile = false
opt.updatetime = 250
opt.timeoutlen = 400
opt.confirm = true        -- 保存していないまま閉じるときは確認
opt.virtualedit = "block" -- 矩形選択で行末より先にも動ける
