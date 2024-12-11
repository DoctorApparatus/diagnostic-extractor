---@mod diagnostic-extractor
---@brief [[
---A Neovim plugin for extracting diagnostics with context
---@brief ]]

local M = {}

---@type ExtractionOptions
local default_config = {
	context_lines = 2,
	filters = {
		ERROR = true,
		WARN = true,
		INFO = true,
		HINT = true,
	},
	include_treesitter = true,
	include_types = true,
	include_symbols = true,
}

---@type ExtractionOptions
M.config = vim.deepcopy(default_config)

---Setup the plugin
---@param opts? ExtractionOptions
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", default_config, opts or {})
end

---Extract diagnostics from current buffer
---@param opts? ExtractionOptions
---@return ExtractionResult
function M.extract(opts)
	opts = vim.tbl_deep_extend("force", M.config, opts or {})
	return require("diagnostic-extractor.extract").extract_diagnostics(opts)
end

---Extract diagnostics as JSON
---@param opts? ExtractionOptions
---@return string
function M.extract_json(opts)
	return vim.json.encode(M.extract(opts))
end

---Generate diagnostic prompt
---@param template_name string
---@param diagnostic_index? integer
---@return string
function M.generate_prompt(template_name, diagnostic_index)
	diagnostic_index = diagnostic_index or 1

	local data = M.extract()
	if not data.diagnostics[diagnostic_index] then
		error(string.format("No diagnostic at index %d", diagnostic_index))
	end

	local manager = require("diagnostic-extractor.template").get_manager()
	return manager:render(template_name, {
		filename = data.filename,
		language = data.language,
		diagnostic = data.diagnostics[diagnostic_index],
	})
end

-- Create commands
local function create_commands()
	vim.api.nvim_create_user_command("DiagnosticExtract", function()
		local json = M.extract_json()
		local formatted = json

		-- Try to format with jq if available
		local ok, result = pcall(function()
			return vim.fn.system({ "jq", "." }, json)
		end)
		if ok and vim.v.shell_error == 0 then
			formatted = result
		end

		-- Open in new buffer
		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(formatted, "\n"))
		vim.api.nvim_command("vsplit")
		vim.api.nvim_win_set_buf(0, bufnr)
		vim.bo[bufnr].filetype = "json"
	end, {})

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
			return vim.tbl_keys(require("diagnostic-extractor.template").get_templates())
		end,
	})
end

-- Initialize plugin
local function init()
	create_commands()
end

init()

return M
