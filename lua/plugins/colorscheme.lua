-- 摺疊行配色修正。
--
-- tokyonight 的 Folded 預設 bg = fg_gutter（moon: #3b4261），比所有 Diff* 的底色都亮：
--   Normal #222436 < DiffChange #252a3f < DiffAdd #2a4556 < DiffText #394b70 < Folded #3b4261
-- 於是在 diffview 裡「完全沒改、被收起來的那一行」反而比真正的差異更搶眼，很容易誤讀成改動。
-- 改成比 Normal 更暗的 bg_dark（moon: #1e2030），語意才對：凹陷 = 收合。
--
-- 註 1：只調 bg。LazyVim 設了 foldtext = ""（lazyvim/config/options.lua:73），Neovim 0.10+
--       對空字串的處理是把摺疊區第一行原樣渲染並保留 syntax highlight，所以 Folded 的 fg
--       會被語法色蓋掉、調了沒用。
-- 註 2：Folded 是全域的，不只 diffview。但本設定是 foldmethod=manual + foldlevel=99，
--       實務上只有 diff mode 會自動產生摺疊，副作用趨近於零。
-- 註 3：必須走 on_highlights，不能在 options.lua 用 nvim_set_hl —— colorscheme 套用時會蓋掉。
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      on_highlights = function(hl, c)
        hl.Folded = { bg = c.bg_dark }

        -- diff 配色。原值 DiffChange #252a3f 跟 Normal #222436 差不到 10，整行改動幾乎看不見；
        -- 而 tokyonight 根本沒定義 DiffTextAdd，Neovim 預設把它 link 到 DiffText，於是
        -- 「兩邊都有但改掉的字」跟「只有這一邊有的字」同色、分不出來。三個一起拉開。
        --
        -- DiffTextAdd 是 Neovim 0.11 才加的群組（:h diff.txt），意思是「行內這段在另一個
        -- buffer 沒有對應」。用青色系是為了跟行級慣例一致：Vim 對「這邊有、那邊沒有」的整行
        -- 本來就標 DiffAdd（青）、另一側補 DiffDelete 填充（粉），所以左窗格的青 = 被刪掉。
        --
        -- 註：這三個群組要出現，前提是 diffopt 沒有 iwhiteall——它會讓整行降級成 DiffAdd、
        -- 行內比對完全不跑。粒度（逐字/逐詞）與空白忽略都設在 lua/config/options.lua，
        -- 那邊有完整說明，配色這裡不管。
        hl.DiffChange = { bg = "#2b3149" } -- 整行有改動：拉開跟 Normal 的距離，但仍低於行內標示
        hl.DiffText = { bg = "#3d5891" } -- 行內：兩邊都有、內容不同
        hl.DiffTextAdd = { bg = "#2f5f74" } -- 行內：只有這一邊有
      end,
    },
  },
}
