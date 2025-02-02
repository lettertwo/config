-- font: https://famfonts.com/metallica/
-- generator: https://www.twitchquotes.com/ascii-art-generator
local HEADER = {
  [[                                  ⡠                                                ⢄                                 ]],
  [[                               ⣠⣴⠟⠁                                                 ⠹⣦⣄                              ]],
  [[                            ⣀⣴⣾⠟⠁⢀⣠⡆ ⢰⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⡆    ⣀⣤⣴⣶⣶⣶⣤⣄⡀  ⢰⣶⣶⣶⣆  ⣶⣶⣶⡶ ⢰⣶⣶⣶⡆ ⢠⣤⡀⠈⠻⣷⣦⣀                           ]],
  [[                         ⣀⣴⣾⣿⡿⠁ ⢰⣿⣿⡇ ⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇  ⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦  ⣿⣿⣿⣿⡀⣸⣿⣿⣿⠇ ⢸⣿⣿⣿⡇ ⢸⣿⣿⣷⣦⣬⣿⣿⣷⣦⣄                        ]],
  [[                      ⣀⣴⣾⣿⣿⣿⣿⣧  ⢸⣿⣿⡇ ⢸⣿⣿⣿⣏⣀⣀⣀⣀⣀⣀⡀ ⣸⣿⣿⣿⣿⠟⠉⠉⠛⢿⣿⣿⣿⣷ ⠸⣿⣿⣿⣷⣿⣿⣿⡿  ⢸⣿⣿⣿⡇ ⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄                     ]],
  [[                    ⠐⠛⠉⣹⣿⣿⠟⢹⣿⣿⣇ ⢸⣿⣿⡇ ⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇ ⣿⣿⣿⣿⠃     ⢻⣿⣿⣿⡇ ⢻⣿⣿⣿⣿⣿⣿⠃  ⢸⣿⣿⣿⡇ ⢸⣿⣿⣿⣿⡙⢿⣿⠟⢿⣿⣿⣏⠉⠛⠂                   ]],
  [[                     ⢀⣼⣿⣿⠏  ⢿⣿⣿⡆⢸⣿⣿⡇ ⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇ ⣿⣿⣿⣿⡄     ⣼⣿⣿⣿⠇ ⠘⣿⣿⣿⣿⣿⡟   ⢸⣿⣿⣿⡇ ⢸⣿⣿⣿⣿⣇ ⠙ ⠈⢻⣿⣿⣧⡀                    ]],
  [[                    ⣠⣿⣿⣿⠃   ⠘⣿⣿⣿⣸⣿⣿⡇ ⢸⣿⣿⣿⣇⣀⣀⣀⣀⣀⣀⡀ ⠹⣿⣿⣿⣿⣶⣤⣤⣤⣾⣿⣿⣿⡟   ⢻⣿⣿⣿⣿⠃   ⢸⣿⣿⣿⡇ ⢸⣿⣿⣿⣿⣿⡀    ⠹⣿⣿⣿⣄                   ]],
  [[                  ⢀⣴⣿⣿⡿⠁     ⢹⣿⣿⣿⣿⣿⡇ ⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇  ⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠏    ⠈⣿⣿⣿⡟    ⢸⣿⣿⣿⡇ ⢸⣿⣿⣿⣿⣿⣇     ⠙⣿⣿⣿⣧⡀                 ]],
  [[                 ⣠⣿⣿⣿⡟⠁       ⢿⣿⣿⣿⣿⠇ ⠸⠿⠿⠿⠿⠿⠿⠿⠿⠿⠿⠃    ⠉⠛⠿⠿⠿⠿⠛⠉       ⠹⠿⠿⠃    ⠸⠿⠿⠿⠇ ⠸⣿⣿⣿⣿⣿⣿⡄     ⠈⢿⣿⣿⣿⣄                ]],
  [[               ⢀⣼⣿⣿⣿⠟         ⠘⣿⠟⠋⠁                                                ⠈⠙⢿⣿⣿⣿⣧      ⠈⢻⣿⣿⣿⣧⡀              ]],
  [[              ⣠⣿⣿⣿⣿⠏                                                                  ⠈⠛⢿⣿⡄       ⠹⣿⣿⣿⣿⣆             ]],
  [[            ⢀⣼⣿⣿⣿⣿⠃                                                                      ⠈⠃        ⠘⣿⣿⣿⣿⣧⡀           ]],
  [[           ⣠⣿⣿⣿⣿⡿⠁ ⣀⣀⣤⡴⠒                                                                      ⠐⢦⣤⣀⣀ ⠈⢿⣿⣿⣿⣿⣄          ]],
  [[         ⢀⣾⣿⣿⣿⣿⣿⣷⣿⣿⡿⠛⠁                                                                          ⠈⠛⢿⣿⣿⣶⣿⣿⣿⣿⣿⣷⡀        ]],
  [[        ⣰⣿⣿⣿⣿⣿⣿⣿⠿⠋⠁                                                                                ⠈⠙⠿⣿⣿⣿⣿⣿⣿⣿⣆       ]],
  [[      ⢀⣾⣿⣿⣿⣿⣿⠟⠋⠁                                                                                      ⠈⠙⠻⣿⣿⣿⣿⣿⣷⡀     ]],
  [[     ⣰⣿⣿⣿⡿⠟⠋                                                                                              ⠉⠻⢿⣿⣿⣿⣆    ]],
  [[   ⢀⣾⣿⡿⠛⠉                                                                                                    ⠉⠛⢿⣿⣷⡀  ]],
  [[  ⣴⡿⠛⠁                                                                                                          ⠈⠛⢿⣆ ]],
  [[⠠⠚⠁                                                                                                                ⠈⠓]],
}

