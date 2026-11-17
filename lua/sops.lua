---@class SopsModule
local M = {}

-- Saving runs inside BufWriteCmd, which must know the outcome before it returns
local SOPS_TIMEOUT_MS = 30000
-- `sops edit` exits with this code when the new content matches the file
local SOPS_EXIT_UNCHANGED = 200

---@param output string
---@return string[]
local split_output = function(output)
  local lines = vim.split(output, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines)
  end
  return lines
end

--- Runs `sops <subcommand> <format flags> <path>` for the buffer's file and waits for it.
---@param bufnr number
---@param subcommand string
---@param env table|nil
---@return vim.SystemCompleted
local run_sops = function(bufnr, subcommand, env)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local cmd = { "sops", subcommand }
  vim.list_extend(cmd, require("util").format_arguments(bufnr))
  table.insert(cmd, path)
  local result = vim.system(cmd, { cwd = vim.fs.dirname(path), env = env, text = true }):wait(SOPS_TIMEOUT_MS)
  return result
end

---@param bufnr number
---@param is_autocmd boolean Enable acwrite for encrypting again with autocmds
---@return boolean decrypted
M.sops_decrypt_buffer = function(bufnr, is_autocmd)
  local result = run_sops(bufnr, "decrypt")
  if result.code ~= 0 then
    vim.notify("SOPS failed to decrypt file: " .. vim.trim(result.stderr or ""), vim.log.levels.WARN)
    return false
  end

  if is_autocmd then
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, split_output(result.stdout))

  if is_autocmd then
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  end

  -- Run BufReadPost autocmds since the buffer contents have changed
  vim.api.nvim_exec_autocmds("BufReadPost", {
    buffer = bufnr,
  })
  return true
end

--- Writes the buffer to its file through `sops edit`, which keeps the file's data key and recipients.
--- Clears 'modified' only once SOPS has written the file.
---@param bufnr number
---@return boolean saved
local save_buffer = function(bufnr)
  local plugin_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
  local editor_script = vim.fs.joinpath(plugin_root, "scripts", "sops-editor.sh")

  if vim.fn.filereadable(editor_script) == 0 then
    vim.notify("SOPS editor script not found: " .. editor_script, vim.log.levels.ERROR)
    return false
  end

  local temp_file = vim.fn.tempname()
  local plaintext_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if vim.fn.writefile(plaintext_lines, temp_file) ~= 0 then
    vim.fn.delete(temp_file)
    vim.notify("Failed to write temp file", vim.log.levels.ERROR)
    return false
  end

  local result = run_sops(bufnr, "edit", {
    SOPS_EDITOR = editor_script,
    SOPS_NVIM_TEMP_FILE = temp_file,
  })
  vim.fn.delete(temp_file)

  if result.code ~= 0 and result.code ~= SOPS_EXIT_UNCHANGED then
    vim.notify("SOPS failed to save file: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
    return false
  end

  vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
  return true
end

---@param bufnr number
---@param is_autocmd boolean Save the buffer to its file instead of showing the file's ciphertext
---@return boolean encrypted
M.sops_encrypt_buffer = function(bufnr, is_autocmd)
  if is_autocmd then
    return save_buffer(bufnr)
  end

  local result = run_sops(bufnr, "encrypt")
  if result.code ~= 0 then
    vim.notify("SOPS failed to encrypt file: " .. vim.trim(result.stderr or ""), vim.log.levels.WARN)
    return false
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, split_output(result.stdout))
  return true
end

---@param opts table
M.setup = function(opts)
  opts = opts or {}
end

return M
