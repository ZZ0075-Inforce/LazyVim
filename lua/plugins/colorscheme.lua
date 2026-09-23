-- 配色。目前用 rose-pine 主版（main），與 Windows Terminal 同一套色票
-- （my_config/wt/settings.json 的 "Rosé Pine" scheme，base #191724）。
--
-- tokyonight 那組設定整組留在檔案下半部沒刪：它是 LazyVim 預設、也是退路，
-- 要切回去只要改下面 LazyVim 那條的 colorscheme 字串。
return {
  ------------------------------------------------------------------
  -- rose-pine（使用中）
  ------------------------------------------------------------------
  {
    "rose-pine/neovim",
    -- name 必填。repo 叫 rose-pine/neovim，不指定的話 lazy.nvim 會拿 repo 名
    -- 註冊成 "neovim"，:colorscheme rose-pine 找不到。
    name = "rose-pine",
    opts = {
      -- main 的 base 是 #191724，跟終端機底色同一個值；moon 是 #232136。
      variant = "main",
      styles = {
        -- 讓終端機的毛玻璃透上來。終端機的 opacity 只作用在「預設背景色」，
        -- 儲存格一旦被明確指定背景色就是不透明的 —— 即使色碼跟預設底色相同。
        -- 所以要編輯區透明，得讓 colorscheme 根本不畫 Normal 的 bg。
        -- 不想要就改 false，其餘設定不受影響。
        transparency = true,
      },
      highlight_groups = {
        -- transparency 會順手把 Folded 的 bg 也設成 NONE（見 rose-pine.lua 的
        -- transparency_highlights），於是摺疊行跟 Normal 同色、分不出來。
        -- 補回實色 surface（#1f1d2e）。它比所有 Diff* 都暗很多 —— Diff* 是把
        -- git_* 顏色 blend 到 base 上，落在 #43xxxx 一帶 —— 所以不會重演
        -- tokyonight 那個「摺疊行比真正的差異還搶眼」的問題。
        Folded = { bg = "surface" },

        -- DiffTextAdd 是 Neovim 0.11 才加的群組（:h diff.txt），意思是「行內這段
        -- 在另一個 buffer 沒有對應」。rose-pine 沒定義它，Neovim 預設 link 到
        -- DiffText，於是「兩邊都有但改掉的字」跟「只有這一邊有的字」同色。
        --
        -- 寫法對齊 DiffText（git_text = rose，blend 40），顏色取 foam —— 那正是
        -- rose-pine 的 git_add。跟行級慣例一致：Vim 對「這邊有、那邊沒有」的整行
        -- 本來就標 DiffAdd，所以左窗格的那片青 = 被刪掉。
        --
        -- 註：blend 是在 highlight_groups 合併「之後」才算的（rose-pine.lua 最後
        -- 那個迴圈），所以這裡寫色名 + blend 會正確展開，不必自己算 hex。
        DiffTextAdd = { bg = "foam", blend = 40 },
      },
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "rose-pine" } },

  ------------------------------------------------------------------
  -- tokyonight（退路，目前不會被載入）
  ------------------------------------------------------------------
  -- 底下兩組修正是還在用 tokyonight 時調的，換到 rose-pine 之後都用不到了：
  --
  -- * Folded：tokyonight 的 Folded 預設 bg = fg_gutter（moon: #3b4261），比所有
  --   Diff* 的底色都亮：
  --     Normal #222436 < DiffChange #252a3f < DiffAdd #2a4556 < DiffText #394b70 < Folded #3b4261
  --   於是在 diffview 裡「完全沒改、被收起來的那一行」反而比真正的差異更搶眼，
  --   很容易誤讀成改動，才改成比 Normal 更暗的 bg_dark（moon: #1e2030），語意
  --   才對：凹陷 = 收合。rose-pine 的 Folded 是 surface，本來就低於所有 Diff*。
  -- * DiffChange：原值 #252a3f 跟 Normal #222436 差不到 10，整行改動幾乎看不見。
  --   rose-pine 的 DiffChange 是 rose blend 20 疊在 base 上（約 #433842），跟
  --   Normal #191724 差距夠大，不用再拉。
  --
  -- 只有 DiffTextAdd 那條跟著搬過去 —— 兩個主題都沒定義它。
  --
  -- 註 1：只調 bg。LazyVim 設了 foldtext = ""（lazyvim/config/options.lua:73），Neovim 0.10+
  --       對空字串的處理是把摺疊區第一行原樣渲染並保留 syntax highlight，所以 Folded 的 fg
  --       會被語法色蓋掉、調了沒用。
  -- 註 2：Folded 是全域的，不只 diffview。但本設定是 foldmethod=manual + foldlevel=99，
  --       實務上只有 diff mode 會自動產生摺疊，副作用趨近於零。
  -- 註 3：必須走 on_highlights，不能在 options.lua 用 nvim_set_hl —— colorscheme 套用時會蓋掉。
  -- 註 4：這三個群組要出現，前提是 diffopt 沒有 iwhiteall——它會讓整行降級成 DiffAdd、
  --       行內比對完全不跑。粒度（逐字/逐詞）與空白忽略都設在 lua/config/options.lua，
  --       那邊有完整說明，配色這裡不管。
  {
    "folke/tokyonight.nvim",
    opts = {
      on_highlights = function(hl, c)
        hl.Folded = { bg = c.bg_dark }

        hl.DiffChange = { bg = "#2b3149" } -- 整行有改動：拉開跟 Normal 的距離，但仍低於行內標示
        hl.DiffText = { bg = "#3d5891" } -- 行內：兩邊都有、內容不同
        hl.DiffTextAdd = { bg = "#2f5f74" } -- 行內：只有這一邊有
      end,
    },
  },
}
