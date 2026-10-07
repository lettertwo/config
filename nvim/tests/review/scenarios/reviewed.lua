return function(H)
  local check, finish, feed = H.check, H.finish, H.feed
  local focus_diff, wait_line1, wait_outline = H.focus_diff, H.wait_line1, H.wait_outline

  -- $REVIEW_SOURCE=stack is set by the runner.
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if H.failed() then
    finish()
    return
  end

  local dk = require("app.review")._active_docket()
  local reviewed = require("app.review.reviewed")
  local function file_named(path)
    for _, f in ipairs(dk.files) do
      if f.path == path then
        return f
      end
    end
  end
  local function current_path()
    local f = dk:current_file()
    return f and f.path
  end

  check("worktree blob ids are filled", file_named("base.lua").new_blob and not file_named("base.lua").new_blob:match("^0+$"))
  check("committed blob ids are full length", #file_named("a1.lua").new_blob == 40, file_named("a1.lua").new_blob)

  local picker = wait_outline(6)
  check("outline picker open", picker ~= nil)

  -- Display order (head-first) is base.lua, b1.lua, a1.lua. Marking a1.lua
  -- from its diff pane advances past it, wrapping to base.lua.
  dk:focus_file(file_named("a1.lua"))
  check("a1.lua rendered", wait_line1("a1"))
  focus_diff()
  feed("<leader>rv")
  check("a1.lua is marked reviewed", reviewed.is_reviewed(file_named("a1.lua")))
  check("the cursor advanced to the next unreviewed file", wait_line1("dirty") and current_path() == "base.lua", current_path())

  local json = dk.cwd .. "/.git/review/reviewed.json"
  check("reviewed.json exists under the common dir", vim.fn.filereadable(json) == 1, json)

  local outline = require("app.review.ui.outline")
  local function row_for(path)
    for _, it in ipairs(outline._items_for(dk, false, dk.state.stack_order)) do
      if it.type == "file" and it.change.path == path then
        return it
      end
    end
  end
  local function has_mark(path)
    for _, c in ipairs(outline._format_item(row_for(path), picker, true)) do
      if c[2] == "ReviewOutlineReviewedMark" then
        return true
      end
    end
    return false
  end
  check("the outline shows the mark on a1.lua", has_mark("a1.lua"))
  check("the outline shows no mark on base.lua", not has_mark("base.lua"))

  -- ]u / <leader>rn skip reviewed files: from base.lua the next unreviewed
  -- one is b1.lua.
  focus_diff()
  feed("<leader>rn")
  check("<leader>rn lands on b1.lua", wait_line1("b1") and current_path() == "b1.lua", current_path())

  -- Mark b1.lua, then amend its commit: the diff changes, so the mark lapses.
  feed("<leader>rv")
  check("b1.lua is marked reviewed", reviewed.is_reviewed(file_named("b1.lua")))
  local old_blob = file_named("b1.lua").new_blob
  vim.fn.writefile({ "local b1 = 2", "return b1" }, dk.cwd .. "/b1.lua")
  vim.system({ "git", "add", "b1.lua" }, { cwd = dk.cwd }):wait()
  vim.system({ "git", "commit", "-q", "--amend", "--no-edit" }, { cwd = dk.cwd }):wait()
  dk:refresh()
  local changed = vim.wait(8000, function()
    local f = file_named("b1.lua")
    return f ~= nil and f.new_blob ~= old_blob
  end, 50)
  check("the reload picked up the amended blob", changed)
  check("the amended b1.lua reads as unreviewed", not reviewed.is_reviewed(file_named("b1.lua")))
  check("a1.lua is still reviewed", reviewed.is_reviewed(file_named("a1.lua")))

  finish()
end
