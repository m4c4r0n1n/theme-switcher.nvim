-- theme-switcher.nvim - Static list theme picker
local M = {}

M.config = {
  width = 40,
  height = 20,
  border = "rounded",
}

M.state = {
  win = nil,
  buf = nil,
  themes = {},
  filtered_themes = {},
  current_line = 1,
  current_theme = nil,
  bg_mode = "normal", -- "normal", "terminal", or "blackout"
  search_query = "",
  search_mode = false,
}

-- Forward declarations (must be before M.setup)
local apply_black_bg
local apply_terminal_bg
local apply_theme_bg

-- Load saved preferences
local function load_preferences()
  local prefs_file = vim.fn.stdpath("data") .. "/theme_switcher_prefs.json"
  if vim.fn.filereadable(prefs_file) == 1 then
    local content = vim.fn.readfile(prefs_file)
    local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
    if ok and type(data) == "table" then
      return data
    end
  end
  return nil
end

-- Save current preferences
local function save_preferences()
  local prefs_file = vim.fn.stdpath("data") .. "/theme_switcher_prefs.json"
  local prefs = {
    theme = vim.g.colors_name,
    bg_mode = M.state.bg_mode,
  }
  vim.fn.writefile({ vim.fn.json_encode(prefs) }, prefs_file)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Load and apply saved preferences
  local prefs = load_preferences()
  if prefs then
    M.state.bg_mode = prefs.bg_mode or "normal"

    -- Apply saved theme and background after a short delay to let plugins load
    vim.defer_fn(function()
      if prefs.theme then
        -- Just load the theme naturally
        pcall(vim.cmd.colorscheme, prefs.theme)

        -- Apply background mode if needed
        if M.state.bg_mode == "terminal" then
          apply_terminal_bg()
        elseif M.state.bg_mode == "blackout" then
          apply_black_bg()
        end
        -- normal mode: do nothing, let theme handle its own background
      end
    end, 100)
  end
end

-- Get all available colorschemes
local function get_colorschemes()
  local colorschemes = vim.fn.getcompletion("", "color")
  table.sort(colorschemes)
  return colorschemes
end

-- Filter themes based on search query
local function filter_themes()
  if M.state.search_query == "" then
    M.state.filtered_themes = M.state.themes
  else
    M.state.filtered_themes = {}
    local query_lower = M.state.search_query:lower()
    for _, theme in ipairs(M.state.themes) do
      if theme:lower():find(query_lower, 1, true) then
        table.insert(M.state.filtered_themes, theme)
      end
    end
  end

  -- Reset selection to first item
  M.state.current_line = 1
end

-- Render the static list with highlight on current line
local function render_list()
  if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
    return
  end

  local lines = {}
  local display_themes = M.state.filtered_themes

  -- Add search bar header
  if M.state.search_mode then
    table.insert(lines, "Search: " .. M.state.search_query .. "_")
  else
    table.insert(lines, "Search: " .. M.state.search_query .. " (press '/' to search)")
  end
  table.insert(lines, string.rep("─", 40))
  table.insert(lines, "")

  -- Show filtered themes
  if #display_themes == 0 then
    table.insert(lines, "  No themes found")
  else
    for i, theme in ipairs(display_themes) do
      local prefix = (i == M.state.current_line) and "> " or "  "
      table.insert(lines, prefix .. theme)
    end
  end

  vim.api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.buf, "modifiable", false)

  -- Set cursor to current line (offset by 3 for header)
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_set_cursor(M.state.win, {M.state.current_line + 3, 0})
  end
end

