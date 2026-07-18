local M = {}

local tasks = require("tapyr.tasks")
local util = require("tapyr.util")

---@class TapyrInstance
---@field host string
---@field port integer
---@field pid? integer
---@field process? string
---@field argv? string[]
---@field command? string
---@field cwd? string
---@field project? string
---@field url string

local function read_proc_argv(pid)
  if not pid then
    return nil, nil
  end

  local handle = io.open("/proc/" .. pid .. "/cmdline", "rb")
  if not handle then
    return nil, nil
  end

  local raw = handle:read("*a")
  handle:close()

  local argv = {}
  for arg in raw:gmatch("([^%z]+)") do
    argv[#argv + 1] = arg
  end
  if vim.tbl_isempty(argv) then
    return nil, nil
  end

  return argv, table.concat(argv, " ")
end

local function read_proc_cwd(pid)
  if not pid then
    return nil
  end

  local proc_cwd = "/proc/" .. pid .. "/cwd"
  local cwd = vim.fn.resolve(proc_cwd)
  if cwd == "" or cwd == proc_cwd then
    return nil
  end
  return cwd
end

local function read_proc_parent(pid)
  local handle = io.open("/proc/" .. pid .. "/status", "r")
  if not handle then
    return nil
  end

  for line in handle:lines() do
    local parent = line:match("^PPid:%s+(%d+)")
    if parent then
      handle:close()
      return tonumber(parent)
    end
  end

  handle:close()
end

local function pyproject_root(path)
  if not path or path == "" then
    return nil
  end

  local pyproject = vim.fs.find("pyproject.toml", {
    upward = true,
    path = path,
    type = "file",
  })[1]
  if pyproject then
    return vim.fs.dirname(pyproject)
  end
end

local function parse_socket_address(address)
  local host, port = address:match("^%[(.*)%]:(%d+)$")
  if not host then
    host, port = address:match("^(.*):(%d+)$")
  end
  if not host or not port then
    return nil, nil
  end

  host = host:gsub("%%.*$", "")
  return host, tonumber(port)
end

local function is_local_host(host)
  return host == "127.0.0.1"
    or host == "localhost"
    or host == "::1"
    or host == "0.0.0.0"
    or host == "::"
    or host == "*"
end

local function display_url(host, port)
  local url_host = host
  if url_host == "0.0.0.0" or url_host == "::" or url_host == "*" then
    url_host = "127.0.0.1"
  end
  if url_host == "::1" then
    return "http://[::1]:" .. port
  end
  return "http://" .. url_host .. ":" .. port
end

local function looks_like_shiny(command, process)
  local haystack = table
    .concat({
      command or "",
      process or "",
    }, " ")
    :lower()

  return haystack:find("shiny", 1, true) ~= nil or haystack:find("app.py", 1, true) ~= nil
end

local function socket_pids(line)
  local pids = {}
  local seen = {}
  for value in line:gmatch("pid=(%d+)") do
    local pid = tonumber(value)
    if pid and not seen[pid] then
      seen[pid] = true
      pids[#pids + 1] = pid
    end
  end
  return pids
end

local function shiny_process(line)
  for _, socket_pid in ipairs(socket_pids(line)) do
    local pid = socket_pid
    for _ = 1, 12 do
      if not pid or pid <= 1 then
        break
      end

      local argv, command = read_proc_argv(pid)
      local process = argv and vim.fs.basename(argv[1]) or nil
      if looks_like_shiny(command, process) then
        return pid, argv, command, read_proc_cwd(pid), process
      end

      pid = read_proc_parent(pid)
    end
  end
end

---@return TapyrInstance[], string?
function M.list()
  if vim.fn.executable("ss") ~= 1 then
    return {}, "ss not found; cannot inspect listening localhost sockets"
  end

  local result = vim.system({ "ss", "-H", "-ltnp" }, { text = true }):wait()
  if result.code ~= 0 then
    return {}, "ss failed; process detection is unavailable"
  end

  local instances = {}
  local seen = {}

  for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
    local fields = vim.split(line, "%s+")
    local address = fields[4]
    local host, port
    if address then
      host, port = parse_socket_address(address)
    end

    if host and port and is_local_host(host) then
      local pid, argv, command, cwd, process_name = shiny_process(line)
      if pid then
        local project = pyproject_root(cwd) or cwd

        ---@type TapyrInstance
        local instance = {
          host = host,
          port = port,
          pid = pid,
          process = process_name,
          argv = argv,
          command = command or process_name,
          cwd = cwd,
          project = project,
          url = display_url(host, port),
        }

        local key = table.concat({
          tostring(host),
          tostring(port),
          tostring(pid),
        }, ":")

        if not seen[key] then
          seen[key] = true
          instances[#instances + 1] = instance
        end
      end
    end
  end

  table.sort(instances, function(a, b)
    if a.port == b.port then
      return tostring(a.pid or "") < tostring(b.pid or "")
    end
    return a.port < b.port
  end)

  return instances, nil
end

---@param pid? integer
---@return boolean
function M.terminate(pid)
  if not pid then
    return false
  end

  local result = vim.system({ "kill", tostring(pid) }, { text = true }):wait()
  if result.code ~= 0 then
    util.notify("failed to terminate pid " .. pid, vim.log.levels.ERROR)
    return false
  end

  util.notify("terminated pid " .. pid)
  return true
end

---@param instance? TapyrInstance
---@param root string
function M.restart(instance, root)
  if not instance then
    util.notify("select a Shiny process first", vim.log.levels.WARN)
    return
  end

  local project = instance.project or instance.cwd
  local is_current_project = project and (project == root or vim.startswith(project, root .. "/"))

  if is_current_project then
    if not M.terminate(instance.pid) then
      return
    end
    vim.defer_fn(function()
      tasks.start(root)
    end, 250)
    return
  end

  if not instance.argv or vim.tbl_isempty(instance.argv) then
    util.notify("restart command is not detectable for this process", vim.log.levels.WARN)
    return
  end

  if not M.terminate(instance.pid) then
    return
  end
  vim.defer_fn(function()
    local job = vim.fn.jobstart(instance.argv, {
      cwd = instance.cwd or instance.project,
      detach = true,
    })
    if job <= 0 then
      util.notify("failed to restart " .. (instance.command or "process"), vim.log.levels.ERROR)
    else
      util.notify("restarted " .. (instance.command or "process"))
    end
  end, 250)
end

---@param url string
function M.open_url(url)
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
    return
  end

  if vim.fn.executable("xdg-open") == 1 then
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
  else
    util.notify("no browser opener found for " .. url, vim.log.levels.WARN)
  end
end

return M
