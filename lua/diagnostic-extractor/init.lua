---@mod diagnostic-extractor
---@brief [[
--- A Neovim plugin for extracting diagnostics with context
---@brief ]]

local extract = require("diagnostic-extractor.extract")

---@class DiagnosticExtractor
local M = {}

---@type Config
local default_config = {
	context_lines = 2,
	include_virtual_text = true,
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
---@return DiagnosticContext[]
function M.extract()
	return extract.extract_diagnostics(M.config)
end

---Extract and format diagnostics into a string representation
---@return string
function M.format_diagnostics()
	local contexts = M.extract()
	local output = {}

	for _, ctx in ipairs(contexts) do
		-- Add diagnostic header
		table.insert(
			output,
			string.format(
				"### %s at line %d, col %d: %s",
				vim.diagnostic.severity[ctx.diagnostic.severity],
				ctx.position.row + 1,
				ctx.position.col + 1,
				ctx.diagnostic.message
			)
		)

		-- Add context lines
		for i, line in ipairs(ctx.lines) do
			local line_num = ctx.start_line + i
			local prefix = line_num == ctx.position.row and ">" or " "
			table.insert(output, string.format("%s %4d | %s", prefix, line_num + 1, line))
		end

		table.insert(output, "")
	end

	return table.concat(output, "\n")
end

return M
