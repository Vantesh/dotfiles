-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.number = true          -- keep absolute line numbers
vim.opt.relativenumber = false -- disable relative ones

-- set curysor to beam and blink only in insert mode
vim.opt.guicursor = {
  "n-c-sm:block",
  "v:ver25",
  "i:ver25-blinkwait300-blinkon200-blinkoff150",
}
