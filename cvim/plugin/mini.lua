local map = vim.keymap.set

vim.pack.add({ "https://github.com/nvim-mini/mini.nvim" })

---------------------------------------------
-- extracted from MiniMax default keymaps
---------------------------------------------
-- local new_scratch_buffer = function()
--   vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
-- end
--
-- nmap_leader('ba', '<Cmd>b#<CR>',                                 'Alternate')
-- nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',         'Delete')
-- nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
-- nmap_leader('bs', new_scratch_buffer,                            'Scratch')
-- nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',        'Wipeout')
-- nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')
--
-- -- e is for 'Explore' and 'Edit'. Common usage:
-- -- - `<Leader>ed` - open explorer at current working directory
-- -- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- -- - `<Leader>ei` - edit 'init.lua'
-- -- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
-- local edit_plugin_file = function(filename)
--   return string.format('<Cmd>edit %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
-- end
-- local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
-- local explore_quickfix = function()
--   vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen')
-- end
-- local explore_locations = function()
--   vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen')
-- end
--
-- nmap_leader('ed', '<Cmd>lua MiniFiles.open()<CR>',          'Directory')
-- nmap_leader('ef', explore_at_file,                          'File directory')
-- nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                 'init.lua')
-- nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),       'Keymaps config')
-- nmap_leader('em', edit_plugin_file('30_mini.lua'),          'MINI config')
-- nmap_leader('en', '<Cmd>lua MiniNotify.show_history()<CR>', 'Notifications')
-- nmap_leader('eo', edit_plugin_file('10_options.lua'),       'Options config')
-- nmap_leader('ep', edit_plugin_file('40_plugins.lua'),       'Plugins config')
-- nmap_leader('eq', explore_quickfix,                         'Quickfix list')
-- nmap_leader('eQ', explore_locations,                        'Location list')
--
-- -- f is for 'Fuzzy Find'. Common usage:
-- -- - `<Leader>ff` - find files; for best performance requires `ripgrep`
-- -- - `<Leader>fg` - find inside files; requires `ripgrep`
-- -- - `<Leader>fh` - find help tag
-- -- - `<Leader>fr` - resume latest picker
-- -- - `<Leader>fv` - all visited paths; requires 'mini.visits'
-- --
-- -- All these use 'mini.pick'. See `:h MiniPick-overview` for an overview.
-- local pick_added_hunks_buf = '<Cmd>Pick git_hunks path="%" scope="staged"<CR>'
-- local pick_workspace_symbols_live = '<Cmd>Pick lsp scope="workspace_symbol_live"<CR>'
--
-- nmap_leader('f/', '<Cmd>Pick history scope="/"<CR>',            '"/" history')
-- nmap_leader('f:', '<Cmd>Pick history scope=":"<CR>',            '":" history')
-- nmap_leader('fa', '<Cmd>Pick git_hunks scope="staged"<CR>',     'Added hunks (all)')
-- nmap_leader('fA', pick_added_hunks_buf,                         'Added hunks (buf)')
-- nmap_leader('fb', '<Cmd>Pick buffers<CR>',                      'Buffers')
-- nmap_leader('fc', '<Cmd>Pick git_commits<CR>',                  'Commits (all)')
-- nmap_leader('fC', '<Cmd>Pick git_commits path="%"<CR>',         'Commits (buf)')
-- nmap_leader('fd', '<Cmd>Pick diagnostic scope="all"<CR>',       'Diagnostic workspace')
-- nmap_leader('fD', '<Cmd>Pick diagnostic scope="current"<CR>',   'Diagnostic buffer')
-- nmap_leader('ff', '<Cmd>Pick files<CR>',                        'Files')
-- nmap_leader('fg', '<Cmd>Pick grep_live<CR>',                    'Grep live')
-- nmap_leader('fG', '<Cmd>Pick grep pattern="<cword>"<CR>',       'Grep current word')
-- nmap_leader('fh', '<Cmd>Pick help<CR>',                         'Help tags')
-- nmap_leader('fH', '<Cmd>Pick hl_groups<CR>',                    'Highlight groups')
-- nmap_leader('fl', '<Cmd>Pick buf_lines scope="all"<CR>',        'Lines (all)')
-- nmap_leader('fL', '<Cmd>Pick buf_lines scope="current"<CR>',    'Lines (buf)')
-- nmap_leader('fm', '<Cmd>Pick git_hunks<CR>',                    'Modified hunks (all)')
-- nmap_leader('fM', '<Cmd>Pick git_hunks path="%"<CR>',           'Modified hunks (buf)')
-- nmap_leader('fr', '<Cmd>Pick resume<CR>',                       'Resume')
-- nmap_leader('fR', '<Cmd>Pick lsp scope="references"<CR>',       'References (LSP)')
-- nmap_leader('fs', pick_workspace_symbols_live,                  'Symbols workspace (live)')
-- nmap_leader('fS', '<Cmd>Pick lsp scope="document_symbol"<CR>',  'Symbols document')
-- nmap_leader('fv', '<Cmd>Pick visit_paths cwd=""<CR>',           'Visit paths (all)')
-- nmap_leader('fV', '<Cmd>Pick visit_paths<CR>',                  'Visit paths (cwd)')
--
-- -- g is for 'Git'. Common usage:
-- -- - `<Leader>gs` - show information at cursor
-- -- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- -- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- -- - `<Leader>gL` - show Git log of current file
-- local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
-- local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'
--
-- nmap_leader('ga', '<Cmd>Git diff --cached<CR>',             'Added diff')
-- nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',        'Added diff buffer')
-- nmap_leader('gc', '<Cmd>Git commit<CR>',                    'Commit')
-- nmap_leader('gC', '<Cmd>Git commit --amend<CR>',            'Commit amend')
-- nmap_leader('gd', '<Cmd>Git diff<CR>',                      'Diff')
-- nmap_leader('gD', '<Cmd>Git diff -- %<CR>',                 'Diff buffer')
-- nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',         'Log')
-- nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>',     'Log buffer')
-- nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>', 'Toggle overlay')
-- nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',  'Show at cursor')
--
-- xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>', 'Show at selection')
--
-- -- l is for 'Language'. Common usage:
-- -- - `<Leader>ld` - show more diagnostic details in a floating window
-- -- - `<Leader>lr` - perform rename via LSP
-- -- - `<Leader>ls` - navigate to source definition of symbol under cursor
-- --
-- -- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- -- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- -- by an "replace" operator in 'mini.operators' (which is more commonly used).
-- nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',     'Actions')
-- nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>',   'Diagnostic popup')
-- nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>',   'Format')
-- nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>',  'Implementation')
-- nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>',           'Hover')
-- nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>',        'Lens')
-- nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>',          'Rename')
-- nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>',      'References')
-- nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>',      'Source definition')
-- nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>', 'Type definition')
--
-- xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>', 'Format selection')
--
-- -- m is for 'Map'. Common usage:
-- -- - `<Leader>mt` - toggle map from 'mini.map' (closed by default)
-- -- - `<Leader>mf` - focus on the map for fast navigation
-- -- - `<Leader>ms` - change map's side (if it covers something underneath)
-- nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>', 'Focus (toggle)')
-- nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',      'Refresh')
-- nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',  'Side (toggle)')
-- nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',       'Toggle')
--
-- -- o is for 'Other'. Common usage:
-- -- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
-- nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>', 'Resize to default width')
-- nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',    'Trim trailspace')
-- nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',          'Zoom toggle')
--
-- -- s is for 'Session'. Common usage:
-- -- - `<Leader>sn` - start new session
-- -- - `<Leader>sr` - read previously started session
-- -- - `<Leader>sd` - delete previously started session
-- local session_new = 'MiniSessions.write(vim.fn.input("Session name: "))'
--
-- nmap_leader('sd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
-- nmap_leader('sn', '<Cmd>lua ' .. session_new .. '<CR>',         'New')
-- nmap_leader('sr', '<Cmd>lua MiniSessions.select("read")<CR>',   'Read')
-- nmap_leader('sw', '<Cmd>lua MiniSessions.write()<CR>',          'Write current')
--
-- -- t is for 'Terminal'
-- nmap_leader('tT', '<Cmd>horizontal term<CR>', 'Terminal (horizontal)')
-- nmap_leader('tt', '<Cmd>vertical term<CR>',   'Terminal (vertical)')
--
-- -- v is for 'Visits'. Common usage:
-- -- - `<Leader>vv` - add    "core" label to current file.
-- -- - `<Leader>vV` - remove "core" label to current file.
-- -- - `<Leader>vc` - pick among all files with "core" label.
-- local make_pick_core = function(cwd, desc)
--   return function()
--     local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
--     local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
--     MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
--   end
-- end
--
-- nmap_leader('vc', make_pick_core('',  'Core visits (all)'),       'Core visits (all)')
-- nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'),       'Core visits (cwd)')
-- nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',    'Add "core" label')
-- nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>', 'Remove "core" label')
-- nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',          'Add label')
-- nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',       'Remove label')

---------------------------------------
-- -- ┌────────────────────┐
-- -- │ MINI configuration │
-- -- └────────────────────┘
-- --
-- -- This file contains configuration of the MINI parts of the config.
-- -- It contains only configs for the 'mini.nvim' plugin (installed in 'init.lua').
-- --
-- -- 'mini.nvim' is a library of modules. Each is enabled independently via
-- -- `require('mini.xxx').setup()` convention. It creates all intended side effects:
-- -- mappings, autocommands, highlight groups, etc. It also creates a global
-- -- `MiniXxx` table that can be later used to access module's features.
-- --
-- -- Every module's `setup()` function accepts an optional `config` table to
-- -- adjust its behavior. See the structure of this table at `:h MiniXxx.config`.
-- --
-- -- See `:h mini.nvim-general-principles` for more general principles.
-- --
-- -- Here each module's `setup()` has a brief explanation of what the module is for,
-- -- its usage examples (uses Leader mappings from 'plugin/20_keymaps.lua'), and
-- -- possible directions for more info.
-- -- For more info about a module see its help page (`:h mini.xxx` for 'mini.xxx').
--
-- -- To minimize the time until first screen draw, modules are enabled in two steps:
-- -- - Step one enables everything that is needed for first draw with `now()`.
-- --   Sometimes needed only if Neovim is started as `nvim -- path/to/file`.
-- -- - Everything else is delayed until the first draw with `later()`.
-- local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
--
-- -- Step one ===================================================================
-- -- Enable 'miniwinter' color scheme. It comes with 'mini.nvim' and uses 'mini.hues'.
-- --
-- -- See also:
-- -- - `:h mini.nvim-color-schemes` - list of other color schemes
-- -- - `:h MiniHues-examples` - how to define highlighting with 'mini.hues'
-- -- - 'plugin/40_plugins.lua' honorable mentions - other good color schemes
-- now(function() vim.cmd('colorscheme miniwinter') end)
--
-- -- You can try these other 'mini.hues'-based color schemes (uncomment with `gcc`):
-- -- now(function() vim.cmd('colorscheme minispring') end)
-- -- now(function() vim.cmd('colorscheme minisummer') end)
-- -- now(function() vim.cmd('colorscheme miniautumn') end)
-- -- now(function() vim.cmd('colorscheme randomhue') end)
--
-- -- Common configuration presets. Example usage:
-- -- - `<C-s>` in Insert mode - save and go to Normal mode
-- -- - `go` / `gO` - insert empty line before/after in Normal mode
-- -- - `gy` / `gp` - copy / paste from system clipboard
-- -- - `\` + key - toggle common options. Like `\h` toggles highlighting search.
-- -- - `<C-hjkl>` (four combos) - navigate between windows.
-- -- - `<M-hjkl>` in Insert/Command mode - navigate in that mode.
-- --
-- -- See also:
-- -- - `:h MiniBasics.config.options` - list of adjusted options
-- -- - `:h MiniBasics.config.mappings` - list of created mappings
-- -- - `:h MiniBasics.config.autocommands` - list of created autocommands
-- now(function()
--   require('mini.basics').setup({
--     -- Manage options in 'plugin/10_options.lua' for didactic purposes
--     options = { basic = false },
--     mappings = {
--       -- Create `<C-hjkl>` mappings for window navigation
--       windows = true,
--       -- Create `<M-hjkl>` mappings for navigation in Insert and Command modes
--       move_with_alt = true,
--     },
--   })
-- end)
--
-- -- Icon provider. Usually no need to use manually. It is used by plugins like
-- -- 'mini.pick', 'mini.files', 'mini.statusline', and others.
-- now(function()
--   -- Set up to not prefer extension-based icon for some extensions
--   local ext3_blocklist = { scm = true, txt = true, yml = true }
--   local ext4_blocklist = { json = true, yaml = true }
--   require('mini.icons').setup({
--     use_file_extension = function(ext, _)
--       return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
--     end,
--   })
--
--   -- Mock 'nvim-tree/nvim-web-devicons' for plugins without 'mini.icons' support.
--   -- Not needed for 'mini.nvim' or MiniMax, but might be useful for others.
--   later(MiniIcons.mock_nvim_web_devicons)
--
--   -- Add LSP kind icons. Useful for 'mini.completion'.
--   later(MiniIcons.tweak_lsp_kind)
-- end)
--
-- -- Notifications provider. Shows all kinds of notifications in the upper right
-- -- corner (by default). Example usage:
-- -- - `:h vim.notify()` - show notification (hides automatically)
-- -- - `<Leader>en` - show notification history
-- --
-- -- See also:
-- -- - `:h MiniNotify.config` for some of common configuration examples.
-- now(function() require('mini.notify').setup() end)
--
-- -- Session management. A thin wrapper around `:h mksession` that consistently
-- -- manages session files. Example usage:
-- -- - `<Leader>sn` - start new session
-- -- - `<Leader>sr` - read previously started session
-- -- - `<Leader>sd` - delete previously started session
-- now(function() require('mini.sessions').setup() end)
--
-- -- Start screen. This is what is shown when you open Neovim like `nvim`.
-- -- Example usage:
-- -- - Type prefix keys to limit available candidates
-- -- - Navigate down/up with `<C-n>` and `<C-p>`
-- -- - Press `<CR>` to select an entry
-- --
-- -- See also:
-- -- - `:h MiniStarter-example-config` - non-default config examples
-- -- - `:h MiniStarter-lifecycle` - how to work with Starter buffer
-- now(function() require('mini.starter').setup() end)
--
-- -- Statusline. Sets `:h 'statusline'` to show more info in a line below window.
-- -- Example usage:
-- -- - Left most section indicates current mode (text + highlighting).
-- -- - Second from left section shows "developer info": Git, diff, diagnostics, LSP.
-- -- - Center section shows the name of displayed buffer.
-- -- - Second to right section shows more buffer info.
-- -- - Right most section shows current cursor coordinates and search results.
-- --
-- -- See also:
-- -- - `:h MiniStatusline-example-content` - example of default content. Use it to
-- --   configure a custom statusline by setting `config.content.active` function.
-- now(function() require('mini.statusline').setup() end)
--
-- -- Tabline. Sets `:h 'tabline'` to show all listed buffers in a line at the top.
-- -- Buffers are ordered as they were created. Navigate with `[b` and `]b`.
-- now(function() require('mini.tabline').setup() end)
--
-- -- Step one or two ============================================================
-- -- Load now if Neovim is started like `nvim -- path/to/file`, otherwise - later.
-- -- This ensures a correct behavior for files opened during startup.
--
-- -- Completion and signature help. Implements async "two stage" autocompletion:
-- -- - Based on attached LSP servers that support completion.
-- -- - Fallback (based on built-in keyword completion) if there is no LSP candidates.
-- --
-- -- Example usage in Insert mode with attached LSP:
-- -- - Start typing text that should be recognized by LSP (like variable name).
-- -- - After 100ms a popup menu with candidates appears.
-- -- - Press `<Tab>` / `<S-Tab>` to navigate down/up the list. These are set up
-- --   in 'mini.keymap'. You can also use `<C-n>` / `<C-p>`.
-- -- - During navigation there is an info window to the right showing extra info
-- --   that the LSP server can provide about the candidate. It appears after the
-- --   candidate stays selected for 100ms. Use `<C-f>` / `<C-b>` to scroll it.
-- -- - Navigating to an entry also changes buffer text. If you are happy with it,
-- --   keep typing after it. To discard completion completely, press `<C-e>`.
-- -- - After pressing special trigger(s), usually `(`, a window appears that shows
-- --   the signature of the current function/method. It gets updated as you type
-- --   showing the currently active parameter.
-- --
-- -- Example usage in Insert mode without an attached LSP or in places not
-- -- supported by the LSP (like comments):
-- -- - Start typing a word that is present in current or opened buffers.
-- -- - After 100ms popup menu with candidates appears.
-- -- - Navigate with `<Tab>` / `<S-Tab>` or `<C-n>` / `<C-p>`. This also updates
-- --   buffer text. If happy with choice, keep typing. Stop with `<C-e>`.
-- --
-- -- It also works with snippet candidates provided by LSP server. Best experience
-- -- when paired with 'mini.snippets' (which is set up in this file).
-- now_if_args(function()
--   -- Customize post-processing of LSP responses for a better user experience.
--   -- Don't show 'Text' suggestions (usually noisy) and show snippets last.
--   local process_items_opts = { kind_priority = { Text = -1, Snippet = 99 } }
--   local process_items = function(items, base)
--     return MiniCompletion.default_process_items(items, base, process_items_opts)
--   end
--   require('mini.completion').setup({
--     lsp_completion = {
--       -- Without this config autocompletion is set up through `:h 'completefunc'`.
--       -- Although not needed, setting up through `:h 'omnifunc'` is cleaner
--       -- (sets up only when needed) and makes it possible to use `<C-u>`.
--       source_func = 'omnifunc',
--       auto_setup = false,
--       process_items = process_items,
--     },
--   })
--
--   -- Set 'omnifunc' for LSP completion only when needed.
--   local on_attach = function(ev)
--     vim.bo[ev.buf].omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'
--   end
--   Config.new_autocmd('LspAttach', nil, on_attach, "Set 'omnifunc'")
--
--   -- Advertise to servers that Neovim now supports certain set of completion and
--   -- signature features through 'mini.completion'.
--   vim.lsp.config('*', { capabilities = MiniCompletion.get_lsp_capabilities() })
-- end)
--
-- -- Navigate and manipulate file system
-- --
-- -- Navigation is done using column view (Miller columns) to display nested
-- -- directories, they are displayed in floating windows in top left corner.
-- --
-- -- Manipulate files and directories by editing text as regular buffers.
-- --
-- -- Example usage:
-- -- - `<Leader>ed` - open current working directory
-- -- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- --
-- -- Basic navigation:
-- -- - `l` - go in entry at cursor: navigate into directory or open file
-- -- - `h` - go out of focused directory
-- -- - Navigate window as any regular buffer
-- -- - Press `g?` inside explorer to see more mappings
-- --
-- -- Basic manipulation:
-- -- - After any following action, press `=` in Normal mode to synchronize, read
-- --   carefully about actions, press `y` or `<CR>` to confirm
-- -- - New entry: press `o` and type its name; end with `/` to create directory
-- -- - Rename: press `C` and type new name
-- -- - Delete: type `dd`
-- -- - Move/copy: type `dd`/`yy`, navigate to target directory, press `p`
-- --
-- -- See also:
-- -- - `:h MiniFiles-navigation` - more details about how to navigate
-- -- - `:h MiniFiles-manipulation` - more details about how to manipulate
-- -- - `:h MiniFiles-examples` - examples of common setups
-- now_if_args(function()
--   -- Enable directory/file preview
--   require('mini.files').setup({ windows = { preview = true } })
--
--   -- Add common bookmarks for every explorer. Example usage inside explorer:
--   -- - `'c` to navigate into your config directory
--   -- - `g?` to see available bookmarks
--   local add_marks = function()
--     MiniFiles.set_bookmark('c', vim.fn.stdpath('config'), { desc = 'Config' })
--     local vimpack_plugins = vim.fn.stdpath('data') .. '/site/pack/core/opt'
--     MiniFiles.set_bookmark('p', vimpack_plugins, { desc = 'Plugins' })
--     MiniFiles.set_bookmark('w', vim.fn.getcwd, { desc = 'Working directory' })
--   end
--   Config.new_autocmd('User', 'MiniFilesExplorerOpen', add_marks, 'Add bookmarks')
-- end)
--
-- -- Miscellaneous small but useful functions. Example usage:
-- -- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
-- -- - `<Leader>or` - resize window to its "editable width"
-- -- - `:lua put_text(vim.lsp.get_clients())` - put output of a function below
-- --   cursor in current buffer. Useful for a detailed exploration.
-- -- - `:lua put(MiniMisc.stat_summary(MiniMisc.bench_time(f, 100)))` - run
-- --   function `f` 100 times and report statistical summary of execution times
-- now_if_args(function()
--   -- Makes `:h MiniMisc.put()` and `:h MiniMisc.put_text()` public
--   require('mini.misc').setup()
--
--   -- Change current working directory based on the current file path. It
--   -- searches up the file tree until the first root marker ('.git' or 'Makefile')
--   -- and sets their parent directory as a current directory.
--   -- This is helpful when simultaneously dealing with files from several projects.
--   MiniMisc.setup_auto_root()
--
--   -- Restore latest cursor position on file open
--   MiniMisc.setup_restore_cursor()
--
--   -- Synchronize terminal emulator background with Neovim's background to remove
--   -- possibly different color padding around Neovim instance
--   MiniMisc.setup_termbg_sync()
-- end)
--
-- -- Step two ===================================================================
--
-- -- Extra 'mini.nvim' functionality.
-- --
-- -- See also:
-- -- - `:h MiniExtra.pickers` - pickers. Most are mapped in `<Leader>f` group.
-- --   Calling `setup()` makes 'mini.pick' respect 'mini.extra' pickers.
-- -- - `:h MiniExtra.gen_ai_spec` - 'mini.ai' textobject specifications
-- -- - `:h MiniExtra.gen_highlighter` - 'mini.hipatterns' highlighters
-- later(function() require('mini.extra').setup() end)
--
-- -- Extend and create a/i textobjects, like `:h a(`, `:h a'`, and more).
-- -- Contains not only `a` and `i` type of textobjects, but also their "next" and
-- -- "last" variants that will explicitly search for textobjects after and before
-- -- cursor. Example usage:
-- -- - `ci)` - *c*hange *i*inside parenthesis (`)`)
-- -- - `di(` - *d*elete *i*inside padded parenthesis (`(`)
-- -- - `yaq` - *y*ank *a*round *q*uote (any of "", '', or ``)
-- -- - `vif` - *v*isually select *i*inside *f*unction call
-- -- - `cina` - *c*hange *i*nside *n*ext *a*rgument
-- -- - `valaala` - *v*isually select *a*round *l*ast (i.e. previous) *a*rgument
-- --   and then again reselect *a*round new *l*ast *a*rgument
-- --
-- -- See also:
-- -- - `:h text-objects` - general info about what textobjects are
-- -- - `:h MiniAi-builtin-textobjects` - list of all supported textobjects
-- -- - `:h MiniAi-textobject-specification` - examples of custom textobjects
-- later(function()
--   local ai = require('mini.ai')
--   ai.setup({
--     -- 'mini.ai' can be extended with custom textobjects
--     custom_textobjects = {
--       -- Make `aB` / `iB` act on around/inside whole *b*uffer
--       B = MiniExtra.gen_ai_spec.buffer(),
--       -- For more complicated textobjects that require structural awareness,
--       -- use tree-sitter. This example makes `aF`/`iF` mean around/inside function
--       -- definition (not call). See `:h MiniAi.gen_spec.treesitter()` for details.
--       F = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
--     },
--
--     -- 'mini.ai' by default mostly mimics built-in search behavior: first try
--     -- to find textobject covering cursor, then try to find to the right.
--     -- Although this works in most cases, some are confusing. It is more robust to
--     -- always try to search only covering textobject and explicitly ask to search
--     -- for next (`an`/`in`) or last (`al`/`il`).
--     -- Try this. If you don't like it - delete next line and this comment.
--     search_method = 'cover',
--   })
-- end)
--
-- -- Align text interactively. Example usage:
-- -- - `gaip,` - `ga` (align operator) *i*nside *p*aragraph by comma
-- -- - `gAip` - start interactive alignment on the paragraph. Choose how to
-- --   split, justify, and merge string parts. Press `<CR>` to make it permanent,
-- --   press `<Esc>` to go back to initial state.
-- --
-- -- See also:
-- -- - `:h MiniAlign-example` - hands-on list of examples to practice aligning
-- -- - `:h MiniAlign.gen_step` - list of support step customizations
-- -- - `:h MiniAlign-algorithm` - how alignment is done on algorithmic level
-- later(function() require('mini.align').setup() end)
--
-- -- Animate common Neovim actions. Like cursor movement, scroll, window resize,
-- -- window open, window close. Animations are done based on Neovim events and
-- -- don't require custom mappings.
-- --
-- -- It is not enabled by default because its effects are a matter of taste.
-- -- Also scroll and resize have some unwanted side effects (see `:h mini.animate`).
-- -- Uncomment next line (use `gcc`) to enable.
-- -- later(function() require('mini.animate').setup() end)
--
-- -- Go forward/backward with square brackets. Implements consistent sets of mappings
-- -- for selected targets (like buffers, diagnostic, quickfix list entries, etc.).
-- -- Example usage:
-- -- - `]b` - go to next buffer
-- -- - `[j` - go to previous jump inside current buffer
-- -- - `[Q` - go to first entry of quickfix list
-- -- - `]X` - go to last conflict marker in a buffer
-- --
-- -- See also:
-- -- - `:h MiniBracketed` - overall mapping design and list of targets
-- later(function() require('mini.bracketed').setup() end)
--
-- -- Remove buffers. Opened files occupy space in tabline and buffer picker.
-- -- When not needed, they can be removed. Example usage:
-- -- - `<Leader>bw` - completely wipeout current buffer (see `:h :bwipeout`)
-- -- - `<Leader>bW` - completely wipeout current buffer even if it has changes
-- -- - `<Leader>bd` - delete current buffer (see `:h :bdelete`)
-- later(function() require('mini.bufremove').setup() end)
--
-- -- Show next key clues in a bottom right window. Requires explicit opt-in for
-- -- keys that act as clue trigger. Example usage:
-- -- - Press `<Leader>` and wait for 1 second. A window with information about
-- --   next available keys should appear.
-- -- - Press one of the listed keys. Window updates immediately to show information
-- --   about new next available keys. You can press `<BS>` to go back in key sequence.
-- -- - Press keys until they resolve into some mapping.
-- --
-- -- Note: it is designed to work in buffers for normal files. It doesn't work in
-- -- special buffers (like for 'mini.starter' or 'mini.files') to not conflict
-- -- with its local mappings.
-- --
-- -- See also:
-- -- - `:h MiniClue-examples` - examples of common setups
-- -- - `:h MiniClue.ensure_buf_triggers()` - use it to enable triggers in buffer
-- -- - `:h MiniClue.set_mapping_desc()` - change mapping description not from config
-- later(function()
--   local miniclue = require('mini.clue')
--   -- stylua: ignore
--   miniclue.setup({
--     -- Define which clues to show. By default shows only clues for custom mappings
--     -- (uses `desc` field from the mapping; takes precedence over custom clue).
--     clues = {
--       -- This is defined in 'plugin/20_keymaps.lua' with Leader group descriptions
--       Config.leader_group_clues,
--       miniclue.gen_clues.builtin_completion(),
--       miniclue.gen_clues.g(),
--       miniclue.gen_clues.marks(),
--       miniclue.gen_clues.registers(),
--       miniclue.gen_clues.square_brackets(),
--       -- This creates a submode for window resize mappings. Try the following:
--       -- - Press `<C-w>s` to make a window split.
--       -- - Press `<C-w>+` to increase height. Clue window still shows clues as if
--       --   `<C-w>` is pressed again. Keep pressing just `+` to increase height.
--       --   Try pressing `-` to decrease height.
--       -- - Stop submode either by `<Esc>` or by any key that is not in submode.
--       miniclue.gen_clues.windows({ submode_resize = true }),
--       miniclue.gen_clues.z(),
--     },
--     -- Explicitly opt-in for set of common keys to trigger clue window
--     triggers = {
--       { mode = { 'n', 'x' }, keys = '<Leader>' }, -- Leader triggers
--       { mode =   'n',        keys = '\\' },       -- mini.basics
--       { mode = { 'n', 'x' }, keys = '[' },        -- mini.bracketed
--       { mode = { 'n', 'x' }, keys = ']' },
--       { mode =   'i',        keys = '<C-x>' },    -- Built-in completion
--       { mode = { 'n', 'x' }, keys = 'g' },        -- `g` key
--       { mode = { 'n', 'x' }, keys = "'" },        -- Marks
--       { mode = { 'n', 'x' }, keys = '`' },
--       { mode = { 'n', 'x' }, keys = '"' },        -- Registers
--       { mode = { 'i', 'c' }, keys = '<C-r>' },
--       { mode =   'n',        keys = '<C-w>' },    -- Window commands
--       { mode = { 'n', 'x' }, keys = 's' },        -- `s` key (mini.surround, etc.)
--       { mode = { 'n', 'x' }, keys = 'z' },        -- `z` key
--     },
--   })
-- end)
--
-- -- Command line tweaks. Improves command line editing with:
-- -- - Autocompletion. Basically an automated `:h cmdline-completion`.
-- -- - Autocorrection of words as-you-type. Like `:W`->`:w`, `:lau`->`:lua`, etc.
-- -- - Autopeek command range (like line number at the start) as-you-type.
-- later(function() require('mini.cmdline').setup() end)
--
-- -- Tweak and save any color scheme. Contains utility functions to work with
-- -- color spaces and color schemes. Example usage:
-- -- - `:Colorscheme default` - switch with animation to the default color scheme
-- --
-- -- See also:
-- -- - `:h MiniColors.interactive()` - interactively tweak color scheme
-- -- - `:h MiniColors-recipes` - common recipes to use during interactive tweaking
-- -- - `:h MiniColors.convert()` - convert between color spaces
-- -- - `:h MiniColors-color-spaces` - list of supported color sapces
-- --
-- -- It is not enabled by default because it is not really needed on a daily basis.
-- -- Uncomment next line (use `gcc`) to enable.
-- -- later(function() require('mini.colors').setup() end)
--
-- -- Comment lines. Provides functionality to work with commented lines.
-- -- Uses `:h 'commentstring'` option to infer comment structure.
-- -- Example usage:
-- -- - `gcip` - toggle comment (`gc`) *i*inside *p*aragraph
-- -- - `vapgc` - *v*isually select *a*round *p*aragraph and toggle comment (`gc`)
-- -- - `gcgc` - uncomment (`gc`, operator) comment block at cursor (`gc`, textobject)
-- --
-- -- The built-in `:h commenting` is based on 'mini.comment'. Yet this module is
-- -- still enabled as it provides more customization opportunities.
-- later(function() require('mini.comment').setup() end)
--
-- -- Autohighlight word under cursor with a customizable delay.
-- -- Word boundaries are defined based on `:h 'iskeyword'` option.
-- --
-- -- It is not enabled by default because its effects are a matter of taste.
-- -- Uncomment next line (use `gcc`) to enable.
-- -- later(function() require('mini.cursorword').setup() end)
--
-- -- Work with diff hunks that represent the difference between the buffer text and
-- -- some reference text set by a source. Default source uses text from Git index.
-- -- Also provides summary info used in developer section of 'mini.statusline'.
-- -- Example usage:
-- -- - `ghip` - apply hunks (`gh`) within *i*nside *p*aragraph
-- -- - `gHG` - reset hunks (`gH`) from cursor until end of buffer (`G`)
-- -- - `ghgh` - apply (`gh`) hunk at cursor (`gh`)
-- -- - `gHgh` - reset (`gH`) hunk at cursor (`gh`)
-- -- - `<Leader>go` - toggle overlay
-- --
-- -- See also:
-- -- - `:h MiniDiff-overview` - overview of how module works
-- -- - `:h MiniDiff-diff-summary` - available summary information
-- -- - `:h MiniDiff.gen_source` - available built-in sources
-- later(function() require('mini.diff').setup() end)
--
-- -- Git integration for more straightforward Git actions based on Neovim's state.
-- -- It is not meant as a fully featured Git client, only to provide helpers that
-- -- integrate better with Neovim. Example usage:
-- -- - `<Leader>gs` - show information at cursor
-- -- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- -- - `<Leader>gL` - show Git log of current file
-- -- - `:Git help git` - show output of `git help git` inside Neovim
-- --
-- -- See also:
-- -- - `:h MiniGit-examples` - examples of common setups
-- -- - `:h :Git` - more details about `:Git` user command
-- -- - `:h MiniGit.show_at_cursor()` - what information at cursor is shown
-- later(function() require('mini.git').setup() end)
--
-- -- Highlight patterns in text. Like `TODO`/`NOTE` or color hex codes.
-- -- Example usage:
-- -- - `:Pick hipatterns` - pick among all highlighted patterns
-- --
-- -- See also:
-- -- - `:h MiniHipatterns-examples` - examples of common setups
-- later(function()
--   local hipatterns = require('mini.hipatterns')
--   local hi_words = MiniExtra.gen_highlighter.words
--   hipatterns.setup({
--     highlighters = {
--       -- Highlight a fixed set of common words. Will be highlighted in any place,
--       -- not like "only in comments".
--       fixme = hi_words({ 'FIXME', 'Fixme', 'fixme' }, 'MiniHipatternsFixme'),
--       hack = hi_words({ 'HACK', 'Hack', 'hack' }, 'MiniHipatternsHack'),
--       todo = hi_words({ 'TODO', 'Todo', 'todo' }, 'MiniHipatternsTodo'),
--       note = hi_words({ 'NOTE', 'Note', 'note' }, 'MiniHipatternsNote'),
--
--       -- Highlight hex color string (#aabbcc) with that color as a background
--       hex_color = hipatterns.gen_highlighter.hex_color(),
--     },
--   })
-- end)
--
-- -- Visualize and work with indent scope. It visualizes indent scope "at cursor"
-- -- with animated vertical line. Provides relevant motions and textobjects.
-- -- Example usage:
-- -- - `cii` - *c*hange *i*nside *i*ndent scope
-- -- - `Vaiai` - *V*isually select *a*round *i*ndent scope and then again
-- --   reselect *a*round new *i*indent scope
-- -- - `[i` / `]i` - navigate to scope's top / bottom
-- --
-- -- See also:
-- -- - `:h MiniIndentscope.gen_animation` - available animation rules
-- later(function() require('mini.indentscope').setup() end)
--
-- -- Jump to next/previous single character. It implements "smarter `fFtT` keys"
-- -- (see `:h f`) that work across multiple lines, start "jumping mode", and
-- -- highlight all target matches. Example usage:
-- -- - `fxff` - move *f*orward onto next character "x", then next, and next again
-- -- - `dt)` - *d*elete *t*ill next closing parenthesis (`)`)
-- later(function() require('mini.jump').setup() end)
--
-- -- Jump within visible lines to pre-defined spots via iterative label filtering.
-- -- Spots are computed by a configurable spotter function. Example usage:
-- -- - Lock eyes on desired location to jump
-- -- - `<CR>` - start jumping; this shows character labels over target spots
-- -- - Type character that appears over desired location; number of target spots
-- --   should be reduced
-- -- - Keep typing labels until target spot is unique to perform the jump
-- --
-- -- See also:
-- -- - `:h MiniJump2d.gen_spotter` - list of available spotters
-- later(function() require('mini.jump2d').setup() end)
--
-- -- Special key mappings. Provides helpers to map:
-- -- - Multi-step actions. Apply action 1 if condition is met; else apply
-- --   action 2 if condition is met; etc.
-- -- - Combos. Sequence of keys where each acts immediately plus execute extra
-- --   action if all are typed fast enough. Useful for Insert mode mappings to not
-- --   introduce delay when typing mapping keys without intention to execute action.
-- --
-- -- See also:
-- -- - `:h MiniKeymap-examples` - examples of common setups
-- -- - `:h MiniKeymap.map_multistep()` - map multi-step action
-- -- - `:h MiniKeymap.map_combo()` - map combo
-- later(function()
--   require('mini.keymap').setup()
--   -- Navigate 'mini.completion' menu with `<Tab>` /  `<S-Tab>`
--   MiniKeymap.map_multistep('i', '<Tab>', { 'pmenu_next' })
--   MiniKeymap.map_multistep('i', '<S-Tab>', { 'pmenu_prev' })
--   -- On `<CR>` try to accept current completion item, fall back to accounting
--   -- for pairs from 'mini.pairs'
--   MiniKeymap.map_multistep('i', '<CR>', { 'pmenu_accept', 'minipairs_cr' })
--   -- On `<BS>` just try to account for pairs from 'mini.pairs'
--   MiniKeymap.map_multistep('i', '<BS>', { 'minipairs_bs' })
-- end)
--
-- -- Window with text overview. It is displayed on the right hand side. Can be used
-- -- for quick overview and navigation. Hidden by default. Example usage:
-- -- - `<Leader>mt` - toggle map window
-- -- - `<Leader>mf` - focus on the map for fast navigation
-- -- - `<Leader>ms` - change map's side (if it covers something underneath)
-- --
-- -- See also:
-- -- - `:h MiniMap.gen_encode_symbols` - list of symbols to use for text encoding
-- -- - `:h MiniMap.gen_integration` - list of integrations to show in the map
-- --
-- -- NOTE: Might introduce lag on very big buffers (10000+ lines)
-- later(function()
--   local map = require('mini.map')
--   map.setup({
--     -- Use Braille dots to encode text
--     symbols = { encode = map.gen_encode_symbols.dot('4x2') },
--     -- Show built-in search matches, 'mini.diff' hunks, and diagnostic entries
--     integrations = {
--       map.gen_integration.builtin_search(),
--       map.gen_integration.diff(),
--       map.gen_integration.diagnostic(),
--     },
--   })
--
--   -- Map built-in navigation characters to force map refresh
--   for _, key in ipairs({ 'n', 'N', '*', '#' }) do
--     local rhs = key
--       -- Also open enough folds when jumping to the next match
--       .. 'zv'
--       .. '<Cmd>lua MiniMap.refresh({}, { lines = false, scrollbar = false })<CR>'
--     vim.keymap.set('n', key, rhs)
--   end
-- end)
--
-- -- Move any selection in any direction. Example usage in Normal mode:
-- -- - `<M-j>`/`<M-k>` - move current line down / up
-- -- - `<M-h>`/`<M-l>` - decrease / increase indent of current line
-- --
-- -- Example usage in Visual mode:
-- -- - `<M-h>`/`<M-j>`/`<M-k>`/`<M-l>` - move selection left/down/up/right
-- later(function() require('mini.move').setup() end)
--
-- -- Text edit operators. All operators have mappings for:
-- -- - Regular operator (waits for motion/textobject to use)
-- -- - Current line action (repeat second character of operator to activate)
-- -- - Act on visual selection (type operator in Visual mode)
-- --
-- -- Example usage:
-- -- - `griw` - replace (`gr`) *i*inside *w*ord
-- -- - `gmm` - multiple/duplicate (`gm`) current line (extra `m`)
-- -- - `vipgs` - *v*isually select *i*nside *p*aragraph and sort it (`gs`)
-- -- - `gxiww.` - exchange (`gx`) *i*nside *w*ord with next word (`w` to navigate
-- --   to it and `.` to repeat exchange operator)
-- -- - `g==` - execute current line as Lua code and replace with its output.
-- --   For example, typing `g==` over line `vim.lsp.get_clients()` shows
-- --   information about all available LSP clients.
-- --
-- -- See also:
-- -- - `:h MiniOperators-mappings` - overview of how mappings are created
-- -- - `:h MiniOperators-overview` - overview of present operators
-- later(function()
--   require('mini.operators').setup()
--
--   -- Create mappings for swapping adjacent arguments. Notes:
--   -- - Relies on `a` argument textobject from 'mini.ai'.
--   -- - It is not 100% reliable, but mostly works.
--   -- - It overrides `:h (` and `:h )`.
--   -- Explanation: `gx`-`ia`-`gx`-`ila` <=> exchange current and last argument
--   -- Usage: when on `a` in `(aa, bb)` press `)` followed by `(`.
--   vim.keymap.set('n', '(', 'gxiagxila', { remap = true, desc = 'Swap arg left' })
--   vim.keymap.set('n', ')', 'gxiagxina', { remap = true, desc = 'Swap arg right' })
-- end)
--
-- -- Autopairs functionality. Insert pair when typing opening character and go over
-- -- right character if it is already to cursor's right. Also provides mappings for
-- -- `<CR>` and `<BS>` to perform extra actions when inside pair.
-- -- Example usage in Insert mode:
-- -- - `(` - insert "()" and put cursor between them
-- -- - `)` when there is ")" to the right - jump over ")" without inserting new one
-- -- - `<C-v>(` - always insert a single "(" literally. This is useful since
-- --   'mini.pairs' doesn't provide particularly smart behavior, like auto balancing
-- later(function()
--   -- Create pairs not only in Insert, but also in Command line mode
--   require('mini.pairs').setup({ modes = { command = true } })
-- end)
--
-- -- Pick anything with single window layout and fast matching. This is one of
-- -- the main usability improvements as it powers a lot of "find things quickly"
-- -- workflows. How to use a picker:
-- -- - Start picker, usually with `:Pick <picker-name>` command. Like `:Pick files`.
-- --   It shows a single window in the bottom left corner filled with possible items
-- --   to choose from. Current item has special full line highlighting.
-- --   At the top there is a current query used to filter+sort items.
-- -- - Type characters (appear at top) to narrow down items. There is fuzzy matching:
-- --   characters may not match one-by-one, but they should be in correct order.
-- -- - Navigate down/up with `<C-n>`/`<C-p>`.
-- -- - Press `<Tab>` to show item's preview. `<Tab>` again goes back to items.
-- -- - Press `<S-Tab>` to show picker's info. `<S-Tab>` again goes back to items.
-- -- - Press `<CR>` to choose an item. The exact action depends on the picker: `files`
-- --   picker opens a selected file, `help` picker opens help page on selected tag.
-- --   To close picker without choosing an item, press `<Esc>`.
-- --
-- -- Example usage:
-- -- - `<Leader>ff` - *f*ind *f*iles; for best performance requires `ripgrep`
-- -- - `<Leader>fg` - *f*ind inside files (a.k.a. "to *g*rep"); requires `ripgrep`
-- -- - `<Leader>fh` - *f*ind *h*elp tag
-- -- - `<Leader>fr` - *r*esume latest picker
-- -- - `:h vim.ui.select()` - implemented with 'mini.pick'
-- --
-- -- See also:
-- -- - `:h MiniPick-overview` - overview of picker functionality
-- -- - `:h MiniPick-examples` - examples of common setups
-- -- - `:h MiniPick.builtin` and `:h MiniExtra.pickers` - available pickers;
-- --   Execute one either with Lua function, `:Pick <picker-name>` command, or
-- --   one of `<Leader>f` mappings defined in 'plugin/20_keymaps.lua'
-- later(function() require('mini.pick').setup() end)
--
-- -- Manage and expand snippets (templates for a frequently used text).
-- -- Typical workflow is to type snippet's (configurable) prefix and expand it
-- -- into a snippet session.
-- --
-- -- How to manage snippets:
-- -- - 'mini.snippets' itself doesn't come with preconfigured snippets. Instead there
-- --   is a flexible system of how snippets are prepared before expanding.
-- --   They can come from pre-defined path on disk, 'snippets/' directories inside
-- --   config or plugins, defined inside `setup()` call directly.
-- -- - This config, however, does come with snippet configuration:
-- --     - 'snippets/global.json' is a file with global snippets that will be
-- --       available in any buffer
-- --     - 'after/snippets/lua.json' defines personal snippets for Lua language
-- --     - 'friendly-snippets' plugin configured in 'plugin/40_plugins.lua' provides
-- --       a collection of language snippets
-- --
-- -- How to expand a snippet in Insert mode:
-- -- - If you know snippet's prefix, type it as a word and press `<C-j>`. Snippet's
-- --   body should be inserted instead of the prefix.
-- -- - If you don't remember snippet's prefix, type only part of it (or none at all)
-- --   and press `<C-j>`. It should show picker with all snippets that have prefixes
-- --   matching typed characters (or all snippets if none was typed).
-- --   Choose one and its body should be inserted instead of previously typed text.
-- --
-- -- How to navigate during snippet session:
-- -- - Snippets can contain tabstops - places for user to interactively adjust text.
-- --   Each tabstop is highlighted depending on session progression - whether tabstop
-- --   is current, was or was not visited. If tabstop doesn't yet have text, it is
-- --   visualized with special "ghost" inline text: • and ∎ by default.
-- -- - Type necessary text at current tabstop and navigate to next/previous one
-- --   by pressing `<C-l>` / `<C-h>`.
-- -- - Repeat previous step until you reach special final tabstop, usually denoted
-- --   by ∎ symbol. If you spotted a mistake in an earlier tabstop, navigate to it
-- --   and return back to the final tabstop.
-- -- - To end a snippet session when at final tabstop, keep typing or go into
-- --   Normal mode. To force end snippet session, press `<C-c>`.
-- --
-- -- See also:
-- -- - `:h MiniSnippets-overview` - overview of how module works
-- -- - `:h MiniSnippets-examples` - examples of common setups
-- -- - `:h MiniSnippets-session` - details about snippet session
-- -- - `:h MiniSnippets.gen_loader` - list of available loaders
-- later(function()
--   -- Define language patterns to work better with 'friendly-snippets'
--   local latex_patterns = { 'latex/**/*.json', '**/latex.json' }
--   local lang_patterns = {
--     tex = latex_patterns,
--     plaintex = latex_patterns,
--     -- Recognize special injected language of markdown tree-sitter parser
--     markdown_inline = { 'markdown.json' },
--   }
--
--   local snippets = require('mini.snippets')
--   local config_path = vim.fn.stdpath('config')
--   snippets.setup({
--     snippets = {
--       -- Always load 'snippets/global.json' from config directory
--       snippets.gen_loader.from_file(config_path .. '/snippets/global.json'),
--       -- Load from 'snippets/' directory of plugins, like 'friendly-snippets'
--       snippets.gen_loader.from_lang({ lang_patterns = lang_patterns }),
--     },
--   })
--
--   -- By default snippets available at cursor are not shown as candidates in
--   -- 'mini.completion' menu. This requires a dedicated in-process LSP server
--   -- that will provide them. To have that, uncomment next line (use `gcc`).
--   -- MiniSnippets.start_lsp_server()
-- end)
--
-- -- Split and join arguments (regions inside brackets between allowed separators).
-- -- It uses Lua patterns to find arguments, which means it works in comments and
-- -- strings but can be not as accurate as tree-sitter based solutions.
-- -- Each action can be configured with hooks (like add/remove trailing comma).
-- -- Example usage:
-- -- - `gS` - toggle between joined (all in one line) and split (each on a separate
-- --   line and indented) arguments. It is dot-repeatable (see `:h .`).
-- --
-- -- See also:
-- -- - `:h MiniSplitjoin.gen_hook` - list of available hooks
-- later(function() require('mini.splitjoin').setup() end)
--
-- -- Surround actions: add/delete/replace/find/highlight. Working with surroundings
-- -- is surprisingly common: surround word with quotes, replace `)` with `]`, etc.
-- -- This module comes with many built-in surroundings, each identified by a single
-- -- character. It searches only for surrounding that covers cursor and comes with
-- -- a special "next" / "last" versions of actions to search forward or backward
-- -- (just like 'mini.ai'). All text editing actions are dot-repeatable (see `:h .`).
-- --
-- -- Example usage (this may feel intimidating at first, but after practice it
-- -- becomes second nature during text editing):
-- -- - `saiw)` - *s*urround *a*dd for *i*nside *w*ord parenthesis (`)`)
-- -- - `sdf`   - *s*urround *d*elete *f*unction call (like `f(var)` -> `var`)
-- -- - `srb[`  - *s*urround *r*eplace *b*racket (any of [], (), {}) with padded `[`
-- -- - `sf*`   - *s*urround *f*ind right part of `*` pair (like bold in markdown)
-- -- - `shf`   - *s*urround *h*ighlight current *f*unction call
-- -- - `srn{{` - *s*urround *r*eplace *n*ext curly bracket `{` with padded `{`
-- -- - `sdl'`  - *s*urround *d*elete *l*ast quote pair (`'`)
-- -- - `vaWsa<Space>` - *v*isually select *a*round *W*ORD and *s*urround *a*dd
-- --                    spaces (`<Space>`)
-- --
-- -- See also:
-- -- - `:h MiniSurround-builtin-surroundings` - list of all supported surroundings
-- -- - `:h MiniSurround-surrounding-specification` - examples of custom surroundings
-- -- - `:h MiniSurround-vim-surround-config` - alternative set of action mappings
-- later(function() require('mini.surround').setup() end)
--
-- -- Highlight and remove trailspace. Temporarily stops highlighting in Insert mode
-- -- to reduce noise when typing. Example usage:
-- -- - `<Leader>ot` - trim all trailing whitespace in a buffer
-- later(function() require('mini.trailspace').setup() end)
--
-- -- Track and reuse file system visits. Every file/directory visit is persistently
-- -- tracked on disk to later reuse: show in special frecency order, etc. It also
-- -- supports adding labels to visited paths to quickly navigate between them.
-- -- Example usage:
-- -- - `<Leader>fv` - find across all visits
-- -- - `<Leader>vv` / `<Leader>vV` - add/remove special "core" label to current file
-- -- - `<Leader>vc` / `<Leader>vC` - show files with "core" label; all or added within
-- --   current working directory
-- --
-- -- See also:
-- -- - `:h MiniVisits-overview` - overview of how module works
-- -- - `:h MiniVisits-examples` - examples of common setups
-- later(function() require('mini.visits').setup() end)
--
-- -- Not mentioned here, but can be useful:
-- -- - 'mini.doc' - needed only for plugin developers.
-- -- - 'mini.fuzzy' - not really needed on a daily basis.
-- -- - 'mini.test' - needed only for plugin developers.

-- require("mini.jump").setup()

Config.once("BufReadPost", function()
	require("mini.trailspace").setup()
	require("mini.operators").setup()
	require("mini.bracketed").setup()

	require("mini.align").setup({
		-- Module mappings. Use `''` (empty string) to disable one.
		mappings = {
			start = "",
			start_with_preview = "ga",
		},
		modifiers = {
			["1"] = function(steps)
				table.insert(steps.pre_justify, require("mini.align").gen_step.filter("n == 1"))
			end,
		},
	})

	local ai = require("mini.ai")
	local gen_ai_spec = require("mini.extra").gen_ai_spec
	ai.setup({
		n_lines = 500,
		custom_textobjects = {
			G = gen_ai_spec.buffer(),
			D = gen_ai_spec.diagnostic(),
			I = gen_ai_spec.indent(),
			V = gen_ai_spec.line(),
			N = gen_ai_spec.number(),
			b = ai.gen_spec.treesitter({ -- code block
				a = { "@block.outer", "@conditional.outer", "@loop.outer" },
				i = { "@block.inner", "@conditional.inner", "@loop.inner" },
			}),
			f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }), -- function
			t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
			e = { -- Word with case
				{ "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
				"^().*()$",
			},
			u = ai.gen_spec.function_call(), -- u for "Usage"
			U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- without dot in function name

			C = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
			-- comment; nvim-treesitter/nvim-treesitter-textobjects only defines "@comment.outer".
			c = ai.gen_spec.treesitter({ a = "@comment.outer", i = "@comment.inner" }), -- comment
		},
	})

	require("mini.surround").setup({
		custom_surroundings = {
			-- Invert the balanced bracket behaviors.
			-- Open inserts without space, close inserts with space.
			["("] = { output = { left = "(", right = ")" } },
			[")"] = { output = { left = "( ", right = " )" } },
			["{"] = { output = { left = "{", right = "}" } },
			["}"] = { output = { left = "{ ", right = " }" } },
			["["] = { output = { left = "[", right = "]" } },
			["]"] = { output = { left = "[ ", right = " ]" } },
			["<"] = { output = { left = "<", right = ">" } },
			[">"] = { output = { left = "< ", right = " >" } },
		},
		mappings = {
			add = "gs", -- Add surrounding in Normal and Visual modes
			delete = "ds", -- Delete surrounding
			replace = "cs", -- Replace surrounding

			find = "", -- Find surrounding (to the right)
			find_left = "", -- Find surrounding (to the left)
			highlight = "", -- Highlight surrounding
			suffix_last = "", -- Suffix to search with "prev" method
			suffix_next = "", -- Suffix to search with "next" method
			update_n_lines = "", -- Update `n_lines`
		},
		n_lines = 500,
		search_method = "cover_or_next",
		respect_selection_type = true,
	})

	-- Convenience for quickly surrounding with () or {}
	map("x", "(", "gs(", { desc = "Add surrounding () to selection", remap = true })
	map("x", ")", "gs)", { desc = "Add surrounding () to selection", remap = true })
	map("x", "{", "gs{", { desc = "Add surrounding {} to selection", remap = true })
	map("x", "}", "gs}", { desc = "Add surrounding {} to selection", remap = true })
end)

