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
    if not require("util").is_sops_encrypted(ev.buf) then
      return
    end

    if not require("util").is_auto_transform_enabled() then
      return
    end

    -- Without plaintext in the buffer, a normal write keeps the ciphertext as it is
    if not require("sops").sops_decrypt_buffer(ev.buf, true) then
      return
    end

    local buf_au_group = vim.api.nvim_create_augroup("sops.nvim_" .. ev.buf, { clear = true })

    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer = ev.buf,
      group = buf_au_group,
      desc = "Encrypt and save with SOPS",
      callback = function(write_ev)
        local path = vim.api.nvim_buf_get_name(ev.buf)
        -- The plaintext would otherwise land in the buffer's own file, not the one named in `:w {file}`
        if vim.fn.fnamemodify(write_ev.match, ":p") ~= vim.fn.fnamemodify(path, ":p") then
          vim.notify("SOPS buffers can only be written to their own file: " .. path, vim.log.levels.ERROR)
          return
        end
        -- Leaves 'modified' set when SOPS fails, so `:wq` stops instead of dropping the edit
        require("sops").sops_encrypt_buffer(ev.buf, true)
      end,
    })
  end,
})
