---@module "snacks"
---@type table<string, snacks.picker.Action.spec>
local recall_actions = {}

function recall_actions.recall_toggle(picker, item)
  local recall_util_ok, recall_util = pcall(require, "plugins.recall.util")
  if not recall_util_ok or not recall_util then
    Snacks.notify.warn("recall utility not found", { title = picker.title })
    return
  end

  if item and item.mark then
    recall_util.unmark(item.mark)
    -- set cursor to the previous mark's position
    picker.list:set_target(math.max(1, picker.list.cursor - 1))
  elseif item and item.file then
    recall_util.mark(item.file)
    -- set cursor to the newest mark's position
    picker.list:set_target(#recall_util.get_all_marks())
  end

  picker:find()
end

function recall_actions.bufdelete_and_recall_unmark(picker)
  local recall_util_ok, recall_util = pcall(require, "plugins.recall.util")

  if recall_util_ok and recall_util then
    for _, item in ipairs(picker:selected({ fallback = true })) do
      recall_util.unmark(item.file or item.buf)
    end
  end

  require("snacks.picker.actions").bufdelete(picker)
end

function recall_actions.recall_move_up(picker, item)
  local recall_util_ok, recall_util = pcall(require, "plugins.recall.util")
  if not recall_util_ok or not recall_util then
    Snacks.notify.warn("recall utility not found", { title = picker.title })
    return
  end

  local mark = item.mark and recall_util.get_mark(item.mark) or nil
  -- If mark is "A", cannot move up, so do nothing.
  if mark and mark.letter == "A" then
    return
  end

  if mark ~= nil then
    -- find the previous alpha mark (may not be contiguous!)
    local mark_byte = string.byte(mark.letter)
    local prev_mark = recall_util.iter_marks():rev():find(function(m)
      return string.byte(m.letter) < mark_byte
    end)
    -- if exists, swap the two marks
    if prev_mark ~= nil then
      recall_util.mark(prev_mark.letter, mark.file, mark.pos)
      recall_util.mark(mark.letter, prev_mark.file, prev_mark.pos)
      -- manually compact to guarantee contiguous ordering-
      recall_util.compact_marks()
      -- set cursor to the previous mark's position
      picker.list:set_target(math.max(1, picker.list.cursor - 1))
    end
  else
    -- not marked, so mark it!
    recall_util.mark(item.file)
    -- set cursor to the newest mark's position
    picker.list:set_target(#recall_util.get_all_marks())
  end

  picker:find()
end

function recall_actions.recall_move_down(picker, item)
  local recall_util_ok, recall_util = pcall(require, "plugins.recall.util")
  if not recall_util_ok or not recall_util then
    Snacks.notify.warn("recall utility not found", { title = picker.title })
    return
  end

  local last_mark = recall_util.iter_marks():last()
  local mark = item.mark and recall_util.get_mark(item.mark) or nil
  -- If mark is the last mark, cannot move down, so do nothing.
  if mark and (mark.letter == "Z" or (last_mark and mark.letter == last_mark.letter)) then
    return
  end

  if mark ~= nil then
    -- find the next alpha mark (may not be contiguous!)
    local mark_byte = string.byte(mark.letter)
    local next_mark = recall_util.iter_marks():find(function(m)
      return string.byte(m.letter) > mark_byte
    end)
    -- if exists, swap the two marks
    if next_mark ~= nil then
      recall_util.mark(next_mark.letter, mark.file, mark.pos)
      recall_util.mark(mark.letter, next_mark.file, next_mark.pos)
      -- manually compact to guarantee contiguous ordering
      recall_util.compact_marks()
      -- set cursor to the next mark's position
      picker.list:set_target(math.min(#recall_util.get_all_marks(), picker.list.cursor + 1))
    end
  else
    -- not marked, so mark it!
    recall_util.mark(item.file)
    -- set cursor to the newest mark's position
    picker.list:set_target(#recall_util.get_all_marks())
  end

  picker:find()
end

return recall_actions
