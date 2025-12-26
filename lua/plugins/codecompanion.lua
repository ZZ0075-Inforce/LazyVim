---@class CodeCompanion.SystemPrompt.Context
---@field language string
---@field adapter CodeCompanion.HTTPAdapter|CodeCompanion.ACPAdapter
---@field date string
---@field nvim_version string
---@field os string the operating system that the user is using
---@field default_system_prompt string
---@field cwd string current working directory
---The closest parent directory that contains one of the following VCS markers:
--- - `.git`
--- - `.svn`
--- - `.hg`
---@field project_root? string the closest parent directory that contains a `.git` subdirectory.
local fmt = string.format

return {
  {
    "olimorris/codecompanion.nvim",
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {
      opts = {
        language = "zh-TW",
      },
      rules = {
        inforceERP = {
          description = "ERP開發相關規範",
          files = {
            -- Literal file paths (absolute or relative to cwd)
            "~/.copilot/copilot-instructionsERP-instructions.md",
            "~/.copilot/copilot-instructions.md",
          },
        },
        opts = {
          chat = {
            enabled = true,
            default_rules = "default", -- The rule groups to load
            autoload = "inforceERP",
          },
        },
      },
      interactions = {
        chat = {
          opts = {
            ---@param ctx CodeCompanion.SystemPrompt.Context
            ---@return string
            system_prompt = function(ctx)
              local custom_instructions = ""
              local home = os.getenv("USERPROFILE") or os.getenv("HOME")
              local path = home .. "/.copilot/copilot-instructions.md"
              -- Normalize path for Windows
              path = path:gsub("\\", "/")

              if vim.fn.filereadable(path) == 1 then
                local file = io.open(path, "r")
                if file then
                  custom_instructions = file:read("*a")
                  file:close()
                  vim.notify("CodeCompanion: Loaded instructions from " .. path, vim.log.levels.INFO)
                end
              else
                vim.notify("CodeCompanion: Instructions file not found at " .. path, vim.log.levels.WARN)
              end

              if custom_instructions ~= "" then
                custom_instructions = "\nUser Defined Instructions:\n" .. custom_instructions
              end

              return ctx.default_system_prompt
                .. fmt(
                  [[Additional context:
All non-code text responses must be written in the %s language.
The current date is %s.
The user's Neovim version is %s.
The user is working on a %s machine. Please respond with system specific commands if applicable. 
%s]],
                  ctx.language,
                  ctx.date,
                  ctx.nvim_version,
                  ctx.os,
                  custom_instructions
                )
            end,
          },

          adapter = {
            name = "copilot",
            model = "gemini-3-flash-preview",
          },
        },
        inline = {
          name = "copilot",
          model = "gemini-3-flash-preview",
        },
        cmd = {
          name = "copilot",
          model = "gemini-3-flash-preview",
        },
        background = {
          adapter = {
            name = "copilot",
            model = "gemini-3-flash-preview",
          },
        },
      },
    },
  },
}
