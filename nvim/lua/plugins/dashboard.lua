local Util = require("util")

---@alias Position "left" | "center" | "right"
---@alias Alignment "left" | "right"
---@alias HighlightGroup string | [string, integer, integer][]
---@alias Element Padding | Text | Button | Group

---@class Padding
---@field type "padding"
---@field val number

---@class Text
---@field type "text"
---@field val string | string[] | fun(): string | string[]
---@field opts { position: Position, hl: HighlightGroup }

---@class FlatText
---@field type "text"
---@field val string
---@field opts { position: Position, hl: HighlightGroup }

---@class Button
---@field type "button"
---@field val string
---@field on_press function
---@field opts ButtonOpts

---@class ButtonOpts
---@field position Position
---@field hl HighlightGroup
---@field shortcut string
---@field align_shortcut Alignment
---@field hl_shortcut string
---@field cursor integer
---@field width integer
---@field keymap table

---@class Group
---@field type "group"
---@field val Element[] | fun(): Element[]
---@field opts { spacing: integer }

local version, commit = unpack(vim.split(vim.fn.execute("version"):gsub(".*%sv([%w%p]+)\n.*", "%1"), "+"))

-- font: https://famfonts.com/metallica/
-- generator: https://www.twitchquotes.com/ascii-art-generator
local header_lines = {
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

-- Get the window that is displaying the alpha buffer.
---@return integer | nil
local function alpha_win()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype == "alpha" then
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
          return win
        end
      end
    end
  end
end

-- Performs a deep copy of a table.
---@see vim.deepcopy
---@type fun(tbl: table): table
local deepcopy = vim.deepcopy

-- Performs a deep merge of `tbl` into `into`.
-- Note that this does not modify either table.
---@see vim.tbl_deep_extend
---@type fun(into: table, tbl: table): table
local function deepmerge(into, tbl)
  return vim.tbl_deep_extend("force", into, tbl)
end

-- Get the character length of string.
---@see strchars
---@type fun(str: string): integer
local len = vim.fn.strchars

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

-- Pads the beginning of `str` with `n` spaces.
---@param str string
---@param n integer
---@return string
local function pad_left(str, n)
  return string.rep(" ", n) .. str
end

-- Pads the end of `str` with `n` spaces.
---@param str string
---@param n integer
---@return string
local function pad_right(str, n)
  return str .. string.rep(" ", n)
end

-- Find a value in `tbl` that passes the `predicate`.
---@generic T: any
---@param tbl table<any, T>
---@param predicate fun(value: T): boolean
---@return T | nil
local function find(tbl, predicate)
  for _, v in ipairs(tbl) do
    if predicate(v) == true then
      return v
    end
  end
  return nil
end

-- Given an index and a count, generates a highlight
-- group name in the range "StartLogo1...StartLogo20"
---@param index number
---@param count number
---@return string
local function header_highlight_group(index, count)
  local ratio = 20 / count
  local group = math.min(20, math.max(1, math.floor(index * ratio + 0.5)))
  return "StartLogo" .. group
end

-- Given a list of line elements, returns an iterator that will
-- yield _single line_ elements in order, flattening nested elements
-- and splitting multiline elements.
--
-- - Group elements are flattened to the elements they contain.
-- - Multiline text elements are split into single line text elements.
-- - Padding elements with value > 1 are split into multiple padding elements.
---@param elements Element[]
---@return fun(): Button | FlatText | Padding | nil
local function iterate_line_elements(elements)
  local co = coroutine.create(function()
    for _, el in ipairs(elements) do
      if el.type == "button" then
        coroutine.yield(deepcopy(el))
      elseif el.type == "padding" then
        for _ = 1, el.val do
          coroutine.yield(deepmerge(el, { val = 1 }))
        end
      elseif el.type == "text" then
        local val = type(el.val) == "function" and el.val() or el.val
        if type(val) == "table" then
          for _, str in ipairs(val) do
            coroutine.yield(deepmerge(el, { val = str }))
          end
        else
          coroutine.yield(deepmerge(el, { val = val }))
        end
      elseif el.type == "group" then
        local val = type(el.val) == "function" and el.val() or el.val
        if type(val) == "table" then
          for nested in iterate_line_elements(val) do
            coroutine.yield(nested)
          end
        end
      end
    end
  end)
  return function()
    local status, value = coroutine.resume(co)
    if status then
      return value
    else
      return nil
    end
  end
end

-- Overwrite `line` with `new_line` starting at `start`.
-- For example: `overwrite("abc", "def", 2) -> "adef" `
---@param line string
---@param start integer
---@param new_line string
---@return string
local function overwrite(line, new_line, start)
  if start < 1 then
    error("start must be positive")
  end
  local line_len = len(line)
  if start > line_len then
    error("start exceeds length of line")
  end
  local result = substr(line, 1, start) .. new_line
  local stop = start + len(new_line) + 1
  if stop < line_len - 1 then
    result = result .. substr(line, stop)
  end
  return result
end

-- Center the string in the given window width.
---@param str string
---@param winwidth number
---@return string
local function center(str, winwidth)
  local diff = winwidth - len(str)
  local pad = math.floor(math.abs(diff) / 2)
  if diff < 0 then
    return substr(str, pad, winwidth)
  else
    return pad_left(pad_right(str, pad), pad)
  end
end

-- Given a header line element and a section line element,
-- embeds the section line in the center of the header line.
--
-- The intended effect is that the header 'wraps around' the section.
---@param header_line FlatText
---@param section_line FlatText | Button | Padding
---@return FlatText | Button
local function embed_section_line(header_line, section_line, winwidth)
  local header_val = header_line.val
  local header_opts = header_line.opts
  local oddwidth = winwidth % 2 == 1

  if section_line.type == "text" then
    ---@type string
    local text_val = section_line.val --[[ @as string ]]
    local text_opts = section_line.opts

    local start = winwidth / 2 - len(text_val) / 2
    start = oddwidth and math.floor(start) or math.ceil(start)

    local val = overwrite(header_val, text_val, start)

    -- TODO: support hl ranges (see button below)
    if type(header_opts.hl) ~= "string" or type(text_opts.hl) ~= "string" then
      error("Expected string for section.opts.hl")
    end

    -- Highlight ranges seem to count bytes, not cells or characters.
    local start_byte = #substr(val, 1, start)
    local hl = {
      { header_opts.hl, 0, start_byte },
      { text_opts.hl, start_byte, start_byte + #text_val },
      { header_opts.hl, start_byte + #text_val, #val },
    }

    return { type = "text", val = val, opts = { hl = hl } }
  elseif section_line.type == "button" then
    ---@type string
    local button_val = section_line.val --[[ @as string ]]
    local button_opts = section_line.opts
    local on_press = section_line.on_press

    -- Pad button val with width and shortcut.
    button_val = button_val .. pad_left(button_opts.shortcut, button_opts.width - len(button_val) - 1)

    local start = winwidth / 2 - len(button_val) / 2
    start = oddwidth and math.floor(start) or math.ceil(start)

    local val = overwrite(header_val, button_val, start)

    -- Highlight ranges seem to count bytes, not cells or characters.
    local start_byte = #substr(val, 1, start)
    local hl = {}
    table.insert(hl, { header_opts.hl, 0, start_byte })
    if type(button_opts.hl) == "table" then
      for _, b in ipairs(button_opts.hl) do ---@diagnostic disable-line: param-type-mismatch
        table.insert(hl, { b[1], b[2] + start_byte, b[3] + start_byte })
      end
    end
    table.insert(hl, { button_opts.hl_shortcut, start_byte + #button_val - 1, start_byte + #button_val })
    table.insert(hl, { header_opts.hl, start_byte + #button_val, #val })

    return {
      type = "button",
      val = val,
      on_press = on_press,
      opts = { hl = hl, cursor = button_opts.cursor + start, keymap = button_opts.keymap },
    }
  end

  return { type = "text", val = header_val, opts = header_opts }
end

local lazy_button
local mason_button

return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    cmd = { "Alpha" },
    keys = { { "<leader>;", "<cmd>Alpha<CR>", desc = "Dashboard" } },
    config = function()
      local alpha = require("alpha")
      local theta = require("alpha.themes.theta")
      local button = require("alpha.themes.dashboard").button

      ---@type Group
      local section_mru = assert(find(theta.config.layout, function(tbl)
        return tbl.type == "group"
          and find(tbl.val, function(v)
              return v.type == "text" and v.val == "Recent files"
            end)
            ~= nil
      end))

      lazy_button = button("L", "鈴" .. " Lazy", "<CMD>Lazy<CR>")
      mason_button = button("M", "鈴" .. " Mason", "<CMD>Mason<CR>")

      ---@type Element[]
      local sections = {
        section_mru,
        { type = "padding", val = 2 },
        {
          type = "group",
          val = {
            { type = "text", val = "Find Stuff", opts = { hl = "SpecialComment", position = "center" } },
            { type = "padding", val = 1 },
            button("l", "  Load Session", [[:lua require("persistence").load() <cr>]]),
            button("e", "פּ  Explore", "<CMD>Telescope file_browser<CR>"),
            button("f", "  Find File", "<CMD>Telescope find_files<CR>"),
            button("r", "  Find Recent", "<CMD>Telescope oldfiles<CR>"),
            button("g", "  Find Text", "<CMD>Telescope live_grep<CR>"),
          },
        },
        { type = "padding", val = 2 },
        {
          type = "group",
          val = {
            {
              type = "text",
              val = "Neovim  " .. version,
              opts = { hl = "SpecialComment", position = "center" },
            },
            {
              type = "text",
              val = commit,
              opts = { hl = "Comment", position = "center" },
            },
            { type = "padding", val = 1 },
            button(
              "c",
              "  Configuration",
              "<CMD>Telescope find_files cwd=" .. vim.fn.stdpath("config") .. " prompt_title=Nvim\\ Config\\ Files<CR>"
            ),
            lazy_button,
            mason_button,
            button("C", "律 Checkhealth", "<CMD>checkhealth<CR>"),
            button("S", "祥 Profile startup", "<CMD>Lazy profile<CR>"),
          },
        },
        { type = "padding", val = 2 },
        button("n", "  New File", "<CMD>ene!<CR>"),
        button(";", "  Close", "<CMD>Alpha<CR>"),
        button("q", "  Quit", "<CMD>qa<CR>"),
        {
          type = "group",
          val = {
            { type = "padding", val = 2 },
            {
              type = "text",
              val = function()
                local stats = require("lazy").stats()
                if stats.startuptime == 0 then
                  return ""
                end

                local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
                return "⚡ Loaded " .. stats.count .. " plugins in " .. ms .. "ms"
              end,
              opts = { hl = "SpecialComment", position = "center" },
            },
          },
        },
      }

      ---@param winwidth integer
      ---@return Element[]
      local function render_layout(winwidth)
        ---@type Element[]
        local layout = {
          { type = "padding", val = 1 },
        }

        local next_section_line = iterate_line_elements(sections)

        -- Build the header section, embedding as many section lines as possible.
        for i, val in ipairs(header_lines) do
          --- @type FlatText
          local header_line = {
            type = "text",
            val = center(val, winwidth),
            opts = { hl = header_highlight_group(i, #header_lines) },
          }
          -- After line 11 we can start embedding section lines in the header.
          -- TODO: Detect when the header has room to start embedding.
          if i > 12 then
            local section_line = next_section_line()
            if section_line ~= nil then
              table.insert(layout, embed_section_line(header_line, section_line, winwidth))
            else
              table.insert(layout, header_line)
            end
          else
            table.insert(layout, header_line)
          end
        end

        -- Insert the remaining section lines into the layout.
        for section_line in next_section_line do
          table.insert(layout, section_line)
        end
        return layout
      end

      local render = Util.debounce(16, function()
        if vim.o.filetype == "alpha" then
          alpha.redraw()
        end
      end)

      local group = vim.api.nvim_create_augroup("Dashboard", { clear = true })

      vim.api.nvim_create_autocmd("VimResized", { pattern = "*", group = group, callback = render })
      vim.api.nvim_create_autocmd("User", { pattern = "LazyVimStarted", group = group, callback = render })

      ---@type 'init' | 'done' | number
      local mason_update_state = "init"

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "LazyLoad",
        callback = function(event)
          local lazy_updates = #require("lazy.manage.checker").updated
          if lazy_updates > 0 and lazy_button ~= nil then
            local label = "  Lazy"
            lazy_button.val = label .. " " .. lazy_updates .. " updates available"
            lazy_button.opts.hl = "SpecialComment"
            render()
          end

          if event.data == "mason.nvim" and mason_update_state == "init" then
            local registry_ok, registry = pcall(require, "mason-registry")
            if registry_ok then
              local update_count = 0

              local function render_mason_status()
                if mason_update_state == 0 then
                  mason_update_state = "done"
                  if update_count > 0 then
                    local label = "  Mason"
                    mason_button.val = label .. " " .. update_count .. " updates available"
                    mason_button.opts.hl = "SpecialComment"
                    render()
                  end
                end
              end

              mason_update_state = 0
              registry.refresh(function()
                for _, name in ipairs(registry.get_installed_package_names()) do
                  -- vim.notify("checking " .. name)
                  mason_update_state = mason_update_state + 1
                  registry.get_package(name):check_new_version(function(ok)
                    mason_update_state = mason_update_state - 1
                    if ok then
                      update_count = update_count + 1
                    end
                    vim.schedule(render_mason_status)
                  end)
                end
              end)
            end
          end
        end,
      })

      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "AlphaClosed",
        callback = function()
          vim.api.nvim_clear_autocmds({ group = group })
          -- TODO: unload the alpha plugin and config?
        end,
      })

      local win = nil

      local opts = {
        margin = 0,
        win = nil,
        setup = function()
          require("alpha.themes.theta").config.opts.setup() -- Adds an autocmd to refresh on dir change.
          win = alpha_win()
        end,
        redraw_on_resize = false,
      }

      local layout = {
        {
          type = "group",
          val = function()
            local winwidth = vim.api.nvim_win_get_width(win or 0)
            return render_layout(winwidth)
          end,
        },
      }

      alpha.setup({ sections = sections, layout = layout, opts = opts })
    end,
  },
}
