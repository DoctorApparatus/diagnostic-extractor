---@mod diagnostic-extractor
---@brief [[
--- A Neovim plugin for extracting diagnostics with context in JSON format
---@brief ]]

local extract = require("diagnostic-extractor.extract")

---@class DiagnosticExtractor
local M = {}

---@type Config
local default_config = {
	context_lines = 2,
	filters = {
		ERROR = true,
		WARN = true,
		INFO = true,
		HINT = true,
	},
}

---@type Config
M.config = default_config

---Setup the plugin
---@param opts? Config
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", default_config, opts or {})
end

---Extract diagnostics with context from current buffer
---@return string JSON string of diagnostic data
function M.extract_json()
	local data = extract.extract_diagnostics(M.config)
	return vim.json.encode(data)
end

return M
