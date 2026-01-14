local M = {}

local function to_subwords(str)
  local subwords = {}
  -- Handle camelCase/PascalCase: insert space before uppercase after lowercase
  str = str:gsub("(%l)(%u)", "%1 %2")
  -- Handle ACRONYMWord: insert space before last uppercase in sequence
  str = str:gsub("(%u)(%u%l)", "%1 %2")
  -- Split on non-alphanumeric characters and collect words
  for subword in str:gmatch("%w+") do
    if subword ~= "" then
      table.insert(subwords, subword)
    end
  end
  return subwords
end

-- Helper to apply a function to each line preserving newlines
-- Can take either a string with newlines or a list of strings
local function apply_per_line(str_or_list, fn)
  local lines = type(str_or_list) == "table" and str_or_list or vim.split(str_or_list, "\n", { plain = true })
  for i, line in ipairs(lines) do
    lines[i] = fn(line)
  end
  return lines
end

M.to_upper_case = {
  key = { "u", "U" },
  desc = "TO UPPER CASE",
  apply = function(str)
    return vim.fn.toupper(str)
  end,
}

M.to_lower_case = {
  key = "l",
  desc = "to lower case",
  apply = function(str)
    return vim.fn.tolower(str)
  end,
}

M.to_dash_case = {
  key = { "d", "-" },
  desc = "to-dash-case",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      subwords[i] = subword:lower()
    end
    return table.concat(subwords, "-")
  end,
}

M.to_snake_case = {
  key = { "s", "_" },
  desc = "to_snake_case",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      subwords[i] = subword:lower()
    end
    return table.concat(subwords, "_")
  end,
}

M.to_camel_case = {
  key = "c",
  desc = "toCamelCase",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      if i == 1 then
        subwords[i] = subword:lower()
      else
        subwords[i] = subword:sub(1, 1):upper() .. subword:sub(2):lower()
      end
    end
    return table.concat(subwords, "")
  end,
}

M.to_pascal_case = {
  key = "p",
  desc = "ToPascalCase",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      subwords[i] = subword:sub(1, 1):upper() .. subword:sub(2):lower()
    end
    return table.concat(subwords, "")
  end,
}

M.to_constant_case = {
  key = "C",
  desc = "TO_CONSTANT_CASE",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      subwords[i] = subword:upper()
    end
    return table.concat(subwords, "_")
  end,
}

M.to_title_case = {
  key = "t",
  desc = "To Title Case",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      subwords[i] = subword:sub(1, 1):upper() .. subword:sub(2):lower()
    end
    return table.concat(subwords, " ")
  end,
}

M.to_sentence_case = {
  key = "S",
  desc = "To sentence case",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      -- subwords[i] = subword:sub(1, 1):upper() .. subword:sub(2):lower()
      if i == 1 then
        subwords[i] = subword:sub(1, 1):upper() .. subword:sub(2):lower()
      else
        subwords[i] = subword:lower()
      end
    end
    return table.concat(subwords, " ")
  end,
}

M.to_dot_case = {
  key = ".",
  desc = "to.dot.case",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      subwords[i] = subword:lower()
    end
    return table.concat(subwords, ".")
  end,
}

M.to_path_case = {
  key = "/",
  desc = "to/path/case",
  apply = function(str)
    local subwords = to_subwords(str)
    for i, subword in ipairs(subwords) do
      subwords[i] = subword:lower()
    end
    return table.concat(subwords, "/")
  end,
}

local function current_visual(method)
  return function()
    local vstart = vim.fn.getpos("v")
    local vstop = vim.fn.getpos(".")
    local str = vim.api.nvim_buf_get_text(0, vstart[2] - 1, vstart[3] - 1, vstop[2] - 1, vstop[3], {})
    local replacement = apply_per_line(str, method.apply)
    if replacement ~= nil then
      vim.api.nvim_buf_set_text(0, vstart[2] - 1, vstart[3] - 1, vstop[2] - 1, vstop[3], replacement)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
      vim.api.nvim_win_set_cursor(0, { vstart[2], vstart[3] - 1 })
    end
  end
end

local function current_word(method)
  return function()
    local cpos = vim.fn.searchpos("\\W", "Wbcn")
    local cword = vim.fn.expand("<cword>")
    local replacement = apply_per_line(cword, method.apply)
    if replacement ~= nil then
      vim.api.nvim_buf_set_text(0, cpos[1] - 1, cpos[2], cpos[1] - 1, cpos[2] + #cword, replacement)
    end
  end
end

local function lsp_rename(method)
  return function()
    local cword = vim.fn.expand("<cword>")
    local replacement = apply_per_line(cword, method.apply)
    if replacement ~= nil then
      vim.lsp.buf_request(0, "textDocument/rename", function(client)
        local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
        ---@diagnostic disable-next-line: inject-field
        params.newName = table.concat(replacement, "\n")
        return params
      end, function(err, result, ctx)
        if err then
          vim.notify("LSP Rename Error: " .. err.message, vim.log.levels.ERROR)
        elseif not result or not result.changes then
          vim.notify("No changes from LSP rename", vim.log.levels.INFO)
        elseif vim.api.nvim_get_current_buf() == ctx.bufnr then
          local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
          vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
        end
      end)
    end
  end
end

local function select_text_case(done)
  return function()
    local cases = vim.tbl_values(M)
    vim.ui.select(cases, {
      prompt = "Select text-case:",
      format_item = function(item)
        return item.desc
      end,
    }, done)
  end
end

vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("TextCaseSetup", { clear = true }),
  pattern = "VeryLazy",
  callback = function()
    for _, method in pairs(M) do
      vim.validate("method", method, "table")
      vim.validate("method.key", method.key, { "string", "table" })
      vim.validate("method.desc", method.desc, "string")
      vim.validate("method.apply", method.apply, "function")
      local keys = type(method.key) == "string" and { method.key } or method.key
      for _, key in ipairs(keys) do
        vim.keymap.set("n", "g~" .. key, current_word(method), { desc = method.desc })
        vim.keymap.set("v", "g~" .. key, current_visual(method), { desc = method.desc })
        vim.keymap.set("n", "gr~" .. key, lsp_rename(method), { desc = method.desc })
      end
    end
    vim.keymap.set(
      "n",
      "g~~",
      select_text_case(function(item)
        return current_word(item)()
      end),
      { desc = "Select text case" }
    )

    if package.loaded["occurrence"] then
      vim.keymap.set({ "n", "v" }, "g~o", "<cmd>Occurrence modify_operator g~<CR>", { desc = "marked occurrences" })
    end
  end,
})

return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "g~", group = "text-case" },
        { "gr~", group = "text-case" },
      },
    },
  },
  {
    "lettertwo/occurrence.nvim",
    optional = true,
    opts = {
      operators = {
        ["g~"] = {
          desc = "Swap text case of marked occurrences",
          before = function(_, ctx)
            return function(done)
              select_text_case(function(item)
                if item == nil then
                  done(false)
                else
                  ctx.textcase = item
                  done()
                end
              end)()
            end
          end,
          operator = function(current, ctx)
            if ctx.textcase == nil or ctx.textcase.apply == nil then
              -- Fallback to builtin case toggle operator
              return require("occurrence.api").toggle_case.operator(current, ctx)
            end
            return apply_per_line(current.text, ctx.textcase.apply)
          end,
        },
      },
    },
  },
}
