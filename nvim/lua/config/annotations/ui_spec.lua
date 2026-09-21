local assert = require("luassert")
local Store = require("config.annotations.store")
local UI = require("config.annotations.ui")

local function file_lines(n)
  local lines = {}
  for i = 1, n do
    lines[i] = "line " .. i
  end
  return lines
end

describe("Config.Annotations.UI jump", function()
  local dir, prev_cwd, buf

  before_each(function()
    prev_cwd = vim.uv.cwd()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
    vim.uv.chdir(dir)
    Store._reset_cache()

    local abs = vim.fs.joinpath(dir, "f.lua")
    buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, abs)
    vim.api.nvim_win_set_buf(0, buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, file_lines(10))

    Store.add({ id = "1", file = "f.lua", lnum = 2, end_lnum = 2, anchor_text = "line 2", body = "a", created_at = 1 })
    Store.add({ id = "2", file = "f.lua", lnum = 5, end_lnum = 5, anchor_text = "line 5", body = "b", created_at = 2 })
    Store.add({ id = "3", file = "f.lua", lnum = 8, end_lnum = 8, anchor_text = "line 8", body = "c", created_at = 3 })
  end)

  after_each(function()
    vim.uv.chdir(prev_cwd)
    vim.fn.delete(dir, "rf")
  end)

  it("wraps from the last annotation to the first", function()
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    UI.next()
    assert.same({ 2, 0 }, vim.api.nvim_win_get_cursor(0))
  end)

  it("wraps from the first annotation to the last", function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    UI.prev()
    assert.same({ 8, 0 }, vim.api.nvim_win_get_cursor(0))
  end)
end)

describe("Config.Annotations.UI clear_resolved", function()
  local dir, prev_cwd

  before_each(function()
    prev_cwd = vim.uv.cwd()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
    vim.uv.chdir(dir)
    Store._reset_cache()
  end)

  after_each(function()
    vim.uv.chdir(prev_cwd)
    vim.fn.delete(dir, "rf")
  end)

  it("removes only records with a merged resolution", function()
    Store.add({ id = "1", file = "a.lua", lnum = 1, end_lnum = 1, anchor_text = "a", body = "b", created_at = 1 })
    Store.add({ id = "2", file = "a.lua", lnum = 2, end_lnum = 2, anchor_text = "c", body = "d", created_at = 2 })
    Store.resolve("1", "done")

    UI.clear_resolved()

    local records = Store.load()
    assert.equals(1, #records)
    assert.equals("2", records[1].id)
  end)
end)

describe("Config.Annotations.UI._prompt_body", function()
  it("creates no record when the submitted body is empty", function()
    local created = false
    UI._prompt_body(nil, function()
      created = true
    end)

    local buf = vim.api.nvim_get_current_buf()
    -- The buffer is a fresh scratch buffer with no lines set, so submitting
    -- it now is the same as pressing <cr> having typed nothing.
    local submit
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      if map.lhs == "<CR>" or map.lhs == "\r" then
        submit = map.callback
      end
    end
    assert.is_function(submit)
    submit()

    assert.is_false(created)
  end)
end)
