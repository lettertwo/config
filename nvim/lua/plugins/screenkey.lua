return {
  {
    "NStefan002/screenkey.nvim",
    cmd = "Screenkey",
    -- lazy = false,
    ---@module "screenkey"
    ---@type screenkey.config
    opts = {
      win_opts = {
        row = 0,
        relative = "win",
        anchor = "NE",
        border = "rounded",
        title = "",
        style = "minimal",
      },
      hl_groups = {
        ["screenkey.hl.key"] = { link = "DiagnosticVirtualTextInfo" },
        ["screenkey.hl.map"] = { link = "DiagnosticVirtualTextOk" },
      },
      group_mappings = true,
      filter = function(keys)
        return vim
          .iter(vim.iter(keys):rev():fold(
            ---@type { keys: screenkey.queued_key[], sequence: nil }
            { keys = {}, current_mapping = nil },
            -- The `group_mappings = true` option adds grouped keymaps to the queue, but
            -- does not filter out the partial key sequences that led to the mapping being
            -- grouped. This function removes those partial sequences from the display.
            -- It also 'downgrades' mapping keys that are repeated more than once to regular keys.
            ---@param key screenkey.queued_key
            function(acc, key)
              if acc.sequence ~= nil and vim.endswith(acc.sequence, key.key) then
                acc.sequence = string.sub(acc.sequence, 1, #acc.sequence - #key.key)
              else
                if key.is_mapping then
                  if key.consecutive_repeats > 2 then
                    key.is_mapping = false
                  else
                    acc.sequence = key.key
                  end
                  table.insert(acc.keys, key)
                elseif
                  #acc.keys > 0
                  and acc.keys[#acc.keys].is_mapping == false
                  and acc.keys[#acc.keys].consecutive_repeats < 3
                then
                  acc.keys[#acc.keys].key = key.key .. acc.keys[#acc.keys].key
                else
                  table.insert(acc.keys, key)
                end
              end
              return acc
            end
          ).keys)
          :rev()
          :totable()
      end,
      colorize = function(keys)
        return vim
          .iter(keys)
          :map(
            -- Give mapping keys extra space. We mitigate layout shifts
            -- by 'borrowing' space from the separator between keys.
            ---@param key screenkey.colored_key
            function(key)
              if key[2] == "screenkey.hl.sep" then
                key[1] = " "
              else
                key[1] = " " .. key[1] .. " "
              end
              return key
            end
          )
          :totable()
      end,
      separator = "    ", -- extra space between keys that we can 'borrow' for colorizing.
      notify_method = "notify",
    },
  },
}
