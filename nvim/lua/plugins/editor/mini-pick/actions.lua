---@class MiniPickCustomActions
local Actions = {}

local MiniPick = require("mini.pick")

---@class MiniPickRefinements
---@field active MiniPickRefinement[]?
---@field latest MiniPickRefinement[]?
local Refinements = { active = nil, latest = nil }

---@class MiniPickRefinement
---@field query string[]
---@field items table[]
---@field opts table

---@return boolean success Whether a refinement was pushed
function Actions.push_refine()
  local query = MiniPick.get_picker_query()

  -- TODO: support "mark"?
  local refine_type = "all"

  if query then
    local items = MiniPick.get_picker_items()
    if #query > 0 and items and #items > 0 then
      local opts = MiniPick.get_picker_opts()

      Refinements.push({
        query = query,
        items = items,
        opts = opts,
      })

      local config = vim.b.minipick_config or MiniPick.config
      local prompt_prefix = opts and opts.window.prompt_prefix or config.window.prompt_prefix
      local matches = MiniPick.get_picker_matches()[refine_type] or {}

      MiniPick.set_picker_opts({
        window = {
          prompt_prefix = prompt_prefix .. table.concat(query) .. config.window.prompt_prefix,
        },
        source = {
          match = config.match or MiniPick.default_match,
        },
      })
      MiniPick.set_picker_items(matches)
      MiniPick.set_picker_query({})
      return true
    end
  end
  return false
end

---@return boolean success Whether a refinement was popped
function Actions.pop_refine()
  local query = MiniPick.get_picker_query()
  if query then
    if #query < 1 then
      local refinement = Refinements.pop()
      if refinement then
        MiniPick.set_picker_opts(refinement.opts)
        MiniPick.set_picker_items(refinement.items)
        MiniPick.set_picker_query(refinement.query)
        return true
      end
    end
  end
  return false
end

function Actions.rotate_picker()
  -- TODO: Rotate pickers!
end

function Actions.rotate_picker_or_push_refine()
  if not Actions.push_refine() then
    Actions.rotate_picker()
  end
end

function Actions.delete_char_or_pop_refine()
  local query = MiniPick.get_picker_query()
  if query and not Actions.pop_refine() then
    query[#query] = nil
    MiniPick.set_picker_query(query)
  end
end

function Actions.send_to_quickfix()
  local items = MiniPick.get_picker_items()
  local opts = MiniPick.get_picker_opts()
  local choose_marked = opts and opts.source and opts.source.choose_marked or MiniPick.default_choose_marked
  choose_marked(items or {}, { list_type = "quickfix" })
  return true
end

function Actions.send_to_loclist()
  local items = MiniPick.get_picker_items()
  local opts = MiniPick.get_picker_opts()
  local choose_marked = opts and opts.source and opts.source.choose_marked or MiniPick.default_choose_marked
  choose_marked(items or {}, { list_type = "location" })
  return true
end

function Actions.setup()
  local group = vim.api.nvim_create_augroup("mini-pick-custom-actions", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MiniPickStart",
    callback = function()
      Refinements.start()
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MiniPickStop",
    callback = function()
      Refinements.stop()
    end,
  })
end

function Refinements:new()
  local refinements = { _stack = {} }
  setmetatable(refinements, { __index = self })
  return refinements
end

function Refinements.push(state)
  local active = Refinements.active
  if active then
    table.insert(active, state)
  else
    vim.notify("No active refinements!", "error")
  end
end

function Refinements.pop()
  local active = Refinements.active
  if active and #active then
    return table.remove(active)
  else
    vim.notify("No active refinements!", "error")
  end
end

function Refinements.start()
  local active = Refinements.active
  if active then
    Refinements.stop()
  end
  Refinements.active = {}
end

function Refinements.stop()
  Refinements.latest = Refinements.active
  Refinements.active = nil
end

return Actions
