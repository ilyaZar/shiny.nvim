local tasks = {}

local messages = require("tapyr.messages")
local app_tasks = {}

local commands = {
  run = { "uv", "run", "shiny", "run", "app.py" },
  test = { "uv", "run", "pytest" },
}

local function get_overseer()
  local ok, overseer = pcall(require, "overseer")
  if not ok then
    messages.show("Overseer is required to run apps and tests", vim.log.levels.ERROR)
    return nil
  end
  return overseer
end

local function task_is_gone(task)
  return not task or task:is_disposed()
end

local function show_output(task)
  vim.defer_fn(function()
    if task_is_gone(task) or not task:get_bufnr() then
      return
    end

    local overseer = get_overseer()
    if not overseer then
      return
    end
    overseer.run_action(task, "open hsplit")
    vim.cmd("wincmd p")
  end, 100)
end

local function new_app_task(root)
  local overseer = get_overseer()
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
function tasks.describe(name)
  return table.concat(commands[name], " ")
end

---@param root string
function tasks.start(root)
  local task = new_app_task(root)
  if not task then
    return
  end

  app_tasks[root] = task
  task:start()
  show_output(task)
end

---@param root string
function tasks.run(root)
  local task = app_tasks[root]
  if task_is_gone(task) then
    task = new_app_task(root)
    if not task then
      return
    end
    app_tasks[root] = task
  end

  local ok, constants = pcall(require, "overseer.constants")
  if not ok then
    messages.show("Overseer is required to run apps and tests", vim.log.levels.ERROR)
    return
  end

  if task.status == constants.STATUS.PENDING then
    task:start()
  elseif task.status ~= constants.STATUS.RUNNING then
    task:restart(true)
  end

  show_output(task)
end

---@param root string
function tasks.restart(root)
  local task = app_tasks[root]
  if task_is_gone(task) then
    task = new_app_task(root)
    if not task then
      return
    end
    app_tasks[root] = task
    task:start()
  else
    task:restart(true)
  end

  show_output(task)
end

---@param root string
function tasks.test(root)
  local overseer = get_overseer()
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
  show_output(task)
end

return tasks
