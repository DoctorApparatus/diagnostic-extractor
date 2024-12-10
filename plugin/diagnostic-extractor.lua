if vim.g.loaded_diagnostic_extractor then
	return
end
vim.g.loaded_diagnostic_extractor = true

-- Create user commands
vim.api.nvim_create_user_command("DiagnosticExtract", function()
	local json = require("diagnostic-extractor").extract_json()

	-- Open in new buffer
	local bufnr = vim.api.nvim_create_buf(false, true)

	-- Format JSON if possible
	local formatted_json = json
	local ok, formatted = pcall(function()
		return vim.fn.system({ "jq", "." }, json)
	end)
	if ok and vim.v.shell_error == 0 then
		formatted_json = formatted
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(formatted_json, "\n"))
	vim.api.nvim_command("vsplit")
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.bo[bufnr].filetype = "json"
end, {})
