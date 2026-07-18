local M = {}

local process = require("tapyr.process")
local tasks = require("tapyr.tasks")
local util = require("tapyr.util")

local uv = vim.uv or vim.loop

local TABS = {
  { key = "list", label = "List" },
  { key = "build", label = "Build" },
  { key = "status", label = "Status" },
}

local BUILD_ROWS = {
  {
    kind = "task",
    name = "run app",
    key = "Ctrl+b",
    command = tasks.command_text("run"),
  },
  {
    kind = "task",
    name = "restart/rebuild",
    key = "Ctrl+Shift+b",
    command = tasks.command_text("run"),
  },
  {
    kind = "task",
    name = "test app",
    key = "Ctrl+t",
    command = tasks.command_text("test"),
  },
  {
    kind = "path",
    name = "app",
    path = "app.py",
  },
  {
    kind = "path",
    name = "project",
    path = "pyproject.toml",
  },
}

local function tab_line(active)
  local parts = {}
  for idx, tab in ipairs(TABS) do
    local label = tab.label
    if idx == active then
      label = "[" .. label .. "]"
    else
      label = " " .. label .. " "
    end
    parts[#parts + 1] = label
  end
  return table.concat(parts, "  ")
end

local function manager_footer()
  return {
    { " " },
    { "Tab", "DiagnosticOk" },
    { ":tabs  " },
    { "[R]", "DiagnosticOk" },
    { " reload  " },
    { "[K]", "DiagnosticOk" },
    { " kill  " },
    { "[S]", "DiagnosticOk" },
    { " show  " },
    { "CR", "DiagnosticOk" },
    { ":open path  " },
    { "[C]", "DiagnosticOk" },
    { " cancel " },
  }
end

local function manager_title(root)
  return {
    { " Tapyr ", "FloatTitle" },
    { util.truncate(root or uv.cwd(), 52), "Comment" },
    { " ", "FloatTitle" },
  }
end

local function render_list(state)
  local instances, warning = process.list()
  state.instances = instances

  local lines = {
    tab_line(state.tab),
    "",
    util.pad("host", 16)
      .. " "
      .. util.pad("port", 6)
      .. " "
      .. util.pad("pid", 8)
      .. " "
      .. util.pad("command", 32)
      .. " project",
    string.rep("-", 86),
  }

  state.rows = {}

  if vim.tbl_isempty(instances) then
    lines[#lines + 1] = "no localhost Python/Shiny listeners detected"
    if warning then
      lines[#lines + 1] = warning
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "start one with Ctrl+b from this project buffer"
    state.first_selectable = nil
    return lines
  end

  for _, instance in ipairs(instances) do
    local row = #lines + 1
    state.rows[row] = {
      kind = "instance",
      instance = instance,
    }
    lines[#lines + 1] = util.pad(instance.host, 16)
      .. " "
      .. util.pad(instance.port, 6)
      .. " "
      .. util.pad(instance.pid or "-", 8)
      .. " "
      .. util.pad(instance.command or "-", 32)
      .. " "
      .. util.truncate(instance.project or "-", 38)
    if not state.first_selectable then
      state.first_selectable = row
    end
  end

  return lines
end

local function build_path(row, root)
  if row.path:sub(1, 1) == "/" then
    return row.path
  end
  return vim.fs.joinpath(root, row.path)
end

local function render_build(state)
  local lines = {
    tab_line(state.tab),
    "",
    util.pad("entry", 18) .. " " .. util.pad("key", 14) .. " detail",
    string.rep("-", 74),
  }

  state.rows = {}
  state.first_selectable = nil

  for _, row in ipairs(BUILD_ROWS) do
    if row.kind == "task" then
      lines[#lines + 1] = util.pad(row.name, 18)
        .. " "
        .. util.pad(row.key, 14)
        .. " "
        .. row.command
    elseif row.kind == "path" then
      local line_nr = #lines + 1
      local path = build_path(row, state.root)
      state.rows[line_nr] = {
        kind = "path",
        path = path,
      }
      lines[#lines + 1] = util.pad(row.name, 18) .. " " .. util.pad("Enter", 14) .. " " .. path
      state.first_selectable = state.first_selectable or line_nr
    end
  end

  return lines
end

local function render_status(state)
  local instances, warning = process.list()
  state.rows = {}
  state.first_selectable = nil

  local lines = {
    tab_line(state.tab),
    "",
    "keys",
    "  Tab       cycle tabs",
    "  R/K/S     reload, kill, or show selected process on List",
    "  Enter     open selected file path on Build",
    "  C/q/Esc   close",
    "",
    "status",
    "  detected listeners: " .. #instances,
    "  project: " .. state.root,
    "",
    "limits",
    "  process command/cwd require readable /proc entries",
    "  reload uses the project task only for the active Shiny root",
  }

  if warning then
    lines[#lines + 1] = "  " .. warning
  end

  return lines
end

local function selected_row(state)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return nil
  end

  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.rows and state.rows[row] or nil
end

local function close_manager(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
end

local function render_manager(state)
  state.rows = {}
  state.first_selectable = nil

  local tab = TABS[state.tab].key
  local lines
  if tab == "list" then
    lines = render_list(state)
  elseif tab == "build" then
    lines = render_build(state)
  else
    lines = render_status(state)
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })

  if state.first_selectable then
    pcall(vim.api.nvim_win_set_cursor, state.win, { state.first_selectable, 0 })
  else
    pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
  end
end

local function next_tab(state, direction)
  state.tab = state.tab + direction
  if state.tab > #TABS then
    state.tab = 1
  elseif state.tab < 1 then
    state.tab = #TABS
  end
  render_manager(state)
end

local function open_selected_path(state)
  local row = selected_row(state)
  if not row or row.kind ~= "path" then
    return
  end

  local path = row.path
  close_manager(state)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function map_manager(state, lhs, callback, desc)
  vim.keymap.set("n", lhs, callback, {
    buffer = state.buf,
    desc = desc,
    noremap = true,
    silent = true,
  })
end

---@param root string
---@return table
function M.open(root)
  local editor_w = vim.o.columns
  local editor_h = vim.o.lines
  local max_width = math.max(editor_w - 4, 1)
  local max_height = math.max(editor_h - 4, 1)
  local desired_width = math.max(78, math.min(110, math.floor(editor_w * 0.72)))
  local desired_height = math.max(12, math.min(20, math.floor(editor_h * 0.45)))
  local width = math.min(desired_width, max_width)
  local height = math.min(desired_height, max_height)
  local row = math.max(math.floor((editor_h - height) / 2), 0)
  local col = math.max(math.floor((editor_w - width) / 2), 0)

  local buf = vim.api.nvim_create_buf(false, true)
  local state = {
    root = root,
    buf = buf,
    win = nil,
    tab = 1,
    rows = {},
    instances = {},
    first_selectable = nil,
  }

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "tapyr", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = manager_title(root),
    title_pos = "center",
    footer = manager_footer(),
    footer_pos = "center",
  })
  state.win = win

  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  render_manager(state)

  map_manager(state, "<Tab>", function()
    next_tab(state, 1)
  end, "Tapyr: next tab")
  map_manager(state, "<S-Tab>", function()
    next_tab(state, -1)
  end, "Tapyr: previous tab")
  map_manager(state, "<CR>", function()
    open_selected_path(state)
  end, "Tapyr: open selected path")
  map_manager(state, "R", function()
    local row_data = selected_row(state)
    process.restart(row_data and row_data.instance, state.root)
    vim.defer_fn(function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        render_manager(state)
      end
    end, 600)
  end, "Tapyr: restart selected app")
  map_manager(state, "K", function()
    local row_data = selected_row(state)
    if not row_data or not row_data.instance then
      util.notify("select a Shiny process first", vim.log.levels.WARN)
      return
    end
    process.terminate(row_data.instance.pid)
    vim.defer_fn(function()
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        render_manager(state)
      end
    end, 400)
  end, "Tapyr: kill selected app")
  map_manager(state, "S", function()
    local row_data = selected_row(state)
    if not row_data or not row_data.instance then
      util.notify("select a Shiny process first", vim.log.levels.WARN)
      return
    end
    process.open_url(row_data.instance.url)
  end, "Tapyr: show selected app")
  map_manager(state, "C", function()
    close_manager(state)
  end, "Tapyr: close")
  map_manager(state, "q", function()
    close_manager(state)
  end, "Tapyr: close")
  map_manager(state, "<Esc>", function()
    close_manager(state)
  end, "Tapyr: close")

  return state
end

return M
