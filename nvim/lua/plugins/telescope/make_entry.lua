local M = {}

function M.gen_from_grapple_tag(opts) end

function M.gen_from_git_hunk(opts)
  return function(line)
    local filename, lnum_string, col_string, extra = line:match("([^:]+):?(%d*):?(%d*):?(.*)")
    -- TODO: Implement this, and then use the same approach for grapple tags
    return M.gen_from_file_smart(opts)({ filename, lnum_string, col_string, extra })
  end
end

function M.gen_from_file_smart(opts)
  return function(result)
    local telescope_make_entry = require("telescope.make_entry")
    local filename = result[2]
    local lnum_string = result[3]
    local entry_maker = telescope_make_entry.gen_from_file(opts)(filename)
    local telescope_display = entry_maker.display
    function entry_maker.display(entry)
      local display, style = telescope_display(entry)
      local updated_dislay = string.format("%s:%s", display, lnum_string)

      table.insert(style, { { #display, #updated_dislay }, "TelescopeResultsLineNr" })

      return updated_dislay, style
    end

    entry_maker.lnum = tonumber(lnum_string)

    return entry_maker
  end
end

return M
