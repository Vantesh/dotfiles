# eza-preview.yazi

[Yazi](https://github.com/sxyazi/yazi) plugin to preview directories using [eza](https://github.com/eza-community/eza), can be switched between list and tree modes.

List mode:
![list.png](list.png)

Tree mode:
![tree.png](tree.png)

## Requirements

- [yazi (25.3+) or nightly](https://github.com/sxyazi/yazi)
- [eza (0.20+)](https://github.com/eza-community/eza)

## Installation

```sh
ya pack -a ahkohd/eza-preview
```

## Usage

### Basic Setup

Add `eza-preview` to previewers in `yazi.toml`:

```toml
[[plugin.prepend_previewers]]
name = "*/"
run = "eza-preview"
```

### Key Bindings

Set key bindings to control the preview in `keymap.toml`:

```toml
[mgr]
prepend_keymap = [
  { on = [ "E" ], run = "plugin eza-preview",  desc = "Toggle tree/list dir preview" },
  { on = [ "-" ], run = "plugin eza-preview inc-level", desc = "Increment tree level" },
  { on = [ "_" ], run = "plugin eza-preview dec-level", desc = "Decrement tree level" },
  { on = [ "$" ], run = "plugin eza-preview toggle-follow-symlinks", desc = "Toggle tree follow symlinks" },
  { on = [ "*" ], run = "plugin eza-preview toggle-hidden", desc = "Toggle hidden files" },
]
```

### Configuration

Configure the plugin in `init.lua`:

```lua
require("eza-preview"):setup({
  -- Set the tree preview to be default (default: true)
  default_tree = true,

  -- Directory depth level for tree preview (default: 3)
  level = 3,

  -- Follow symlinks when previewing directories (default: false)
  follow_symlinks = false,

  -- Show target file info instead of symlink info (default: false)
  dereference = false,

  -- Show hidden files (default: true) 
  all = true
})

-- Or use default settings
require("eza-preview"):setup({})
```

## Available Commands

- `plugin eza-preview` - Toggle between tree and list modes
- `plugin eza-preview inc-level` - Increase tree depth level
- `plugin eza-preview dec-level` - Decrease tree depth level  
- `plugin eza-preview toggle-follow-symlinks` - Toggle symlink following
- `plugin eza-preview toggle-hidden` - Toggle hidden file visibility

## Contributing

Feel free to contribute by opening issues or submitting pull requests!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

