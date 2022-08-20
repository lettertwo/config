local function is_flowtype()
  return vim.fn.getline(1):match("//%s*@flow")
end

vim.filetype.add({
  extension = {
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
