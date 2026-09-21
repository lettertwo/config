local assert = require("luassert")
local Store = require("config.annotations.store")
local Watch = require("config.annotations.watch")

describe("Config.Annotations.Watch", function()
  local dir, prev_cwd

  before_each(function()
    prev_cwd = vim.uv.cwd()
    dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.system({ "git", "init", "-q" }, { cwd = dir }):wait()
    vim.uv.chdir(dir)
    Store._reset_cache()
    -- Watch.start is a no-op unless claude-annotations/ already exists.
    vim.fn.mkdir(vim.fs.joinpath(dir, ".git", "claude-annotations"), "p")
  end)

  after_each(function()
    Watch.stop()
    vim.uv.chdir(prev_cwd)
    vim.fn.delete(dir, "rf")
  end)

  it("collapses a burst of appends inside the debounce window into one reload", function()
    Watch.start()

    local reloads = 0
    local autocmd_id = vim.api.nvim_create_autocmd("User", {
      pattern = "AnnotationsChanged",
      callback = function()
        reloads = reloads + 1
      end,
    })

    local res_path = vim.fs.joinpath(dir, ".git", "claude-annotations", "resolutions.jsonl")
    for i = 1, 3 do
      local lines = {}
      if vim.fn.filereadable(res_path) == 1 then
        lines = vim.fn.readfile(res_path)
      end
      table.insert(lines, vim.json.encode({ id = tostring(i), status = "changed", note = "", ts = i }))
      vim.fn.writefile(lines, res_path)
    end

    -- The debounce is 100ms; give it room to fire once, well short of a
    -- second reload ever having a reason to happen.
    vim.wait(500, function()
      return reloads > 0
    end, 20)

    vim.api.nvim_del_autocmd(autocmd_id)
    assert.equals(1, reloads)
  end)
end)
