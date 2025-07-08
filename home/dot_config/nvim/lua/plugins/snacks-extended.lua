return {
  "folke/snacks.nvim",
  opts = {

    lazygit = {
      configure = false,
    },
    notifier = {
      style = "fancy",
    },
    terminal = {
      win = {
        position = "float",
      },
    },
    picker = {
      previewers = {
        git = {
          builtin = false,
        },
      },
      matcher = {
        frecency = true,
      },
      win = {
        input = {
          keys = {
            ["<c-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["<a-j>"] = { "list_scroll_down", mode = { "i", "n" } },
            ["<c-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
            ["<a-k>"] = { "list_scroll_up", mode = { "i", "n" } },
          },
        },
      },
    },
    image = {
      enabled = true,
      doc = {
        inline = false,
      },
    },
    scroll = {
      animate = {
        duration = { step = 10, total = 150 },
      },
    },
  },
  -- stylua: ignore
  keys = {
    {
      "<leader>fz",
      function()
        Snacks.picker.zoxide({
          -- Remove the finder line as it might be causing issues
          format = "file",
          confirm = function(picker, item)
            picker:close()
            if item then
              -- Change directory first
              vim.fn.chdir(item.file)
              -- Then open files picker in that directory
              Snacks.picker.files({ cwd = item.file })
            end
          end,
          win = {
            preview = {
              minimal = true,
            },
          },
        })
      end,
      desc = "Zoxide"
    },
    {
      "<leader>fZ",
      function()
        Snacks.picker.zoxide({
          confirm = function(picker, item)
            picker:close()
            if item then
              -- Just change directory, don't open file picker
              vim.fn.chdir(item.file)
              vim.notify("Changed to: " .. item.file)
            end
          end,
        })
      end,
      desc = "Zoxide (Change Dir Only)"
    },

    {
      "<leader>B",
      function()
        Snacks.picker.buffers({
          on_show = function()
            vim.cmd.stopinsert()
          end,
          current = false,
          sort_lastused = true,
        })
      end,
      desc = "Buffers"
    },
    {
      "<leader>,",
      function()
        Snacks.picker.buffers({
          on_show = function()
            vim.cmd.stopinsert()
          end,
          current = false,
          sort_lastused = true,
        })
      end,
      desc = "Buffers"
    },
    { "<leader>gB", function() Snacks.picker.git_branches() end, desc = "Git Branches" },
    { "<leader>go", function() Snacks.gitbrowse() end,           desc = "Git Open Line" },
  },
}
