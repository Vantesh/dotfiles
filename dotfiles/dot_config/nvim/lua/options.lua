require "nvchad.options"


local o = vim.o
local opt = vim.opt

-- terminal general
o.termguicolors = true
o.guicursor = "i-ci:ver25-blinkwait500-blinkon500-blinkoff500"


-- editing
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4


-- new things
opt.title = true
opt.hlsearch = true
opt.showcmd = true
opt.scrolloff = 10
opt.inccommand = "split"
opt.backspace = { "start", "eol", "indent" }
opt.path:append({ "**" })
opt.wildignore:append({ "*/node_modules/*" })
opt.formatoptions:append({ "r" })
