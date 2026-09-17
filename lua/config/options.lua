-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.clipboard = "" -- 關閉系統剪貼簿自動同步：y 只進內部暫存器，要進系統剪貼簿一律用 "+y / "+p（覆寫 LazyVim 預設的 unnamedplus）
vim.opt.foldenable = false
vim.opt.foldmethod = "manual"
vim.opt.fixendofline = false
vim.opt.wrap = true

-- diff 忽略空白變更（= git diff -b）。純縮排調整、tab↔空白、行尾空白不會被當成差異，
-- 需要時用 <leader>uW 切回來。
--
-- 刻意用 iwhite 而不是 iwhiteall：實測 iwhiteall 會讓 Neovim 把「行尾多出一段」這種改動
-- 從 changed line 降級成整行 DiffAdd，連帶整個行內比對都不跑，DiffText / DiffTextAdd
-- 完全不會出現（iwhite / iwhiteeol / icase 都沒這問題）。也就是 TortoiseGitMerge 那種
-- 「只把真正改掉的那一段上色」的效果，加了 iwhiteall 就沒了。
-- 換成 iwhite 的代價只有一項：原本存在的空白被整個刪光（如 `a = b` → `a=b`）會算成差異。
--
-- 生效範圍：diffview（走 Vim 原生 diff mode、自己不碰 diffopt）、:diffthis、以及 gitsigns——
-- gitsigns 的 diff_opts 預設就是從 diffopt 推導（gitsigns/config.lua:146-153 的 optmap，
-- iwhite → ignore_whitespace_change），所以左側 hunk 標記也會一起忽略。
-- 不生效：Neogit status buffer 的 inline diff，它自己跑 git diff、不吃 diffopt
-- （neogit/config.lua:406 的 word_diff_highlight 預設已開，是另一套獨立機制）。
vim.opt.diffopt:append("iwhite")

-- 行內差異逐「詞」比對，= TortoiseGitMerge 的「Inline diff word-wise」。
-- 逐字元（Neovim 內建預設的 inline:char）在 IDNAME → IDNAM 這種情況只會標最後那個 E，
-- 逐詞則整個識別字一起標，讀程式碼時好抓很多。中文字與 emoji 各自算一個詞，
-- 所以 SQL 裡的中文註解粒度不會變粗。想換回逐字元把下面兩個 word 改成 char 即可。
-- 註：inline: 雖然是單值旗標，但 :append 不會取代舊值，會留下
-- "inline:char,...,inline:word" 這種髒字串（實測最後一個生效，但 tbl_contains 之類的
-- 判斷會被誤導），所以要先 remove 掉內建的 inline:char。
vim.opt.diffopt:remove("inline:char")
vim.opt.diffopt:append("inline:word")

-- Disable autoformat globally
vim.g.autoformat = false

-- Force tree-sitter to use gcc
vim.env.CC = "gcc"
-- Add MinGW bin to PATH so compiled parsers can find runtime DLLs
vim.env.PATH = vim.env.PATH .. ";C:\\ProgramData\\chocolatey\\lib\\mingw\\tools\\install\\mingw64\\bin"
