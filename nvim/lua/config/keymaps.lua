-- Adapted from: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local Util = require("util")

-- hover
vim.keymap.set("n", "K", require("util.hover").hover, { desc = "Hover" })
vim.keymap.set("n", "gh", require("util.hover").hover, { desc = "Hover" })

-- better up/down
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Resize window using <ctrl> arrow keys
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Move Lines
vim.keymap.set("n", "<A-j>", ":m .+1<cr>==", { desc = "Move down", silent = true })
vim.keymap.set("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down", silent = true })
vim.keymap.set("i", "<A-j>", "<Esc>:m .+1<cr>==gi", { desc = "Move down", silent = true })
vim.keymap.set("n", "<A-k>", ":m .-2<cr>==", { desc = "Move up", silent = true })
vim.keymap.set("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up", silent = true })
vim.keymap.set("i", "<A-k>", "<Esc>:m .-2<cr>==gi", { desc = "Move up", silent = true })

-- buffers
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "bh", "<cmd>bprevious<cr>", { desc = "Previous" })
vim.keymap.set("n", "bl", "<cmd>bnext<cr>", { desc = "Next" })
vim.keymap.set("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
vim.keymap.set("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
vim.keymap.set("n", "<leader>br", "<cmd>e %<cr>", { desc = "Reopen buffer" })

-- Close floats, and clear highlights with <Esc>
vim.keymap.set("n", "<Esc>", Util.close_floats_and_clear_highlights, { desc = "Close floats, clear highlights" })

-- Clear search, diff update and redraw
-- taken from runtime/lua/_editor.lua
vim.keymap.set(
  "n",
  "<leader>ur",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  { desc = "Redraw / clear hlsearch / diff update" }
)

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
vim.keymap.set("n", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
vim.keymap.set("n", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
vim.keymap.set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- Add undo break-points
vim.keymap.set("i", ",", ",<c-g>u")
vim.keymap.set("i", ".", ".<c-g>u")
vim.keymap.set("i", ";", ";<c-g>u")

-- save file
vim.keymap.set({ "i", "v", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- better indenting
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")

-- lazy
vim.keymap.set("n", "<leader>L", "<cmd>:Lazy<cr>", { desc = "Lazy" })

-- quickfix, location list
vim.keymap.set("n", "<leader>xl", "<cmd>lopen<cr>", { desc = "Open Location List" })
vim.keymap.set("n", "<leadr>xq", "<cmd>copen<cr>", { desc = "Open Quickfix List" })

--- @param type 'qf' | 'quickfix' | 'lf' | 'loclist'
--- @param opts? { bufnr: number, lnum: number, col: number }
local function add_location_to_list(type, opts)
  local new_entry = {
    bufnr = opts and opts.bufnr ~= 0 and opts.bufnr or vim.api.nvim_get_current_buf(),
    lnum = opts and opts.lnum or vim.api.nvim_win_get_cursor(0)[1],
    col = opts and opts.col or vim.api.nvim_win_get_cursor(0)[2],
  }

  new_entry.text = vim.api.nvim_buf_get_lines(new_entry.bufnr, new_entry.lnum - 1, new_entry.lnum, true)[1]

  if type == "qf" or type == "quickfix" then
    -- check if location is already in the list
    for _, entry in ipairs(vim.fn.getqflist()) do
      if entry.bufnr == new_entry.bufnr and entry.lnum == new_entry.lnum and entry.col == new_entry.col then
        vim.notify("location already in list", vim.log.levels.DEBUG)
        return
      end
    end
    vim.notify("adding to quickfix", vim.log.levels.DEBUG)
    vim.fn.setqflist({ new_entry }, "a")
  elseif type == "lf" or type == "loclist" then
    -- check if location is already in the list
    for _, entry in ipairs(vim.fn.getloclist(0)) do
      if entry.bufnr == new_entry.bufnr and entry.lnum == new_entry.lnum and entry.col == new_entry.col then
        vim.notify("location already in list", vim.log.levels.DEBUG)
        return
      end
    end
    vim.notify("adding to loclist", vim.log.levels.DEBUG)
    vim.fn.setloclist(0, { new_entry }, "a")
  else
    error("unknown list type " .. type)
  end
end

--- @param type 'qf' | 'quickfix' | 'lf' | 'loclist'
--- @param opts? { bufnr: number, lnum: number, col: number }
local function remove_location_from_list(type, opts)
  local bufnr = opts and opts.bufnr ~= 0 and opts.bufnr or vim.api.nvim_get_current_buf()
  local lnum = opts and opts.lnum or vim.api.nvim_win_get_cursor(0)[1]
  local col = opts and opts.col or vim.api.nvim_win_get_cursor(0)[2]

  if type == "qf" or type == "quickfix" then
    local list = vim.fn.getqflist()
    -- if location is in the list, remove it
    for i, entry in ipairs(list) do
      if entry.bufnr == bufnr and entry.lnum == lnum and entry.col == col then
        table.remove(list, i)
        vim.notify("removing from quickfix", vim.log.levels.DEBUG)
        vim.fn.setqflist(list, "r")
        return
      end
    end
  elseif type == "lf" or type == "loclist" then
    local list = vim.fn.getloclist(0)
    -- if location is in the list, remove it
    for i, entry in ipairs(list) do
      if entry.bufnr == bufnr and entry.lnum == lnum and entry.col == col then
        table.remove(list, i)
        vim.notify("removing from loclist", vim.log.levels.DEBUG)
        vim.fn.setloclist(0, list, "r")
        return
      end
    end
  else
    error("unknown list type " .. type)
  end
end

-- stylua: ignore start
vim.keymap.set("n", "<leader>xa", function() add_location_to_list("lf") end, { desc = "Add to Location List" })
vim.keymap.set("n", "<leader>xA", function() add_location_to_list("qf") end, { desc = "Add to Quickfix List" })
vim.keymap.set("n", "<leader>xr", function() remove_location_from_list("lf") end, { desc = "Remove from Location List" })
vim.keymap.set("n", "<leader>xR", function() remove_location_from_list("qf") end, { desc = "Remove from Quickfix List" })
-- stylua: ignore end

---@return string | nil
local function get_trouble_provider()
  local trouble_ok, cfg = pcall(require, "trouble.config")
  if not trouble_ok or not cfg.options then
    return nil
  end
  return cfg.options.mode
end

--- @param type? 'qf' | 'quickfix' | 'lf' | 'loclist'
--- @return table[] | nil
local function current_trouble_items_to_list_items(type)
  local trouble_ok, trouble = pcall(require, "trouble")
  if not trouble_ok or not trouble or vim.bo.filetype ~= "Trouble" then
    return nil
  end

  if type == nil then
    type = get_trouble_provider()
  end

  local result = {}
  local list
  if type == "qf" or type == "quickfix" then
    list = vim.fn.getqflist()
  elseif type == "lf" or type == "loclist" then
    list = vim.fn.getloclist(0)
  else
    return nil
  end

  local trouble_items = trouble.get_items()
  local line = vim.api.nvim_win_get_cursor(0)[1]

  local trouble_items_to_map = {}
  if trouble_items[line] and trouble_items[line].is_file then
    -- get all entries from this file to the next file
    for i = line + 1, #trouble_items do
      local next_item = trouble_items[i]
      if next_item.is_file then
        break
      end
      table.insert(trouble_items_to_map, next_item)
    end
  elseif trouble_items[line] then
    trouble_items_to_map = { trouble_items[line] }
  end

  for _, trouble_item in ipairs(trouble_items_to_map) do
    for _, list_item in ipairs(list) do
      if
        list_item.bufnr == trouble_item.bufnr
        and list_item.lnum == trouble_item.lnum
        and list_item.col == trouble_item.col
      then
        table.insert(result, list_item)
      end
    end
  end

  return #result > 0 and result or nil
end

--- @param type? 'qf' | 'quickfix' | 'lf' | 'loclist'
--- @return table | nil
local function current_list_item(type)
  if type == nil then
    if vim.bo.filetype == "qf" then
      type = "qf"
    elseif vim.bo.filetype == "lf" then
      type = "lf"
    end
  end

  if type == "qf" or type == "quickfix" then
    if vim.bo.filetype ~= "qf" then
      return nil
    end
    local list = vim.fn.getqflist()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return list[line]
  elseif type == "lf" or type == "loclist" then
    if vim.bo.filetype ~= "lf" then
      return nil
    end
    local list = vim.fn.getloclist(0)
    local line = vim.api.nvim_win_get_cursor(0)[1]
    return list[line]
  else
    error("unknown list type " .. type)
  end
end

-- Add keybindings to qflist and loclist buffers
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "lf", "Trouble" },
  callback = function(event)
    local keyopts = { buffer = event.buf, desc = "Remove from list" }
    if event.match == "Trouble" then
      local provider = get_trouble_provider()
      if provider == "quickfix" or provider == "loclist" then
        vim.keymap.set("n", "dd", function()
          local to_remove = current_trouble_items_to_list_items(provider)
          if to_remove ~= nil then
            for _, entry in ipairs(to_remove) do
              remove_location_from_list(provider, entry)
            end
            local trouble_ok, trouble = require("trouble")
            if trouble_ok and trouble then
              trouble.refresh()
            end
          end
        end, keyopts)
      end
    else
      vim.keymap.set("n", "dd", function()
        remove_location_from_list(event.match, current_list_item(event.match))
      end, keyopts)
    end
  end,
})

-- stylua: ignore start

-- toggle options
vim.keymap.set("n", "<leader>us", Util.create_option_toggle("spell"), { desc = "Toggle Spelling" })
vim.keymap.set("n", "<leader>uw", Util.create_option_toggle("wrap"), { desc = "Toggle Word Wrap" })

-- quit
vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- highlights under cursor
if vim.fn.has("nvim-0.9.0") == 1 then
  vim.keymap.set("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })
end

-- tabs
vim.keymap.set("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last" })
vim.keymap.set("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First" })
vim.keymap.set("n", "<leader><tab>l", "<cmd>tabnext<cr>", { desc = "Next" })
vim.keymap.set("n", "<leader><tab>h", "<cmd>tabprevious<cr>", { desc = "Previous" })
vim.keymap.set("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
vim.keymap.set("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close" })
vim.keymap.set("n", "<leader><tab>D", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })

-- Normal --
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { desc = "Next quickfix" })
vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { desc = "Previous quickfix" })
vim.keymap.set("n", "gp", "`[v`]", { desc = "Switch to VISUAL using the last changed or yanked text" })

