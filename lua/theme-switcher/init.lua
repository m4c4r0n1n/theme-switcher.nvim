-- theme-switcher.nvim: a static list theme picker with background modes.
local M = {}

M.config = {
  width = 40,
  height = 20,
  border = "rounded",
  -- Background mode when no mode is saved: "normal" (theme background),
  -- "terminal" (transparent) or "blackout" (pure black).
  default_bg = "normal",
  -- Colorscheme names to hide from the picker.
  exclude = {},
  -- Send the theme and the background mode to the other open Neovim instances.
  sync = true,
}

M.state = {
  win = nil,
  buf = nil,
  themes = {},
  filtered_themes = {},
  current_line = 1,
  current_theme = nil,
  bg_mode = "normal", -- "normal", "terminal" or "blackout"
  search_query = "",
  search_mode = false,
  -- Background colors of the theme before a mode changes them.
  theme_bg = nil,
}

local prefs_file = vim.fn.stdpath("data") .. "/theme_switcher_prefs.json"

local function load_preferences()
  if vim.fn.filereadable(prefs_file) == 0 then
    return nil
  end
  local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(prefs_file), "\n"))
  if ok and type(data) == "table" then
    return data
  end
  return nil
end

-- The name given to :colorscheme. Some themes (for example rose-pine) set one
-- colors_name for all their variants, thus colors_name is not always correct.
local function theme_name()
  return M.state.current_theme or vim.g.colors_name
end

local function save_preferences()
  vim.fn.mkdir(vim.fn.fnamemodify(prefs_file, ":h"), "p")
  local prefs = { theme = theme_name(), bg_mode = M.state.bg_mode }
  vim.fn.writefile({ vim.json.encode(prefs) }, prefs_file)
end

-- ── Sync ────────────────────────────────────────────────────────────────────

-- The server sockets of the other Neovim instances of this user. They are in
-- the folder of this socket, or (without XDG_RUNTIME_DIR) in folders beside it.
local function other_servers()
  local own = vim.v.servername
  if own == "" then
    return {}
  end
  local dir = vim.fn.fnamemodify(own, ":h")
  local found = vim.fn.glob(dir .. "/nvim.*", true, true)
  vim.list_extend(found, vim.fn.glob(vim.fn.fnamemodify(dir, ":h") .. "/*/nvim.*", true, true))
  local servers, seen = {}, { [own] = true }
  for _, path in ipairs(found) do
    local stat = vim.uv.fs_stat(path)
    if not seen[path] and stat and stat.type == "socket" then
      seen[path] = true
      servers[#servers + 1] = path
    end
  end
  return servers
end

-- Send the theme and the mode to the other instances. An instance without
-- theme-switcher does nothing.
local function sync_others()
  if not M.config.sync then
    return
  end
  local code = "local ok, ts = pcall(require, 'theme-switcher') "
    .. "if ok and ts.sync_receive then ts.sync_receive(...) end"
  for _, path in ipairs(other_servers()) do
    local ok, chan = pcall(vim.fn.sockconnect, "pipe", path, { rpc = true })
    if ok and chan > 0 then
      vim.rpcnotify(chan, "nvim_exec_lua", code, { theme_name(), M.state.bg_mode })
      -- Close the channel after the message goes out.
      vim.defer_fn(function()
        pcall(vim.fn.chanclose, chan)
      end, 1000)
    end
  end
end

-- ── Background modes ────────────────────────────────────────────────────────

-- Groups that show the editor background. Blackout and terminal modes change them.
local bg_groups = {
  "Normal",
  "NormalNC",
  "NormalSB",
  "NormalFloat",
  "FloatBorder",
  "SignColumn",
  "EndOfBuffer",
  "NonText",
  "LineNr",
  "LineNrAbove",
  "LineNrBelow",
  "CursorLineNr",
  "Folded",
  "FoldColumn",
  "VertSplit",
  "WinSeparator",
  "StatusLine",
  "StatusLineNC",
  "TabLine",
  "TabLineFill",
  "TabLineSel",
  "Pmenu",
  "PmenuSbar",
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "NeoTreeEndOfBuffer",
  "NeoTreeWinSeparator",
  "SnacksDashboardNormal",
  "SnacksDashboardFooter",
}

-- Popups often use the float background. A group with one of these words in its
-- name gets the new background when its background is the float background.
local popup_words = { "Normal", "Float", "Border", "Title", "Footer", "Pmenu", "Cmp", "WhichKey", "WinBar" }

local function is_popup(name)
  for _, word in ipairs(popup_words) do
    if name:find(word, 1, true) then
      return true
    end
  end
  return false
end

-- Give a group a new background. Keep its text color.
local function set_bg(name, bg, ctermbg)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  hl.bg = bg
  hl.ctermbg = ctermbg
  vim.api.nvim_set_hl(0, name, hl)
end

-- Change the background groups and each group that uses the theme background.
-- Do not change linked groups. They follow the group that they link to.
local function paint(bg, ctermbg)
  for _, name in ipairs(bg_groups) do
    set_bg(name, bg, ctermbg)
  end
  local theme = M.state.theme_bg
  if not theme then
    return
  end
  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
    if hl.bg and not hl.link then
      if hl.bg == theme.normal or (hl.bg == theme.float and is_popup(name)) then
        set_bg(name, bg, ctermbg)
      end
    end
  end
end

local function apply_mode()
  if M.state.bg_mode == "blackout" then
    paint("#000000", 0)
  elseif M.state.bg_mode == "terminal" then
    paint("NONE", "NONE")
  end
  -- "normal": the theme sets its own background.
end

-- Each colorscheme change: record the theme background, then apply the mode.
-- Plugins (for example lualine and bufferline) make their groups again after a
-- colorscheme change. Thus apply the mode one more time after them.
local function on_colorscheme(args)
  if args and args.match and args.match ~= "" then
    M.state.current_theme = args.match
  end
  M.state.theme_bg = {
    normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg,
    float = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false }).bg,
  }
  apply_mode()
  vim.schedule(apply_mode)
