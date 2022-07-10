local wk = require("which-key")

-- Space is leader
vim.g.mapleader = " "
vim.g.maplocalleader = " "

wk.setup {
  window = { border = "single" }
}
-- TODO: Figure out how to reset bindings on reload
-- wk.reset()

local register = wk.register

local function callable(tbl)
  local __call = tbl.__call
  if type(__call) ~= "function" then
    error "Expected a __call method on table!"
  end
  tbl.__call = nil
  return setmetatable(tbl, { __call = __call })
end

local function bindmode(mode)
  return callable {
    __call = function(self, lhs, rhs, desc)
      return self.register({[lhs] = {rhs, desc}})
    end,
    register = function(mappings)
      return register(mappings, { mode = mode })
    end,
    leader = function(mappings)
      return register(mappings, { mode = mode, prefix = "<Leader>" })
    end,
  }
end

local normal = bindmode "n"
local visual = bindmode "x"
local select = bindmode "s"
local operator = bindmode "o"
local insert = bindmode "i"
local command = bindmode "c"
local terminal = bindmode "t"

-- Normal --
normal("<C-h>", "<C-w>h", "Go to the left window")
normal("<C-j>", "<C-w>j", "Go to the down window")
normal("<C-k>", "<C-w>k", "Go to the up window")
normal("<C-l>", "<C-w>l", "Go to the left window")
normal("L", ":bnext<CR>", "Go to the next buffer")
normal("H", ":bprevious<CR>", "Go to the previous buffer")
normal("<Esc>", ":nohlsearch<Bar>:echo<CR>", "Cancel search highlight")

-- Visual --
visual("p", '"_dP', "Paste over selection (without yanking)")
visual("<", "<gv", "Outdent selected lines")
visual("H", "<gv", "Outdent selected lines")
visual(">", ">gv", "Indent selected lines")
visual("L", ">gv", "Indent selected lines")
visual("J", ":move '>+1<CR>gv-gv", "Move selected lines down")
visual("K", ":move '<-2<CR>gv-gv", "Move selected lines up")

-- Buffer management
normal.leader {
  -- TODO: Look at lvim's smart quit
  q = { ":q!<CR>", "Quit" },
  w = { ":write<CR>", "Save" },
  W = { ":noautocmd write<CR>", "Save (no autocmd)" },
  u = { ":update<CR>", "Save, if changed" },
  ["<cr>"] = { ":update<CR>", "Save, if changed" },
  b = {
    name = "Buffer",
    d = { ":bd!<CR>", "Close current buffer" },
    D = { ":bw!<CR>", "Wipe current buffer" },
    s = {
      function()
        local fname = vim.fn.input("Save as: ", vim.fn.bufname(), "file")
        if fname ~= "" then
          vim.cmd(":saveas! " .. fname)
        end
      end,
      "Save current buffer as",
    },
  },
}

-- Packer
normal.leader {
  P = {
    name = "Packer",
    c = { ":PackerCompile<cr>", "Compile" },
    i = { ":PackerInstall<CR>", "Install" },
    u = { ":PackerUpdate<CR>", "Update" },
    s = { ":PackerSync<CR>", "Sync" },
    S = { ":PackerStatus<CR>", "Status" },
  },
}

return {
  visual = visual,
  select = select,
  operator = operator,
  insert = insert,
  command = command,
  terminal = terminal,
  register = register,
}