local SPINNER = { "⠋ ", "⠙ ", "⠹ ", "⠸ ", "⠼ ", "⠴ ", "⠦ ", "⠧ ", "⠇ ", "⠏ " }

---@class DashboardStats
---@field nvim { version: string, commit: string }
---@field lvim { version: string, commit: string }
---@field lazy_stats LazyStats
local stats = setmetatable({}, {
  __index = function(self, key)
    if key == "lazy_stats" then
      self._lazy_stats = self._lazy_stats and self._lazy_stats.startuptime > 0 and self._lazy_stats
        or require("lazy.stats").stats()
      return self._lazy_stats
    elseif key == "lvim" then
      if not self._lvim then
        local plugin = require("lazy.core.config").plugins["LazyVim"]
        local info = require("lazy.manage.git").info(plugin.dir, true) or {}
        self._lvim = {
          version = info.tag or (info.version and tostring(info.version)) or "unknown",
          commit = info.commit and info.commit:sub(1, 7) or "",
        }
      end
      return self._lvim
    elseif key == "nvim" then
      if not self._nvim then
        local version, commit = unpack(vim.split(vim.fn.execute("version"):gsub(".*%sv([%w%p]+)\n.*", "%1"), "+"))
        self._nvim = { version = version, commit = commit and commit:sub(1, 7) or "" }
      end
      return self._nvim
    else
      return rawget(self, key)
    end
  end,
})

---@overload fun(string): string, boolean, number?
local lazy_check = setmetatable({ status = nil, pending = false }, {
  __call = function(self, desc)
    local lazy_checker = package.loaded["lazy.manage.checker"]
    if self.status == nil and not self.pending then
      self.pending = true
      lazy_checker = lazy_checker or require("lazy.manage.checker")
      lazy_checker.fast_check()
    end

    if lazy_checker and not lazy_checker.updating and not lazy_checker.running then
      self.status = #lazy_checker.updated
      self.pending = false
    end

    if self.status ~= nil and self.status > 0 then
      desc = desc .. " " .. self.status .. " " .. (self.status == 1 and "update available" or "updates available")
    end

    return desc, self.pending, self.status
  end,
})

---@overload fun(string): string, boolean, number?
local mason_check = setmetatable({ status = nil, pending = false }, {
  __call = function(self, desc)
    local mason_registry = package.loaded["mason-registry"]
    if self.status == nil and not self.pending then
      self.pending = true
      mason_registry = mason_registry or require("mason-registry")
      mason_registry.refresh(function()
        local installed_packages = mason_registry.get_installed_package_names()
        local update_count = 0
        local pending = #installed_packages
        for _, name in ipairs(installed_packages) do
          mason_registry.get_package(name):check_new_version(function(ok)
            update_count = ok and update_count + 1 or update_count
            pending = pending - 1
            if pending < 1 then
              self.status = update_count
              self.pending = false
            end
          end)
        end
      end)
    end

    if self.status ~= nil and self.status > 0 then
      desc = desc .. " " .. self.status .. " " .. (self.status == 1 and "update available" or "updates available")
    end

    return desc, self.pending, self.status
  end,
})

-- Get the character length of string.
---@see strchars
---@type fun(str: string): integer
local len = vim.fn.strchars

local trim = vim.trim

-- Get a substring of `str` starting with the character at `start`
-- and ending after `count` characters.
---@param str string
---@param start integer
---@param count? integer
---@return string
local function substr(str, start, count)
  if count == nil then
    count = len(str) - start + 1
  end
  return vim.fn.strcharpart(str, start - 1, count)
end

