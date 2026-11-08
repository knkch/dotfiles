-- プラグインに関係ない基本のキー操作
-- (どのキーが何かは スペース を押して少し待つと which-key が一覧を出す)
local map = vim.keymap.set

-- Esc で検索のハイライトを消す
map("n", "<Esc>", "<cmd>nohlsearch<cr>")

-- 保存 / 閉じる
map({ "n", "i", "x" }, "<C-s>", "<cmd>write<cr><esc>", { desc = "保存" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "全部閉じて終了" })

-- Ctrl+h/j/k/l でウィンドウを移動
map("n", "<C-h>", "<C-w>h", { desc = "左のウィンドウへ" })
map("n", "<C-j>", "<C-w>j", { desc = "下のウィンドウへ" })
map("n", "<C-k>", "<C-w>k", { desc = "上のウィンドウへ" })
map("n", "<C-l>", "<C-w>l", { desc = "右のウィンドウへ" })

-- 画面分割
map("n", "<leader>|", "<C-w>v", { desc = "右に分割" })
map("n", "<leader>-", "<C-w>s", { desc = "下に分割" })

-- Shift+h/l でバッファ (開いているファイル) を切り替え
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "前のバッファ" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "次のバッファ" })

-- 選択中の行を Alt+j/k で上下に動かす
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "行を下へ" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "行を上へ" })
map("x", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "選択を下へ", silent = true })
map("x", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "選択を上へ", silent = true })

-- インデントを変えても選択を解除しない
map("x", "<", "<gv")
map("x", ">", ">gv")

-- 診断 (エラー・警告) の詳細を浮かぶウィンドウで見る
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "この行の診断を表示" })
