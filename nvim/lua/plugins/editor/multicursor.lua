return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "BufReadPost",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      set("x", "I", mc.insertVisual)
      set("x", "A", mc.appendVisual)

      -- Mappings defined in a keymap layer only apply when there are
      -- multiple cursors. This lets you have overlapping mappings.
      mc.addKeymapLayer(function(layerSet)
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

        layerSet("n", "gx", function()
          if mc.cursorsEnabled() then
            mc.disableCursors()
          end
          mc.toggleCursor()
        end, { desc = "toggle cursor" })

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
  {
    "lettertwo/occurrence.nvim",
    optional = true,
    opts = {
      operators = {
        ["change"] = {
          desc = "Change marked occurrences",
          before = function(marks, ctx)
            local ok, multicursor = pcall(require, "multicursor-nvim")
            if not ok then
              -- Fallback to builtin change operator
              return require("occurrence.api").change.before(marks, ctx)
            else
              ctx.mc = multicursor
            end
          end,
          operator = function(current, ctx)
            if ctx.mc == nil then
              -- Fallback to builtin change operator
              return require("occurrence.api").change.operator(current, ctx)
            else
              return {}
            end
          end,
          after = function(marks, ctx)
            if ctx.mc ~= nil then
              ctx.mc.action(function(cursors)
                for i, mark in ipairs(marks) do
                  if i == 1 then
                    cursors:mainCursor():setPos(mark[2].start:to_pos())
                  else
                    cursors:addCursor():setPos(mark[2].start:to_pos())
                  end
                end
                ctx.occurrence:dispose()
                vim.cmd.startinsert()
              end)
            end
          end,
        },
        ["I"] = {
          desc = "Add cursors at marked occurrences",
          before = function(marks, ctx)
            local ok, multicursor = pcall(require, "multicursor-nvim")
            if ok and multicursor then
              return function(done)
                multicursor.action(function(cursors)
                  for i, mark in ipairs(marks) do
                    if i == 1 then
                      cursors:mainCursor():setPos(mark[2].start:to_pos())
                    else
                      cursors:addCursor():setPos(mark[2].start:to_pos())
                    end
                  end
                  done(false)
                  ctx.occurrence:dispose()
                end)
              end
            end
            return false
          end,
          operator = function()
            return false
          end,
        },
        ["A"] = {
          desc = "Add cursors after marked occurrences",
          before = function(marks, ctx)
            local ok, multicursor = pcall(require, "multicursor-nvim")
            if ok and multicursor then
              return function(done)
                multicursor.action(function(cursors)
                  for i, mark in ipairs(marks) do
                    if i == 1 then
                      cursors:mainCursor():setPos(mark[2].stop:to_pos())
                    else
                      cursors:addCursor():setPos(mark[2].stop:to_pos())
                    end
                  end
                  done(false)
                  ctx.occurrence:dispose()
                end)
              end
            end
            return false
          end,
          operator = function()
            return false
          end,
        },
      },
    },
  },
}
