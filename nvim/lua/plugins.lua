local ok, packer = pcall(require, "packer")
if not ok then return end

packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({border = "rounded"})
    end,
  },
})

local use = packer.use
packer.reset()

use "wbthomason/packer.nvim"    -- Packer can manage itself
use 'lewis6991/impatient.nvim'  -- Gotta go fast
use "nvim-lua/plenary.nvim"     -- A common dependency in lua plugins

packer.compile() -- since we didn't use packer.startup(), manually compile plugins

