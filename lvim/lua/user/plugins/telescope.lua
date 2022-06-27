local Telescope = {}

function Telescope.config()
  if not lvim.builtin.telescope.active then
    return
  end

  local _, telescope = pcall(require, "telescope")
  if not telescope then
    return
  end

  -- TODO: configure this: https://github.com/nvim-telescope/telescope-ui-select.nvim
  pcall(telescope.load_extension, "ui-select")
  -- TODO: Configure this: https://github.com/nvim-telescope/telescope-file-browser.nvim
  pcall(telescope.load_extension, "file_browser")

  local actions = require("telescope.actions")
  local files = require("telescope.builtin.files")
  local themes = require("telescope.themes")
  local _, trouble = pcall(require, "trouble.providers.telescope")

  -- Use ivy theme by default.
  lvim.builtin.telescope.defaults = vim.tbl_deep_extend("force", lvim.builtin.telescope.defaults, themes.get_ivy())

  lvim.builtin.telescope.extensions["ui-select"] = { theme = "dropdown" }

  -- Change Telescope navigation to use j and k for navigation and n and p for history in both input and normal mode.
  lvim.builtin.telescope.defaults.mappings = {
    -- for input mode
    i = {
      ["<C-j>"] = actions.move_selection_next,
      ["<C-k>"] = actions.move_selection_previous,
      ["<C-n>"] = actions.cycle_history_next,
      ["<C-p>"] = actions.cycle_history_prev,
    },
    -- for normal mode
    n = {
      ["<C-j>"] = actions.move_selection_next,
      ["<C-k>"] = actions.move_selection_previous,
    },
  }

  if trouble then
    lvim.builtin.telescope.defaults.mappings.i["<C-t>"] = trouble.open_with_trouble
    lvim.builtin.telescope.defaults.mappings.n["<C-t>"] = trouble.open_with_trouble
  end

  -- Delete buffers in the buffer picker with <c-d>
  lvim.builtin.telescope.defaults.pickers.buffers = {
    mappings = {
      i = {
        ["<c-d>"] = actions.delete_buffer + actions.move_to_top,
      },
      n = {
        ["<c-d>"] = actions.delete_buffer + actions.move_to_top,
      },
    },
  }
  lvim.builtin.which_key.mappings["P"] = { "<cmd>Telescope projects<CR>", "Projects" }
  lvim.builtin.which_key.mappings["H"] = { "<cmd>Telescope highlights<CR>", "Highlights" }
  lvim.builtin.which_key.mappings["br"] = { "<cmd>Telescope oldfiles<CR>", "Open Recent File" }
  lvim.builtin.which_key.mappings["r"] = { "<cmd>Telescope oldfiles<CR>", "Open Recent File" }
  lvim.builtin.which_key.mappings["e"] = { "<cmd>Telescope file_browser path=%:p:h<CR>", "File Explorer" }

  lvim.builtin.which_key.mappings["<Leader>"] = { "<cmd>Telescope<CR>", "Telescope" }

  -- Art (╯°□°）╯︵ ┻━┻
  lvim.builtin.which_key.mappings["se"] = {
    "<cmd>lua require'telescope.builtin'.symbols({sources={'emoji'}})<CR>",
    "Emoji 😀",
  }
  lvim.builtin.which_key.mappings["sg"] = {
    "<cmd>lua require'telescope.builtin'.symbols({sources={'gitmoji'}})<CR>",
    "Gitmoji 🚀",
  }
  lvim.builtin.which_key.mappings["sa"] = {
    "<cmd>lua require'telescope.builtin'.symbols({sources={'kaomoji'}})<CR>",
    "Art (╯°□°）╯︵ ┻━┻",
  }
  lvim.builtin.which_key.mappings["sm"] = {
    "<cmd>lua require'telescope.builtin'.symbols({sources={'math'}})<CR>",
    "Math Symbols ∑",
  }

  local function lvim_config_files()
    files.find_files({
      prompt_title = "Lvim Config Files",
      cwd = vim.env.LUNARVIM_CONFIG_DIR,
    })
  end

  local function xdg_config_files()
    files.find_files({
      prompt_title = "Config Files",
      cwd = vim.env.XDG_CONFIG_HOME,
    })
  end

  local function xdg_config_grep()
    files.live_grep({
      prompt_title = "Search Config",
      search_dirs = { vim.env.XDG_CONFIG_HOME },
    })
  end

  -- Config search
  lvim.builtin.which_key.mappings["LC"] = { lvim_config_files, "User Config Files" }

  lvim.builtin.which_key.mappings["c"] = {
    name = "Config",
    ["l"] = { lvim_config_files, "LunarVim Config Files" },
    ["f"] = { xdg_config_files, "Find Config Files" },
    ["s"] = { xdg_config_grep, "Search Config Dir" },
  }
end

return Telescope
