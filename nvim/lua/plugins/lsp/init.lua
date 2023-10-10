return {
  {
    "neovim/nvim-lspconfig",
    event = "BufReadPost",
    dependencies = {
      {
        "folke/neoconf.nvim",
        cmd = "Neoconf",
        keys = {
          { "<leader>cc", "<cmd>Neoconf local<CR>", desc = "Edit (local)" },
          { "<leader>cg", "<cmd>Neoconf local<CR>", desc = "Edit (global)" },
          { "<leader>ce", "<cmd>Neoconf<CR>", desc = "Edit conf" },
          { "<leader>cl", "<cmd>Neoconf lsp<CR>", desc = "Show lsp" },
          { "<leader>cs", "<cmd>Neoconf show<CR>", desc = "Show conf" },
        },
        config = true,
      },
      {
        "folke/neodev.nvim",
        opts = {
          experimental = { pathStrict = true },
          library = {
            plugins = { "nvim-dap-ui" },
            types = true,
          },
        },
      },
      {
        "smjonas/inc-rename.nvim",
        cmd = "IncRename",
        event = "BufReadPost",
        config = true,
      },
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
      "b0o/SchemaStore.nvim",
      {
        "simrat39/rust-tools.nvim",
        opts = {
          tools = {
            runnables = {
              use_telescope = true,
            },
            inlay_hints = {
              auto = false,
            },
          },
          server = {
            standalone = false,
          },
        },
      },
      {
        "aznhe21/actions-preview.nvim",
        config = function(_, opts)
          local actions_preview = require("actions-preview")
          actions_preview.setup(opts)
          require("util").on_attach(function(client, bufnr)
            require("plugins.lsp.keymaps").apply({ bufnr = bufnr, client = client }, {
              { "<leader>.", actions_preview.code_actions, desc = "Show code actions" },
              { "<leader>la", actions_preview.code_actions, desc = "Show code actions" },
            })
          end)
        end,
      },
      {
        "lvimuser/lsp-inlayhints.nvim",
        branch = "anticonceal",
        opts = {
          inlay_hints = {
            parameter_hints = {
              show = false,
            },
            type_hints = {
              show = true,
            },
          },
        },
        config = function(_, opts)
          local inlay_hints = require("lsp-inlayhints")
          inlay_hints.setup(opts)
          require("util").on_attach(function(client, buffer)
            inlay_hints.on_attach(client, buffer, false)

            require("plugins.lsp.keymaps").apply({ buffer = buffer, client = client }, {
              { "<leader>li", inlay_hints.toggle, desc = "Toggle inlay hints" },
              { "<leader>ul", inlay_hints.toggle, desc = "Toggle inlay hints" },
              { "<leader>lI", inlay_hints.reset, desc = "Reset inlay hints" },
            })
          end)
        end,
      },
    },
    ---@class PluginLspOpts
    opts = {
      autoformat = true,
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
        eslint = {
          filetypes = { "javascript", "javascriptreact", "javascript.jsx", "flowtype", "flowtypereact" },
          on_attach = function(client, buffer)
            vim.api.nvim_create_autocmd("BufWritePre", {
              buffer = buffer,
              command = "EslintFixAll",
            })
          end,
        },
        ["rust_analyzer"] = {
          checkOnSave = {
            command = "clippy",
          },
          on_attach = function(client, buffer)
            local rt = require("rust-tools")

            -- stylua: ignore
            require("plugins.lsp.keymaps").apply({buffer = buffer, client = client}, {
              { "<leader>le", rt.expand_macro.expand_macro, desc = "Expand macro" },
              { "<leader>lp", rt.parent_module.parent_module, desc = "Parent module" },
              -- { "<leader>lu", rt.move_item.move_item, desc = "Move item up" },
              -- { "<leader>ld", rt.move_item.move_item, desc = "Move item down" },
              { "<leader>lj", rt.join_lines.join_lines, desc = "Join lines" },
              { "<leader>l/", rt.ssr.ssr, desc = "Structural search replace" },

              { "<leader>dr", rt.debuggables.debuggables, desc = "Debuggables" },

              { "<leader>cr", rt.runnables.runnables, desc = "Runnables" },
              { "<leader>co", rt.open_cargo_toml.open_cargo_toml, desc = "Open cargo.toml" },
              -- { "<leader>cg", function() rt.crate_graph.view_crate_graph('bmp') end, desc = "View crate graph" },
            })
          end,
        },

        "html",
        "cssls",
        "pyright",
        "bashls",
      },
    },
    ---@param opts PluginLspOpts
    config = function(_, opts)
      local lspconfig = require("lspconfig")


      require("util").on_attach(function(client, buffer)
        if client.name == "copilot" then
          return
        end
        require("plugins.lsp.format").on_attach(client, buffer)
        require("plugins.lsp.keymaps").on_attach(client, buffer)
        require("plugins.lsp.hover").on_attach(client, buffer)
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
        lspconfig[server].setup(vim.tbl_deep_extend("error", default_opts, server_opts))
      end

      require("mason-lspconfig").setup({ ensure_installed = ensure_installed, autoinstall = true })
    end,
  },

  -- Linting
  {
    "jose-elias-alvarez/null-ls.nvim",
    event = "BufReadPost",
    dependencies = { "jayp0521/mason-null-ls.nvim" },
    config = function()
      local null_ls = require("null-ls")

      -- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins
      local code_actions = null_ls.builtins.code_actions
      local completion = null_ls.builtins.completion
      local diagnostics = null_ls.builtins.diagnostics
      local formatting = null_ls.builtins.formatting
      local hover = null_ls.builtins.hover

      null_ls.setup({
        debug = false,
        sources = {
          -- TODO: Look into switching back to eslint via null-ls, since eslint-lsp seems to lack many features like
          -- code actions and formatting.
          formatting.prettier.with({
            extra_filetypes = { "toml", "flowtype", "flowtypereact" },
          }),
          formatting.black.with({ extrargs = { "fast" } }),
          formatting.stylua,
          diagnostics.flake8,
          code_actions.gitsigns,
          code_actions.gitrebase,
          completion.spell,
          hover.dictionary,
        },
      })

      require("mason-null-ls").setup({
        ensure_installed = {
          "prettier",
          "black",
          "stylua",
          "flake8",
        },
        automatic_installation = true,
      })
    end,
  },
}
