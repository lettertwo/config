local map = vim.keymap.set

Config.on("PackChanged", function(ev)
  local name, kind = ev.data.spec.name, ev.data.kind
  if name == "smart-splits.nvim" and kind ~= "delete" then
    if not ev.data.active then
      vim.cmd.packadd("smart-splits.nvim")
    end

    local function resolve(filepath)
      return vim.fs.normalize(vim.fs.joinpath(ev.data.path, filepath))
    end

    local function link(filepath)
      local filename = vim.fs.basename(filepath)
      return vim.fn.system(string.format("ln -sf %s $XDG_CONFIG_HOME/kitty/%s", resolve(filepath), filename))
    end

    link("kitty/neighboring_window.py")
    link("kitty/relative_resize.py")
    link("kitty/split_window.py")
  end
end)

vim.schedule(function()
  Config.add("mrjones2014/smart-splits.nvim")

  require("smart-splits").setup({
    at_edge = "stop", -- 'wrap' | 'split' | 'stop'
  })

  -- stylua: ignore start
  -- resizing splits
  map("n", "<C-S-h>", function() require("smart-splits").resize_left() end, { desc = "Resize window left" })
  map("n", "<C-S-l>", function() require("smart-splits").resize_right() end, { desc = "Resize window right" })
  map("n", "<C-S-j>", function() require("smart-splits").resize_down() end, { desc = "Resize window down" })
  map("n", "<C-S-k>", function() require("smart-splits").resize_up() end, { desc = "Resize window up" })
  -- moving between splits
  map("n", "<C-h>", function() require("smart-splits").move_cursor_left() end, { desc = "Go to the left window" })
  map("n", "<C-j>", function() require("smart-splits").move_cursor_down() end, { desc = "Go to the down window"})
  map("n", "<C-k>", function() require("smart-splits").move_cursor_up() end, { desc = "Go to the up window" })
  map("n", "<C-l>", function() require("smart-splits").move_cursor_right() end, { desc = "Go to the right window" })
  -- swapping buffers between windows
  map("n", "<C-w>xh", function() require("smart-splits").swap_buf_left() end, { desc = "swap left" })
  map("n", "<C-w>xj", function() require("smart-splits").swap_buf_down() end, { desc = "swap down" })
  map("n", "<C-w>xk", function() require("smart-splits").swap_buf_up() end, { desc = "swap up" })
  map("n", "<C-w>xl", function() require("smart-splits").swap_buf_right() end, { desc = "swap right" })
  map("n", "<C-w>R", function() require("smart-splits").start_resize_mode() end, { desc = "Enter window resize mode" })

  map("n", "<C-w>H", "<C-S-h>", { remap = true, desc = "Resize window left" })
  map("n", "<C-w>L", "<C-S-l>", { remap = true, desc = "Resize window right" })
  map("n", "<C-w>J", "<C-S-j>", { remap = true, desc = "Resize window down" })
  map("n", "<C-w>K", "<C-S-k>", { remap = true, desc = "Resize window up" })
  map("n", "<C-w>h", "<C-h>", { remap = true, desc = "Go to the left window" })
  map("n", "<C-w>j", "<C-j>", { remap = true, desc = "Go to the down window"})
  map("n", "<C-w>k", "<C-k>", { remap = true, desc = "Go to the up window" })
  map("n", "<C-w>l", "<C-l>", { remap = true, desc = "Go to the right window" })
  map("n", "<C-w>xx", "<C-w><C-x>", { remap = true, desc = "swap current with next" })
  map("n", "<C-w><Tab>", "<c-w>T", { remap = true, desc = "break out into new tab" })
  -- stylua: ignore end
end)
