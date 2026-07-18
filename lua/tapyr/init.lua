---@mod tapyr Shiny for Python tools for Neovim

local tapyr = {}

local uv = vim.uv or vim.loop
local active_root = nil

local function map(bufnr, lhs, callback, desc)
  vim.keymap.set("n", lhs, callback, {
    buffer = bufnr,
    desc = desc,
    silent = true,
  })
end

---@param bufnr? integer
function tapyr.attach(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return
  end

  if vim.b[bufnr].tapyr_attached then
    active_root = vim.b[bufnr].tapyr_root
    return
  end

  local root = require("tapyr.project").find_root(bufnr)
  if not root then
    return
  end

  active_root = root
  vim.b[bufnr].tapyr_attached = true
  vim.b[bufnr].tapyr_root = root

  map(bufnr, "<C-b>", function()
    require("tapyr.tasks").run(root)
  end, "Tapyr: run app")

  map(bufnr, "<C-S-b>", function()
    require("tapyr.tasks").restart(root)
  end, "Tapyr: restart app")

  map(bufnr, "<C-t>", function()
    require("tapyr.tasks").test(root)
  end, "Tapyr: test")

  map(bufnr, "<leader>tm", function()
    tapyr.open(root)
  end, "Tapyr: panel")
end

---@param root? string
function tapyr.open(root)
  root = root or require("tapyr.project").find_root(0) or active_root or uv.cwd()

  return require("tapyr.panel").open(root)
end

return tapyr
