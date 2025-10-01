return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "BufReadPost",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      -- set("x", "I", mc.insertVisual)
      -- set("x", "A", mc.appendVisual)
      -- set("x", "c", function()
      --   -- perform default change operation
      --   vim.api.nvim_feedkeys("c", "n", true)
      --   -- local visual_key = vim.api.nvim_replace_termcodes("<C-v>", true, false, true)
      --   -- in visual block mode restore selection and add cursors
      --   if vim.fn.mode() == "" then
      --     vim.cmd("normal! gv")
      --     mc.insertVisual()
      --   end
      -- end)

      -- set({ "n", "x" }, "go", function()
      --   mc.matchAllAddCursors()
      --   mc.disableCursors()
      -- end, { desc = "Mark occurrences of word under cursor" })

      -- ---@type string keymap to change occurrences of the word under cursor. Default is 'co'.
      -- change = "co",
      -- set({ "n", "x" }, "co", mc.addCursorOperatorVisual)
      -- ---@type string keymap to change occurrences of the word under cursor in the line. Default is 'coo'.
      -- change_line = "coo",
      -- set({ "n", "x" }, "coo", mc.addCursorOperatorVisual)
      -- ---@type string keymap to delete occurrences of the word under cursor. Default is 'do'.
      -- delete = "do",
      -- set({ "n", "x" }, "do", mc.addCursorOperatorVisual)
      -- ---@type string keymap to delete occurrences of the word under cursor in the line. Default is 'doo'.
      -- delete_line = "doo",
      -- set({ "n", "x" }, "doo", mc.addCursorOperatorVisual)
      -- -- TODO: support individual config for operators.
      -- -- |y|	y	yank into register (does not change the text)
      -- -- |~|	~	swap case (only if 'tildeop' is set)
      -- -- |g~|	g~	swap case
      -- -- |gu|	gu	make lowercase
      -- -- |gU|	gU	make uppercase
      -- -- |!|	!	filter through an external program
      -- -- |=|	=	filter through 'equalprg' or C-indenting if empty
      -- -- |gq|	gq	text formatting
      -- -- |gw|	gw	text formatting with no cursor movement
      -- -- |g?|	g?	ROT13 encoding
      -- -- |>|	>	shift right
      -- -- |<|	<	shift left
      -- -- |zf|	zf	define a fold
      -- -- |g@|	g@	call function set with the 'operatorfunc' option

      -- Add or skip cursor above/below the main cursor.
      -- set({ "n", "x" }, "<up>", function()
      --   mc.lineAddCursor(-1)
      -- end)
      -- set({ "n", "x" }, "<down>", function()
      --   mc.lineAddCursor(1)
      -- end)
      -- set({ "n", "x" }, "<leader><up>", function()
      --   mc.lineSkipCursor(-1)
      -- end)
      -- set({ "n", "x" }, "<leader><down>", function()
      --   mc.lineSkipCursor(1)
      -- end)

      -- Add or skip adding a new cursor by matching word/selection
      -- set({ "n", "x" }, "<leader>n", function()
      --   mc.matchAddCursor(1)
      -- end)
      -- set({ "n", "x" }, "<leader>s", function()
      --   mc.matchSkipCursor(1)
      -- end)
      -- set({ "n", "x" }, "<leader>N", function()
      --   mc.matchAddCursor(-1)
      -- end)
      -- set({ "n", "x" }, "<leader>S", function()
      --   mc.matchSkipCursor(-1)
      -- end)

      -- Mappings defined in a keymap layer only apply when there are
      -- multiple cursors. This lets you have overlapping mappings.
      mc.addKeymapLayer(function(layerSet)
        -- layerSet("n", "V", function()
        --   mc.disableCursors()
        -- end, { desc = "Prev cursor" })

        layerSet("n", "N", function()
          mc.prevCursor(true)
        end, { desc = "Prev cursor" })

        layerSet("n", "n", function()
          mc.nextCursor(true)
        end, { desc = "Next cursor" })

        layerSet("n", "gn", function()
          mc.matchAddCursor(1)
        end, { desc = "Add cursor at next match" })

        layerSet("n", "gN", function()
          mc.matchAddCursor(-1)
        end, { desc = "Add cursor at prev match" })

        layerSet("n", "go", function()
          if mc.cursorsEnabled() then
            mc.disableCursors()
          end
          mc.toggleCursor()
        end, { desc = "toggle cursor" })

        -- layerSet("n", "gO", function()
        --   local enabled = mc.cursorsEnabled()
        --   if enabled then
        --     mc.disableCursors()
        --   end
        --   mc.toggleCursor()
        --   mc.prevCursor(true)
        --   if enabled then
        --     mc.enableCursors()
        --   end
        -- end, { desc = "toggle cursor and move to prev" })

        -- Enable and clear cursors using escape.
        layerSet("n", "<esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)

      -- Customize how cursors look.
      local hl = vim.api.nvim_set_hl
      -- hl(0, "MultiCursorCursor", { reverse = true })
      -- hl(0, "MultiCursorVisual", { link = "Visual" })
      -- hl(0, "MultiCursorMatchPreview", { link = "Error" })
      hl(0, "MultiCursorDisabledCursor", { link = "Search" })
      -- hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
      hl(0, "MultiCursorSign", { link = "Normal" })
      -- hl(0, "MultiCursorMainSign", { link = "Normal" })
      -- hl(0, "MultiCursorDisabledSign", { link = "Normal" })
    end,
  },
}
