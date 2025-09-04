return {
  {
    "folke/snacks.nvim",
    cmd = { "ClaudeCode", "ClaudeCodeContinue", "ClaudeCodeResume", "ClaudeCodeVerbose" },
    keys = {
      { "<leader>a", "", desc = "+ai", mode = { "n", "v" } },
      { "<leader>aa", "<cmd>ClaudeCode<cr>", desc = "Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCodeContinue<cr>", desc = "Claude Code Continue" },
      { "<leader>ar", "<cmd>ClaudeCodeResume<cr>", desc = "Claude Code Resume" },
      { "<leader>av", "<cmd>ClaudeCodeVerbose<cr>", desc = "Claude Code Verbose" },
    },
    opts = function()
      local claude_terminal_id = nil

      -- Enhanced Claude Code terminal setup
      local function setup_claude_terminal(cmd, args)
        -- Build command string properly for snacks terminal
        local full_cmd = cmd
        if args and args ~= "" then
          full_cmd = cmd .. " " .. args
        end

        claude_terminal_id = Snacks.terminal(full_cmd, {
          win = {
            position = "right",
            relative = "editor",
            size = { width = 0.4 },
            bo = {
              filetype = "claude-code",
            },
            keys = {
              q = false,
              { "q", "hide", desc = "Hide terminal" },
              { "<Esc>", "hide", desc = "Hide terminal" },
              { "<c-q>", "hide", desc = "Hide terminal", mode = { "t", "n" } },
              { "<c-h>", "<c-\\><c-n><c-w>h", expr = true, desc = "Move to left window", mode = { "t" } },
              { "<c-j>", "<c-\\><c-n><c-w>j", expr = true, desc = "Move to lower window", mode = { "t" } },
              { "<c-k>", "<c-\\><c-n><c-w>k", expr = true, desc = "Move to upper window", mode = { "t" } },
              { "<c-l>", "<c-\\><c-n><c-w>l", expr = true, desc = "Move to right window", mode = { "t" } },
              {
                "i",
                function()
                  vim.cmd("startinsert")
                  return "i"
                end,
                expr = true,
                desc = "Enter insert mode",
              },
              term_normal = {
                "<Esc>",
                function()
                  -- Just a couple of dumb heuristics to determine if claude is looking for <esc>.
                  -- It's quite possible that we don't cover all scenarios here.
                  if vim.fn.search([[-- INSERT\|Esc to|esc to|Esc/Tab to]], "nw") ~= 0 then
                    return "<Esc>"
                  else
                    vim.cmd("stopinsert")
                  end
                end,
                mode = { "t" },
                expr = true,
                desc = "Escape to normal mode",
              },
            },
          },
        })
        return claude_terminal_id
      end

      -- Create user commands
      vim.api.nvim_create_user_command("ClaudeCode", function(opts)
        setup_claude_terminal("claude", opts.args)
      end, { nargs = "*" })

      vim.api.nvim_create_user_command("ClaudeCodeContinue", function()
        setup_claude_terminal("claude", "--continue")
      end, {})

      vim.api.nvim_create_user_command("ClaudeCodeResume", function()
        setup_claude_terminal("claude", "--resume")
      end, {})

      vim.api.nvim_create_user_command("ClaudeCodeVerbose", function()
        setup_claude_terminal("claude", "--verbose")
      end, {})
    end,
  },

  -- Optional edgy.nvim integration for proper window management
  {
    "folke/edgy.nvim",
    optional = true,
    opts = {
      right = {
        {
          ft = "claude-code",
          size = { width = 0.4 },
          -- title = "%{b:snacks_terminal.id}: Claude Code: %{b:term_title}",
          title = function()
            local title = "%{b:snacks_terminal.id}: Claude Code"
            if vim.b.term_title and vim.b.term_title ~= "" then
              if vim.b.term_title:find("term://") == 1 then
                local segments = vim.split(vim.b.term_title, "term://")
                title = title .. ": " .. segments[2]
              else
                title = title .. ": " .. vim.b.term_title
              end
            end
            return title
          end,
          filter = function(_, win)
            return vim.w[win].snacks_win
              and vim.w[win].snacks_win.position == "right"
              and vim.w[win].snacks_win.relative == "editor"
              and not vim.w[win].trouble_preview
          end,
          pinned = true,
        },
      },
    },
  },
}
