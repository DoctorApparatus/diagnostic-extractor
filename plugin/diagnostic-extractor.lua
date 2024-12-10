if vim.g.loaded_diagnostic_extractor then
	return
end
vim.g.loaded_diagnostic_extractor = true

-- Create user commands
vim.api.nvim_create_user_command("DiagnosticExtract", function()
	local formatted = require("diagnostic-extractor").format_diagnostics()
	-- Open in new buffer
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(formatted, "\n"))
	vim.api.nvim_command("vsplit")
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.bo[bufnr].filetype = "markdown"
end, {})
