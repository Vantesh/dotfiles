require "nvchad.autocmds"

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = vim.fn.expand("~/.config/kitty/kitty.conf"),
  callback = function()
    vim.fn.system("kill -SIGUSR1 $(pgrep kitty)")
  end,
})

