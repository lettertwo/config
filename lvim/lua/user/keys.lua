-- keymappings [view all the defaults by pressing <leader>Lk]
-- unmap a default keymapping by setting it to false

-- Use space as the leader key.
-- See plugins/which-key for <Leader> mappings.
lvim.leader = "space"

-- Cancel search highlighting with ESC
lvim.keys.normal_mode["<ESC>"] = ":nohlsearch<Bar>:echo<CR>"

-- Paste over selection (without yanking)
lvim.keys.visual_mode["p"] = '"_dP'

-- Indent and outdent visual selections
lvim.keys.visual_mode["H"] = "<gv"
lvim.keys.visual_mode["L"] = ">gv"

-- Seamless window management between Kitty and Neovim
-- lvim.keys.normal_mode["<c-w>h"] = ":KittyNavigateLeft<CR>"
-- lvim.keys.normal_mode["<c-w>j"] = ":KittyNavigateDown<CR>"
-- lvim.keys.normal_mode["<c-w>k"] = ":KittyNavigateUp<CR>"
-- lvim.keys.normal_mode["<c-w>l"] = ":KittyNavigateRight<CR>"
