---@class MiniPickCustomPickers
local Pickers = {}

function Pickers.files(local_opts)
  local MiniPick = require("mini.pick")
  local opts = {
    source = {
      name = "Files",
    },
  }
  if local_opts.cwd == "root" then
    opts.source.cwd = require("lazyvim.util").root.cwd()
  elseif local_opts.cwd == "buf" or local_opts.cwd == "buffer" then
    opts.source.cwd = vim.fn.expand("%:p:h")
  else
    opts.source.cwd = local_opts.cwd or require("lazyvim.util").root.get()
  end
  opts.source.name = opts.source.name .. " (" .. require("util").smart_shorten_path(opts.source.cwd) .. ")"

  return MiniPick.builtin.files(local_opts, opts)
end

function Pickers.recent(local_opts)
  local MiniPick = require("mini.pick")
  local MiniExtra = require("mini.extra")
  local opts = {
    source = {
      name = "Recent",
    },
  }
  if local_opts.cwd == "root" then
    opts.source.cwd = require("lazyvim.util").root.cwd()
  elseif local_opts.cwd == "buf" or local_opts.cwd == "buffer" then
    opts.source.cwd = vim.fn.expand("%:p:h")
  else
    opts.source.cwd = local_opts.cwd or require("lazyvim.util").root.get()
  end
  opts.source.name = opts.source.name .. " (" .. require("util").smart_shorten_path(opts.source.cwd) .. ")"

  -- TODO: Combine oldfiles with current session files
  return MiniExtra.pickers.oldfiles(local_opts, opts)
end

function Pickers.grep(local_opts)
  local MiniPick = require("mini.pick")
  local opts = {
    source = {
      name = "Grep",
    },
  }

  if local_opts.cwd == "root" then
    opts.source.cwd = require("lazyvim.util").root.cwd()
  elseif local_opts.cwd == "buf" or local_opts.cwd == "buffer" then
    opts.source.cwd = vim.fn.expand("%:p:h")
  else
    opts.source.cwd = local_opts.cwd or require("lazyvim.util").root.get()
  end
  opts.source.name = opts.source.name .. " (" .. require("util").smart_shorten_path(opts.source.cwd) .. ")"

  local_opts.cwd = nil

  if local_opts.scope == "buffers" then
    opts.source.name = opts.source.name .. " Buffers"

    local queue = vim
      .iter(vim.api.nvim_list_bufs())
      :filter(function(buf_id)
        return type(buf_id) == "number" and vim.bo[buf_id].buflisted and vim.bo[buf_id].buftype == ""
      end)
      :totable()

    -- Sort by loaded status, reversed for faster dequeue
    table.sort(queue, function(a, b)
      return vim.api.nvim_buf_is_loaded(b) and not vim.api.nvim_buf_is_loaded(a)
    end)

    local dequeue

    dequeue = coroutine.create(function(items, query_tick)
      items = items or {}

      -- if query_tick and query_tick ~= MiniPick.get_query_tick() then
      --   vim.notify("query tick mismatch: " .. query_tick .. " vs " .. MiniPick.get_query_tick(), vim.log.levels.ERROR)
      --   return
      -- end

      if not MiniPick.poke_is_picker_active() then
        return
      end

      local buf_id = table.remove(queue)
      if type(buf_id) ~= "number" then
        return
      end

      if not vim.api.nvim_buf_is_loaded(buf_id) then
        local cache_eventignore = vim.o.eventignore
        vim.o.eventignore = "BufEnter"
        pcall(vim.fn.bufload, buf_id)
        vim.o.eventignore = cache_eventignore
      end

      if not vim.api.nvim_buf_is_loaded(buf_id) or not vim.api.nvim_buf_is_valid(buf_id) then
        return
      end

      local buf_name = vim.api.nvim_buf_get_name(buf_id)
      if buf_name ~= "" then
        buf_name = vim.fn.fnamemodify(buf_name, ":~:.")
      end

      local n_digits = math.floor(math.log10(vim.api.nvim_buf_line_count(buf_id))) + 1
      local format_pattern = "%s%" .. n_digits .. "d\0%s"
      for lnum, l in ipairs(vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)) do
        -- local prefix = is_scope_all and (buf_name .. "\0") or ""
        local prefix = buf_name .. "\0"
        table.insert(items, { text = format_pattern:format(prefix, lnum, l), bufnr = buf_id, lnum = lnum })
      end

      MiniPick.set_picker_items(items)

      if #queue > 0 then
        query_tick = MiniPick.get_query_tick()
        vim.schedule(function()
          coroutine.resume(dequeue, items, query_tick)
        end)
        coroutine.yield()
      end
    end)

    local config = vim.tbl_deep_extend("force", MiniPick.config or {}, vim.b.minipick_config or {})

    local show = config.source.show
    -- if is_scope_all and show == nil then
    if show == nil then
      show = function(buf_id, items, query)
        MiniPick.default_show(buf_id, items, query, { show_icons = true })
      end
    end
    local match_opts = { sync = false, preserve_order = true }

    local match = function(stritems, inds, query)
      return MiniPick.default_match(stritems, inds, query, match_opts)
    end

    -- local default_source = { name = string.format("Buffer lines (%s)", scope), show = show, match = match }
    local default_source = { name = "Buffer lines", show = show, match = match }
    local fallback = {
      source = {
        preview = MiniPick.default_preview,
        choose = MiniPick.default_choose,
        choose_marked = MiniPick.default_choose_marked,
      },
    }
    return MiniPick.start(
      vim.tbl_deep_extend(
        "force",
        fallback,
        { source = default_source },
        opts or {},
        { source = { items = vim.schedule_wrap(function()
          coroutine.resume(dequeue)
        end) } }
      )
    )
  elseif local_opts.scope == "word" then
    if vim.fn.mode() == "v" then
      local saved_reg = vim.fn.getreg("v")
      vim.cmd([[noautocmd sil norm! "vy]])
      local_opts.pattern = vim.fn.getreg("v")
      vim.fn.setreg("v", saved_reg)
    else
      local_opts.pattern = vim.fn.expand("<cword>")
    end
    opts.source.name = opts.source.name .. " Word (" .. local_opts.pattern .. ")"
  end

  local_opts.scope = nil

  if local_opts.pattern then
    return MiniPick.builtin.grep(local_opts, opts)
  else
    return MiniPick.builtin.grep_live(local_opts, opts)
  end
end

function Pickers.setup()
  local MiniPick = require("mini.pick")
  for name, picker in pairs(Pickers) do
    if name ~= "setup" then
      MiniPick.registry[name] = picker
    end
  end
end

return Pickers
