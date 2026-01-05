local M = {}

local SOPS_MARKER_BYTES = "ENC["

-- Use a better validation function, once sops has implemented validation https://github.com/getsops/sops/issues/437
---@param bufnr number
---@return boolean
M.is_sops_encrypted = function(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = vim.fn.join(lines, "\n")
  -- local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  return string.find(content, SOPS_MARKER_BYTES, 1, true) ~= nil
end

---@return boolean
M.is_auto_transform_enabled = function()
  if vim.b.sops_auto_transform ~= nil then
    return vim.b.sops_auto_transform
  end
  return vim.g.sops_auto_transform == true
end

return M
