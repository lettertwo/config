-- Shared changeset builder: fans a list of {id, title, base, head, pr_number?}
-- specs out to `git.diff` and assembles Review.Changeset[] in spec order.
-- Extracted from the stack source so the ref source (base..head ranges) can
-- reuse the same fan-out/tagging/ordering behavior.

local M = {}
local git = require("app.review.diff.git")
local parser = require("app.review.diff.parser")

---@class Review.ChangesetSpec
---@field id string
---@field title string
---@field base string
---@field head string
---@field pr_number? integer

-- Diff each spec's base..head, tag every file with its changeset identity,
-- and emit changesets in spec order (results arrive out of order — held
-- until every diff completes). Per-spec errors produce an empty file list
-- rather than aborting the whole load.
---@param cwd string
---@param specs Review.ChangesetSpec[]
---@param callback fun(changesets: Review.Changeset[], err: string?)
function M.build(cwd, specs, callback)
  if #specs == 0 then
    callback({}, nil)
    return
  end

  local by_id = {}
  local pending = #specs

  for _, spec in ipairs(specs) do
    local base, head, spec_id = spec.base, spec.head, spec.id

    git.diff(cwd, base, head, function(raw, _)
      -- Per-spec errors produce empty file lists rather than aborting the load.
      local files = raw and parser.parse(raw) or {}
      for _, f in ipairs(files) do
        f.changeset_id = spec_id
        f.base_ref = base
        f.head_ref = head
      end
      by_id[spec_id] = {
        id = spec_id,
        title = spec.title,
        base_ref = base,
        head_ref = head,
        files = files,
        pr_number = spec.pr_number,
        head_sha = head,
      }
      pending = pending - 1
      if pending == 0 then
        -- Results arrive out of order; emit in spec order.
        local ordered = {}
        for _, s in ipairs(specs) do
          if by_id[s.id] then
            table.insert(ordered, by_id[s.id])
          end
        end
        callback(ordered, nil)
      end
    end)
  end
end

return M
