return {
  {
    "neovim/nvim-lspconfig",
    event = "BufReadPost",
    dependencies = {
      { "folke/neoconf.nvim", cmd = "Neoconf", config = true },
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
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
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
        -- tsserver = {
        --   -- Only activate tsserver if the project has config for it.
        --   root_dir = function(...)
        --     return require("lspconfig.util").root_pattern("tsconfig.json", "jsconfig.json")(...)
        --   end,
        -- },
        flow = {
          filetypes = { "javascript", "javascriptreact", "javascript.jsx", "flowtype", "flowtypereact" },
        },
        jsonls = {
          on_new_config = function(new_config)
            new_config.settings.json.schemas = new_config.settings.json.schemas or {}
            vim.list_extend(new_config.settings.json.schemas, require("schemastore").json.schemas())
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
          formatting.prettierd.with({
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
          "prettierd",
          "black",
          "stylua",
          "flake8",
        },
        automatic_installation = true,
      })
    end,
  },
}