-- Merge `line` with `new_line`.
-- Empty spaces in `new_line` will be filled with characters from `line`.
-- For example: `merge_lines("ab def", " xy  ") -> "axydef"`
---@param line string
---@param new_line string
---@return string
local function merge_lines(line, new_line)
  local line_len = len(line)
  local result = ""
  local new_line_len = len(new_line)
  local stop = new_line_len + 1
  local old_line = substr(line, 0, stop)

  -- merge new_line into old_line
  for i = 1, new_line_len do
    local new_char = substr(new_line, i, 1)
    if new_char == " " and i < stop then
      new_char = substr(old_line, i, 1)
    end
    result = result .. new_char
  end

  if stop <= line_len then
    result = result .. substr(line, stop)
  end
  return result
end

local function get_indent(dashboard, text)
  local text_width = len(text)
  local indent = dashboard.col or 1
  if text_width > dashboard.opts.width then
    indent = indent - (text_width - dashboard.opts.width) / 2
  end
  -- return text_width % 2 == 1 and math.floor(indent) or math.ceil(indent)
  return math.floor(indent)
end

local function get_embed_space(text)
  local max = len(text)
  if max < 3 then
    return 0
  end

  local i = math.floor(len(text) / 2)
  local j = i + 1
  local found_i = false
  local found_j = false

  while i > 1 or j < max do
    if not found_i and substr(text, i, 1) == " " then
      i = math.max(i - 1, 1)
    else
      found_i = true
    end

    if not found_j and substr(text, j, 1) == " " then
      j = math.min(j + 1, max)
    else
      found_j = true
    end

    if found_i and found_j then
      break
    end
  end

  return j - i - 1
end

