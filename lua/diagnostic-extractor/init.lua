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

---Get diagnostic under cursor
---@return vim.Diagnostic?
local function get_cursor_diagnostic()
	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_row = cursor[1] - 1 -- Convert to 0-based
	local cursor_col = cursor[2]

	local diagnostics = vim.diagnostic.get(bufnr, {
		lnum = cursor_row,
	})

	-- Find diagnostic that spans cursor position
	for _, diagnostic in ipairs(diagnostics) do
		local start_col = diagnostic.col
		local end_col = diagnostic.end_col or diagnostic.col

		if cursor_col >= start_col and cursor_col <= end_col then
			return diagnostic
		end
	end

	-- If no exact match, return any diagnostic on the line
	return diagnostics[1]
end

function M.generate_prompt(template_name)
	local diagnostic = get_cursor_diagnostic()
	if not diagnostic then
		error("No diagnostic under cursor")
	end

	local data = M.extract()

	-- Find the index of our cursor diagnostic in the full list
	local diagnostic_index
	for i, d in ipairs(data.diagnostics) do
		if d.range.start.row == diagnostic.lnum and d.range.start.col == diagnostic.col then
			diagnostic_index = i
			break
		end
	end

	if not diagnostic_index then
		error("Failed to find cursor diagnostic in extracted data")
	end

	local manager = require("diagnostic-extractor.template").get_manager()
	local template = manager:get_template(template_name)
	if not template then
		error(string.format("Template '%s' not found", template_name))
	end

	return manager:render(template, {
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

		local prompt = M.generate_prompt(template)
		vim.fn.setreg("+", prompt)
		vim.notify("Copied diagnostic prompt to clipboard!")
	end, {
		nargs = "?",
		complete = function()
			return vim.tbl_keys(require("diagnostic-extractor.template").get_templates())
		end,
	})

	-- vim.api.nvim_create_user_command("DiagnosticPrompt", function(opts)
	-- 	local args = vim.split(opts.args, "%s+")
	-- 	local template = args[1] or "fix"
	-- 	local index = tonumber(args[2]) or 1
	--
	-- 	local prompt = M.generate_prompt(template, index)
	-- 	vim.fn.setreg("+", prompt)
	-- 	vim.notify(string.format("Copied %s prompt to clipboard (diagnostic #%d)!", template, index))
	-- end, {
	-- 	nargs = "*",
	-- 	complete = function()
	-- 		return vim.tbl_keys(require("diagnostic-extractor.template").get_templates())
	-- 	end,
	-- })
end

-- Initialize plugin
local function init()
	create_commands()
end

init()

return M