-- Apply the selected theme
local function apply_theme(theme)
  if not theme then
    return
  end

  local ok, err = pcall(vim.cmd.colorscheme, theme)
  if ok then
    M.state.current_theme = theme
    -- Save preferences
    save_preferences()
    vim.notify("Applied theme: " .. theme, vim.log.levels.INFO)
  else
    vim.notify("Failed to apply theme: " .. theme .. "\n" .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Preview theme without closing window
local function preview_theme()
  local theme = M.state.filtered_themes[M.state.current_line]
  if theme then
    apply_theme(theme)
  end
end


-- Move selection up
local function move_up()
  if M.state.current_line > 1 then
    M.state.current_line = M.state.current_line - 1
    render_list()
    preview_theme()
  end
end

-- Move selection down
local function move_down()
  if M.state.current_line < #M.state.filtered_themes then
    M.state.current_line = M.state.current_line + 1
    render_list()
    preview_theme()
  end
end

-- Jump to top
local function jump_top()
  M.state.current_line = 1
  render_list()
  preview_theme()
end

-- Jump to bottom
local function jump_bottom()
  M.state.current_line = #M.state.filtered_themes
  render_list()
  preview_theme()
end

-- Close the picker
local function close_picker()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  M.state.win = nil
  M.state.buf = nil
end

-- Confirm selection and close
local function confirm_selection()
  local theme = M.state.filtered_themes[M.state.current_line]
  if theme then
    apply_theme(theme)
  end
  close_picker()
end

-- Enter search mode
local function enter_search_mode()
  M.state.search_mode = true
  render_list()
end

-- Exit search mode
local function exit_search_mode()
  M.state.search_mode = false
  render_list()
end

-- Clear search
local function clear_search()
  M.state.search_query = ""
  filter_themes()
  render_list()
end

-- Handle character input in search mode
local function handle_search_char(char)
  M.state.search_query = M.state.search_query .. char
  filter_themes()
  render_list()
end

-- Backspace in search mode
local function search_backspace()
  if #M.state.search_query > 0 then
    M.state.search_query = M.state.search_query:sub(1, -2)
    filter_themes()
    render_list()
  end
end

-- Setup keymaps for the picker
local function setup_keymaps()
  if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
    return
  end

  local opts = { buffer = M.state.buf, silent = true, nowait = true }

  -- Navigation (only when not in search mode)
  vim.keymap.set("n", "j", function()
    if not M.state.search_mode then move_down() end
  end, opts)
  vim.keymap.set("n", "k", function()
    if not M.state.search_mode then move_up() end
  end, opts)
  vim.keymap.set("n", "<Down>", function()
    if not M.state.search_mode then move_down() end
  end, opts)
  vim.keymap.set("n", "<Up>", function()
    if not M.state.search_mode then move_up() end
  end, opts)
  vim.keymap.set("n", "gg", function()
    if not M.state.search_mode then jump_top() end
  end, opts)
  vim.keymap.set("n", "G", function()
    if not M.state.search_mode then jump_bottom() end
  end, opts)

  -- Selection
  vim.keymap.set("n", "<CR>", function()
    if M.state.search_mode then
      exit_search_mode()
    else
      confirm_selection()
    end
  end, opts)
  vim.keymap.set("n", "<Space>", function()
    if not M.state.search_mode then confirm_selection() end
  end, opts)

  -- Preview (manual if needed)
  vim.keymap.set("n", "p", function()
    if not M.state.search_mode then preview_theme() end
  end, opts)

  -- Search
  vim.keymap.set("n", "/", enter_search_mode, opts)
  vim.keymap.set("n", "<BS>", function()
    if M.state.search_mode then
      search_backspace()
    end
  end, opts)

  -- Clear search
  vim.keymap.set("n", "<C-c>", clear_search, opts)

  -- Close
  vim.keymap.set("n", "q", function()
    if not M.state.search_mode then close_picker() end
  end, opts)
  vim.keymap.set("n", "<Esc>", function()
    if M.state.search_mode then
      exit_search_mode()
    else
      close_picker()
    end
  end, opts)

  -- Character input in search mode
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
  for i = 1, #chars do
    local char = chars:sub(i, i)
    vim.keymap.set("n", char, function()
      if M.state.search_mode then
        handle_search_char(char)
      end
    end, opts)
  end
end

-- Open the theme picker
function M.open()
  -- Get all colorschemes
  M.state.themes = get_colorschemes()

  if #M.state.themes == 0 then
    vim.notify("No colorschemes found", vim.log.levels.WARN)
    return
  end

  -- Initialize search state
  M.state.search_query = ""
  M.state.search_mode = false
  M.state.filtered_themes = M.state.themes

  -- Find current theme in list
  local current_colorscheme = vim.g.colors_name or "default"
  M.state.current_line = 1
  for i, theme in ipairs(M.state.filtered_themes) do
    if theme == current_colorscheme then
      M.state.current_line = i
      break
    end
  end

  -- Create buffer
  M.state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.state.buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(M.state.buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(M.state.buf, "swapfile", false)

  -- Calculate window size and position
  local width = math.min(M.config.width, vim.o.columns - 4)
  local height = math.min(M.config.height, #M.state.filtered_themes + 3, vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Create floating window
  M.state.win = vim.api.nvim_open_win(M.state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = M.config.border,
    title = " nana-switcher ",
    title_pos = "center",
  })

  -- Window options
  vim.wo[M.state.win].number = false
  vim.wo[M.state.win].relativenumber = false
  vim.wo[M.state.win].cursorline = true
  vim.wo[M.state.win].signcolumn = "no"
  vim.wo[M.state.win].wrap = false

  -- Setup keymaps
  setup_keymaps()

  -- Render initial list
  render_list()
end

-- Toggle the picker
function M.toggle()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    close_picker()
  else
    M.open()
  end
end

-- Apply pure black background
apply_black_bg = function()
  -- Force pure black background on UI groups only
  -- IMPORTANT: Only modify UI background groups, NOT text/syntax groups
  local black_groups = {
    "Normal",
    "NormalFloat",
    "NormalNC",
    "SignColumn",
    "EndOfBuffer",
    "LineNr",
    "LineNrAbove",
    "LineNrBelow",
    "CursorLineNr",
    "Folded",
    "FoldColumn",
    "NonText",
    "VertSplit",
    "WinSeparator",
    "StatusLine",
    "StatusLineNC",
    "TabLine",
    "TabLineFill",
    "TabLineSel",
    "NormalSB",
    -- Dashboard/Snacks specific
    "SnacksDashboardNormal",
    "SnacksDashboardFooter",
  }

  -- DO NOT touch: FloatBorder, Pmenu, notifications, or any syntax/text groups
  for _, group in ipairs(black_groups) do
    -- Get existing highlight and preserve everything except bg
    local hl = vim.api.nvim_get_hl(0, { name = group })
    hl.bg = "#000000"  -- Set to black
    hl.ctermbg = 0
    vim.api.nvim_set_hl(0, group, hl)
  end
end

-- Apply terminal background (transparent)
apply_terminal_bg = function()
  -- Make background transparent to show terminal colors
  local transparent_groups = {
    "Normal",
    "NormalFloat",
    "NormalNC",
    "SignColumn",
    "EndOfBuffer",
    "LineNr",
    "LineNrAbove",
    "LineNrBelow",
    "Folded",
    "FoldColumn",
    "NonText",
    "VertSplit",
    "WinSeparator",
    "StatusLine",
    "StatusLineNC",
    "TabLine",
    "TabLineFill",
    "NormalSB",
    -- Dashboard/Snacks specific
    "SnacksDashboardNormal",
    "SnacksDashboardFooter",
  }

  for _, group in ipairs(transparent_groups) do
    local hl = vim.api.nvim_get_hl(0, { name = group })
    hl.bg = "NONE"  -- Transparent
    hl.ctermbg = "NONE"
    vim.api.nvim_set_hl(0, group, hl)
  end
end

-- Restore theme's natural background
apply_theme_bg = function()
  -- Reload the colorscheme to restore its natural colors
  local current_theme = vim.g.colors_name
  if current_theme then
    -- Reload the colorscheme directly (no hi clear needed - just reapply)
    -- This properly restores the theme's original background and colors
    pcall(vim.cmd.colorscheme, current_theme)
  end
end

-- Toggle background mode (terminal <-> blackout only)
function M.toggle_background()
  if M.state.bg_mode == "terminal" then
    -- Switch to blackout - force pure black
    M.state.bg_mode = "blackout"
    apply_black_bg()
    vim.notify("Background: Blackout", vim.log.levels.INFO)
  else
    -- Switch to terminal - transparent background
    M.state.bg_mode = "terminal"
    apply_terminal_bg()
    vim.notify("Background: Terminal", vim.log.levels.INFO)
  end
  -- Save preferences after toggling
  save_preferences()
end

-- Set background mode explicitly
function M.set_background(mode)
  if mode == "normal" or mode == "terminal" or mode == "blackout" then
    M.state.bg_mode = mode
    if mode == "normal" then
      -- Reload theme to restore natural background
      apply_theme_bg()
      vim.notify("Background: Normal (Theme)", vim.log.levels.INFO)
    elseif mode == "terminal" then
      -- Apply terminal transparent background
      apply_terminal_bg()
      vim.notify("Background: Terminal", vim.log.levels.INFO)
    else
      -- Apply blackout
      apply_black_bg()
      vim.notify("Background: Blackout", vim.log.levels.INFO)
    end
    -- Save preferences after setting
    save_preferences()
  else
    vim.notify("Invalid background mode. Use 'normal', 'terminal', or 'blackout'", vim.log.levels.ERROR)
  end
end

return M
