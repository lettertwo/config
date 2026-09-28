local assert = require("luassert")

describe("signs: word-emphasis tier", function()
  local signs = require("app.review.ui.signs")

  -- Hand-set the groups signs.setup() reads from, independent of whatever
  -- colorscheme the test runner happens to have loaded.
  local function seed(add_fg, add_bg, del_fg, del_bg, normal_bg)
    vim.cmd("highlight clear")
    vim.api.nvim_set_hl(0, "Normal", { bg = normal_bg, fg = 0xe0e0e0 })
    vim.api.nvim_set_hl(0, "DiffAdd", { fg = add_fg, bg = add_bg })
    vim.api.nvim_set_hl(0, "DiffDelete", { fg = del_fg, bg = del_bg })
  end

  it("word groups are background-only and distinct from the line groups", function()
    seed(0x00ff88, 0x0a1c14, 0xff4466, 0x1c0a10, 0x101010)
    signs.setup()

    local add_line = vim.api.nvim_get_hl(0, { name = "ReviewDiffAdd", link = false })
    local del_line = vim.api.nvim_get_hl(0, { name = "ReviewDiffDelete", link = false })
    local add_word = vim.api.nvim_get_hl(0, { name = "ReviewDiffAddWord", link = false })
    local del_word = vim.api.nvim_get_hl(0, { name = "ReviewDiffDeleteWord", link = false })

    assert.is_nil(add_word.fg)
    assert.is_nil(del_word.fg)
    assert.is_not_nil(add_word.bg)
    assert.is_not_nil(del_word.bg)

    assert.are_not.equal(add_line.bg, add_word.bg)
    assert.are_not.equal(del_line.bg, del_word.bg)
    assert.are_not.equal(add_word.bg, del_word.bg)
  end)

  it("nudges DiffAdd/DiffDelete's own background toward the accent when they carry no foreground", function()
    -- `highlight clear` restores builtin defaults, so DiagnosticOk/Added
    -- still resolve an accent even with DiffAdd/DiffDelete bg-only —
    -- exercising the middle branch, not the no-accent-at-all fallback.
    vim.cmd("highlight clear")
    vim.api.nvim_set_hl(0, "Normal", { bg = 0x101010, fg = 0xe0e0e0 })
    vim.api.nvim_set_hl(0, "DiffAdd", { bg = 0x0a1c14 }) -- bg only, no fg
    vim.api.nvim_set_hl(0, "DiffDelete", { bg = 0x1c0a10 })
    signs.setup()

    local add_word = vim.api.nvim_get_hl(0, { name = "ReviewDiffAddWord", link = false })
    local del_word = vim.api.nvim_get_hl(0, { name = "ReviewDiffDeleteWord", link = false })
    assert.is_nil(add_word.fg)
    assert.is_nil(del_word.fg)
    assert.are_not.equal(0x0a1c14, add_word.bg)
    assert.are_not.equal(0x1c0a10, del_word.bg)
  end)

  it("falls back to a link when Normal has no background (transparent theme)", function()
    vim.cmd("highlight clear")
    vim.api.nvim_set_hl(0, "Normal", { fg = 0xe0e0e0 })
    vim.api.nvim_set_hl(0, "DiffAdd", { fg = 0x00ff88, bg = 0x0a1c14 })
    vim.api.nvim_set_hl(0, "DiffDelete", { fg = 0xff4466, bg = 0x1c0a10 })
    signs.setup()

    assert.equals("DiffTextAdd", vim.api.nvim_get_hl(0, { name = "ReviewDiffAddWord" }).link)
    assert.equals("DiffText", vim.api.nvim_get_hl(0, { name = "ReviewDiffDeleteWord" }).link)
  end)

  it("recomputes on ColorScheme after `hi clear` wipes the computed groups", function()
    seed(0x00ff88, 0x0a1c14, 0xff4466, 0x1c0a10, 0x101010)
    signs.setup()
    local before = vim.api.nvim_get_hl(0, { name = "ReviewDiffAddWord", link = false }).bg

    seed(0x2266ff, 0x0a1220, 0xffaa22, 0x201810, 0x202020)
    vim.api.nvim_exec_autocmds("ColorScheme", {})
    local after
    vim.wait(200, function()
      after = vim.api.nvim_get_hl(0, { name = "ReviewDiffAddWord", link = false }).bg
      return after ~= nil and after ~= before
    end)

    assert.are_not.equal(before, after)
  end)
end)
