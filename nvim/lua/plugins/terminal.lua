---@param cmd string
---@param opts? table
---@return fun(size?: number, direction?: string): Terminal
local function create_cmd(cmd, opts)
  opts = vim.tbl_extend(
    "force",
    {
      on_open = function()
        vim.cmd("startinsert!")
      end,
      on_close = function()
        vim.cmd("startinsert!")
      end,
    },
    opts or {},
    {

      cmd = cmd,
      hidden = true, -- prevent toggling by `:ToggleTerm` and friends.
    }
  )

  local term
  return function(size, direction)
    if term == nil then
      local Terminal = require("toggleterm.terminal").Terminal
      term = Terminal:new(opts)
    end
    term:open(size, direction)
    return term
  end
end

local open_lazygit_cmd

local function open_lazygit()
  if open_lazygit_cmd ~= nil then
    return open_lazygit_cmd()
  end

  local config_dir = vim.fn.resolve(vim.fs.joinpath(require("util").config_path(), "../lazygit"))
  local lazygit_cmd = "lazygit --use-config-file='"
    .. vim.fs.joinpath(config_dir, "config.yml")
    .. ","
    .. vim.fs.joinpath(config_dir, "config-nvim.yml")
    .. "'"

  local cmd = create_cmd(lazygit_cmd)
  open_lazygit_cmd = function()
    local term = cmd()

    -- add autocmd to close lazygit when a buffer is opened for editing
    local group = vim.api.nvim_create_augroup("LazygitClose", { clear = true })
    vim.api.nvim_create_autocmd("BufEnter", {
      callback = function(args)
        vim.api.nvim_del_augroup_by_id(group)

        -- Give nvim remote some time to process the edit cmd
        local timer = vim.uv.new_timer()
        timer:start(
          100,
          0,
          vim.schedule_wrap(function()
            if term:is_open() then
              term:close()
            end
            timer:stop()
            timer:close()
          end)
        )
      end,
      once = true,
      group = group,
      pattern = "*",
    })

    return term
  end

  return open_lazygit_cmd()
end

local function open_cbd(opts)
  opts = vim.tbl_extend("force", opts or {}, { dir = vim.fn.expand("%:p:h") })
  return create_cmd(nil, opts)()
end

return {
  {
    "akinsho/toggleterm.nvim",
    event = "VeryLazy",
    cmd = "ToggleTerm",
    keys = {
      { "<leader>\\\\", "<cmd>ToggleTerm<cr>", desc = "terminal" },
      { "<leader>\\.", open_cbd, desc = "terminal at file" },
      { "<leader>\\g", open_lazygit, desc = "lazygit" },
      { "<leader>\\n", create_cmd("node"), desc = "node repl" },
      -- remaps
      { "\\", "<leader>\\\\", remap = true, desc = "terminal" },
      { "<leader>gg", "<leader>\\g", remap = true, desc = "lazygit" },
    },
    opts = {
      autochdir = false,
      direction = "float",
      shade_filetypes = {},
      hide_numbers = true,
      insert_mappings = true,
      terminal_mappings = true,
      start_in_insert = true,
      close_on_exit = true,
      persist_mode = true,
      persist_size = true,
      auto_scroll = true,
      -- shade_terminals = true,
      shell = vim.o.shell,
      -- shading_factor = 2,
      float_opts = {
        border = "curved",
      },
      highlights = {
        Float = { link = "Float" },
        FloatTitle = { link = "FloatTitle" },
        FloatBorder = { link = "FloatBorder" },
        NormalFloat = { link = "NormalFloat" },
      },
      on_open = function()
        vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], { buffer = 0 })
        vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], { buffer = 0 })
        vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], { buffer = 0 })
      end,
    },
  },
}
