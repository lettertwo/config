---@module "lazy"
---@type LazyPluginSpec[]
return {
  {
    "fnune/recall.nvim",
    dependencies = { "folke/snacks.nvim" },
    event = "VeryLazy",
    cmd = {
      -- wrapped
      "RecallMark",
      "RecallUnmark",
      "RecallToggle",
      "RecallNext",
      "RecallPrevious",
      "RecallClear",

      -- custom
      "RecallNextBuffer",
      "RecallPreviousBuffer",
      "RecallClearBuffer",
      "RecallToggleBuffer",
      "RecallCloseUnmarkedBuffers",
      "RecallDeleteAndUnmarkBuffer",
      "RecallDeleteAndUnmarkOthers",
    },
    keys = {
      { "<leader>m", "<cmd>RecallToggleBuffer<cr>", desc = "Toggle mark" },
      { "<leader>M", "<cmd>RecallClearBuffer<cr>", desc = "Clear buffer marks" },
      { "<C-m>", "<cmd>RecallToggle<cr>", desc = "Toggle mark" },
      { "L", "<cmd>RecallNextBuffer<cr>", desc = "Next marked buffer" },
      { "H", "<cmd>RecallPreviousBuffer<cr>", desc = "Previous marked buffer" },
      { "<leader>bc", "<cmd>RecallCloseUnmarkedBuffers<cr>", desc = "Close unmarked buffers" },
      { "<leader>bm", "<cmd>RecallClearBuffer<cr>", desc = "Clear buffer marks" },
      { "<leader>bM", "<cmd>RecallClear<cr>", desc = "Clear all marks" },
      { "<leader>bd", "<cmd>RecallDeleteAndUnmarkBuffer<cr>", desc = "Delete and unmark buffer" },
      { "<leader>bo", "<cmd>RecallDeleteAndUnmarkOthers<cr>", desc = "Delete and unmark others" },
    },
    config = function(_, opts)
      require("recall").setup(vim.tbl_deep_extend("force", {}, opts or {}, {
        sign = LazyVim.config.icons.tag,
        sign_highlight = "@tag",
      }))

      local recall_util = require("plugins.editor.recall.util")

      -- Wrapped Commands
      -- stylua: ignore start
      vim.api.nvim_create_user_command("RecallMark",     function() recall_util.mark() end, {})
      vim.api.nvim_create_user_command("RecallUnmark",   function() recall_util.unmark() end, {})
      vim.api.nvim_create_user_command("RecallToggle",   function() recall_util.toggle() end, {})
      vim.api.nvim_create_user_command("RecallNext",     function() recall_util.goto_next() end, {})
      vim.api.nvim_create_user_command("RecallPrevious", function() recall_util.goto_prev() end, {})
      vim.api.nvim_create_user_command("RecallClear",    function() recall_util.clear() end, {})
      -- stylua: ignore end

      vim.api.nvim_create_user_command("RecallNextBuffer", function()
        local current_file = recall_util.normalize_filepath(0)
        local marked_files = recall_util.iter_marked_files()
        local next_file = marked_files:next()
        local saw_current_file = next_file == current_file
        next_file = marked_files:find(function(file)
          if saw_current_file then
            return true
          elseif file == current_file then
            saw_current_file = true
          end
        end) or next_file
        if next_file then
          vim.cmd.edit(next_file)
        else
          vim.notify("No marked buffers found", vim.log.levels.WARN)
        end
      end, {})

      vim.api.nvim_create_user_command("RecallPreviousBuffer", function()
        local current_file = recall_util.normalize_filepath(0)
        local marked_files = recall_util.iter_marked_files():rev()
        local prev_file = marked_files:next()
        local saw_current_file = prev_file == current_file
        prev_file = marked_files:find(function(file)
          if saw_current_file then
            return true
          elseif file == current_file then
            saw_current_file = true
          end
        end) or prev_file
        if prev_file then
          vim.cmd.edit(prev_file)
        else
          vim.notify("No marked buffers found", vim.log.levels.WARN)
        end
      end, {})

      vim.api.nvim_create_user_command("RecallClearBuffer", function()
        recall_util.unmark(0)
      end, {})

      vim.api.nvim_create_user_command("RecallToggleBuffer", function()
        recall_util.toggle(0)
      end, {})

      ---Close all buffers that don't have marks
      vim.api.nvim_create_user_command("RecallCloseUnmarkedBuffers", function()
        local marks = recall_util.get_all_marks()
        if not marks or #marks == 0 then
          vim.notify("No marks found", vim.log.levels.WARN)
          return
        end

        local marked_paths = {}
        for _, mark in ipairs(marks) do
          marked_paths[mark.file] = true
        end

        Snacks.bufdelete.delete({
          filter = function(bufnr)
            local should_close = vim.api.nvim_buf_is_valid(bufnr)
              and vim.fn.buflisted(bufnr) >= 1
              and marked_paths[vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))] == nil
            if should_close then
              vim.print("Closing buffer: " .. vim.api.nvim_buf_get_name(bufnr))
            end
            return should_close
          end,
        })
      end, {})

      -- Command: Delete buffer and remove its mark
      vim.api.nvim_create_user_command("RecallDeleteAndUnmarkBuffer", function()
        recall_util.unmark()
        Snacks.bufdelete.delete()
      end, {})

      -- Command: Delete all other buffers and remove their marks
      vim.api.nvim_create_user_command("RecallDeleteAndUnmarkOthers", function()
        Snacks.bufdelete.delete({
          filter = function(b)
            if b == vim.api.nvim_get_current_buf() then
              return false
            end

            if recall_util.has_marks(b) then
              -- Switch to buffer to unmark it
              local current_buf = vim.api.nvim_get_current_buf()
              vim.api.nvim_set_current_buf(b)
              recall_util.unmark()
              vim.api.nvim_set_current_buf(current_buf)
            end

            return true
          end,
        })
      end, {})

      vim.api.nvim_create_autocmd("User", {
        pattern = "RecallUpdate",
        callback = function()
          vim.schedule(vim.cmd.redraw)
        end,
      })
    end,
    specs = {
      {
        "nvim-mini/mini.files",
        optional = true,
        opts = function()
          local ns_mini_files_recall = vim.api.nvim_create_namespace("mini_files_recall")
          local MiniFiles = require("mini.files")
          local recall = require("plugins.editor.recall.util")
          local group = vim.api.nvim_create_augroup("mini_files_recall_integration", { clear = true })

          local function toggle_mark()
            local entry = MiniFiles.get_fs_entry()
            if entry ~= nil and entry.path ~= nil and entry.fs_type == "file" then
              -- Toggle mark without opening the buffer
              recall.toggle(entry.path)
              --- HACK: `force = true` is not documented
              --- but has the effect of forcing a refresh.
              MiniFiles.refresh({ content = { force = true } })
            end
          end

          local function update_extmarks(buf_id)
            local marked_files = recall.iter_marked_files():totable() or nil
            if marked_files and #marked_files then
              -- Update extmarks for each file entry
              for i = 1, vim.api.nvim_buf_line_count(buf_id) do
                local entry = MiniFiles.get_fs_entry(buf_id, i)
                if not entry or not entry.path then
                  break
                end

                local normalized_path = recall.normalize_filepath(entry.path)
                if vim.list_contains(marked_files, normalized_path) then
                  vim.api.nvim_buf_set_extmark(buf_id, ns_mini_files_recall, i - 1, 0, {
                    virt_text = { { LazyVim.config.icons.tag, "@tag" } },
                    virt_text_pos = "right_align",
                    hl_mode = "combine",
                  })
                end
              end
            end
          end

          vim.api.nvim_create_autocmd("User", {
            pattern = "MiniFilesBufferCreate",
            group = group,
            callback = function(args)
              if args.data.buf_id ~= nil then
                vim.keymap.set("n", "<C-m>", toggle_mark, { desc = "Toggle mark", buffer = args.data.buf_id })
              end
            end,
          })

          vim.api.nvim_create_autocmd("User", {
            pattern = "MiniFilesBufferUpdate",
            group = group,
            callback = function(args)
              if args.data.buf_id ~= nil then
                update_extmarks(args.data.buf_id)
              end
            end,
          })
        end,
      },
      {
        "lewis6991/satellite.nvim",
        optional = true,
        opts = function(_, opts)
          ---@module "satellite"
          ---@class RecallHandler: Satellite.Handler
          local RecallHandler = {
            name = "recall_marks",
            config = {
              enable = true,
              overlap = true,
              priority = 100,
            },
          }

          function RecallHandler.setup(config, update)
            RecallHandler.config = vim.tbl_deep_extend("force", RecallHandler.config, config or {})
            vim.api.nvim_create_autocmd("User", {
              group = vim.api.nvim_create_augroup("satellite_recall_marks", {}),
              pattern = "RecallUpdate",
              callback = vim.schedule_wrap(update),
            })
          end

          ---@param bufnr number
          ---@param winid number
          ---@return Satellite.Mark[]
          function RecallHandler.update(bufnr, winid)
            if not vim.api.nvim_buf_is_valid(bufnr) then
              return {}
            end

            return require("plugins.editor.recall.util")
              .iter_marks(bufnr)
              :map(function(mark)
                local line = mark.pos and mark.pos[1] or 1
                return {
                  pos = require("satellite.util").row_to_barpos(winid, line - 1),
                  highlight = "@tag",
                  symbol = LazyVim.config.icons.tag,
                }
              end)
              :totable()
          end

          require("satellite.handlers").register(RecallHandler)

          return vim.tbl_deep_extend("force", opts or {}, {
            handlers = {
              recall_marks = { enable = true },
            },
          })
        end,
      },
      {
        "nvim-lualine/lualine.nvim",
        optional = true,
        event = "VeryLazy",
        opts = function(_, opts)
          local filetype = require("plugins.ui.lualine.components").filetype
          local Util = require("util")
          local _, recall_util = pcall(require, "plugins.editor.recall.util")

          local Buffer = require("lualine.utils.class"):extend()

          ---@class BufferProps
          ---@field current boolean?
          ---@field aftercurrent boolean?
          ---@field beforecurrent boolean?
          ---@field first boolean?
          ---@field last boolean?
          ---@field disambiguate boolean?

          ---@class BufferOpts
          ---@field bufnr number
          ---@field tag number?
          ---@field options table
          ---@field highlights table

          function Buffer:init(opts)
            assert(opts.bufnr, "Cannot create Buffer without bufnr")
            self.bufnr = opts.bufnr
            self.tag = opts.tag
            self.options = opts.options
            self.highlights = opts.highlights

            if vim.api.nvim_buf_is_valid(self.bufnr) then
              self.file = require("lualine.utils.utils").stl_escape(vim.api.nvim_buf_get_name(self.bufnr))
              self.buftype = vim.api.nvim_get_option_value("buftype", { buf = self.bufnr })
              self.filetype = vim.api.nvim_get_option_value("filetype", { buf = self.bufnr })
              self.modified = vim.api.nvim_get_option_value("modified", { buf = self.bufnr })
              self.icon = require("mini.icons").get("file", self.file)
            end
          end

          ---@param props BufferProps
          function Buffer:name(props)
            local name = {}

            if self.tag then
              table.insert(name, tostring(self.tag))
            end

            if props.current then
              table.insert(name, self.icon)
              table.insert(name, Util.title_path(self.file, { disambiguate = props.disambiguate }))
            elseif #name == 0 then
              table.insert(name, Util.title_path(self.file, { disambiguate = props.disambiguate }))
            end

            return table.concat(name, " ")
          end

          function Buffer:is_current()
            local current_bufnr = vim.api.nvim_get_current_buf()
            return self.bufnr == current_bufnr
          end

          ---returns line configured for handling mouse click
          ---@param name string
          ---@return string
          function Buffer:configure_mouse_click(name)
            if not _G.SwitchBuffer then
              function _G.SwitchBuffer(bufnr, _, mousebutton)
                if mousebutton == nil or mousebutton == "l" then
                  vim.api.nvim_set_current_buf(bufnr)
                end
              end
            end

            return string.format("%%%s@v:lua.SwitchBuffer@%s%%X", self.bufnr, name)
          end

          ---apply separator before current buffer
          ---@param props BufferProps
          ---@return string
          function Buffer:separator_before(props)
            if props.current or props.aftercurrent then
              return "%Z{" .. self.options.section_separators.left .. "}"
            else
              return self.options.component_separators.left
            end
          end

          ---apply separator after current buffer
          ---@param props BufferProps
          ---@return string
          function Buffer:separator_after(props)
            if props.current or props.beforecurrent then
              return "%z{" .. self.options.section_separators.right .. "}"
            else
              return self.options.component_separators.right
            end
          end

          ---adds spaces to left and right
          function Buffer.apply_padding(str, padding)
            local l_padding, r_padding = 1, 1
            if type(padding) == "number" then
              l_padding, r_padding = padding, padding
            elseif type(padding) == "table" then
              l_padding, r_padding = padding.left or 0, padding.right or 0
            end
            return string.rep(" ", l_padding) .. str .. string.rep(" ", r_padding)
          end

          ---@param props BufferProps
          ---@return string
          function Buffer:render(props)
            local name = self:name(props)

            name = Buffer.apply_padding(name, self.options.padding)
            self.len = vim.fn.strchars(name)

            -- setup for mouse clicks
            local line = self:configure_mouse_click(name)

            -- apply highlight
            line = require("lualine.highlight").component_format_highlight(
              self.highlights[(props.current and "active" or "inactive")]
            ) .. line

            -- apply separators
            if self.options.self.section < "x" and not props.first then
              local sep_before = self:separator_before(props)
              line = sep_before .. line
              self.len = self.len + vim.fn.strchars(sep_before)
            elseif self.options.self.section >= "x" and not props.last then
              local sep_after = self:separator_after(props)
              line = line .. sep_after
              self.len = self.len + vim.fn.strchars(sep_after)
            end

            return line
          end

          ---@param section string
          ---@param is_active boolean
          ---@return string hl name
          local function get_hl(section, is_active)
            local highlight = require("lualine.highlight")
            local suffix = is_active and highlight.get_mode_suffix() or "_inactive"
            return section .. suffix
          end

          local default_options = {}

          local RecallBuffers = require("lualine.component"):extend()

          function RecallBuffers:init(options)
            RecallBuffers.super.init(self, options)
            self.options = vim.tbl_deep_extend("keep", self.options or {}, default_options)
            self.highlights = {
              active = self:create_hl(function()
                return get_hl("lualine_" .. options.self.section, true)
              end, "active"),
              inactive = self:create_hl(get_hl("lualine_" .. options.self.section, false), "inactive"),
            }
          end

          function RecallBuffers:buffers()
            local buffers = {}
            local bufnr = vim.api.nvim_get_current_buf()
            local found_current = false

            if recall_util then
              buffers = recall_util
                .iter_marked_files()
                :enumerate()
                :map(function(tag, file)
                  local mark_bufnr = vim.fn.bufnr(file)
                  if mark_bufnr ~= -1 then
                    if mark_bufnr == bufnr then
                      found_current = true
                    end
                    return Buffer:new({
                      bufnr = mark_bufnr,
                      tag = tag,
                      options = self.options,
                      highlights = self.highlights,
                    })
                  end
                end)
                :totable()
            end

            if not found_current then
              table.insert(
                buffers,
                Buffer:new({
                  bufnr = bufnr,
                  options = self.options,
                  highlights = self.highlights,
                })
              )
            end

            return buffers
          end

          function RecallBuffers:update_status()
            local data = {}
            local buffers = self:buffers()
            local current = 0
            -- disambiguate buffers with same name
            local buffers_by_name = {}

            -- first pass: group buffers by name
            for _, buffer in ipairs(buffers) do
              local name = Util.title_path(buffer.file)
              buffers_by_name[name] = buffers_by_name[name] or {}
              table.insert(buffers_by_name[name], buffer)
            end

            -- second pass: render buffers
            for i, buffer in ipairs(buffers) do
              if current == 0 and buffer:is_current() then
                current = i
              end

              table.insert(
                data,
                buffer:render({
                  current = i == current,
                  beforecurrent = i == current - 1,
                  aftercurrent = i == current + 1,
                  first = i == 1,
                  last = i == #buffers,
                  disambiguate = #buffers_by_name[Util.title_path(buffer.file)] > 1,
                })
              )
            end

            return table.concat(data)
          end

          function RecallBuffers:draw()
            self.status = ""
            self.applied_separator = ""

            if not filetype.cond() then
              return self.status
            end
            if self.options.cond ~= nil and self.options.cond() ~= true then
              return self.status
            end
            local status = self:update_status()
            if type(status) == "string" and #status > 0 then
              self.status = status
              self:apply_section_separators()
              self:apply_separator()
            end
            return self.status
          end

          vim.api.nvim_create_autocmd("User", {
            pattern = "RecallUpdate",
            callback = function()
              require("lualine").refresh({ place = { "winbar" }, scope = "all" })
            end,
          })

          opts = opts or {}
          opts.winbar = opts.winbar or {}
          opts.winbar.lualine_a = { RecallBuffers }
          return opts
        end,
      },
    },
  },
}
