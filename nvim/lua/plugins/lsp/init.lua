local Util = require("util")

return {
  {
    "neovim/nvim-lspconfig",
    cmd = { "LspInfo", "LspStart", "LspStop", "LspRestart" },
    event = "BufReadPost",
    keys = {
      { "<leader>lI", "<cmd>LspInfo<CR>", desc = "Show LSP status" },
      { "<leader>lS", "<cmd>LspStart<CR>", desc = "Start LSP clients" },
      { "<leader>lR", "<cmd>LspRestart<CR>", desc = "Restart LSP clients" },
      { "<leader>lq", "<cmd>LspStop<CR>", desc = "Stop LSP client(s)" },
    },
    dependencies = {
      {
        "folke/neoconf.nvim",
        cmd = "Neoconf",
        keys = {
          { "<leader>,e", "<cmd>Neoconf local<CR>", desc = "Edit (local)" },
          { "<leader>,g", "<cmd>Neoconf local<CR>", desc = "Edit (global)" },
          { "<leader>,,", "<cmd>Neoconf<CR>", desc = "Edit conf" },
          { "<leader>,l", "<cmd>Neoconf lsp<CR>", desc = "Show Neoconf lsp" },
          { "<leader>lc", "<cmd>Neoconf lsp<CR>", desc = "Show Neoconf lsp" },
          { "<leader>,s", "<cmd>Neoconf show<CR>", desc = "Show conf" },
        },
        config = true,
      },
      {
        "folke/neodev.nvim",
        config = true,
      },
      {
        "smjonas/inc-rename.nvim",
        cmd = "IncRename",
        event = "BufReadPost",
        config = true,
      },
      "hrsh7th/cmp-nvim-lsp",
      "b0o/SchemaStore.nvim",
      {
        "mrcjkb/rustaceanvim",
        ft = { "rust" },
        init = function()
          vim.g.rustaceanvim = {
            -- Plugin configuration
            tools = {
              hover_actions = {
                replace_builtin_hover = false,
              },
            },

            -- LSP configuration
            server = {
              on_attach = function(client, buffer)
                -- stylua: ignore
                require("plugins.lsp.keymaps").apply({buffer = buffer, client = client}, {
                  { "<leader>le", "<cmd>RustLsp expandMacro<cr>", desc = "Expand macro" },
                  { "<leader>lp", "<cmd>RustLsp parentModule<cr>", desc = "Parent module" },
                  { "<leader>lk", "<cmd>RustLsp moveItem up<cr>", desc = "Move item up" },
                  { "<leader>lj", "<cmd>RustLsp moveItem down<cr>", desc = "Move item down" },
                  { "<leader>lJ", "<cmd>RustLsp joinLines<cr>", desc = "Join lines" },

                  { "<leader>dr", "<cmd>RustLsp debuggables<cr>", desc = "Debuggables" },

                  { "<leader>Pcr", "<cmd>RustLsp runnables<cr>", desc = "Runnables" },
                  { "<leader>Pco", "<cmd>RustLsp openCargo<cr>", desc = "Open cargo.toml" },

                  -- TODO: mappings for these:
                  -- { "<leader>Pcg", "<cmd>RustLsp crateGraph bmp<cr>", desc = "View crate graph" },
                  -- { "<leader>l/", "<cmd>RustLsp ssr<cr>", desc = "Structural search replace" },
                  -- { "<leader>", "<cmd>RustLsp syntaxTree<cr>", desc = "View syntax tree" },
                  -- { "<leader>", "<cmd>RustLsp explainError<cr>", desc = "Explain errors" },
                  -- { "<leader>", "<cmd>RustLsp hover actions<cr>", desc = "Hover actions" },
                  -- { "<leader>", "<cmd>RustLsp hover range<cr>", desc = "Hover range" },
                  -- { "<leader>", "<cmd>RustLsp hover rebuildProcMacros<cr>", desc = "Rebuild proc macros" },
                })
              end,
              standalone = false,
              settings = {
                ["rust_analyzer"] = {
                  checkOnSave = {
                    command = "clippy",
                  },
                },
              },
            },

            -- DAP configuration
            -- dap = {},
          }
        end,
      },
      {
        "aznhe21/actions-preview.nvim",
        config = function(_, opts)
          local actions_preview = require("actions-preview")
          actions_preview.setup(opts)
          Util.on_attach(function(client, bufnr)
            require("plugins.lsp.keymaps").apply({ bufnr = bufnr, client = client }, {
              { "<leader>.", actions_preview.code_actions, desc = "Show code actions" },
              { "<leader>la", actions_preview.code_actions, desc = "Show code actions" },
            })
          end)
        end,
      },
    },
    ---@class PluginLspOpts
    opts = {
      format = {
        formatting_options = nil,
        timeout_ms = nil,
      },
      servers = {
        lua_ls = {
          settings = {
            Lua = {
              telemetery = {
                enabled = false,
              },
              workspace = {
                checkThirdParty = false,
              },
              completion = {
                callSnippet = "Replace",
              },
              hint = {
                enable = true,
                arrayIndex = "Disable",
                semicolon = "Disable",
              },
            },
          },
        },
        tsserver = {
          -- Only activate tsserver if the project has config for it.
          root_dir = function(...)
            return require("lspconfig.util").root_pattern("tsconfig.json", "jsconfig.json")(...)
          end,
          typescript = {
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName = false,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
          javascript = {
            inlayHints = {
              includeInlayParameterNameHints = "all",
              includeInlayParameterNameHintsWhenArgumentMatchesName = false,
              includeInlayFunctionParameterTypeHints = true,
              includeInlayVariableTypeHints = true,
              includeInlayVariableTypeHintsWhenTypeMatchesName = false,
              includeInlayPropertyDeclarationTypeHints = true,
              includeInlayFunctionLikeReturnTypeHints = true,
              includeInlayEnumMemberValueHints = true,
            },
          },
        },
        flow = {
          filetypes = { "javascript", "javascriptreact", "javascript.jsx", "flowtype", "flowtypereact" },
        },
        jsonls = {
          on_new_config = function(new_config)
            new_config.settings.json.schemas =
              vim.list_extend(new_config.settings.json.schemas or {}, require("schemastore").json.schemas())
          end,
          settings = {
            json = {
              format = {
                enable = true,
              },
              validate = { enable = true },
            },
          },
        },
        yamlls = {
          on_new_config = function(new_config)
            new_config.settings.yaml.schemas =
              vim.tbl_extend("error", new_config.settings.yaml.schemas or {}, require("schemastore").yaml.schemas())
          end,
          settings = {
            yaml = {
              schemaStore = {
                enable = false,
                url = "",
              },
            },
          },
        },
        ["rust_analyzer"] = false, -- NOTE: configured by rustaceanvim
        "html",
        "cssls",
        "pyright",
        "bashls",
      },
    },
    ---@param opts PluginLspOpts
    config = function(_, opts)
      local lspconfig = require("lspconfig")

      Util.on_attach(function(client, buffer)
        if client.name == "copilot" then
          return
        end
        require("plugins.lsp.keymaps").on_attach(client, buffer)
        require("plugins.lsp.hover").on_attach(client, buffer)
        require("plugins.lsp.inlay_hint").on_attach(client, buffer)
      end)

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }

      local default_opts = { capabilities = capabilities }

      local servers = opts.servers
      local ensure_installed = {}
      for server, server_opts in pairs(servers) do
        if type(server) == "number" and type(server_opts) == "string" then
          server = server_opts
          server_opts = {}
        end

        if server ~= "flow" then -- apparently flow is not a valid lsp server name (any more?).
          table.insert(ensure_installed, server)
        end
        if server_opts ~= false then
          lspconfig[server].setup(vim.tbl_deep_extend("error", default_opts, server_opts))
        end
      end

      Util.ensure_installed(ensure_installed)
    end,
  },
}
