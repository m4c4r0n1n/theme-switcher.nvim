# theme-switcher.nvim

A simple, static theme picker for Neovim. Browse all available colorschemes in a floating window with a moving highlight.

## Features

- **All themes**: Shows every colorscheme installed on your system
- **Static list**: Theme names stay in place, only the highlight moves
- **Search/filter**: Press `/` to filter themes by typing
- **Live preview**: See themes as you navigate
- **Fast navigation**: j/k, arrows, gg/G
- **Background toggle**: Toggle between Normal and Blackout backgrounds
- **Persistent**: Saves your theme and background choice - applies automatically on restart
- **Simple**: No dependencies, just works

## Installation

### lazy.nvim

```lua
{
  "theme-switcher.nvim",
  dir = vim.fn.expand("~/projects/theme-switcher.nvim"),
  config = function()
    require("theme-switcher").setup({
      width = 50,
      height = 25,
      border = "rounded", -- "rounded", "solid", "double", "none"
    })
  end,
  keys = {
    { "<leader>th", function() require("theme-switcher").toggle() end, desc = "Theme switcher" },
    { "<leader>tb", function() require("theme-switcher").toggle_background() end, desc = "Toggle background (dark/light)" },
  },
}
```

## Usage

### Keybindings

- `<leader>th` - Open the theme switcher (pick colorscheme)
- `<leader>tb` - Cycle through backgrounds (Terminal → Themed → Blackout → ...)

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
- `p` - Preview theme (happens automatically on movement)
- `q` / `<Esc>` - Close picker

## How it works

### Theme Switcher (`<leader>th`)

1. Gathers **ALL** installed colorschemes using `getcompletion()`
2. Shows them in a sorted, static list
3. Press `/` to search/filter by typing theme names
4. Highlights the current selection
5. Previews themes as you navigate (j/k)
6. Apply with Enter

### Background Toggle (`<leader>tb`)

Toggles between two background modes:
1. **Normal**: Let the theme use its natural background (might be transparent or colored)
2. **Blackout**: Force pure black (#000000) background override

**Note**: These are independent controls:
- You can pick any theme with `<leader>th`
- Press `<leader>tb` to toggle between Normal and Blackout
- Blackout mode overrides any theme background with pure black
- Normal mode lets each theme handle backgrounds naturally
- Works with any theme!

### Persistence

Your theme and background choices are automatically saved to `~/.local/share/nvim/theme_switcher_prefs.json` and restored when you restart nvim.
