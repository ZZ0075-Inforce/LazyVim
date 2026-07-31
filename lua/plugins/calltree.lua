-- 階層式 Call Hierarchy 樹狀檢視
-- 使用自製模組 util.calltree，不依賴外部外掛
-- gai = incoming calls (誰呼叫了此函式)
-- gao = outgoing calls (此函式呼叫了誰)
return {
  -- 用 LazyVim 的 servers["*"].keys 機制覆寫 gai/gao
  -- 這是唯一能蓋過 Snacks picker 綁定的方式
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ["*"] = {
          keys = {
            {
              "gai",
              function()
                require("util.calltree").incoming()
              end,
              desc = "Incoming Calls (階層樹)",
              has = "callHierarchy/incomingCalls",
            },
            {
              "gao",
              function()
                require("util.calltree").outgoing()
              end,
              desc = "Outgoing Calls (階層樹)",
              has = "callHierarchy/outgoingCalls",
            },
          },
        },
      },
    },
  },
}
