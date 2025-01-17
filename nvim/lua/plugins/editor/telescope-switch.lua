return {
  -- {
  --   "telescope-switch.nvim",
  --   virtual = true,
  --   config = function()
  --     ----@module "lazyvim"
  --     LazyVim.on_load("telescope.nvim", function()
  --       local telescope = require("telescope")
  --       telescope.register_extension({
  --         exports = {
  --           switch = function(opts)
  --             vim.print("opts?", opts)
  --             -- opts = require("telescope._extensions.switch.config").get(opts)
  --             --
  --             -- local matches, default_selection_idx = get_matches(opts)
  --             --
  --             -- -- TODO: implement some or all of these features of the builtin selector:
  --             -- -- [x] Selection (<cr>): select the tag under the cursor
  --             -- -- [x] Split (horizontal) (<c-s>): select the tag under the cursor (split)
  --             -- -- [x] Split (vertical) (|): select the tag under the cursor (vsplit)
  --             -- -- [ ] Quick select (default: 1-9): select the tag at a given index
  --             -- -- [x] Deletion: delete a line to delete the tag
  --             -- -- [x] Reordering: move a line to move a tag
  --             -- -- [ ] Renaming (R): rename the tag under the cursor
  --             -- -- [x] Quickfix (<c-q>): send all tags to the quickfix list (:h quickfix)
  --             -- -- [ ] Go up (-): navigate up to the scopes window
  --             -- -- [x] Help (?): open the help window
  --             -- -- [ ] Add smart_open to switch results.
  --             -- -- [ ] Update tag when tagged buffer is renamed/moved
  --             --
  --             -- local picker = pickers.new(opts, {
  --             --   prompt_title = "Switch to",
  --             --   preview_title = "",
  --             --   finder = finders.new_table({
  --             --     results = matches,
  --             --     entry_maker = gen_entry_maker_from_match(opts),
  --             --   }),
  --             --   sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
  --             --   previewer = require("telescope.config").values.grep_previewer(opts),
  --             --   default_selection_index = default_selection_idx,
  --             --   attach_mappings = function(_, map)
  --             --     map({ "i", "n" }, "<C-d>", Actions.delete_buffer(opts), { desc = "delete buffer" })
  --             --     map("n", "m", Actions.toggle_tag(opts), { desc = "toggle tag" })
  --             --     map("n", "dd", Actions.delete_buffer(opts), { desc = "delete buffer" })
  --             --     map(
  --             --       "n",
  --             --       "<space>",
  --             --       telescope_actions.move_selection_next,
  --             --       { desc = "move selection next", nowait = true }
  --             --     )
  --             --     map("n", "<A-k>", Actions.move_up(opts), { desc = "move buffer up" })
  --             --     -- <A-k> on macos emits "˚"
  --             --     map("n", "˚", Actions.move_up(opts), { desc = "move buffer up" })
  --             --     map("n", "<A-j>", Actions.move_down(opts), { desc = "move buffer down" })
  --             --     -- <A-j> on macos emits "∆"
  --             --     map("n", "∆", Actions.move_down(opts), { desc = "move buffer down" })
  --             --     return true
  --             --   end,
  --             -- })
  --             --
  --             -- picker:find()
  --           end,
  --         },
  --       })
  --
  --       telescope.load_extension("switch")
  --     end)
  --   end,
  -- },
  -- {
  --   "nvim-telescope/telescope.nvim",
  --   keys = {
  --     { "<leader><space>", "<cmd>Telescope switch<CR>", desc = "Switch Buffer" },
  --   },
  --   opts = {
  --     extensions = {
  --       switch = {
  --         theme = "dropdown",
  --         sort_mru = true,
  --         select_current = false,
  --         previewer = false,
  --
  --         -- FIXME: why don't these mappings get applied?
  --         -- mappings = {
  --         --   i = {
  --         --     ["<C-d>"] = actions.delete_buffer,
  --         --   },
  --         --   n = {
  --         --     ["d"] = actions.delete_buffer,
  --         --   },
  --         -- },
  --       },
  --     },
  --   },
  -- },
}
