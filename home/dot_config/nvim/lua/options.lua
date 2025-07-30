require "nvchad.options"


local o = vim.o
local set = vim.opt

-- terminal general
o.termguicolors = true
o.guicursor = "i-ci:ver25-blinkwait500-blinkon500-blinkoff500"


-- editing
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4

set.swapfile = false
set.title = true
set.foldexpr = "nvim_treesitter#foldexpr()"
