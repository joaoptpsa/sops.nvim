---@class SopsModule
local M = {}

---@param bufnr number
---@param is_autocmd boolean Enable acwrite for encrypting again with autocmds
M.sops_decrypt_buffer = function(bufnr, is_autocmd)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local cwd = vim.fs.dirname(path)

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

  vim.system(
    { "sops", "--decrypt", "--input-type", filetype, "--output-type", filetype, path },
    { cwd = cwd, text = true },
    function(out)
      vim.schedule(function()
        if out.code ~= 0 then
          vim.notify("Failed to decrypt file", vim.log.levels.WARN)

          return
        end

        local decrypted_lines = vim.fn.split(out.stdout, "\n", false)

        if is_autocmd then
            vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, decrypted_lines)

        if is_autocmd then
            vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
        end

        -- Run BufReadPost autocmds since the buffer contents have changed
        vim.api.nvim_exec_autocmds("BufReadPost", {
          buffer = bufnr,
        })
      end)
    end
  )
end

---@param bufnr number
---@param is_autocmd boolean Run this function for autocmd
M.sops_encrypt_buffer = function(bufnr, is_autocmd)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local cwd = vim.fs.dirname(path)

  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  local editor_script = vim.fs.joinpath(plugin_root, "scripts", "sops-editor.sh")

  if vim.fn.filereadable(editor_script) == 0 then
    vim.notify("SOPS editor script not found: " .. editor_script, vim.log.levels.WARN)

    return
  end

  local temp_file = vim.fn.tempname()
  local function cleanup()
    vim.fn.delete(temp_file)
  end

  local plaintext_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local success = vim.fn.writefile(plaintext_lines, temp_file) == 0

  if not success then
    cleanup()
    vim.notify("Failed to write temp file", vim.log.levels.WARN)

    return
  end

  local cmd = {"sops", "encrypt", path}

  if is_autocmd then
    cmd = {"sops", "edit", path}
  end

  vim.system(cmd, {
    cwd = cwd,
    env = {
      SOPS_EDITOR = editor_script,
      SOPS_NVIM_TEMP_FILE = temp_file,
    },
    text = true,
  }, function(out)
    vim.schedule(function()
      cleanup()

      if out.code ~= 0 then
        vim.notify("SOPS failed to edit file: " .. (out.stderr or ""), vim.log.levels.WARN)
        return
      end

      if not is_autocmd then
          vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(out.stdout, "\n", { plain = true }))
      end

      -- NOTE the 'modified' flag is reset AFTER executing the BufReadPost
      if is_autocmd then
          vim.api.nvim_exec_autocmds("BufReadPost", {
            buffer = bufnr,
          })
      end
    end)
  end)
end


---@param opts table
M.setup = function(opts)
  opts = opts or {}
end

return M