require("mini.files").setup({
	-- Module mappings created only inside explorer.
	-- Use `''` (empty string) to not create one.
	mappings = {
		close = "q",
		go_in = "l",
		go_in_plus = "<CR>",
		go_out = "<BS>",
		go_out_plus = "h",
		reset = "!",
		reveal_cwd = "@",
		show_help = "g?",
		synchronize = "w",
		trim_left = "<",
		trim_right = ">",
	},

	options = {
		permanent_delete = true,
		use_as_default_explorer = true,
	},

	windows = {
		preview = true,
		width_focus = 50,
		width_nofocus = 15,
		width_preview = 70,
	},
})

local actions = require("config.mini.files.actions")

map("n", "<leader>e", actions.open_buffer, { desc = "File explorer (buffer)" })
map("n", "<leader>~", actions.open_cwd, { desc = "File explorer (cwd)" })

Config.on("User", "MiniFilesBufferCreate", function(args)
	if args.data.buf_id ~= nil then
    -- stylua: ignore start
    map("n", "<esc>", actions.close,            { desc = "Close minifiles",  buffer = args.data.buf_id })
    map("n", "g.",    actions.toggle_dotfiles,  { desc = "Toggle dotfiles",  buffer = args.data.buf_id })
    map("n", "<C-.>", actions.files_set_cwd,    { desc = "Set cwd",          buffer = args.data.buf_id })
    map("n", "<C-s>", actions.split,            { desc = "Open in split",    buffer = args.data.buf_id })
    map("n", "<C-v>", actions.vsplit,           { desc = "Open in vsplit",   buffer = args.data.buf_id })
    map("n", "<C-o>", actions.reveal_in_finder, { desc = "Reveal in finder", buffer = args.data.buf_id })
		-- stylua: ignore end
	end
end)

require("config.mini.files.status").setup()
require("config.mini.files.severity").setup()
