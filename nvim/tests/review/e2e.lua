-- Headless end-to-end checks for the review app. Run via tests/review/run.fish,
-- or directly:
--
--   VIM_APP=review REVIEW_E2E=standalone nvim --headless -c "lua dofile('nvim/tests/review/e2e.lua')"
--   VIM_APP=review REVIEW_E2E=degraded   nvim --headless -c "lua dofile('nvim/tests/review/e2e.lua')"
--                  REVIEW_E2E=embedded   nvim --headless -c "lua dofile('nvim/tests/review/e2e.lua')"
--
-- Each scenario needs its own nvim process (degraded stubs the codediff
-- require before anything loads it; embedded boots the default app).
-- Prints PASS/FAIL per check and a final E2E-RESULT line; exits 1 on failure.
--
-- This file only dispatches: shared check/finish/fixture helpers live in
-- harness.lua, and each scenario is its own file under scenarios/. Loaded
-- via dofile (not require) with absolute paths so this keeps working after
-- vim.cmd.cd(fixture) below changes the cwd.

local this_file = debug.getinfo(1, "S").source:sub(2)
local dir = vim.fn.fnamemodify(this_file, ":h")

local H = dofile(dir .. "/harness.lua")

local fixture = H.scenario == "stack" and H.build_stack_fixture()
  or H.scenario == "trunk-ahead" and H.build_trunk_ahead_fixture()
  or H.build_fixture()
vim.cmd.cd(fixture)

local scenario_file = dir .. "/scenarios/" .. H.scenario .. ".lua"
if vim.uv.fs_stat(scenario_file) then
  dofile(scenario_file)(H, fixture)
else
  H.check("known scenario", false, H.scenario)
  H.finish()
end
