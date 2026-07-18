local function buffer_has_mapping(bufnr, desc)
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if mapping.desc == desc then
      return true
    end
  end
  return false
end

assert(vim.fn.exists(":Tapyr") == 2, "Tapyr command is missing")

local fixture = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "sample-project", "app.py")
vim.cmd.edit(vim.fn.fnameescape(fixture))

local app_buf = vim.api.nvim_get_current_buf()
assert(buffer_has_mapping(app_buf, "Tapyr: panel"), "Shiny buffer mapping is missing")

vim.cmd.Tapyr()
assert(vim.bo.filetype == "tapyr", "panel filetype is missing")

local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
assert(first_line:find("[Apps]", 1, true), "Apps view is missing")

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1]:find("[Project]", 1, true), "Project view is missing")

local app_row
for index, line in ipairs(lines) do
  if line:find("/app.py", 1, true) then
    app_row = index
    break
  end
end
assert(app_row, "app.py row is missing")

vim.api.nvim_win_set_cursor(0, { app_row, 0 })
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(vim.api.nvim_buf_get_name(0) == fixture, "app.py row did not open")

vim.o.columns = 40
vim.o.lines = 12
vim.cmd.Tapyr()
assert(vim.bo.filetype == "tapyr", "panel failed in a narrow editor")
vim.api.nvim_feedkeys("q", "x", false)

vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vim.fn.getcwd(), "README.md")))
assert(not buffer_has_mapping(0, "Tapyr: panel"), "non-Shiny buffer was mapped")

print("tapyr tests passed")
