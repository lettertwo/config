return {
  {
    "neovim/nvim-lspconfig",
    event = "BufReadPre",
    dependencies = {
      { "folke/neoconf.nvim", cmd = "Neoconf", config = true },
      { "folke/neodev.nvim", opts = { experimental = { pathStrict = true } } },
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
      "simrat39/rust-tools.nvim",
      "b0o/SchemaStore.nvim",
    },
    ---@class PluginLspOpts
    opts = {
      autoformat = true,
      format = {
        formatting_options = nil,
        timeout_ms = nil,
      },
      servers = {
        sumneko_lua = {
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
        -- tsserver = {
        --   -- Only activate tsserver if the project has config for it.
        --   root_dir = function(...)
        --     return require("lspconfig.util").root_pattern("tsconfig.json", "jsconfig.json")(...)
        --   end,
        -- },
        -- flow = {
        --   filetypes = { "javascript", "javascriptreact", "javascript.jsx", "flowtype", "flowtypereact" },
        -- },
        -- jsonls = {
        --   on_new_config = function(new_config)
        --     new_config.settings.json.schemas = new_config.settings.json.schemas or {}
        --     vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
        --   end,
        --   settings = {
        --     json = {
        --       format = {
        --         enable = true,
        --       },
        --       validate = { enable = true },
        --     },
        --   },
        -- },
        "eslint",
        "html",
        "cssls",
        "pyright",
        "bashls",
        "yamlls",
      },
    },
    ---@param opts PluginLspOpts
    config = function(_, opts)
      local lspconfig = require("lspconfig")
      local rt = require("rust-tools")

      vim.lsp.handlers["textDocument/hover"] = require("plugins.lsp.hover").hover

      require("util").on_attach(function(client, bufnr)
        if client.name == "copilot" then
          return
        end
        require("plugins.lsp.location").on_attach(client, bufnr)
        require("plugins.lsp.format").on_attach(client, bufnr)
        require("plugins.lsp.keymaps").on_attach(client, bufnr)
      end)

      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }

      local default_opts = { capabilities = capabilities }

      local servers = opts.servers
      for server, opts in pairs(servers) do
        if type(server) == "number" then
          server = opts
          opts = {}
        end

        lspconfig[server].setup(vim.tbl_deep_extend("error", default_opts, opts))
      end

      require("mason-lspconfig").setup({ autoinstall = true })

      -- Rust tools setup
      rt.setup({
        server = {
          on_attach = function(client, bufnr)
            on_attach(client, bufnr)
            -- Hover actions
            vim.keymap.set("n", "K", rt.hover_actions.hover_actions, { buffer = bufnr })
          end,
          checkOnSave = {
            allFeatures = true,
            overrideCommand = {
              "cargo",
              "clippy",
              "--workspace",
              "--message-format=json",
              "--all-targets",
              "--all-features",
            },
          },
        },
      })
    end,
  },

  -- Linting
  {
    "jose-elias-alvarez/null-ls.nvim",
    event = "BufReadPre",
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
          formatting.prettierd.with({
            extra_filetypes = { "toml", "flowtype", "flowtypereact" },
          }),
          formatting.black.with({ extrargs = { "fast" } }),
          formatting.stylua,
          formatting.google_java_format,
          diagnostics.flake8,
          code_actions.gitsigns,
          code_actions.gitrebase,
          completion.spell,
          hover.dictionary,
        },
      })

      require("mason-null-ls").setup({
        automatic_installation = true,
      })
    end,
  },
}