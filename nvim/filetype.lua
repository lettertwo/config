local function is_flowtype()
  ---@diagnostic disable-next-line: undefined-field
  return vim.fn.getline(1):match("//%s*@flow")
end

vim.filetype.add({
  extension = {
    flow = "flowtype",
    js = function()
      if is_flowtype() then
        return "flowtype"
      end
      return "javascript"
    end,

    jsx = function()
      if is_flowtype() then
        return "flowtypereact"
      end
      return "javascriptreact"
    end,
  },
})
