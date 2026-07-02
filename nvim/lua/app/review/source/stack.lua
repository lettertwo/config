-- Stack source: one changeset per stack node (Graphite branch or first-parent
-- commit via the graph fallback), base→head order, with the uncommitted
-- changeset prepended when it has files.

local M = {}
local git = require("app.review.diff.git")
local parser = require("app.review.diff.parser")
local graph_factory = require("app.review.source.graph")
local uncommitted = require("app.review.source.uncommitted")

---@param opts {cwd: string}
---@return Review.Source
function M.new(opts)
  local cwd = opts.cwd or Config.root("git") or vim.fn.getcwd()

  local self = {
    kind = "stack",
    cwd = cwd,
    default_outline_mode = "stack", -- consumed by the M3 outline
  }

  local graph = graph_factory.create(cwd)

  ---@param nodes Review.StackNode[]
  ---@param callback fun(changesets: Review.Changeset[], err: string?)
  local function build_changesets(nodes, callback)
    if #nodes == 0 then
      callback({}, nil)
      return
    end

    local by_id = {}
    local pending = #nodes

    for _, node in ipairs(nodes) do
      local base = graph:base_ref(node)
      local head = graph:head_ref(node)
      local meta = graph:metadata(node)
      local node_id = node.id

      git.diff(cwd, base, head, function(raw, _)
        -- Per-node errors produce empty file lists rather than aborting the load.
        local files = raw and parser.parse(raw) or {}
        for _, f in ipairs(files) do
          f.changeset_id = node_id
          f.base_ref = base
          f.head_ref = head
        end
        by_id[node_id] = {
          id = node_id,
          title = meta.title or node.branch or node_id,
          base_ref = base,
          head_ref = head,
          files = files,
          pr_number = meta.pr_number,
          head_sha = head,
        }
        pending = pending - 1
        if pending == 0 then
          -- Results arrive out of order; emit in node (base→head) order.
          local ordered = {}
          for _, n in ipairs(nodes) do
            if by_id[n.id] then
              table.insert(ordered, by_id[n.id])
            end
          end
          callback(ordered, nil)
        end
      end)
    end
  end

  ---@param nodes Review.StackNode[]
  ---@param callback fun(changesets: Review.Changeset[]?, err: string?)
  local function load_with_uncommitted(nodes, callback)
    local stack_result, uncommitted_cs
    local pending = 2

    local function maybe_done()
      pending = pending - 1
      if pending ~= 0 then
        return
      end
      local all = {}
      if uncommitted_cs and #uncommitted_cs.files > 0 then
        table.insert(all, uncommitted_cs)
      end
      vim.list_extend(all, stack_result or {})
      callback(all, nil)
    end

    build_changesets(nodes, function(changesets)
      stack_result = changesets
      maybe_done()
    end)

    -- The uncommitted source returns the same Changeset shape, with the
    -- staged/unstaged attribution M5 staging wants.
    uncommitted.new({ cwd = cwd }):load(function(changesets, _)
      uncommitted_cs = changesets and changesets[1] or nil
      maybe_done()
    end)
  end

  function self:load(callback)
    if graph.load then
      graph:load(function(nodes)
        load_with_uncommitted(nodes, callback)
      end)
    else
      load_with_uncommitted(graph:nodes(), callback)
    end
  end

  function self:refresh(callback)
    self:load(callback)
  end

  function self:can_stage()
    return true
  end

  return self
end

return M
