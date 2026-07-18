local messages = {}

---@param message string
---@param level? integer
function messages.show(message, level)
  vim.notify(message, level or vim.log.levels.INFO, {
    title = "Tapyr",
  })
end

return messages
