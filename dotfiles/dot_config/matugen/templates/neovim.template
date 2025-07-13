-- Catppuccin mocha
local palette = require("catppuccin.palettes").get_palette("mocha") -- Import your favorite catppuccin colors

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
  {
    "catppuccin/nvim",
    lazy = true,
    name = "catppuccin",
    opts = {
      transparent_background = true,
      custom_highlights = function(colors)
        return {
          -- Change the color of the tabline
          -- TabLine = { bg = colors.mantle, fg = colors.surface0 },
          LazyNormal = { bg = colors.mantle }, -- transparent background
        }
      end,

      term_colors = true,
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = false },
        leap = true,
        lsp_trouble = true,
        mason = true,
        markdown = true,
        mini = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        semantic_tokens = true,
        snacks = true,
        telescope = true,
        treesitter = true,
        treesitter_context = true,
        which_key = true,
      },
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        opts = {
          highlights = require("catppuccin.groups.integrations.bufferline").get({
            styles = { "italic", "bold" },
            custom = {
              all = {
                fill = {
                  bg = palette.mantle,
                },
                separator_selected = {
                  bg = palette.base,
                  fg = palette.mantle,
                },
                separator = {
                  bg = palette.mantle,
                  fg = palette.mantle,
                },
                tab_separator = {
                  bg = palette.mantle,
                  fg = palette.mantle,
                },
                tab_selected = {
                  bg = palette.base,
                },
                tab_separator_selected = {
                  bg = palette.base,
                  fg = palette.mantle,
                },
              },
            },
          }),
        },
      },
      {
        "rasulomaroff/reactive.nvim",
        optional = true,
        opts = {
          load = { "catppuccin-mocha-cursor", "catppuccin-mocha-cursorline" },
        },
      },
      {
        "rachartier/tiny-devicons-auto-colors.nvim",
        optional = true,
        opts = {
          colors = palette,
          factors = {
            lightness = 0.9,
            chroma = 1,
            hue = 0.7,
          },
        },
      },

    },

  },

}
