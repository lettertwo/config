local specifier = "occurrence"
local is_plugin_dir = vim.loop.cwd():find("occurrence.nvim", 1, true) ~= nil

if is_plugin_dir then
  vim.notify(
    "Loading occurrence.nvim in dev mode from local development path: " .. vim.loop.cwd(),
    vim.log.levels.DEBUG
  )
  specifier = "occurrence.dev"
end

-- Virtualtext for occurrence status
local ns = vim.api.nvim_create_namespace("occurrence_virtualtext")
local last_status = { buf = -1, line = -1, text = "" }

local function update_virtualtext()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  -- Get occurrence status for marked occurrences only
  local status_ok, status = pcall(require("occurrence").status, { marked = true })
  ---@cast status occurrence.Status?

  -- Clear virtualtext from previous location
  if last_status.buf ~= -1 and vim.api.nvim_buf_is_valid(last_status.buf) then
    vim.api.nvim_buf_clear_namespace(last_status.buf, ns, 0, -1)
  end

  -- If no marked occurrences, clear and return
  if not status_ok or not status or status.total == 0 then
    last_status = { buf = -1, line = -1, text = "" }
    return
  end

  -- Format the status text
  local text = string.format("[%d/%d]", status.current, math.min(status.total, 999))

  -- Only update if something changed
  if last_status.buf == buf and last_status.line == line and last_status.text == text then
    return
  end

  -- Set virtualtext at end of line
  vim.api.nvim_buf_set_extmark(buf, ns, line, 0, {
    virt_text = { { text, "Comment" } },
    virt_text_pos = "eol",
    priority = 100,
  })

  last_status = { buf = buf, line = line, text = text }
end

local function clear_virtualtext()
  if last_status.buf ~= -1 and vim.api.nvim_buf_is_valid(last_status.buf) then
    vim.api.nvim_buf_clear_namespace(last_status.buf, ns, 0, -1)
  end
  last_status = { buf = -1, line = -1, text = "" }
end

