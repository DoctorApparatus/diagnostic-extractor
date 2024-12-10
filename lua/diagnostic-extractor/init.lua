---@mod diagnostic-extractor
---@brief [[
--- A Neovim plugin for extracting diagnostics with context and types
---@brief ]]

local extract = require("diagnostic-extractor.extract")
local templates = require("diagnostic-extractor.templates")

---@class Config
---@field context_lines integer Number of lines before and after diagnostic
---@field filters table<string,boolean> Filters for diagnostic severities

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
---@return table JSON-serializable diagnostic data
function M.extract()
	return extract.extract_diagnostics(M.config)
end

---Extract diagnostics and format as JSON
---@return string JSON-formatted diagnostic data
function M.extract_json()
	local data = M.extract()
	return vim.json.encode(data)
end

---Generate LLM prompt for diagnostic
---@param template_name string Name of the template to use
---@param diagnostic_index? integer Index of diagnostic to use (defaults to first)
---@return string prompt The generated prompt
function M.generate_prompt(template_name, diagnostic_index)
	diagnostic_index = diagnostic_index or 1

	local data = M.extract()
	if not data.diagnostics[diagnostic_index] then
		error(string.format("No diagnostic at index %d", diagnostic_index))
	end

	local ctx = {
		filename = data.filename,
		language = data.language,
		diagnostic = data.diagnostics[diagnostic_index],
	}

	return templates.generate_prompt(template_name, ctx)
end

-- Create plugin commands
local function create_commands()
	-- Command to extract diagnostics to JSON
	vim.api.nvim_create_user_command("DiagnosticExtract", function()
		local json = M.extract_json()

		-- Format JSON if possible
		local formatted_json = json
		local ok, formatted = pcall(function()
			return vim.fn.system({ "jq", "." }, json)
		end)
		if ok and vim.v.shell_error == 0 then
			formatted_json = formatted
		end

		-- Open in new buffer
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(formatted_json, "\n"))
		vim.api.nvim_command("vsplit")
		vim.api.nvim_win_set_buf(0, bufnr)
		vim.bo[bufnr].filetype = "json"
	end, {})

	-- Command to generate LLM prompt
	vim.api.nvim_create_user_command("DiagnosticPrompt", function(opts)
		local args = vim.split(opts.args, "%s+")
		local template = args[1] or "fix"
		local index = tonumber(args[2]) or 1

		local prompt = M.generate_prompt(template, index)
		vim.fn.setreg("+", prompt)
		vim.notify(string.format("Copied %s prompt to clipboard (diagnostic #%d)!", template, index))
	end, {
		nargs = "*",
		complete = function()
			return vim.tbl_keys(templates.templates)
		end,
	})
end

-- Initialize the plugin
local function init()
	create_commands()
end

init()

return M
