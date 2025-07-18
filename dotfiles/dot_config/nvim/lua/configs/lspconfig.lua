---@type ChadrcConfig
return {
  "neovim/nvim-lspconfig",
  config = function()
    require("nvchad.configs.lspconfig").defaults()
    local configs = require("nvchad.configs.lspconfig")
    local on_init = configs.on_init
    local capabilities = configs.capabilities
    local custom_on_attach = function(client, bufnr)
      local on_attach = require("nvchad.configs.lspconfig").on_attach -- nvchad's
      on_attach(client, bufnr)                                     -- execute it to run defaults

      -- define the hl
      vim.api.nvim_set_hl(0, "LspFloatWinBorder", { fg = "#a9a1e1" })
      -- define the border
      local border = {
        { "╭", "LspFloatWinBorder" },
        { "─", "LspFloatWinBorder" },
        { "╮", "LspFloatWinBorder" },
        { "│", "LspFloatWinBorder" },
        { "╯", "LspFloatWinBorder" },
        { "─", "LspFloatWinBorder" },
        { "╰", "LspFloatWinBorder" },
        { "│", "LspFloatWinBorder" },
      }

      -- configure the handler
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
        border = border,
      })

      -- Add this if you want the same border for lsp signature help
      vim.lsp.handlers["textDocument/signatureHelp"] =
          vim.lsp.with(vim.lsp.handlers.signature_help, { border = border })

      -- then replace the on_attach you likely defined at the top, outside this function, and replace all instances of on_attach with custom_on_attach
    end

    local lspconfig = require("lspconfig")
    local servers = {
      "html",
      "cssls",
      "marksman",
      "somesass_ls",
      "jsonls",
      "bashls",
      "jdtls",
    }

    -- lsps with default config
    for _, lsp in ipairs(servers) do
      lspconfig[lsp].setup({
        on_attach = custom_on_attach,
        on_init = on_init,
        capabilities = capabilities,
      })
    end

    lspconfig.tsserver.setup({
      on_attach = custom_on_attach,
      on_init = on_init,
      capabilities = capabilities,
      filetypes = {
        "javascript",
        "javascriptreact",
        "typescript",
        "typescriptreact",
      },
      init_options = {
        preferences = {
          includeInlayParameterNameHints = "all",
          includeInlayParameterNameHintsWhenArgumentMatchesName = true,
          includeInlayFunctionParameterTypeHints = true,
          includeInlayVariableTypeHints = true,
          includeInlayPropertyDeclarationTypeHints = true,
          includeInlayFunctionLikeReturnTypeHints = true,
          includeInlayEnumMemberValueHints = true,
          importModuleSpecifierPreference = "non-relative",
        },
      },
      settings = {
        completions = {
          completeFunctionCalls = false,
        },
      },
    })

    lspconfig.jsonls.setup({
      on_attach = custom_on_attach,
      on_init = on_init,
      capabilities = capabilities,
      settings = {
        json = {
          format = {
            enable = false,
          },
        },
      },
    })

    lspconfig.eslint.setup({
      on_attach = function(client, bufnr)
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          command = "EslintFixAll",
        })
      end,
      on_init = on_init,
      capabilities = capabilities,
    })

    lspconfig.sqlls.setup({
      on_attach = custom_on_attach,
      on_init = on_init,
      capabilities = capabilities,
      filetypes = { "sql", "mysql" },
      root_dir = function(_)
        return vim.loop.cwd()
      end,
    })

    lspconfig.lua_ls.setup({
      on_attach = custom_on_attach,
      on_init = on_init,
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = {
            -- Get the language server to recognize the `vim` global
            globals = {
              "vim",
              "require",
            },
          },
        },
      },
    })
  end,
}
