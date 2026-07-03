return function(H)
  local check, finish, feed = H.check, H.finish, H.feed
  local focus_diff, diff_line1, wait_line1, wait_outline = H.focus_diff, H.diff_line1, H.wait_line1, H.wait_outline

  -- Boot as the default app; :Review must open a tab, render, load review's
  -- own plugins/ dir (the launch→load framework path), and q must restore.
  local tabs_before = #vim.api.nvim_list_tabpages()
  local ok = pcall(vim.cmd, "Review")
  check(":Review runs", ok)
  check("render completed", wait_line1())
  check("opens a new tab", #vim.api.nvim_list_tabpages() == tabs_before + 1)
  check(
    "review plugins/ loaded via launch",
    package.loaded["app.review.plugins.diff"] ~= nil
  )
  check("renders first file", diff_line1() == "local gone = true")
  check("outline opens embedded", wait_outline(3) ~= nil)
  focus_diff()
  feed("q")
  vim.wait(2000, function()
    return #vim.api.nvim_list_tabpages() == tabs_before
  end, 50)
  check("q closes back to host tab", #vim.api.nvim_list_tabpages() == tabs_before)

  finish()
end
