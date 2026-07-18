local M = {}

local uv = vim.uv or vim.loop

local function is_shiny_app(path)
  if vim.fn.filereadable(path) ~= 1 then
    return false
  end

  for _, line in ipairs(vim.fn.readfile(path, "", 200)) do
    if
      line:match("^%s*from%s+shiny[%s%.]")
      or line:match("^%s*import%s+shiny%s*$")
      or line:match("^%s*import%s+shiny[%s,]")
    then
      return true
    end
  end

  return false
end

---@param bufnr? integer
---@return string?
function M.root(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  local start = path ~= "" and vim.fs.dirname(path) or uv.cwd()
  local app = vim.fs.find("app.py", {
    upward = true,
    path = start,
    type = "file",
  })[1]

  if app and is_shiny_app(app) then
    return vim.fs.dirname(app)
  end
end

return M
