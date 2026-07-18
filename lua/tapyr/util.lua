local M = {}

---@param message string
---@param level? integer
function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, {
    title = "Tapyr",
  })
end

---@param value any
---@param width integer
---@return string
function M.truncate(value, width)
  value = tostring(value or "")
  if #value <= width then
    return value
  end
  if width <= 3 then
    return value:sub(1, width)
  end
  return value:sub(1, width - 3) .. "..."
end

---@param value any
---@param width integer
---@return string
function M.pad(value, width)
  value = M.truncate(value, width)
  return value .. string.rep(" ", math.max(width - #value, 0))
end

return M
