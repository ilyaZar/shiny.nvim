local M = {}

local util = require("tapyr.util")
local server_tasks = {}

local commands = {
  run = { "uv", "run", "shiny", "run", "app.py" },
  test = { "uv", "run", "pytest" },
}

local function load_overseer()
  local ok, overseer = pcall(require, "overseer")
  if not ok then
    util.notify("overseer.nvim is required", vim.log.levels.ERROR)
    return nil
  end
  return overseer
end

local function is_disposed(task)
  return not task or task:is_disposed()
end

local function open_below(task)
  vim.defer_fn(function()
    if is_disposed(task) or not task:get_bufnr() then
      return
    end

    local overseer = load_overseer()
    if not overseer then
      return
    end
    overseer.run_action(task, "open hsplit")
    vim.cmd("wincmd p")
  end, 100)
end

local function new_server_task(root)
  local overseer = load_overseer()
  if not overseer then
    return nil
  end

  return overseer.new_task({
    name = "Tapyr: run app",
    cmd = commands.run,
    cwd = root,
    components = { "default" },
  })
end

---@param name "run"|"test"
---@return string
function M.command_text(name)
  return table.concat(commands[name], " ")
end

---@param root string
function M.start(root)
  local task = new_server_task(root)
  if not task then
    return
  end

  server_tasks[root] = task
  task:start()
  open_below(task)
end

---@param root string
function M.run(root)
  local task = server_tasks[root]
  if is_disposed(task) then
    task = new_server_task(root)
    if not task then
      return
    end
    server_tasks[root] = task
  end

  local ok, constants = pcall(require, "overseer.constants")
  if not ok then
    util.notify("overseer.nvim is required", vim.log.levels.ERROR)
    return
  end

  if task.status == constants.STATUS.PENDING then
    task:start()
  elseif task.status ~= constants.STATUS.RUNNING then
    task:restart(true)
  end

  open_below(task)
end

---@param root string
function M.rebuild(root)
  local task = server_tasks[root]
  if is_disposed(task) then
    task = new_server_task(root)
    if not task then
      return
    end
    server_tasks[root] = task
    task:start()
  else
    task:restart(true)
  end

  open_below(task)
end

---@param root string
function M.test(root)
  local overseer = load_overseer()
  if not overseer then
    return
  end

  local task = overseer.new_task({
    name = "Tapyr: test app",
    cmd = commands.test,
    cwd = root,
    components = {
      { "on_output_quickfix", open_on_match = true, set_diagnostics = true },
      "on_result_diagnostics",
      "default",
    },
  })

  task:start()
  open_below(task)
end

return M
