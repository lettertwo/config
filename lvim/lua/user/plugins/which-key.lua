local WhichKey = {}

function WhichKey.config()
  if not lvim.builtin.which_key.active then
    return
  end

  lvim.builtin.which_key.setup.plugins.presets.motions = true
  lvim.builtin.which_key.setup.plugins.presets.operators = true
  lvim.builtin.which_key.setup.plugins.presets.windows = true
  lvim.builtin.which_key.setup.plugins.presets.text_objects = true

  lvim.builtin.which_key.setup.operators = {
    sa = "Sandwich",
  }

  local function save_as()
    local fname = vim.fn.input("Save as: ", vim.fn.bufname(), "file")
    if fname ~= "" then
      vim.cmd(":saveas! " .. fname)
    end
  end

  -- Use which-key to add extra bindings with the leader-key prefix
  lvim.builtin.which_key.mappings["<cr>"] = { "<cmd>update!<CR>", "Save, if changed" }
  lvim.builtin.which_key.mappings["b"] = vim.tbl_deep_extend("force", lvim.builtin.which_key.mappings["b"], {
    w = { "<cmd>w<CR>", "Write current buffer" },
    W = { "<cmd>noa w<CR>", "Write without autocmds" },
    a = { "<cmd>wa<CR>", "Write all buffers" },
    u = { "<cmd>update<CR>", "Update current buffer" },
    c = { "<cmd>bd!<CR>", "Close current buffer" },
    C = { "<cmd>%bd|e#|bd#<CR>", "Close all buffers" },
    n = { "<cmd>enew<CR>", "Open new buffer" },
    s = { save_as, "Save current buffer (as)" },
    ["%"] = { "<cmd>source %<CR>", "Source current file" },
  })
end

return WhichKey
