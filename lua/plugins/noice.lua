return {
  {
    "folke/noice.nvim",
    opts = {
      -- noice 的 {date} 預設格式是 "%X"（noice/config/format.lua:145），而 %X 是
      -- 「locale 的時間表示法」，走 C runtime 的 locale。這台機器系統 ACP = 950，
      -- 於是 os.date("%X") 回傳 Big5 的「下午 08:14:06」，塞進 UTF-8 的 buffer
      -- 就顯示成 <a4>U<a4><c8>。改成純 ASCII 的 24 小時制。
      --
      -- 同理受影響的還有 %p（下午）、%A（星期四）、%B、%c，都要避開；
      -- %H %M %S %Y %m %d 這類純數字的沒問題。
      -- 這不是誰改壞的設定，是 noice 原廠預設，只在非 UTF-8 locale 的機器上才會壞。
      format = {
        date = { format = "%H:%M:%S" },
      },
    },
  },
}