-- Visual --
vim.keymap.set("x", "p", '"_dP', { desc = "Paste over selection (without yanking)" })
vim.keymap.set("n", "<A-l>", ">>", { desc = "Indent right" })
vim.keymap.set("x", "<A-l>", ">gv", { desc = "Indent right" })
vim.keymap.set("n", "<A-h>", "<<", { desc = "Indent left" })
vim.keymap.set("x", "<A-h>", "<gv", { desc = "Indent left" })

-- TODO: Add some bindings for doing diff stuff, e.g.:
-- :windo diffthis -- diff buffers in all windows
-- :windo diffoff -- turn off diffing for all windows
-- :diffoff! -- alternative version of above?
-- :windo diffupdate -- update diffs for all windows

-- :[range]diffget [buf] -- same as [count]do
-- :[range]diffput [buf] -- same as [count]dp

-- :vert diffsplit %~ -- diff current buffer with previous version
-- :vert diffpatch /path/to/patch -- diff current buffer with patch from file

-- Add a way to change the diff algorithm.
-- Currently supported algorithms are:
-- myers      the default algorithm
-- minimal    spend extra time to generate the smallest possible diff
-- patience   patience diff algorithm
-- histogram  histogram diff algorithm
-- vim.opt.diffopt:append(algorithm:{text})

