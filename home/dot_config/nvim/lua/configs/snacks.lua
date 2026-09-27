return {
  bigfile = { enabled = true },
  explorer = { enabled = true },
  dashboard = {
    enabled = true,
    preset = {
      header = [[
 ███▄▄▄▄      ▄████████  ▄██████▄   ▄█    █▄   ▄█    ▄▄▄▄███▄▄▄▄
 ███▀▀▀██▄   ███    ███ ███    ███ ███    ███ ███  ▄██▀▀▀███▀▀▀██▄
 ███   ███   ███    █▀  ███    ███ ███    ███ ███▌ ███   ███   ███
 ███   ███  ▄███▄▄▄     ███    ███ ███    ███ ███▌ ███   ███   ███
 ███   ███ ▀▀███▀▀▀     ███    ███ ███    ███ ███▌ ███   ███   ███
 ███   ███   ███    █▄  ███    ███ ███    ███ ███  ███   ███   ███
 ███   ███   ███    ███ ███    ███ ███    ███ ███  ███   ███   ███
  ▀█   █▀    ██████████  ▀██████▀   ▀██████▀  █▀    ▀█   ███   █▀

             ]],
    },
  },
  indent = {
    priority = 1,
    enabled = true,
    char = "│",
    only_scope = false,
    only_current = false,
    hl = "SnacksIndent",
  },
  animate = {
    enabled = vim.fn.has("nvim-0.10") == 1,
    style = "out",
    easing = "inOutCubic",
    duration = {
      step = 10,
      total = 500,
    },
  },
  scope = {
    enabled = true,
    priority = 200,
    char = "│",
    underline = false,
    only_current = false,
    hl = "SnacksIndentScope",
  },
  chunk = {
    enabled = false,
    only_current = false,
    priority = 200,
    hl = "SnacksIndentChunk",
    char = {
      corner_top = "┌",
      corner_bottom = "└",
      horizontal = "─",
      vertical = "│",
      arrow = ">",
    },
  },
  input = { enabled = true },
  notifier = {
    enabled = true,
    timeout = 3000,
  },
  picker = { enabled = true },
  quickfile = { enabled = true },
  scroll = {
    animate = {
      duration = { step = 15, total = 250 },
      easing = "linear",
    },
    animate_repeat = {
      delay = 100,
      duration = { step = 5, total = 50 },
      easing = "linear",
    },
    filter = function(buf)
      return vim.g.snacks_scroll ~= false
          and vim.b[buf].snacks_scroll ~= false
          and vim.bo[buf].buftype ~= "terminal"
    end,
  },
  statuscolumn = { enabled = true },
  words = { enabled = true },
  styles = {
    notification = {},
  },
  zen = {
    toggles = {
      dim = false,
      git_signs = false,
      mini_diff_signs = false,
    },
    win = {
      backdrop = {
        transparent = false,
        blend = 99,
      },
    },
  },
}
