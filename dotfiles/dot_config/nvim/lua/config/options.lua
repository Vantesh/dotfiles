-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.number = true          -- keep absolute line numbers
vim.opt.relativenumber = false -- disable relative ones

local go = vim.g
local o = vim.opt

-- Autoformat on save (Global)
go.autoformat = true


-- Font
go.gui_font_default_size = 10
go.gui_font_size = go.gui_font_default_size
go.gui_font_face = "MonoLisa Nerd Font"

-- Optimizations on startup
vim.loader.enable()

-- Disable annoying cmd line stuff
o.showcmd = false
o.laststatus = 3
o.cmdheight = 0

-- Smoothscroll
if vim.fn.has("nvim-0.10") == 1 then
  o.smoothscroll = true
end

o.conceallevel = 2


-- set curysor to beam and blink only in insert mode
vim.opt.guicursor = {
  "n-c-sm:block",
  "v:ver25",
  "i:ver25-blinkwait300-blinkon200-blinkoff150",
}