end

local augroup = vim.api.nvim_create_augroup("nana_theme_switcher_bg", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = augroup, callback = on_colorscheme })
-- lazy.nvim loads many UI plugins on this event. Apply the mode again after them.
vim.api.nvim_create_autocmd("User", {
  group = augroup,
  pattern = "VeryLazy",
  once = true,
  callback = function()
    vim.schedule(apply_mode)
  end,
})

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  local prefs = load_preferences()
  M.state.bg_mode = (prefs and prefs.bg_mode) or M.config.default_bg or "normal"

  -- Apply the saved theme after the startup colorscheme. A schedule keeps the order
  -- and applies the theme before the first screen.
  vim.schedule(function()
    if prefs and prefs.theme and prefs.theme ~= theme_name() then
      pcall(vim.cmd.colorscheme, prefs.theme)
    end
    if not M.state.theme_bg then
      on_colorscheme()
    end
  end)
end

-- Toggle between blackout (theme text on pure black) and the theme background.
function M.toggle_background()
  if M.state.bg_mode == "blackout" then
    M.set_background("normal")
  else
    M.set_background("blackout")
  end
end

local mode_names = { normal = "Normal (Theme)", terminal = "Terminal", blackout = "Blackout" }

function M.set_background(mode)
  if not mode_names[mode] then
    vim.notify("Invalid background mode. Use 'normal', 'terminal', or 'blackout'", vim.log.levels.ERROR)
    return
  end
  M.state.bg_mode = mode
  -- Load the theme again. The ColorScheme autocommand applies the mode.
  if theme_name() then
    pcall(vim.cmd.colorscheme, theme_name())
  else
    on_colorscheme()
  end
  vim.notify("Background: " .. mode_names[mode], vim.log.levels.INFO)
  save_preferences()
  sync_others()
end

-- Apply a theme and a mode from a different instance. Do not save them (that
-- instance saved them) and do not send them again.
function M.sync_receive(theme, mode)
  if mode_names[mode] then
    M.state.bg_mode = mode
  end
  theme = theme or theme_name()
  if theme then
    pcall(vim.cmd.colorscheme, theme)
  end
end

-- ── Picker ──────────────────────────────────────────────────────────────────

-- All colorschemes, without the names in config.exclude.
local function get_colorschemes()
  local hidden = {}
  for _, name in ipairs(M.config.exclude or {}) do
    hidden[name] = true
  end
  local colorschemes = {}
  for _, name in ipairs(vim.fn.getcompletion("", "color")) do
    if not hidden[name] then
      table.insert(colorschemes, name)
    end
  end
  table.sort(colorschemes)
  return colorschemes
end

local function filter_themes()
  if M.state.search_query == "" then
    M.state.filtered_themes = M.state.themes
  else
    M.state.filtered_themes = {}
    local query = M.state.search_query:lower()
    for _, theme in ipairs(M.state.themes) do
      if theme:lower():find(query, 1, true) then
        table.insert(M.state.filtered_themes, theme)
      end
    end
  end
  M.state.current_line = 1
end

local function render_list()
  local buf = M.state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local lines = {}
  if M.state.search_mode then
    table.insert(lines, "Search: " .. M.state.search_query .. "_")
  else
    table.insert(lines, "Search: " .. M.state.search_query .. " (press '/' to search)")
  end
  table.insert(lines, string.rep("─", 40))
  table.insert(lines, "")

  if #M.state.filtered_themes == 0 then
    table.insert(lines, "  No themes found")
  else
    for i, theme in ipairs(M.state.filtered_themes) do
      table.insert(lines, ((i == M.state.current_line) and "> " or "  ") .. theme)
    end
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- The list starts after the 3 header lines.
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_set_cursor(M.state.win, { M.state.current_line + 3, 0 })
  end
