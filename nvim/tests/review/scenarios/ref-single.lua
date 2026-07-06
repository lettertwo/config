-- REVIEW_KIND=ref REVIEW_REF=feature over the stack fixture: single-ref
-- review, one changeset diffing feature^..feature, flat outline mode.
return function(H)
  local check, finish = H.check, H.finish
  local diff_win, wait_line1, wait_outline = H.diff_win, H.wait_line1, H.wait_outline

  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  if H.failed() then
    finish()
    return
  end
  local win = (diff_win())
  local function winbar()
    return vim.wo[win].winbar or ""
  end

  check("opens on the single commit's file (b1.lua)", wait_line1("b1"))
  -- With exactly one changeset, set_winbar (docket.lua:150) omits the
  -- "[i/n title]" bracket entirely — only the title and file position show.
  check("winbar shows the review title and file position, no changeset bracket", winbar():find("feature", 1, true) ~= nil and winbar():find("b1.lua (1/1)", 1, true) ~= nil, winbar())

  local dk = require("app.review")._active_docket()
  check("exactly one changeset", #dk.changesets == 1, #dk.changesets)
  check("default outline mode is flat", dk.source.default_outline_mode == "flat")
  check("source is read-only (can_stage() == false)", dk.source:can_stage() == false)

  local picker = wait_outline(1)
  check("outline picker open (flat mode)", picker ~= nil)
  if picker then
    check("outline has exactly 1 file item", picker:count() == 1, picker:count())
  end

  finish()
end
