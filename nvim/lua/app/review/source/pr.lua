-- PR source: resolves a classified PR reference (source/classify.lua's "pr"
-- kind) into one changeset. Metadata comes from `gh pr view`; head and base
-- are then fetched fresh as ordinary branches -- never `refs/pull/N/head`,
-- which this repo never reads -- and the span is merge-base(base, head)..head,
-- matching GitHub's own three-dot comparison. A URL-derived reference is
-- repo-scoped with `-R` so a foreign PR fails at fetch instead of silently
-- reviewing the local repo's PR of the same number.
--
-- Every failure here is pre-launch: gh unavailable, bad metadata, a missing
-- remote, or a failed fetch. None of them fall back to another source.

local M = {}
local git = require("app.review.diff.git")
local span = require("app.review.source.span")

local GH_FIELDS = "number,title,headRefName,baseRefName"

-- Runs `gh` and normalizes the result shape. This is the seam a test
-- replaces (`opts.run`) to fake `gh` output without touching the network;
-- the default shells out for real.
---@param cwd string
---@return fun(args: string[], callback: fun(result: {code: integer, stdout: string, stderr: string}))
local function make_default_run(cwd)
  return function(args, callback)
    local ok, err = pcall(vim.system, args, { cwd = cwd, text = true }, function(result)
      vim.schedule(function()
        callback({ code = result.code, stdout = result.stdout or "", stderr = result.stderr or "" })
      end)
    end)
    if not ok then
      -- vim.system raises synchronously when the executable isn't found.
      vim.schedule(function()
        callback({ code = 127, stdout = "", stderr = tostring(err) })
      end)
    end
  end
end

-- Turn a failed gh invocation into one of the two named gh failures: gh
-- itself is missing, or it ran but isn't authenticated. Anything else is
-- reported as the metadata failure it is.
---@param result {code: integer, stdout: string, stderr: string}
---@return string
local function gh_failure_reason(result)
  if result.code == 127 then
    return "gh is not installed"
  end
  local stderr = result.stderr or ""
  if stderr:lower():match("not logged") or stderr:lower():match("auth login") then
    return "gh is not logged in; run 'gh auth login'"
  end
  return "gh pr view failed: " .. (stderr ~= "" and stderr or "unknown error")
end

---@param stdout string
---@return {title: string, head_ref: string, base_ref: string}?, string?
local function parse_metadata(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok or type(data) ~= "table" then
    return nil, "invalid JSON from gh pr view"
  end
  if type(data.headRefName) ~= "string" or type(data.baseRefName) ~= "string" then
    return nil, "gh pr view response is missing headRefName/baseRefName"
  end
  return { title = data.title or data.headRefName, head_ref = data.headRefName, base_ref = data.baseRefName }, nil
end

-- The remote to fetch head/base branches from: `origin` when configured,
-- else whichever remote git reports first. A remoteless checkout names its
-- own failure rather than guessing a fetch target.
---@param cwd string
---@param callback fun(remote: string?, err: string?)
local function detect_remote(cwd, callback)
  vim.system({ "git", "-C", cwd, "remote" }, { text = true }, function(result)
    vim.schedule(function()
      local names = {}
      for line in (result.stdout or ""):gmatch("[^\n]+") do
        table.insert(names, vim.trim(line))
      end
      if #names == 0 then
        callback(nil, "no remote configured")
        return
      end
      for _, name in ipairs(names) do
        if name == "origin" then
          callback("origin", nil)
          return
        end
      end
      callback(names[1], nil)
    end)
  end)
end

-- Fetch a branch fresh into `refs/remotes/<remote>/<branch>`. Always a fresh
-- fetch, never a short-circuit on an existing tracking ref, since a stale
-- base would corrupt the merge-base against it.
---@param cwd string
---@param remote string
---@param branch string
---@param callback fun(err: string?)
local function fetch_branch_fresh(cwd, remote, branch, callback)
  local refspec = ("+refs/heads/%s:refs/remotes/%s/%s"):format(branch, remote, branch)
  vim.system({ "git", "-C", cwd, "fetch", remote, refspec }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(("failed to fetch %s: %s"):format(branch, result.stderr ~= "" and result.stderr or "git fetch failed"))
        return
      end
      callback(nil)
    end)
  end)
end

---@param opts {cwd: string, classified: table, run?: fun(args: string[], callback: fun(result: table))}
---           classified: source/classify.lua's "pr" result, {kind="pr", number=integer, repo=string?}
---@return Review.Source
function M.new(opts)
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()
  local classified = opts.classified
  local run = opts.run or make_default_run(cwd)

  local self = {
    kind = "pr",
    cwd = cwd,
    default_outline_mode = "flat",
  }

  local label = "PR #" .. tostring(classified.number)
  local last_changesets = nil

  local function view_pr(callback)
    local args = { "gh", "pr", "view", tostring(classified.number), "--json", GH_FIELDS }
    if classified.repo then
      table.insert(args, "-R")
      table.insert(args, classified.repo)
    end
    run(args, function(result)
      if result.code ~= 0 then
        callback(nil, label .. ": " .. gh_failure_reason(result))
        return
      end
      local metadata, err = parse_metadata(result.stdout)
      if not metadata then
        callback(nil, label .. ": " .. err)
        return
      end
      callback(metadata, nil)
    end)
  end

  function self:load(callback)
    view_pr(function(metadata, view_err)
      if view_err then
        callback(nil, view_err)
        return
      end
      detect_remote(cwd, function(remote, remote_err)
        if remote_err then
          callback(nil, label .. ": " .. remote_err)
          return
        end
        fetch_branch_fresh(cwd, remote, metadata.head_ref, function(head_fetch_err)
          if head_fetch_err then
            callback(nil, label .. ": " .. head_fetch_err)
            return
          end
          fetch_branch_fresh(cwd, remote, metadata.base_ref, function(base_fetch_err)
            if base_fetch_err then
              callback(nil, label .. ": " .. base_fetch_err)
              return
            end
            local head_tip = remote .. "/" .. metadata.head_ref
            local base_tip = remote .. "/" .. metadata.base_ref
            git.merge_base(cwd, base_tip, head_tip, function(base_sha, mb_err)
              if mb_err then
                callback(nil, label .. ": " .. mb_err)
                return
              end
              git.rev_parse(cwd, head_tip, function(head_sha, rp_err)
                if rp_err then
                  callback(nil, label .. ": not a commit: " .. head_tip)
                  return
                end
                span.build_resolved(cwd, base_sha, head_sha, metadata.title, function(changesets, build_err)
                  if changesets and #changesets > 0 then
                    changesets[1].current = true
                  end
                  last_changesets = changesets
                  callback(changesets, build_err)
                end)
              end)
            end)
          end)
        end)
      end)
    end)
  end

  -- Re-resolving would hit the network on every tick-driven refresh, and
  -- nothing a PR renders depends on index or worktree state -- a relaunch,
  -- not a refresh, picks up new remote commits.
  function self:refresh(callback)
    callback(last_changesets, nil)
  end

  function self:can_stage()
    return false
  end

  return self
end

return M
