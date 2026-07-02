local M = {}

M.ns = vim.api.nvim_create_namespace("review")

-- Blend two 24-bit colors: pct=0 → a, pct=100 → b.
local function mix(a, b, pct)
  local function chan(shift)
    local ca = math.floor(a / shift) % 256
    local cb = math.floor(b / shift) % 256
    return math.floor(ca + (cb - ca) * pct / 100 + 0.5) * shift
  end
  return chan(65536) + chan(256) + chan(1)
end

-- Resolved color of a highlight group attribute (follows links), or nil
-- when the group doesn't define it (nvim_get_hl doesn't error on unknowns).
local function hl_color(name, attr)
  return vim.api.nvim_get_hl(0, { name = name, link = false })[attr]
end

-- Base groups are default=true links so colorschemes can override. Staged
-- variants are computed: no builtin group reads as "dimmer diff", so blend
-- the resolved base colors further toward Normal bg (lines/words) and toward
-- Comment (signs) — the POC's "staged reads as settled" treatment. Also
-- default=true, so a colorscheme that defines Review*Staged* wins.
function M.setup()
  local defs = {
    ReviewDiffAdd        = { link = "DiffAdd" },
    ReviewDiffDelete     = { link = "DiffDelete" },
    ReviewDiffAddWord    = { link = "DiffTextAdd" },
    ReviewDiffDeleteWord = { link = "DiffText" },
    ReviewDiffFiller     = { link = "DiffDelete" },
    ReviewSignAdd        = { link = "DiffAdd" },
    ReviewSignDelete     = { link = "DiffDelete" },
    ReviewSignChange     = { link = "DiffText" },
  }
  for name, opts in pairs(defs) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("keep", opts, { default = true }))
  end

  -- No Normal bg (transparent themes): blending toward black would make
  -- staged read as MORE prominent — fall back to plain links instead.
  local bg = hl_color("Normal", "bg")
  local comment = hl_color("Comment", "fg")
  local staged = {
    ReviewDiffStagedAdd        = { base = "ReviewDiffAdd", attr = "bg", toward = bg, pct = 45 },
    ReviewDiffStagedDelete     = { base = "ReviewDiffDelete", attr = "bg", toward = bg, pct = 45 },
    ReviewDiffStagedAddWord    = { base = "ReviewDiffAddWord", attr = "bg", toward = bg, pct = 40 },
    ReviewDiffStagedDeleteWord = { base = "ReviewDiffDeleteWord", attr = "bg", toward = bg, pct = 40 },
    ReviewSignStagedAdd        = { base = "ReviewSignAdd", attr = "fg", toward = comment, pct = 55 },
    ReviewSignStagedDelete     = { base = "ReviewSignDelete", attr = "fg", toward = comment, pct = 55 },
    ReviewSignStagedChange     = { base = "ReviewSignChange", attr = "fg", toward = comment, pct = 55 },
  }
  for name, s in pairs(staged) do
    local c = hl_color(s.base, s.attr)
    local opts = { default = true }
    if c and s.toward then
      opts[s.attr] = mix(c, s.toward, s.pct)
    else
      opts.link = s.base
    end
    vim.api.nvim_set_hl(0, name, opts)
  end

  -- :colorscheme runs `hi clear`, wiping the computed groups; recompute.
  -- (default=true set_hl is a no-op only while a definition exists — after
  -- hi clear the groups are gone, so re-running setup restores them.)
  local aug = vim.api.nvim_create_augroup("ReviewSigns", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = aug,
    callback = function()
      vim.schedule(M.setup)
    end,
  })
end

---@param bufnr integer
function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
end

return M
