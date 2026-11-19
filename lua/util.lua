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

-- SOPS infers the store from the last extension only, which reads `.env.sops` as binary.
-- Neovim filetypes are not SOPS store names (`env` is `dotenv`) and vary with user config.
local EXTENSION_FORMATS = {
  env = "dotenv",
  ini = "ini",
  json = "json",
  yaml = "yaml",
  yml = "yaml",
}
local FILETYPE_FORMATS = {
  dosini = "ini",
  env = "dotenv",
  json = "json",
  yaml = "yaml",
}

--- Whether the file on disk is a SOPS binary store: a JSON document holding only `data` and `sops`.
--- SOPS writes YAML stores in block style, which never parses as JSON; a YAML store hand-rewritten
--- in JSON flow syntax with only a `data` key would read as binary, a case accepted as unrealistic.
---@param path string
---@return boolean
local is_binary_store = function(path)
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok or #content == 0 then
    return false
  end
  local decoded_ok, document = pcall(vim.json.decode, table.concat(content, "\n"))
  if not decoded_ok or type(document) ~= "table" or type(document.data) ~= "string" then
    return false
  end
  local keys = vim.tbl_keys(document)
  local is_binary = #keys == 2 and document.sops ~= nil and vim.startswith(document.data, SOPS_MARKER_BYTES)
  return is_binary
end

--- The extension left once `sops` parts are removed (`.env.sops`, `x.sops.yaml`), else the filetype.
--- A binary store on disk wins over a dotenv, YAML or INI name, since its name only describes the plaintext.
--- Returns nil when neither names a store, leaving SOPS to infer it from the path.
---@param bufnr number
---@return string|nil
M.store_format = function(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local basename = vim.fs.basename(path)
  local parts = vim.tbl_filter(function(part)
    return part ~= "" and part ~= "sops"
  end, vim.split(basename, ".", { plain = true }))
  -- A lone part is an extension only in a dotfile name (`.env.sops`), not in `secrets.sops`
  local has_extension = #parts > 1 or (#parts == 1 and vim.startswith(basename, "."))
  local extension = has_extension and parts[#parts] or ""
  local format = EXTENSION_FORMATS[extension:lower()] or FILETYPE_FORMATS[vim.bo[bufnr].filetype]
  -- A JSON store holding only `data` looks the same as a binary store, so a JSON name keeps JSON
  if format ~= "json" and is_binary_store(path) then
    format = "binary"
  end
  return format
end

--- `--input-type` and `--output-type` for the buffer's store, or nothing when it is unknown.
---@param bufnr number
---@return string[]
M.format_arguments = function(bufnr)
  local format = M.store_format(bufnr)
  if not format then
    return {}
  end
  return { "--input-type", format, "--output-type", format }
end

---@return boolean
M.is_auto_transform_enabled = function()
  if vim.b.sops_auto_transform ~= nil then
    return vim.b.sops_auto_transform
  end
  return vim.g.sops_auto_transform == true
end

return M
