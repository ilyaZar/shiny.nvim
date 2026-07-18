---@mod tapyr Shiny for Python workflow manager

local M = {}

local uv = vim.uv or vim.loop
local active_root = nil

local function map_buffer(bufnr, lhs, callback, desc)
  vim.keymap.set("n", lhs, callback, {
    buffer = bufnr,
    desc = desc,
    silent = true,
  })
end

---@param bufnr? integer
function M.attach(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return
  end

  if vim.b[bufnr].tapyr_attached then
    active_root = vim.b[bufnr].tapyr_root
    return
  end

  local root = require("tapyr.project").root(bufnr)
  if not root then
    return
  end

  active_root = root
  vim.b[bufnr].tapyr_attached = true
  vim.b[bufnr].tapyr_root = root

  map_buffer(bufnr, "<C-b>", function()
    require("tapyr.tasks").run(root)
  end, "Tapyr: run app")

  map_buffer(bufnr, "<C-S-b>", function()
    require("tapyr.tasks").rebuild(root)
  end, "Tapyr: rebuild app")

  map_buffer(bufnr, "<C-t>", function()
    require("tapyr.tasks").test(root)
  end, "Tapyr: test")

  map_buffer(bufnr, "<leader>tm", function()
    M.open(root)
  end, "Tapyr: manager")
end

---@param root? string
function M.open(root)
  root = root or require("tapyr.project").root(0) or active_root or uv.cwd()

  return require("tapyr.ui").open(root)
end

return M
