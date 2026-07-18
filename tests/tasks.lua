local messages = require("tapyr.messages")
local tasks = require("tapyr.tasks")

local original_constants = package.loaded["overseer.constants"]
local original_overseer = package.loaded.overseer
local original_preload = package.preload.overseer
local original_show = messages.show

local status = {
  PENDING = "pending",
  RUNNING = "running",
}

local created = {}
local function new_task(spec)
  local task = {
    disposed = false,
    restarts = 0,
    starts = 0,
    status = status.PENDING,
    spec = spec,
  }

  function task:get_bufnr()
    return nil
  end

  function task:is_disposed()
    return self.disposed
  end

  function task:restart()
    self.restarts = self.restarts + 1
    self.status = status.RUNNING
  end

  function task:start()
    self.starts = self.starts + 1
    self.status = status.RUNNING
  end

  return task
end

package.loaded.overseer = {
  new_task = function(spec)
    local task = new_task(spec)
    created[#created + 1] = task
    return task
  end,
  run_action = function()
    error("task output should not open without a buffer")
  end,
}
package.loaded["overseer.constants"] = { STATUS = status }

tasks.start("/tmp/start")
assert(created[#created].starts == 1, "start task was not started")
assert(created[#created].spec.cwd == "/tmp/start", "start task used the wrong root")

tasks.run("/tmp/run")
local run_task = created[#created]
assert(run_task.starts == 1, "pending task was not started")

run_task.status = "success"
tasks.run("/tmp/run")
assert(run_task.restarts == 1, "completed task was not restarted")

run_task.status = status.RUNNING
tasks.run("/tmp/run")
assert(run_task.restarts == 1, "running task was restarted")

tasks.restart("/tmp/restart")
local restart_task = created[#created]
assert(restart_task.starts == 1, "new restart task was not started")

tasks.restart("/tmp/restart")
assert(restart_task.restarts == 1, "existing task was not restarted")

tasks.test("/tmp/test")
local test_task = created[#created]
assert(test_task.starts == 1, "test task was not started")
assert(test_task.spec.cwd == "/tmp/test", "test task used the wrong root")
assert(test_task.spec.cmd[3] == "pytest", "test task used the wrong command")

local messages_seen = {}
messages.show = function(message)
  messages_seen[#messages_seen + 1] = message
end
package.loaded.overseer = nil
package.preload.overseer = function()
  error("overseer unavailable")
end

tasks.start("/tmp/missing-overseer")
assert(
  messages_seen[#messages_seen] == "Overseer is required to run apps and tests",
  "missing Overseer error was not shown"
)

messages.show = original_show
package.loaded.overseer = original_overseer
package.loaded["overseer.constants"] = original_constants
package.preload.overseer = original_preload
