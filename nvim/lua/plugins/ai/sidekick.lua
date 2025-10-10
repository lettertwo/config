-- @module "sidekick"

---@param keys string
---@param mode? string default is 'mx'. See :h feedkeys()
local function feedkeys(keys, mode)
  keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(keys, mode or "mx", false)
end

-- Key mappings for Claude in sidekick.nvim terminal buffers.
---@type table<string, sidekick.cli.Keymap|false>
local claude_keys = {
  new_line = {
    "<s-cr>",
    function(t)
      t:send("\\")
      t:submit()
    end,
  },
  term_normal = {
    "<Esc>",
    function(t)
      -- Just a couple of dumb heuristics to determine if claude is looking for <esc>.
      -- It's quite possible that we don't cover all scenarios here.
      if vim.fn.search([[-- INSERT\|Esc to\|Esc/Tab to]], "nw") ~= 0 then
        t:send(vim.keycode("<Esc>"))
      else
        vim.cmd("stopinsert")
      end
    end,
  },
}

return {
  {
    "folke/sidekick.nvim",
    keys = {
      { "<leader>ac", "<cmd>Sidekick cli show name=claude_continue<cr>", desc = "Claude Continue" },
      { "<leader>ar", "<cmd>Sidekick cli show name=claude_resume<cr>", desc = "Claude Resume" },
      { "<leader>af", "<cmd>Sidekick cli show name=claude_fork<cr>", desc = "Claude Fork" },
    },
    ---@module "sidekick"
    ---@type sidekick.Config
    opts = {
      cli = {
        tools = {
          claude = { cmd = { "claude", "--verbose" }, keys = claude_keys },
          claude_continue = { cmd = { "claude", "--verbose", "--continue" }, keys = claude_keys },
          claude_resume = { cmd = { "claude", "--verbose", "--resume" }, keys = claude_keys },
          claude_fork = { cmd = { "claude", "--verbose", "--resume", "--fork-session" }, keys = claude_keys },
        },
        win = {
          wo = { winbar = "%!v:lua.require'edgy.window'.edgy_winbar()" },
          -- stylua: ignore
          keys = {
            hide_n        = false,
            hide_ctrl_z   = false,
            stopinsert    = false,
            hide_ctrl_q   = { "<c-q>", "hide", mode = "nt" },
            nav_left      = { "<c-h>", function() feedkeys("<c-h>") end },
            nav_down      = { "<c-j>", function() feedkeys("<c-j>") end },
            nav_up        = { "<c-k>", function() feedkeys("<c-k>") end },
            nav_right     = { "<c-l>", function() feedkeys("<c-l>") end },
          },
        },
      },
    },
  },
  {
    "folke/edgy.nvim",
    opts = {
      right = {
        {
          ft = "sidekick_terminal",
          size = { width = 0.4 },
          title = function()
            local title = "Sidekick"
            local name = vim.b.sidekick_cli
            local term_title = vim.b.term_title
            if type(name) == "string" then
              if name:find("claude") == 1 then
                name = "Claude"
              else
                name = name:sub(1, 1):upper() .. name:sub(2)
              end
              title = name
            end
            if type(term_title) == "string" then
              local segments = vim.split(vim.b.term_title, "//")
              if #segments >= 2 then
                term_title = segments[2]
              end
              title = title .. " (" .. term_title .. ")"
            end
            return title
          end,
        },
      },
    },
  },
}