-- Buffer management
vim.keymap.set("n", "<leader><cr>", "<cmd>update!<CR>", { desc = "Save, if changed" })
vim.keymap.set("n", "<leader>w", "<cmd>write!<CR>", { desc = "Save" })
vim.keymap.set("n", "<leader>W", "<cmd>noautocmd write!<CR>", { desc = "Save (no autocmd)" })
vim.keymap.set("n", "<leader>bw", "<leader>w", { remap = true, desc = "Save" })
vim.keymap.set("n", "<leader>bW", "<leader>W", { remap = true, desc = "Save (no autocmd)" })
vim.keymap.set("n", "<leader>bu", "<leader><cr>", { remap = true, desc = "Save, if changed" })
vim.keymap.set("n", "<leader>ba", "<cmd>wa!<CR>", { desc = "Write all buffers" })
vim.keymap.set("n", "<leader>bC", "<cmd>%bd|e#|bd#<CR>", { desc = "Close all buffers" })
vim.keymap.set("n", "<leader>bs", function()
  local fname = vim.fn.input({ prompt = "Save as: ", default = vim.fn.bufname(), completion = "file" })
  if fname ~= "" then
    vim.cmd("<cmd>saveas! " .. fname)
  end
end, { desc = "Save current buffer as" })

vim.keymap.set("n", "<leader>b%", "<cmd>source %<CR>", { desc = "Source current file" })
vim.keymap.set("n", "<leader>f%", "<cmd>source %<CR>", { desc = "Source current file" })

-- new file
vim.keymap.set("n", "<leader>bn", "<cmd>enew<cr>", { desc = "New file" })
vim.keymap.set("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New file" })

-- Mason
vim.keymap.set("n", "<leader>M", "<cmd>Mason<cr>", { desc = "Mason" })


local function toggle_profile()
  if vim.v.profiling == 1 then
    vim.cmd [[ profile pause | profile dump | noautocmd qall! ]]
  else
    vim.cmd [[ profile start profile.log | profile func * | profile file * ]]
  end
end

vim.keymap.set({"n", "i"}, "<C-p>", toggle_profile, { desc = "Toggle profile" })
