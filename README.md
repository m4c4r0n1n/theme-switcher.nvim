## UPDATES!!!

I've fixed a few blackout issues on here, if you use this with another config other than Nananvim, let me know if you have any issues and I will do my best to resolve them. Thanks!

Latest:
- `j`, `k`, `G` and `q` work in the picker again
- It remembers the exact variant you pick (rose-pine-dawn stays dawn after a restart)
- No message on every move, only one when you apply a theme
- Blackout now covers the tab line, statusline, popups and menus too
- Your saved theme loads right away, no flash of the default theme on startup
- No more error on the first save of a fresh install

# theme-switcher.nvim

<img width="1718" height="1400" alt="image" src="https://github.com/user-attachments/assets/4b81444e-592f-4682-b790-741d451df243" />


A simple, static theme picker for Neovim. Browse all available colorschemes in a floating window with a moving highlight.

## Features

- **All themes**: Shows every colorscheme installed on your system
- **Static list**: Theme names stay in place, only the highlight moves
- **Search/filter**: Press `/` to filter themes by typing
- **Live preview**: See themes as you navigate
- **Fast navigation**: j/k, arrows, gg/G
- **Background modes**: Blackout (theme text on pure black), the theme's own background, or transparent
- **Persistent**: Saves your theme and background choice and applies them on restart
- **Simple**: No dependencies, just works

## Installation

### lazy.nvim

This is the spec [nananvim](https://github.com/m4c4r0n1n/nananvim) uses:

```lua
{
  "m4c4r0n1n/theme-switcher.nvim",
  lazy = false,
  config = function()
    require("theme-switcher").setup({
      width = 50,
      height = 25,
      border = "rounded", -- "rounded", "solid", "double", "none"
      default_bg = "blackout", -- "normal", "terminal" or "blackout" (before you pick one)
      exclude = {}, -- colorscheme names to hide, for example { "rose-pine-main" }
    })
  end,
  keys = {
    { "<leader>th", function() require("theme-switcher").toggle() end, desc = "Theme switcher" },
    { "<leader>tb", function() require("theme-switcher").toggle_background() end, desc = "Toggle blackout / theme background" },
  },
}
```

Load it at startup (`lazy = false`). It applies your saved theme and background when Neovim starts.

## Usage

### Keybindings

- `<leader>th` - Open the theme switcher (pick colorscheme)
- `<leader>tb` - Toggle blackout and the theme's own background

### Inside the Theme Picker

**Navigation:**
- `j` / `<Down>` - Move down
- `k` / `<Up>` - Move up
- `gg` - Jump to top
- `G` - Jump to bottom

**Search:**
- `/` - Enter search mode (start typing to filter themes)
- Type any letters/numbers to filter the list
- `<BS>` - Delete last character
- `<Esc>` - Exit search mode
- `<Enter>` - Exit search mode (when in search)
- `<C-c>` - Clear search completely

**Actions:**
- `<Enter>` / `<Space>` - Apply theme and close
- `p` - Preview theme (moving the selection also previews)
- `q` / `<Esc>` - Close picker (the previewed theme stays)

## How it works

### Theme Switcher (`<leader>th`)

1. Gathers **ALL** installed colorschemes using `getcompletion()`
2. Shows them in a sorted, static list
3. Press `/` to search/filter by typing theme names
4. Highlights the current selection
5. Previews themes as you navigate (j/k)
6. Apply with Enter

### Background modes (`<leader>tb`)

1. **Blackout**: pure black (#000000) background with the theme's text colors
2. **Normal**: the theme's own background
3. **Terminal**: transparent, your terminal shows through

`<leader>tb` toggles Blackout and Normal. For Terminal, run:

```vim
:lua require("theme-switcher").set_background("terminal")
```

The mode stays when you change the theme. Blackout and Terminal also change each part of the screen that uses the theme background, for example the tab line, the statusline, popups and menus.

### Persistence

Your theme and background choices are automatically saved to `~/.local/share/nvim/theme_switcher_prefs.json` and restored when you restart nvim.
