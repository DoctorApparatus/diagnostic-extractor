---@mod diagnostic-extractor.lsp
---@brief [[
---LSP integration functionality
---@brief ]]

local M = {}

---Get type information for position
---@param bufnr integer
---@param row integer
---@param col integer
---@return TypeInfo?
function M.get_type_info(bufnr, row, col)
	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })

	for _, client in ipairs(clients) do
		local params = {
			textDocument = vim.lsp.util.make_text_document_params(bufnr),
			position = { line = row, character = col },
		}

		-- Try hover request first
		local hover = client.request_sync("textDocument/hover", params, 1000, bufnr)
		if hover and hover.result then
			local type_info = M.parse_hover_type(hover.result.contents)
			if type_info then
				return type_info
			end
		end
	end

	return nil
end

---Get symbol information for position
---@param bufnr integer
---@param row integer
---@param col integer
---@return SymbolInfo?
function M.get_symbol_info(bufnr, row, col)
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
		position = { line = row, character = col },
	}

	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })

	for _, client in ipairs(clients) do
		-- Try to get definition and references together
		local results = M.get_symbol_locations(client, bufnr, params)
		if results then
			return M.build_symbol_info(client, bufnr, row, col, results)
		end
	end

	return nil
end

---Get symbol locations from LSP
---@param client table LSP client
---@param bufnr integer
---@param params table
---@return table?
function M.get_symbol_locations(client, bufnr, params)
	-- Get definition first
	local definition = client.request_sync("textDocument/definition", params, 1000, bufnr)
	if not (definition and definition.result and definition.result[1]) then
		return nil
	end

	-- Then get references
	local references = client.request_sync("textDocument/references", params, 1000, bufnr)
	if not (references and references.result) then
		return nil
	end

	return {
		definition = definition.result[1],
		references = references.result,
	}
end

---Build symbol information from LSP results
---@param client table
---@param bufnr integer
---@param row integer
---@param col integer
---@param results table
---@return SymbolInfo
function M.build_symbol_info(client, bufnr, row, col, results)
	return {
		name = M.get_symbol_name(bufnr, row, col),
		type = M.get_symbol_type(client, bufnr, results.definition),
		kind = M.get_symbol_kind(results.definition),
		definition = M.convert_lsp_range(results.definition.targetRange),
		references = vim.tbl_map(function(ref)
			return {
				row = ref.range.start.line,
				col = ref.range.start.character,
			}
		end, results.references),
	}
end

---Parse type information from hover response
---@param contents string|table
---@return TypeInfo?
function M.parse_hover_type(contents)
	if type(contents) == "string" then
		-- Common patterns for type information
		local type_patterns = {
			-- Rust
			"^type: (.-)$",
			"^pub %w+ (.*): (.*)$",
			-- TypeScript
			"^const (.-):(.-)$",
			"^let (.-):(.-)$",
			-- General
			"type: (.-)\n",
			": (.-)\n",
		}

		for _, pattern in ipairs(type_patterns) do
			local match = string.match(contents, pattern)
			if match then
				return {
					type = match,
					source = "hover",
				}
			end
		end
	elseif type(contents) == "table" and contents.kind == "markdown" then
		return M.parse_hover_type(contents.value)
	end
	return nil
end

---Get symbol name from position
---@param bufnr integer
---@param row integer
---@param col integer
---@return string
function M.get_symbol_name(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	if not line then
		return ""
	end

	-- Find word boundaries
	local start_col = col
	while start_col > 0 and line:sub(start_col, start_col):match("[%w_]") do
		start_col = start_col - 1
	end

	local end_col = col
	while end_col <= #line and line:sub(end_col, end_col):match("[%w_]") do
		end_col = end_col + 1
	end

	return line:sub(start_col + 1, end_col - 1)
end

---Get symbol type from definition
---@param client table LSP client
---@param bufnr integer
---@param definition table
---@return string?
function M.get_symbol_type(client, bufnr, definition)
	local params = {
		textDocument = {
			uri = definition.uri or definition.targetUri,
		},
		position = definition.range.start or definition.targetRange.start,
	}

	local symbol = client.request_sync("textDocument/hover", params, 1000, bufnr)
	if symbol and symbol.result then
		local type_info = M.parse_hover_type(symbol.result.contents)
		if type_info then
			return type_info.type
		end
	end
	return nil
end

---Get symbol kind from definition
---@param definition table
---@return string?
function M.get_symbol_kind(definition)
	local kinds = {
		[1] = "File",
		[2] = "Module",
		[3] = "Namespace",
		[4] = "Package",
		[5] = "Class",
		[6] = "Method",
		[7] = "Property",
		[8] = "Field",
		[9] = "Constructor",
		[10] = "Enum",
		[11] = "Interface",
		[12] = "Function",
		[13] = "Variable",
		[14] = "Constant",
		[15] = "String",
		[16] = "Number",
		[17] = "Boolean",
		[18] = "Array",
		[19] = "Object",
		[20] = "Key",
		[21] = "Null",
		[22] = "EnumMember",
		[23] = "Struct",
		[24] = "Event",
		[25] = "Operator",
		[26] = "TypeParameter",
	}
	return kinds[definition.kind]
end

---Convert LSP range to internal range format
---@param range table
---@return DiagnosticRange
function M.convert_lsp_range(range)
	return {
		start = {
			row = range.start.line,
			col = range.start.character,
		},
		["end"] = {
			row = range["end"].line,
			col = range["end"].character,
		},
	}
end

return M