end

-- Apply and save a theme. Show a message only when announce is true.
local function apply_theme(theme, announce)
  if not theme then
    return
  end
  local ok, err = pcall(vim.cmd.colorscheme, theme)
  if not ok then
    vim.notify("Failed to apply theme: " .. theme .. "\n" .. tostring(err), vim.log.levels.ERROR)
    return
  end
  M.state.current_theme = theme
  save_preferences()
  if announce then
    vim.notify("Applied theme: " .. theme, vim.log.levels.INFO)
  end
end

local function preview_theme()
  apply_theme(M.state.filtered_themes[M.state.current_line], false)
end

local function move_to(line)
  local last = #M.state.filtered_themes
  if last == 0 then
    return
  end
  line = math.max(1, math.min(line, last))
  if line == M.state.current_line then
    return
  end
  M.state.current_line = line
  render_list()
  preview_theme()
end

local function move_down()
  move_to(M.state.current_line + 1)
end

local function move_up()
  move_to(M.state.current_line - 1)
end

local function jump_top()
  move_to(1)
end

local function jump_bottom()
  move_to(#M.state.filtered_themes)
end

local function close_picker()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  M.state.win = nil
  M.state.buf = nil
  if theme_name() ~= M.state.opened_theme then
    sync_others()
  end
end

local function confirm_selection()
  apply_theme(M.state.filtered_themes[M.state.current_line], true)
  close_picker()
end

local function enter_search_mode()
  M.state.search_mode = true
  render_list()
end

local function exit_search_mode()
  M.state.search_mode = false
  render_list()
end

local function clear_search()
  M.state.search_query = ""
  filter_themes()
  render_list()
end

local function add_search_text(text)
  M.state.search_query = M.state.search_query .. text
  filter_themes()
  render_list()
end

local function search_backspace()
  if #M.state.search_query > 0 then
    M.state.search_query = M.state.search_query:sub(1, -2)
    filter_themes()
    render_list()
  end
end

-- Each key has one mapping. It does the list action, or in search mode the
-- search action.
local function setup_keymaps()
  local buf = M.state.buf
  local function map(lhs, list_fn, search_fn, nowait)
    vim.keymap.set("n", lhs, function()
      if M.state.search_mode then
        if search_fn then
          search_fn()
        end
      elseif list_fn then
        list_fn()
      end
    end, { buffer = buf, silent = true, nowait = nowait ~= false })
  end

  -- Letters, digits, "-" and "_" type search text. Some letters are also list keys.
  local list_keys = { j = move_down, k = move_up, G = jump_bottom, p = preview_theme, q = close_picker }
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
  for i = 1, #chars do
    local char = chars:sub(i, i)
    -- "g" waits for a second "g" (gg).
    map(char, list_keys[char], function()
      add_search_text(char)
    end, char ~= "g")
  end
  map("gg", jump_top, function()
    add_search_text("gg")
  end)

  map("<Down>", move_down)
  map("<Up>", move_up)
  map("<CR>", confirm_selection, exit_search_mode)
  map("<Space>", confirm_selection)
  map("/", enter_search_mode, enter_search_mode)
  map("<BS>", nil, search_backspace)
  map("<C-c>", clear_search, clear_search)
  map("<Esc>", close_picker, exit_search_mode)
end

function M.open()
  M.state.themes = get_colorschemes()
  if #M.state.themes == 0 then
    vim.notify("No colorschemes found", vim.log.levels.WARN)
    return
  end

  M.state.search_query = ""
  M.state.search_mode = false
  M.state.filtered_themes = M.state.themes

  -- Start on the current theme.
  M.state.current_line = 1
  M.state.opened_theme = theme_name()
  local current = theme_name() or "default"
  for i, theme in ipairs(M.state.filtered_themes) do
    if theme == current then
      M.state.current_line = i
      break
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  M.state.buf = buf

  local width = math.min(M.config.width, vim.o.columns - 4)
  local height = math.min(M.config.height, #M.state.filtered_themes + 3, vim.o.lines - 4)
  M.state.win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = M.config.border,
    title = " nana-switcher ",
    title_pos = "center",
  })

  local wo = vim.wo[M.state.win]
  wo.number = false
  wo.relativenumber = false
  wo.cursorline = true
  wo.signcolumn = "no"
  wo.wrap = false

  setup_keymaps()
  render_list()
end

function M.toggle()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    close_picker()
  else
    M.open()
  end
end

return M
