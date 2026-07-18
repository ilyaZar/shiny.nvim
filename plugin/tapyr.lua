if vim.g.loaded_tapyr == 1 then
  return
end
vim.g.loaded_tapyr = 1

vim.api.nvim_create_user_command("Tapyr", function()
  require("tapyr").open()
end, {
  desc = "Open Tapyr",
  force = false,
})

vim.api.nvim_create_autocmd({ "BufEnter", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("tapyr", { clear = true }),
  callback = function(event)
    require("tapyr").attach(event.buf)
  end,
})
