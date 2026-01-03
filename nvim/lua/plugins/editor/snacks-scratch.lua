local FILETYPES = {
  { text = "css" },
  { text = "go" },
  { text = "html" },
  { text = "javascript" },
  { text = "javascriptreact" },
  { text = "lua" },
  { text = "markdown" },
  { text = "python" },
  { text = "rust" },
  { text = "typescript" },
  { text = "typescriptreact" },
  { text = "zig" },
}

local function new_scratch(filetypes)
  Snacks.picker.pick({
    source = "scratch",
    items = filetypes,
    format = "text",
    pattern = vim.bo.filetype,
    title = "Select a filetype",
    layout = { preset = "vscode" },
    actions = {
      confirm = function(picker, item)
        picker:close()
        vim.schedule(function()
          local items = picker:items()
          if #items == 0 then
            Snacks.scratch({ ft = picker:filter().pattern })
          else
            Snacks.scratch({ ft = item.text })
          end
        end)
      end,
    },
  })
end

return {
  {
    "folke/snacks.nvim",
    -- stylua: ignore
    keys = {
      {"<leader>.", false},
      {"<leader>S", false},
      { "<leader>bn", function() return new_scratch(FILETYPES) end, desc = "New Scratch Buffer" },
      { "<leader>bs", function() require('snacks').scratch() end, desc = "Toggle Scratch Buffer" },
      { "<leader>bS", function() require('snacks.picker').scratch() end, desc = "Select Scratch Buffer" },
      { "<leader>bt", function() require('snacks').scratch.open({name = "TODO", ft = "markdown", icon = " " }) end, desc = "Toggle Todo Buffer" },
    },
    opts = {
      scratch = {
        win = {
          width = function()
            return vim.o.columns
          end,
          height = function()
            return math.ceil(vim.o.lines * 0.9)
          end,
          zindex = 50,
        },
      },
    },
  },
}
