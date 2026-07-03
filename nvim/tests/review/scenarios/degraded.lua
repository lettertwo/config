return function(H)
  local check, finish, feed = H.check, H.finish, H.feed
  local focus_diff, wait_line1 = H.focus_diff, H.wait_line1

  -- codediff's require must be attempted exactly once and rendering must
  -- degrade to no word highlights (no crash, no repeated installer runs).
  _G.__cd_attempts = 0
  package.loaded["codediff.core.diff"] = nil
  package.preload["codediff.core.diff"] = function()
    _G.__cd_attempts = _G.__cd_attempts + 1
    error("simulated missing libvscode-diff")
  end

  _G.App.launch("review", { context = "standalone" })
  check("render completed", wait_line1())
  local _, dbuf = focus_diff()
  feed("]f")
  check("main.lua rendered", wait_line1("fn_1"))

  local signs = require("app.review.ui.signs")
  local counts = { bg = 0, word = 0, virt = 0 }
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(dbuf, signs.ns, 0, -1, { details = true })) do
    if m[4].priority == 100 and m[4].hl_group then counts.bg = counts.bg + 1 end
    if m[4].priority == 1000 then counts.word = counts.word + 1 end
    if m[4].virt_lines then counts.virt = counts.virt + 1 end
  end
  check("diff still renders (bg marks)", counts.bg > 0, counts.bg)
  check("del virt_lines still render", counts.virt > 0, counts.virt)
  check("no word-diff marks", counts.word == 0, counts.word)
  check("require attempted exactly once", _G.__cd_attempts == 1, _G.__cd_attempts)

  finish()
end
