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

-- "always on" plugins; no setup necessary! --
use "wbthomason/packer.nvim"       -- Packer can manage itself
use 'lewis6991/impatient.nvim'     -- Gotta go fast
use "nvim-lua/plenary.nvim"        -- A common dependency in lua plugins
use "kyazdani42/nvim-web-devicons" -- Icons used by lots of other nvim plugins

-- some assembly required --
use "folke/which-key.nvim"         -- See keymap.lua

-- Status bar --
use { "nvim-lualine/lualine.nvim", config = [[ require("config.lualine") ]] }

-- Colorscheme --
use { "~/.local/share/laserwave", requires = { "rktjmp/lush.nvim", "rktjmp/shipwright.nvim" } }

packer.compile() -- since we didn't use packer.startup(), manually compile plugins

