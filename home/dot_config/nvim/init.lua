---@diagnostic disable: undefined-global
vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
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
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
do
  local cache = vim.g.base46_cache or (vim.fn.stdpath "data" .. "/base46/")

  local function file_exists(path)
    local uv = vim.uv or vim.loop
    return uv and uv.fs_stat and uv.fs_stat(path) ~= nil
  end

  local ok_defaults = false
  local ok_statusline = false

  if file_exists(cache .. "defaults") then
    ok_defaults = pcall(dofile, cache .. "defaults")
  end

  if file_exists(cache .. "statusline") then
    ok_statusline = pcall(dofile, cache .. "statusline")
  end

  -- Fallback: if cache files are missing (first run) try loading via base46 directly
  if not (ok_defaults and ok_statusline) then
    local ok, base46 = pcall(require, "base46")
    if ok and base46 and type(base46.load_all) == "function" then
      pcall(base46.load_all)
    end
  end
end

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)

-- theme reloader
pcall(function()
  require('nvchad.utils').reload()
end)
local autocmd = vim.api.nvim_create_autocmd
autocmd("Signal", {
  pattern = "SIGUSR1",
  callback = function()
    pcall(function()
      require('nvchad.utils').reload()
    end)
  end
})