return {
  {
    "lettertwo/occurrence.nvim",
    dir = is_plugin_dir and vim.loop.cwd() or nil,
    ---@module "occurrence"
    ---@type occurrence.Options
    opts = {
      keymaps = {
        ["dd"] = {
          mode = "n",
          desc = "Delete marked occurrences on line",
          callback = function(occ)
            local range = require("occurrence.Range").of_line()
            occ:apply_operator("delete", { motion = range, motion_type = "line" })
          end,
        },
        ["D"] = {
          mode = { "n", "v" },
          desc = "Delete marked occurrences from cursor to end of line",
          callback = function(occ)
            occ:apply_operator("delete", { motion = "$" })
          end,
        },
        ["cc"] = {
          mode = "n",
          desc = "Change marked occurrences on line",
          callback = function(occ)
            local range = require("occurrence.Range").of_line()
            occ:apply_operator("change", { motion = range, motion_type = "line" })
          end,
        },
        ["C"] = {
          mode = { "n", "v" },
          desc = "Change marked occurrences from cursor to end of line",
          callback = function(occ)
            occ:apply_operator("change", { motion = "$" })
          end,
        },
      },
      operators = {
        ["<C-q>"] = {
          desc = "Send marked occurrences to quickfix list",
          operator = function(current, ctx)
            local start = current.range.start:to_pos()
            local stop = current.range.stop:to_pos()
            local item = {
              bufnr = ctx.occurrence.buffer,
              lnum = start[1],
              col = start[2],
              text = table.concat(vim.api.nvim_buf_get_lines(ctx.occurrence.buffer, start[1] - 1, stop[1], false), " "),
            }
            vim.fn.setqflist({}, "a", { title = "Occurrences", items = { item } })
            if current.index >= #ctx.marks then
              vim.cmd.copen()
            end
          end,
        },
      },
    },
    ---@module "lazy"
    ---@type fun(plugin: LazyPlugin, opts: occurrence.Options)
    config = function(plugin, opts)
      local occurrence = require(specifier)
      occurrence.setup(opts)

      local augroup = vim.api.nvim_create_augroup("OccurrenceVirtualtext", { clear = true })

      -- Update virtualtext on occurrence changes
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        pattern = "OccurrenceUpdate",
        callback = update_virtualtext,
      })

      -- Also update virtualtext on cursor movement
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = augroup,
        callback = update_virtualtext,
      })

      -- Clear virtualtext on occurrence disposal
      vim.api.nvim_create_autocmd("User", {
        group = augroup,
        pattern = "OccurrenceDispose",
        callback = clear_virtualtext,
      })
    end,
  },

  {
    "jake-stewart/multicursor.nvim",
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
            end
            return function(done)
              -- Get updated range, as we've been modifying the buffer.
              local range = assert(ctx.occurrence.extmarks:get_mark(current.id))
              vim.api.nvim_buf_set_text(
                ctx.occurrence.buffer,
                range.start.line,
                range.start.col,
                range.stop.line,
                range.stop.col,
                {}
              )
              ctx.mc.action(function(cursors)
                if current.index == 1 then
                  cursors:mainCursor():setPos(range.start:to_pos())
                else
                  cursors:addCursor():setPos(range.start:to_pos())
                end
                if current.index >= #ctx.marks then
                  vim.schedule(function()
                    ctx.occurrence:dispose()
                    vim.cmd.startinsert()
                  end)
                end
                done(true)
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

  {
    "nvim-mini/mini.surround",
    optional = true,
    opts = {
      operators = {
        ["gs"] = {
          desc = "Surround marked occurrences",
          before = function(marks, ctx)
            local ok, mini_surround = pcall(require, "mini.surround")
            if not ok then
              vim.notify("mini.surround not found", vim.log.levels.WARN)
              return false
            end

            -- HACK: Access mini.surround's internals via debug
            local H = nil
            local info = debug.getinfo(mini_surround.add, "u")
            for i = 1, info.nups do
              local name, value = debug.getupvalue(mini_surround.add, i)
              if name == "H" and type(value) == "table" then
                H = value
                break
              end
            end

            if not H or not H.get_surround_spec then
              vim.notify("Could not access mini.surround internals", vim.log.levels.WARN)
              return false
            end

            ---@diagnostic disable-next-line: redefined-local
            local ok, surr_info = pcall(H.get_surround_spec, "output")

            if not ok or not surr_info or not surr_info.left or not surr_info.right then
              vim.notify("Invalid surround specification", vim.log.levels.WARN)
              return false
            end

            -- Store in context for operator to use
            ctx.surr_info = surr_info
            ctx.respect_selection_type = mini_surround.config.respect_selection_type
          end,
          operator = function(current, ctx)
            if not ctx.surr_info then
              return false
            end
            ctx.register = nil -- Don't yank replaced text to register
            if ctx.respect_selection_type then
              return vim.tbl_map(function(line)
                return ctx.surr_info.left .. line .. ctx.surr_info.right
              end, current.text)
            else
              return ctx.surr_info.left .. table.concat(current.text, "\n") .. ctx.surr_info.right
            end
          end,
        },
      },
    },
  },

  {
    "folke/snacks.nvim",
    optional = true,
    keys = {
      {
        "<leader>so",
        function()
          Snacks.picker.pick("occurrences")
        end,
        desc = "Occurrences",
        mode = { "n", "v" },
      },
    },
    opts = {
      ---@type snacks.picker.sources.Config
      sources = {
        occurrences = {
          title = "Select Occurrences",
          layout = {
            preview = "main",
            preset = "ivy",
          },
          finder = function(_, ctx)
            local occ = require("occurrence").get(ctx.filter.current_buf)
            if not occ then
              return {}
            end

            local selection_range = nil
            if ctx.picker.visual and ctx.picker.visual.pos and ctx.picker.visual.end_pos then
              local start = require("occurrence.Location").from_markpos(ctx.picker.visual.pos)
              local stop = require("occurrence.Location").from_markpos(ctx.picker.visual.end_pos)
              if start and stop then
                selection_range = require("occurrence.Range").new(start, stop)
              end
            end

            local highlights =
              require("snacks.picker.util.highlight").get_highlights({ buf = occ.buffer, extmarks = true })

            ---@type snacks.picker.finder.Item[]
            local items = {}
            for match in occ:matches(selection_range) do
              local start = match.start:to_pos()
              local stop = match.stop:to_pos()
              local text = table.concat(vim.api.nvim_buf_get_lines(occ.buffer, start[1] - 1, stop[1], false), " ")
              table.insert(items, {
                pos = start,
                end_pos = stop,
                buf = occ.buffer,
                text = text,
                highlights = highlights[start[1]],
                match = match,
                marked = occ.extmarks:has_mark(match),
              })
            end
            return items
          end,
          sort = { fields = { "score:desc", "idx" } },
          format = function(item)
            local ret = {} ---@type snacks.picker.Highlight[]
            local line_count = vim.api.nvim_buf_line_count(item.buf)
            local idx = Snacks.picker.util.align(tostring(item.pos[1]), #tostring(line_count), { align = "right" })
            ret[#ret + 1] = { idx, "LineNr", virtual = true }
            ret[#ret + 1] = { "  ", virtual = true }
            ret[#ret + 1] = { item.text }

            local offset = #idx + 2

            for _, extmark in ipairs(item.highlights or {}) do
              extmark = vim.deepcopy(extmark)
              if type(extmark[1]) ~= "string" then
                ---@cast extmark snacks.picker.Extmark
                extmark.col = extmark.col + offset
                if extmark.end_col then
                  extmark.end_col = extmark.end_col + offset
                end
              end
              ret[#ret + 1] = extmark
            end
            return ret
          end,
          on_show = function(picker)
            for _, item in ipairs(picker:items()) do
              if item.marked then
                picker.list:select(item)
              end
            end
          end,
          confirm = function(picker)
            picker:close()
            local ctx = picker.finder:ctx(picker)
            local occ = assert(require("occurrence").get(ctx.filter.current_buf))
            occ:unmark_all()
            for _, item in ipairs(picker:items()) do
              if picker.list:is_selected(item) and item.match then
                occ:mark(item.match)
              end
            end
          end,
        },
      },
    },
  },
}
