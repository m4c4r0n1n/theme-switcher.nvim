<div align="center">

# theme-switcher.nvim

**A simple theme picker for Neovim.** Every installed colorscheme in one float, with live preview.

<a href="https://github.com/neovim/neovim/releases"><img alt="Neovim 0.10+" src="https://img.shields.io/badge/Neovim-0.10%2B-c4a7e7?logo=neovim&logoColor=e0def4&style=for-the-badge&labelColor=232136" /></a>
<a href="https://github.com/m4c4r0n1n/theme-switcher.nvim/commits/main"><img alt="Last commit" src="https://img.shields.io/github/last-commit/m4c4r0n1n/theme-switcher.nvim?logo=git&logoColor=e0def4&color=f6c177&style=for-the-badge&labelColor=232136" /></a>
<a href="https://github.com/m4c4r0n1n/theme-switcher.nvim/commits/main"><img alt="Maintained: yes" src="https://img.shields.io/badge/Maintained%3F-yes-9ccfd8?style=for-the-badge&labelColor=232136" /></a>
<a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/m4c4r0n1n/theme-switcher.nvim?color=ea9a97&style=for-the-badge&labelColor=232136" /></a>
<a href="https://ko-fi.com/koifist"><img alt="Ko-fi" src="https://img.shields.io/badge/Ko--fi-support-eb6f92?logo=kofi&logoColor=e0def4&style=for-the-badge&labelColor=232136" /></a>

</div>

<img width="1718" height="1400" alt="theme-switcher picker" src="https://github.com/user-attachments/assets/4b81444e-592f-4682-b790-741d451df243" />

Built for [nananvim](https://github.com/m4c4r0n1n/nananvim). Works in any config.

## Features

- 🎨 **All themes**: every installed colorscheme, in a static sorted list
- 👀 **Live preview**: the theme changes as you move
- 🔍 **Search**: `/` filters the list as you type
- 🌑 **Background modes**: blackout (pure black), the theme's own background, or transparent
- 💾 **Persistent**: your theme and background come back on restart
- 🔗 **Synced**: every open Neovim follows your pick
- 🪶 **No dependencies**

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "m4c4r0n1n/theme-switcher.nvim",
  lazy = false,
  config = function()
    require("theme-switcher").setup({
      width = 50,
      height = 25,
      border = "rounded",      -- "rounded" | "solid" | "double" | "none"
      default_bg = "blackout", -- "normal" | "terminal" | "blackout"
      exclude = {},            -- themes to hide, for example { "rose-pine-main" }
      sync = true,             -- other open Neovims follow your pick
    })
  end,
  keys = {
    { "<leader>th", function() require("theme-switcher").toggle() end, desc = "Theme switcher" },
    { "<leader>tb", function() require("theme-switcher").toggle_background() end, desc = "Toggle blackout / theme background" },
  },
}
```

Keep `lazy = false`. It applies your saved theme at startup.

## Keys

| Key | Does |
| --- | --- |
| `<leader>th` | Open the picker |
| `<leader>tb` | Toggle blackout and the theme background |

**In the picker**

| Key | Does |
| --- | --- |
| `j` / `k`, `<Down>` / `<Up>` | Move and preview |
| `gg` / `G` | Top / bottom |
| `/` | Search. `<BS>` deletes, `<Esc>` or `<CR>` stops, `<C-c>` clears |
| `<CR>` / `<Space>` | Apply and close |
| `p` | Preview |
| `q` / `<Esc>` | Close. The preview stays |

## Background modes

- **Blackout**: pure black with the theme's text colors
- **Normal**: the theme's own background
- **Terminal**: transparent, your terminal shows through

`<leader>tb` toggles blackout and normal. For terminal:

```vim
:lua require("theme-switcher").set_background("terminal")
```

The mode stays when you change the theme. Blackout and terminal also cover the tab line, statusline, popups and menus.

## Desktop sync

`:ThemeSwitch <theme> [mode]` applies a theme in every open Neovim and saves it. Run it from your desktop theme script:

```bash
nvim --headless "+ThemeSwitch rose-pine-dawn normal" +qa
```

The mode is optional. `<Tab>` completes both.

## Persistence

Saved to `~/.local/share/nvim/theme_switcher_prefs.json`.

## License

MIT
