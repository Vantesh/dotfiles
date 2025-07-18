return {
  "rachartier/tiny-inline-diagnostic.nvim",
  event = "VeryLazy", -- Or `LspAttach`
  priority = 1000,   -- needs to be loaded in first
  config = function()
    require("tiny-inline-diagnostic").setup({
      preset = "powerline",
      options = {
        virt_text = 9999,
        show_all_diags_on_cursorline = true,
      },
      overflow = {
        mode = "oneline",
      },
    })
    vim.diagnostic.config({ virtual_text = false })
  end,
}
