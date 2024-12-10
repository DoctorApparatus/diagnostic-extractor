local M = {}

---Get type information using LSP if available
---@param bufnr integer
---@param row integer
---@param col integer
---@return TypeInfo?
function M.get_type_info(bufnr, row, col)
	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
	local type_info = nil

	for _, client in ipairs(clients) do
		-- Try to get hover information which often contains type info
		local params = {
			textDocument = vim.lsp.util.make_text_document_params(bufnr),
			position = { line = row, character = col },
		}

		local hover_result = client.request_sync("textDocument/hover", params, 1000, bufnr)
		if hover_result and hover_result.result then
			local contents = hover_result.result.contents
			if type(contents) == "table" then
				contents = contents.value or contents
			end

			-- Parse type information from hover response
			-- This is language-specific and would need careful parsing
			local type_str = M.extract_type_from_hover(contents)
			if type_str then
				type_info = {
					type = type_str,
					type_source = "lsp_hover",
				}

				-- For Rust, try to get trait information
				if client.name == "rust_analyzer" then
					local traits = M.get_rust_traits(client, bufnr, row, col)
					if traits then
						type_info.traits = traits
					end
				end

				break
			end
		end
	end

	return type_info
end

---Get symbol references using LSP
---@param bufnr integer
---@param row integer
---@param col integer
---@return SymbolReference?
function M.get_symbol_references(bufnr, row, col)
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
		position = { line = row, character = col },
	}

	-- First try to get symbol information
	local symbol_info = nil
	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })

	for _, client in ipairs(clients) do
		-- Get definition first
		local definition = client.request_sync("textDocument/definition", params, 1000, bufnr)

		if definition and definition.result then
			-- Get references
			local references =
				client.request_sync("textDocument/references", vim.lsp.util.make_position_params(0), 1000, bufnr)

			if references and references.result then
				-- Convert to our format
				local refs = {}
				for _, ref in ipairs(references.result) do
					table.insert(refs, {
						row = ref.range.start.line,
						col = ref.range.start.character,
					})
				end

				-- Try to get symbol kind/type through documentSymbol request
				local symbol_type, symbol_kind = M.get_symbol_type_and_kind(
					client,
					bufnr,
					definition.result[1].targetRange or definition.result[1].range
				)

				symbol_info = {
					name = vim.api.nvim_buf_get_text(bufnr, row, col, row, col + 1, {})[1] or "",
					type = symbol_type,
					kind = symbol_kind,
					definition_range = {
						start_row = definition.result[1].targetRange.start.line,
						start_col = definition.result[1].targetRange.start.character,
						end_row = definition.result[1].targetRange["end"].line,
						end_col = definition.result[1].targetRange["end"].character,
					},
					references = refs,
				}
				break
			end
		end
	end

	return symbol_info
end

---Extract type information from LSP hover response
---@param contents string|table
---@return string?
function M.extract_type_from_hover(contents)
	if type(contents) == "string" then
		-- Try to extract type information using common patterns
		local type_patterns = {
			-- Rust
			"^type: (.-)$",
			-- TypeScript
			"^const (.-):(.-)$",
			-- General
			"type: (.-)\n",
		}

		for _, pattern in ipairs(type_patterns) do
			local match = string.match(contents, pattern)
			if match then
				return match
			end
		end
	end
	return nil
end

---Get trait information for Rust
---@param client table LSP client
---@param bufnr integer
---@param row integer
---@param col integer
---@return string[]?
function M.get_rust_traits(client, bufnr, row, col)
	-- This would need to use rust-analyzer specific requests
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
		position = { line = row, character = col },
	}

	-- Note: This is a rust-analyzer specific request
	local traits = client.request_sync("rust-analyzer/resolveTraits", params, 1000, bufnr)
	if traits and traits.result then
		local trait_list = {}
		for _, trait in ipairs(traits.result) do
			table.insert(trait_list, trait.name)
		end
		return trait_list
	end
	return nil
end

return M
