local options = {
  formatters_by_ft = {
    css = { "prettier" },
    html = { "prettier" },
    javascript = { "prettier", "eslint_d" },
    javascriptreact = { "prettier", "eslint_d" },
    json = { "jsonlint" },
    lua = { "stylua" },
    markdown = { "mdformat" },
    mysql = { "sqlfluff" },
    scss = { "prettier" },
    typescript = { "prettier", "eslint_d" },
    typescriptreact = { "prettier", "eslint_d" },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 500,
    lsp_fallback = true,
  },
  formatters = {
    prettier = {
      prepend_args = { "--tab-width", "4", "--use-tabs", "false" },
    },
  },
}

return options
