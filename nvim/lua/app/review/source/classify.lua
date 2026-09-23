-- Classifies the single `:Review`/`review` argument into a source shape.
-- Pure and synchronous: no git, no filesystem, no network. Runs before any
-- tab opens, so a malformed argument fails fast with a named reason instead
-- of falling back to something else.
--
-- Precedence: PR spelling, then keyword, then range, then bare ref. A branch
-- literally named "stack" or "uncommitted" is reachable only by its full ref
-- form (e.g. refs/heads/stack) — keywords always win.
--
-- Result shapes:
--   { kind = "stack" }
--   { kind = "uncommitted" }
--   { kind = "pr", number = integer, repo = string? }
--   { kind = "ref", shape = "range", dots = 2|3, base = string, head = string }
--   { kind = "ref", shape = "single", ref = string }

local M = {}

local PR_URL_PATTERN = "^https?://github%.com/([%w_%.%-]+)/([%w_%.%-]+)/pull/(%d+)/?$"

---@param text string
---@return {kind: "pr", number: integer, repo: string?}|nil, string?
local function classify_pr(text)
  local owner, repo, url_number = text:match(PR_URL_PATTERN)
  if owner then
    return { kind = "pr", number = tonumber(url_number), repo = owner .. "/" .. repo }
  end

  local hash_rest = text:match("^#(.*)$")
  local prefixed_rest = text:match("^pr%-(.*)$") or text:match("^pr#(.*)$")
  local rest = hash_rest or prefixed_rest
  if not rest then
    return nil
  end
  if rest:match("^%d+$") then
    return { kind = "pr", number = tonumber(rest) }
  end
  return nil, ("malformed PR spelling: %q"):format(text)
end

---@param text string
---@return {kind: "ref", shape: "range", dots: 2|3, base: string, head: string}
local function classify_range(text)
  local function endpoint(side)
    return side ~= "" and side or "HEAD"
  end
  local base3, head3 = text:match("^(.-)%.%.%.(.*)$")
  if base3 then
    return { kind = "ref", shape = "range", dots = 3, base = endpoint(base3), head = endpoint(head3) }
  end
  local base2, head2 = text:match("^(.-)%.%.(.*)$")
  if base2 then
    return { kind = "ref", shape = "range", dots = 2, base = endpoint(base2), head = endpoint(head2) }
  end
  return nil
end

---@param text string?
---@return table?, string?
function M.classify(text)
  text = vim.trim(text or "")

  if text == "" or text == "stack" then
    return { kind = "stack" }
  end
  if text == "uncommitted" then
    return { kind = "uncommitted" }
  end

  local pr, pr_err = classify_pr(text)
  if pr then
    return pr
  end
  if pr_err then
    return nil, pr_err
  end

  local range = classify_range(text)
  if range then
    return range
  end

  return { kind = "ref", shape = "single", ref = text }
end

return M
