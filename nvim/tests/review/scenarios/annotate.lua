return function(H, fixture)
  local check, finish, feed = H.check, H.finish, H.feed
  local focus_diff, wait_line1 = H.focus_diff, H.wait_line1

  -- The fixture's commits each touch their own file. Rebuild the feature
  -- branch as add a1, edit a1, add b1 so the commit after "add a1" has that
  -- commit as its base: its left pane then shows the content the earlier
  -- commit's right pane showed, which is what a rev-keyed annotation follows.
  local function git(...)
    local r = vim.system({ "git", ... }, { cwd = fixture, text = true }):wait()
    assert(r.code == 0, r.stderr)
    return vim.trim(r.stdout)
  end
  git("stash", "-q")
  git("reset", "-q", "--hard", "main")
  local function commit(name, lines, msg)
    vim.fn.writefile(lines, fixture .. "/" .. name)
    git("add", name)
    git("commit", "-qm", msg)
  end
  commit("a1.lua", { "local a1 = 1", "return a1" }, "add a1")
  commit("a1.lua", { "local a1 = 2", "return a1" }, "edit a1")
  commit("b1.lua", { "local b1 = 1", "return b1" }, "add b1")
  git("stash", "pop", "-q")
  local add_a1_sha = git("rev-parse", "HEAD~2")

  -- $REVIEW_SOURCE=stack is set by the runner.
  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if H.failed() then
    finish()
    return
  end

  local dk = require("app.review")._active_docket()
  local Store = require("config.annotations.store")
  local Anchor = require("config.annotations.anchor")

  local function file_in(title)
    for _, f in ipairs(dk.files) do
      local cs = dk.changesets[dk.cs_idx_by_id[f.changeset_id]]
      if cs.title == title and f.path == "a1.lua" then
        return f
      end
    end
  end
  local function sign_rows(buf)
    local rows = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, Anchor._ns(), 0, -1, { details = true })) do
      if m[4].sign_text then
        table.insert(rows, m[2])
      end
    end
    return rows
  end

  -- Annotate line 2 of a1.lua in the "add a1" commit's right pane.
  local first = file_in("add a1")
  check("found a1.lua in the add a1 changeset", first ~= nil)
  dk:focus_file(first)
  check("a1.lua rendered", wait_line1("a1"))
  local win, buf = focus_diff()
  vim.api.nvim_win_set_cursor(win, { 2, 0 })
  feed("<leader>aa")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "name this better" })
  feed("<cr>")

  local records = Store.load()
  check("one annotation was stored", #records == 1, #records)
  local rec = records[1] or {}
  check("it carries the commit's full sha as rev", rec.rev == add_a1_sha and #(rec.rev or "") == 40, rec.rev)
  check("it carries the file line, not the buffer row", rec.file == "a1.lua" and rec.lnum == 2, vim.inspect(rec))
  check("it anchors on the source text", rec.anchor_text == "return a1", rec.anchor_text)
  check("a sign extmark is drawn on that row", vim.wait(2000, function()
    return vim.deep_equal(sign_rows(buf), { 1 })
  end, 50), vim.inspect(sign_rows(buf)))

  -- The next commit's left pane shows the same content, so the same annotation.
  local second = file_in("edit a1")
  check("found a1.lua in the edit a1 changeset", second ~= nil)
  dk:toggle_layout()
  dk:focus_file(second)
  check("edit a1 rendered side by side", vim.wait(8000, function()
    return dk.dv.layout == "sbs" and dk.dv._rendered_file == second and next(dk.dv.left.row_map) ~= nil
  end, 50))
  local left_buf = dk.dv.left.bufnr
  check("the annotation renders on the next commit's left pane", vim.wait(2000, function()
    return vim.deep_equal(sign_rows(left_buf), { 1 })
  end, 50), vim.inspect(sign_rows(left_buf)))
  check("it does not render on that commit's right pane", #sign_rows(dk.dv.right.bufnr) == 0)

  -- The worktree buffer holds the same path but another version of it.
  local wt = vim.fn.bufadd(fixture .. "/a1.lua")
  vim.fn.bufload(wt)
  Anchor.render(wt)
  check("the worktree file buffer shows no annotation", #sign_rows(wt) == 0, vim.inspect(sign_rows(wt)))

  finish()
end
