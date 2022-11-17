local wk = require("which-key")

-- Space is leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

wk.setup({
  window = { border = "single" },
  operators = { gs = "Surround", gS = "Surround" },
  show_help = false,
  show_keys = false,
})
-- TODO: Figure out how to reset bindings on reload
-- wk.reset()

local register = wk.register

local function callable(tbl)
  local __call = tbl.__call
  if type(__call) ~= "function" then
    error("Expected a __call method on table!")
  end
  tbl.__call = nil
  return setmetatable(tbl, { __call = __call })
end

local function bindopts(opts)
  return callable({
    __call = function(self, lhs, rhs, label)
      return self.register({ [lhs] = { rhs, label } })
    end,
    register = function(mappings)
      return register(mappings, opts)
    end,
    leader = function(mappings)
      return register(mappings, vim.tbl_deep_extend("error", { prefix = "<Leader>" }, opts))
    end,
    label = function(lhs, label)
      return register({ [lhs] = label }, opts)
    end,
    delete = function(lhs)
      vim.keymap.del(opts.mode, lhs, { buffer = opts.buffer })
    end,
  })
end

local normal = bindopts({ mode = "n" })
local visual = bindopts({ mode = "x" })
local select = bindopts({ mode = "s" })
local operator = bindopts({ mode = "o" })
local insert = bindopts({ mode = "i" })
local command = bindopts({ mode = "c" })
local terminal = bindopts({ mode = "t" })

local function buffer(bufno)
  if bufno == nil then
    bufno = vim.api.nvim_get_current_buf()
  end
  return {
    normal = bindopts({ buffer = bufno, mode = "n" }),
    visual = bindopts({ buffer = bufno, mode = "x" }),
    select = bindopts({ buffer = bufno, mode = "s" }),
    operator = bindopts({ buffer = bufno, mode = "o" }),
    insert = bindopts({ buffer = bufno, mode = "i" }),
    command = bindopts({ buffer = bufno, mode = "c" }),
    terminal = bindopts({ buffer = bufno, mode = "t" }),
  }
end

-- Normal --
normal("L", ":bnext<CR>", "Go to the next buffer")
normal("H", ":bprevious<CR>", "Go to the previous buffer")
normal("<Esc>", ":nohlsearch<Bar>:echo<CR>", "Cancel search highlight")
normal("<C-Up>", ":resize -2<CR>", "Decrease height")
normal("<C-Down>", ":resize +2<CR>", "Increase height")
normal("<C-Left>", ":vertical resize -2<CR>", "Decrease width")
normal("<C-Right>", ":vertical resize +2<CR>", "Increase width")
normal("]q", ":cnext<CR>", "Next quickfix")
normal("[q", ":cprev<CR>", "Previous quickfix")

-- Visual --
visual("p", '"_dP', "Paste over selection (without yanking)")
visual("<", "<gv", "Outdent selected lines")
visual("H", "<gv", "Outdent selected lines")
visual(">", ">gv", "Indent selected lines")
visual("L", ">gv", "Indent selected lines")
visual("J", ":move '>+1<CR>gv-gv", "Move selected lines down")
visual("K", ":move '<-2<CR>gv-gv", "Move selected lines up")

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
normal.leader({
  -- TODO: Look at lvim's smart quit
  q = { ":quit!<CR>", "Quit" },
  w = { ":write!<CR>", "Save" },
  W = { ":noautocmd write!<CR>", "Save (no autocmd)" },
  u = { ":update!<CR>", "Save, if changed" },
  ["<cr>"] = { ":update!<CR>", "Save, if changed" },
  b = {
    name = "Buffer",
    d = { ":bd!<CR>", "Close current buffer" },
    D = { ":bw!<CR>", "Wipe current buffer" },
    s = {
      function()
        local fname = vim.fn.input({ prompt = "Save as: ", default = vim.fn.bufname(), completion = "file" })
        if fname ~= "" then
          vim.cmd(":saveas! " .. fname)
        end
      end,
      "Save current buffer as",
    },
    a = { "<cmd>wa!<CR>", "Write all buffers" },
    n = { "<cmd>enew<CR>", "Open new buffer" },
    C = { "<cmd>%bd|e#|bd#<CR>", "Close all buffers" },
    ["%"] = { "<cmd>source %<CR>", "Source current file" },
  },
})

-- Packer
normal.leader({
  P = {
    name = "Packer",
    c = { ":PackerCompile<cr>", "Compile" },
    i = { ":PackerInstall<CR>", "Install" },
    u = { ":PackerUpdate<CR>", "Update" },
    s = { ":PackerSync<CR>", "Sync" },
    S = { ":PackerStatus<CR>", "Status" },
  },
})

-- Mason
normal.leader({
  M = {
    name = "Mason",
    l = { ":MasonLog<cr>", "Logs" },
    h = { ":checkhealth mason<cr>", "Check health" },
    M = { ":Mason<cr>", "Status" },
  },
})

return {
  buffer = buffer,
  normal = normal,
  visual = visual,
  select = select,
  operator = operator,
  insert = insert,
  command = command,
  terminal = terminal,
  register = register,
}
