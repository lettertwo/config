local function download_packer()
  if vim.fn.input("Download Packer? (y for yes)") ~= "y" then
    return
  end
  print(" Downloading packer.nvim...")

  local join_paths = require("fs").join_paths
  local packer_url = "https://github.com/wbthomason/packer.nvim"
  local packer_path = join_paths(vim.fn.stdpath("data"), "site", "pack", "packer", "start")
  vim.fn.mkdir(packer_path, "p")

  print(vim.fn.system({ "git", "clone", packer_url, join_paths(packer_path, "packer.nvim") }))

  vim.cmd([[packadd packer.nvim]])
  require("plugins")

  vim.fn.input("You will need to restart neovim! (press any key to continue)")
  vim.cmd([[ autocmd User PackerComplete quitall ]])
  vim.cmd([[ PackerSync ]])
end

return function()
  if not pcall(require, "packer") then
    download_packer()
    return true
  end
  return false
end
