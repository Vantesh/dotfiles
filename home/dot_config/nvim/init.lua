vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.fn.mkdir(vim.g.base46_cache, "p")
for _, cache_name in ipairs { "tbline", "nvcheatsheet" } do
  local cache_file = vim.g.base46_cache .. cache_name
  if vim.fn.filereadable(cache_file) == 0 then
    vim.fn.writefile({}, cache_file)
  end
end
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
  },

  "nvim-lua/plenary.nvim",
  {
    "nvchad/ui",
    lazy = false,
    config = function()
      require "nvchad"
    end,
  },

  { import = "plugins" },
}, lazy_config)

local base46 = require "base46"
base46.merge_tb = base46.merge_tb or base46.load

local tabufline = require "nvchad.tabufline"
local close_buffer = tabufline.close_buffer
tabufline.close_buffer = function(bufnr)
  vim.t.bufs = vim.tbl_filter(vim.api.nvim_buf_is_valid, vim.t.bufs or {})

  if #vim.t.bufs == 0 then
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    vim.cmd "enew"
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.cmd("bw " .. bufnr)
    end
    return
  end

  return close_buffer(bufnr)
end

vim.cmd.colorscheme("dms")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
