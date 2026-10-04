return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = require "configs.noice",
  -- stylua: ignore
  keys = {
    { "<leader>sn",  "",                                                                            desc = "+noice" },
    { "<S-Enter>",   function() require("noice").redirect(vim.fn.getcmdline()) end,                 mode = "c",                              desc = "Redirect Cmdline" },
    { "<leader>snl", function() require("noice").cmd("last") end,                                   desc = "Noice Last Message" },
    { "<leader>snh", function() require("noice").cmd("history") end,                                desc = "Noice History" },
    { "<leader>sna", function() require("noice").cmd("all") end,                                    desc = "Noice All" },
    { "<leader>snd", function() require("noice").cmd("dismiss") end,                                desc = "Dismiss All" },
    { "<leader>snt", function() require("noice").cmd("pick") end,                                   desc = "Noice Picker (Telescope/FzfLua)" },
    { "<c-f>",       function() if not require("noice.lsp").scroll(4) then return "<c-f>" end end,  silent = true,                           expr = true,              desc = "Scroll Forward",  mode = { "i", "n", "s" } },
    { "<c-b>",       function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end, silent = true,                           expr = true,              desc = "Scroll Backward", mode = { "i", "n", "s" } },
  },
  config = function(_, opts)
    -- HACK: noice shows messages from before it was enabled,
    -- but this is not ideal when Lazy is installing plugins,
    -- so clear the messages in this case.
    if vim.o.filetype == "lazy" then
      vim.cmd([[messages clear]])
    end
    require("noice").setup(opts)
  end,
}
