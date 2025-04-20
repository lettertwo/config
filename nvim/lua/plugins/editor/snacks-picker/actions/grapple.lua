---@module "snacks"
---@type table<string, snacks.picker.Action.spec>
local grapple_actions = {}

-- TODO: implement some or all of these features of the builtin selector:
-- [x] Selection (<cr>): select the tag under the cursor
-- [x] Split (horizontal) (<c-s>): select the tag under the cursor (split)
-- [x] Split (vertical) (|): select the tag under the cursor (vsplit)
-- [ ] Quick select (default: 1-9): select the tag at a given index
-- [x] Deletion: delete a line to delete the tag
-- [x] Reordering: move a line to move a tag
-- [ ] Renaming (R): rename the tag under the cursor
-- [x] Quickfix (<c-q>): send all tags to the quickfix list (:h quickfix)
-- [ ] Go up (-): navigate up to the scopes window
-- [x] Help (?): open the help window
-- [ ] Update tag when tagged buffer is renamed/moved

function grapple_actions.grapple_toggle(picker, item)
  local grapple_ok, Grapple = pcall(require, "grapple")
  if grapple_ok and Grapple then
    if item and item.file then
      local err = Grapple.toggle({ path = item.file })
      if err then
        Snacks.notify.warn(err, { title = picker.title })
      end
    end
  else
    Snacks.notify.warn("grapple is not installed", { title = picker.title })
  end

  local new_index = Grapple.name_or_index({ buffer = item.buf })
  if type(new_index) == "number" then
    picker.list:set_target(new_index)
  else
    picker.list:set_target(math.max(1, picker.list.cursor - 1))
  end
  picker:find()
end

function grapple_actions.bufdelete_and_grapple_untag(picker, _item)
  local grapple_ok, Grapple = pcall(require, "grapple")
  if grapple_ok and Grapple then
    for _, item in ipairs(picker:selected({ fallback = true })) do
      if item.buf then
        if Grapple.name_or_index({ buffer = item.buf }) ~= nil then
          local err = Grapple.toggle({ buffer = item.buf })
          if err then
            Snacks.notify.warn(err, { title = picker.title })
          end
        end
      end
    end
  end
  require("snacks.picker.actions").bufdelete(picker, _item)
end

function grapple_actions.grapple_move_up(picker, item)
  local grapple_ok, Grapple = pcall(require, "grapple")
  if not grapple_ok or not Grapple then
    Snacks.notify.warn("grapple is not installed", { title = picker.title })
    return
  end

  local index = Grapple.name_or_index({ buffer = item.buf })
  if type(index) == "string" then
    error("Cannot move a named tag")
  end

  -- If the tag is already at the top, do nothing.
  if index == 1 then
    return
  end

  if index ~= nil then
    -- Untag the target buffer first.
    Grapple.untag({ buffer = item.buf })
    -- Collect all the subsequent tags.
    local to_retag = {}
    local tags = Grapple.tags()
    if tags ~= nil then
      for i, tag in ipairs(tags) do
        if i >= index - 1 then
          table.insert(to_retag, tag.path)
        end
      end
    end
    -- Untag the subsequent tags.
    for _, path in ipairs(to_retag) do
      Grapple.untag({ path = path })
    end
    -- Retag the target buffer.
    Grapple.tag({ buffer = item.buf })
    -- Retag the subsequent tags.
    for _, path in ipairs(to_retag) do
      Grapple.tag({ path = path })
    end
    picker.list:set_target(picker.list.cursor - 1)
  else
    -- If not numbered, move to the end
    Grapple.tag({ buffer = item.buf })
    local new_index = Grapple.name_or_index({ buffer = item.buf })
    if type(new_index) == "number" then
      picker.list:set_target(new_index)
    end
  end

  picker:find()
end

function grapple_actions.grapple_move_down(picker, item)
  local grapple_ok, Grapple = pcall(require, "grapple")
  if not grapple_ok or not Grapple then
    Snacks.notify.warn("grapple is not installed", { title = picker.title })
    return
  end

  local index = Grapple.name_or_index({ buffer = item.buf })
  if type(index) == "string" then
    error("Cannot move a named tag")
  end
  if index ~= nil then
    -- Untag the target buffer first.
    Grapple.untag({ buffer = item.buf })
    -- Collect all the subsequent tags.
    local to_retag = {}
    local tags = Grapple.tags()
    if tags ~= nil then
      for i, tag in ipairs(tags) do
        if i > index then
          table.insert(to_retag, tag.path)
        end
      end
    end
    -- Untag the subsequent tags.
    for _, path in ipairs(to_retag) do
      Grapple.untag({ path = path })
    end
    -- Retag the target buffer.
    Grapple.tag({ buffer = item.buf })
    -- Retag the subsequent tags.
    for _, path in ipairs(to_retag) do
      Grapple.tag({ path = path })
    end
    picker.list:set_target(picker.list.cursor + 1)
  else
    -- If not numbered, move to the end
    Grapple.tag({ buffer = item.buf })
    local new_index = Grapple.name_or_index({ buffer = item.buf })
    if type(new_index) == "number" then
      picker.list:set_target(new_index)
    end
  end

  picker:find()
end

return grapple_actions
