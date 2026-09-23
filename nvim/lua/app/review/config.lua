-- Review app config: Lua defaults, merged with `vim.g.review` once when this
-- module is required. No git config, no `setup()` call site, no reload
-- command — editing `vim.g.review` (global or via `.nvim.lua`) and running
-- `:Review` again picks up the change, because `open()` clears this module
-- from `package.loaded` before re-requiring it (see the comment on that
-- call). The merge and its validation happen once here, at require time, so
-- every reader (keymap install, the outline's action table) sees the same
-- already-validated tables instead of re-deriving them.
--
-- Only key bindings are configurable today. `keys.diff` and `keys.outline`
-- are `lhs -> action name` for normal mode; `keys.diff_visual` is the same
-- shape for the two Visual-mode selection actions, kept in its own table
-- because Visual and Normal maps are different keymap namespaces and a
-- default key like `<leader>rs` legitimately means one action in each. A
-- value of `false` unbinds that default without needing a replacement
-- action. `<Esc>` can never appear in any table here: it always runs the
-- peek → outline-filter → review-close cascade, and the confirm dialog and
-- the diff pane's fold remaps are similarly fixed outside this registry.

local actions = require("app.review.actions")

local M = {}

M.defaults = {
  keys = {
    diff = {
      ["]f"] = "next_file",
      ["[f"] = "prev_file",
      ["]h"] = "next_hunk",
      ["[h"] = "prev_hunk",
      ["]c"] = "next_changeset",
      ["[c"] = "prev_changeset",
      ["<leader>rl"] = "toggle_layout",
      ["<leader>rz"] = "toggle_whole",
      ["<leader>rs"] = "stage",
      ["<leader>rS"] = "stage_file",
      ["<leader>rd"] = "discard",
      ["<leader>rD"] = "discard_file",
      ["<leader>o"] = "focus_outline",
      ["R"] = "refresh",
      ["q"] = "close",
    },
    diff_visual = {
      ["<leader>rs"] = "stage_selection",
      ["<leader>rd"] = "discard_selection",
    },
    outline = {
      ["]f"] = "next_file",
      ["[f"] = "prev_file",
      ["]h"] = "next_hunk",
      ["[h"] = "prev_hunk",
      ["]c"] = "next_changeset",
      ["[c"] = "prev_changeset",
      ["l"] = "toggle_layout",
      ["z"] = "toggle_whole",
      ["<Space>"] = "stage",
      ["d"] = "discard",
      ["R"] = "refresh",
      ["q"] = "close",
      ["a"] = "stage_all",
      ["i"] = "cycle_mode",
      ["r"] = "toggle_stack_order",
      ["K"] = "peek",
    },
  },
}

-- Whether `name` names an action legally bound in `view` ("diff",
-- "diff_visual", or "outline"). "diff_visual" requires the diff handler's
-- `mode == "x"`; plain "diff" requires a diff handler that ISN'T Visual-only.
local function legal_in_view(name, view)
  local action = actions.list[name]
  if not action then
    return false
  end
  if view == "outline" then
    return action.outline ~= nil
  end
  local diff = action.diff
  if not diff then
    return false
  end
  if view == "diff_visual" then
    return diff.mode == "x"
  end
  return diff.mode ~= "x"
end

-- Every action name legally bindable in `view`, for suggestion lookups.
local function legal_names(view)
  local names = {}
  for name in pairs(actions.list) do
    if legal_in_view(name, view) then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

-- Levenshtein edit distance, for "did you mean" suggestions on a typo'd
-- action name. Action names are short (longest is `toggle_stack_order`), so
-- the O(n*m) table is cheap.
local function edit_distance(a, b)
  local la, lb = #a, #b
  local row = {}
  for j = 0, lb do
    row[j] = j
  end
  for i = 1, la do
    local prev = row[0] -- row[i-1][0]
    row[0] = i
    for j = 1, lb do
      local above = row[j] -- row[i-1][j], before this cell overwrites it
      if a:sub(i, i) == b:sub(j, j) then
        row[j] = prev
      else
        row[j] = 1 + math.min(prev, row[j], row[j - 1])
      end
      prev = above
    end
  end
  return row[lb]
end

local function suggest(name, candidates)
  local best, best_dist = nil, math.huge
  for _, candidate in ipairs(candidates) do
    local dist = edit_distance(name, candidate)
    if dist < best_dist then
      best, best_dist = candidate, dist
    end
  end
  return best
end

-- Validate one view's key table against the shipped default for that view:
-- start from the defaults, then apply each user entry that passes
-- validation. An entry that fails is dropped (its default, if any, stays
-- live) and appends one warning to `warnings`.
---@param view string
---@param defaults table<string, string>
---@param overrides table<string, any>
---@param warnings string[]
---@return table<string, string>
local function validate_view(view, defaults, overrides, warnings)
  local resolved = vim.deepcopy(defaults)
  for lhs, value in pairs(overrides) do
    if lhs == "<Esc>" then
      warnings[#warnings + 1] = ("review: %s is reserved (close cascade) and can't be rebound"):format(lhs)
    elseif value == false then
      resolved[lhs] = nil
    elseif type(value) ~= "string" then
      warnings[#warnings + 1] =
        ("review: keys.%s[%q] must be an action name or false, got %s"):format(view, lhs, type(value))
    elseif not actions.list[value] then
      local names = legal_names(view)
      local hint = suggest(value, names)
      warnings[#warnings + 1] = ("review: keys.%s[%q] names unknown action %q (did you mean %q?)"):format(
        view,
        lhs,
        value,
        hint or "?"
      )
    elseif not legal_in_view(value, view) then
      local hint = suggest(value, legal_names(view))
      warnings[#warnings + 1] = ("review: action %q has no %s handler (did you mean %q?)"):format(
        value,
        view,
        hint or "?"
      )
    else
      resolved[lhs] = value
    end
  end
  return resolved
end

-- Merge `vim.g.review` over the defaults and validate every key entry.
-- Exposed as a function (rather than only run at require time) so the
-- config spec can exercise it directly against arbitrary overrides.
---@param overrides table?
---@return table config, string[] warnings
function M.resolve(overrides)
  overrides = overrides or {}
  local keys = overrides.keys or {}
  local warnings = {}
  local known_views = { diff = true, diff_visual = true, outline = true }
  for view in pairs(keys) do
    if not known_views[view] then
      warnings[#warnings + 1] = ("review: keys.%s is not a known view (diff, diff_visual, outline)"):format(view)
    end
  end
  local resolved = {
    keys = {
      diff = validate_view("diff", M.defaults.keys.diff, keys.diff or {}, warnings),
      diff_visual = validate_view("diff_visual", M.defaults.keys.diff_visual, keys.diff_visual or {}, warnings),
      outline = validate_view("outline", M.defaults.keys.outline, keys.outline or {}, warnings),
    },
  }
  return resolved, warnings
end

local resolved, warnings = M.resolve(vim.g.review)
for _, warning in ipairs(warnings) do
  vim.notify(warning, vim.log.levels.WARN, { title = "Review" })
end

M.keys = resolved.keys
M.warnings = warnings

return M
