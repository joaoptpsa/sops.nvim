vim.api.nvim_create_user_command("SopsDecrypt", function()
  local bufnr = vim.api.nvim_get_current_buf()
  require("sops").sops_decrypt_buffer(bufnr, false)
end, {
  desc = "Decrypt the current file using SOPS",
})

vim.api.nvim_create_user_command("SopsEncrypt", function()
  local bufnr = vim.api.nvim_get_current_buf()
  require("sops").sops_encrypt_buffer(bufnr, false)
end, {
  desc = "Encrypt the current file using SOPS",
})

local main_au_group = vim.api.nvim_create_augroup("sops.nvim", { clear = true })

vim.api.nvim_create_autocmd({
  -- use BufWinEnter so it would fire when session was restored. This autocmd will be running more than once
  "BufWinEnter",
  "BufReadPost",
  "FileReadPost",
}, {
  group = main_au_group,
  callback = function(ev)
    if not require("sops.util").is_sops_encrypted(ev.buf) then
      return
    end

    local buf_au_group = vim.api.nvim_create_augroup("sops.nvim_" .. ev.buf, { clear = true })

    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer = ev.buf,
      group = buf_au_group,
      callback = function()
        if not require("sops.util").is_auto_transform_enabled() then
          return
        end
        require("sops").sops_encrypt_buffer(ev.buf, true)
        vim.api.nvim_set_option_value("modified", false, { buf = ev.buf })
      end,
    })
    if not require("sops.util").is_auto_transform_enabled() then
      return
    end

    require("sops").sops_decrypt_buffer(ev.buf, true)
  end,
})
