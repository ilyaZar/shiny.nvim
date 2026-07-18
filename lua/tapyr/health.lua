local M = {}

function M.check()
  vim.health.start("tapyr.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10 or newer")
  else
    vim.health.error("Neovim 0.10 or newer is required")
  end

  if vim.fn.executable("uv") == 1 then
    vim.health.ok("uv is available")
  else
    vim.health.error("uv is required to run apps and tests")
  end

  if vim.fn.executable("ss") == 1 then
    vim.health.ok("ss is available")
  else
    vim.health.error("ss is required for listener discovery")
  end

  if vim.fn.isdirectory("/proc") == 1 then
    vim.health.ok("/proc is available")
  else
    vim.health.error("/proc is required for process discovery")
  end

  if pcall(require, "overseer") then
    vim.health.ok("overseer.nvim is available")
  else
    vim.health.error("overseer.nvim is required for app and test tasks")
  end
end

return M
