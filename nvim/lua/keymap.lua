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

local function map(mode, lhs, rhs, label)
  if mode == '' then mode = 'nvo' end
  if #mode > 1 then
    for mode in mode:gmatch('.') do
      return register({ [lhs] = {rhs, label} }, { mode = mode })
    end
  else
    return register({ [lhs] = {rhs, label} }, { mode = mode })
  end
end

local function label(mode, lhs, label)
  if mode == '' then mode = 'nvo' end
  if #mode > 1 then
    for mode in mode:gmatch('.') do
      return register({ [lhs] = label }, { mode = mode })
    end
  else
    return register({ [lhs] = label }, { mode = mode })
  end
end


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
    __call = function(self, lhs, rhs, label)
      return self.register({[lhs] = {rhs, label}})
    end,
    register = function(mappings)
      return register(mappings, { mode = mode })
    end,
    leader = function(mappings)
      return register(mappings, { mode = mode, prefix = "<Leader>" })
    end,
    label = function(lhs, label)
      return register({[lhs] = label}, { mode = mode })
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
normal("<C-l>", "<C-w>l", "Go to the right window")
normal("L", ":bnext<CR>", "Go to the next buffer")
normal("H", ":bprevious<CR>", "Go to the previous buffer")
normal("<Esc>", ":nohlsearch<Bar>:echo<CR>", "Cancel search highlight")
normal("<C-Up>", ":resize -2<CR>", "Decrease height")
normal("<C-Down>", ":resize +2<CR>", "Increase height")
normal("<C-Left>", ":vertical resize -2<CR>", "Decrease width")
normal("<C-Right>", ":vertical resize +2<CR>", "Increase width")
normal("]q", ":cnext<CR>", "Next quickfix")
normal("[q", ":cprev<CR>", "Previous quickfix")
normal("<C-q>", ":call QuickFixToggle()<CR>", "Toggle quickfix")

-- Visual --
visual("p", '"_dP', "Paste over selection (without yanking)")
visual("<", "<gv", "Outdent selected lines")
visual("H", "<gv", "Outdent selected lines")
visual(">", ">gv", "Indent selected lines")
visual("L", ">gv", "Indent selected lines")
visual("J", ":move '>+1<CR>gv-gv", "Move selected lines down")
visual("K", ":move '<-2<CR>gv-gv", "Move selected lines up")

-- Terminal --
terminal("<C-h>", "<C-\\><C-N><C-w>h", "Go to the left window")
terminal("<C-j>", "<C-\\><C-N><C-w>j", "Go to the down window")
terminal("<C-k>", "<C-\\><C-N><C-w>k", "Go to the up window")
terminal("<C-l>", "<C-\\><C-N><C-w>l", "Go to the right window")

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
  normal = normal,
  visual = visual,
  select = select,
  operator = operator,
  insert = insert,
  command = command,
  terminal = terminal,
  register = register,
  label = label,
  map = map,
}