return {
  {
    "folke/snacks.nvim",
    cmd = { "Dashboard" },
    keys = { { "<leader>;", "<cmd>Dashboard<cr>" } },
    opts = function(_, opts)
      local Snacks = require("snacks")

      -- The default zindex for the dashboard is 10, but some UI elements
      -- (e.g., satellite scrollbars) have a higher default.
      Snacks.config.style("dashboard", { zindex = 99 })

      -- TODO: Compute steps from SnacksDashboardHeader* groups?
      local steps = 20
      local ratio = steps / #HEADER
      local function get_header_hl_group(row)
        return "SnacksDashboardHeader" .. math.min(steps, math.max(1, math.floor(row * ratio)))
      end

      local original_render_buf = Snacks.dashboard.Dashboard.render_buf
      Snacks.dashboard.Dashboard.render_buf = function(self, original_extmarks)
        local lines = {}
        local extmarks = {}

        -- Scan header lines from the bottom to find the first header line
        -- that has enough space to start embedding dashboard lines.
        local first_embeddable_header_index
        for header_index, header_text in vim.iter(HEADER):rev():enumerate() do
          if get_embed_space(header_text) >= self.opts.width + 2 then
            first_embeddable_header_index = header_index + 1
          else
            break
          end
        end

        for line_index, line in ipairs(self.lines) do
          if len(trim(line)) > self.opts.width then
            first_embeddable_header_index = #HEADER + 1 - line_index
            break
          end
        end

        first_embeddable_header_index = first_embeddable_header_index or #HEADER + 1

        local line_index = self.row + 1
        for header_index, header_text in ipairs(HEADER) do
          local header_col = get_indent(self, header_text)
          local header_line = header_text
          if header_col > 0 then
            header_line = (" "):rep(header_col) .. header_line
          elseif header_col < 0 then
            header_line = substr(header_line, -header_col)
            header_col = 0
          end

          local header_hl_group = get_header_hl_group(header_index)

          local header_row = header_index - 1
          local header_extmark = {
            row = header_row,
            col = header_col,
            opts = { hl_group = header_hl_group, end_col = #header_line },
          }

          table.insert(lines, header_line)
          table.insert(extmarks, header_extmark)

          if line_index < #self.lines and header_index >= first_embeddable_header_index then
            local embed_line = self.lines[line_index]
            local embed_row = line_index - self.row - 1
            line_index = line_index + 1

            if embed_line then
              header_line = merge_lines(header_line, embed_line)
              lines[header_index] = header_line

              header_extmark.opts.end_col = #header_line

              -- extract extmarks for the embedded line
              original_extmarks = vim.tbl_filter(function(extmark)
                if extmark.row == embed_row then
                  local col = vim.fn.byteidx(header_line, vim.fn.charidx(embed_line, extmark.col))
                  table.insert(extmarks, {
                    row = header_row,
                    col = col,
                    opts = {
                      hl_group = extmark.opts.hl_group,
                      end_col = col + extmark.opts.end_col - extmark.col,
                    },
                  })
                end
                return extmark.row > embed_row
              end, original_extmarks)
            end
          end
        end

        for _, extmark in ipairs(original_extmarks) do
          table.insert(extmarks, {
            row = extmark.row + first_embeddable_header_index - 1,
            col = extmark.col,
            opts = extmark.opts,
          })
        end

        -- offset item cursor rows to align with the first embedded line index.
        for _, item in ipairs(self.items) do
          ---@diagnostic disable-next-line: invisible
          if item._ then
            ---@diagnostic disable-next-line: invisible
            item._.row = item._.row + first_embeddable_header_index - 1
          end
        end

        self.lines = vim.list_extend(lines, vim.list_slice(self.lines, line_index))
        -- insert empty lines corresponding to the `row` option.
        self.lines = vim.list_extend(vim.split((" "):rep(self.row - 1), " "), self.lines)

        original_render_buf(self, extmarks)
      end

      function Snacks.dashboard.sections.tasks()
        return {
          align = "left",
          {
            text = {
              { "󰄰  TODO: Implement tasks section", hl = "TaskFgTODO" },
            },
          },
        }
      end

      function Snacks.dashboard.sections.stats()
        return {
          align = "center",
          {
            text = {
              { " Neovim ", hl = "footer" },
              { stats.nvim.version, hl = "special" },
              { " " },
              { stats.nvim.commit, hl = "footer" },
            },
          },
          {
            text = {
              { " LazyVim ", hl = "footer" },
              { stats.lvim.version, hl = "special" },
              { " " },
              { stats.lvim.commit, hl = "footer" },
            },
          },
          {
            text = {
              { "loaded ", hl = "footer" },
              { stats.lazy_stats.loaded .. "/" .. stats.lazy_stats.count, hl = "special" },
              { " plugins in ", hl = "footer" },
              { (math.floor(stats.lazy_stats.startuptime * 100 + 0.5) / 100) .. "ms", hl = "special" },
            },
          },
        }
      end

      -- Frame counter for animating the spinner while waiting for updates.
      local frame = 1
      -- Whether any live sections are pending updates.
      local live_pending = false

      ---@class LiveSectionOptions
      ---@field key string
      ---@field action string
      ---@field icon string
      ---@field desc string
      ---@field check fun(string): string, boolean, number?

      ---@param live_options LiveSectionOptions
      function Snacks.dashboard.sections.live(live_options)
        local updated_desc, pending, status = live_options.check(live_options.desc)
        live_pending = pending or live_pending
        return {
          key = live_options.key,
          action = live_options.action,
          icon = pending and { SPINNER[frame], hl = "footer" } or live_options.icon,
          desc = updated_desc and { updated_desc, hl = pending and "footer" or (status > 0 and "special" or nil) }
            or live_options.desc,
        }
      end

      local dashboard_open

      vim.api.nvim_create_user_command("Dashboard", function()
        if not dashboard_open then
          Snacks.dashboard.open()
        end
      end, { desc = "Show dashboard", nargs = 0 })

      local function init()
        vim.api.nvim_create_autocmd("User", {
          pattern = "SnacksDashboardOpened",
          group = vim.api.nvim_create_augroup("dashboard_open", { clear = true }),
          callback = function(e)
            local group = vim.api.nvim_create_augroup("dashboard_open", { clear = true })

            vim.api.nvim_create_autocmd("User", {
              pattern = "SnacksDashboardClosed",
              group = group,
              callback = function()
                dashboard_open = false
                init()
              end,
            })

            vim.api.nvim_create_autocmd("User", {
              pattern = "SnacksDashboardUpdatePre",
              group = group,
              callback = function()
                frame = frame % #SPINNER + 1
                live_pending = false
              end,
            })

            vim.api.nvim_create_autocmd("User", {
              pattern = "SnacksDashboardUpdatePost",
              group = group,
              callback = function()
                if live_pending then
                  vim.defer_fn(Snacks.dashboard.update, 100)
                end
              end,
            })

            vim.api.nvim_create_autocmd("VimResized", { group = group, callback = Snacks.dashboard.update })

            if dashboard_open == false then
              vim.keymap.set("n", "q", "<cmd>bd<cr>", { silent = true, buffer = e.buf })
            end

            dashboard_open = true
          end,
        })
      end

      init()

      ---@module 'snacks'
      ---@type snacks.Config
      return {
        dashboard = {
          width = 60,
          row = 3,
          sections = {
            { icon = "? ", title = "Up Next", section = "tasks", padding = 1, indent = 2 },
            { icon = " ", title = "Recent Files", section = "recent_files", cwd = true, padding = 1, indent = 2 },
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = " ", key = "L", desc = "Lazy", action = ":Lazy", section = "live", check = lazy_check },
            { icon = " ", key = "M", desc = "Mason", action = ":Mason", section = "live", check = mason_check },
            { icon = "󰓙 ", key = "C", desc = "Checkhealth", action = ":checkhealth" },
            { icon = "󰔛 ", key = "S", desc = "Profile startup", action = ":Lazy profile", padding = 1 },
            { icon = "󰈤 ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = "󰐥 ", key = "q", desc = "Quit/close", action = ":qa", padding = 1 },
            { section = "stats" },
          },
        },
      }
    end,
  },
}
