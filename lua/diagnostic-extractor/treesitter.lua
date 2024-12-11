---@mod diagnostic-extractor.treesitter
---@brief [[
---Treesitter analysis functionality
---@brief ]]

local M = {}

---Options for getting position context
---@class ContextOptions
---@field max_parents integer? Maximum number of parent nodes to include
---@field include_types boolean? Include type information
---@field include_symbols boolean? Include symbol information

---Get parent node types
---@param node TSNode
---@param max_parents? integer
---@return string[]
local function get_parent_types(node, max_parents)
	max_parents = max_parents or 5
	local types = {}
	local current = node
	local count = 0

	while current and count < max_parents do
		local parent = current:parent()
		if not parent then
			break
		end
		table.insert(types, parent:type())
		current = parent
		count = count + 1
	end

	return types
end

---Find containing scope node
---@param node TSNode
---@return TSNode?
local function find_scope_node(node)
	local scope_types = {
		function_definition = true,
		method_definition = true,
		class_definition = true,
		module = true,
		block = true,
	}

	local current = node
	while current do
		if scope_types[current:type()] then
			return current
		end
		current = current:parent()
	end
	return nil
end

---Get scope information
---@param scope_node TSNode
---@param bufnr integer
---@return TreesitterScope
local function get_scope_info(scope_node, bufnr)
	local start_row, start_col, end_row, end_col = scope_node:range()

	return {
		type = scope_node:type(),
		text = vim.treesitter.get_node_text(scope_node, bufnr),
		range = {
			start = { row = start_row, col = start_col },
			["end"] = { row = end_row, col = end_col },
		},
	}
end

---Get treesitter context for position
---@param bufnr integer
---@param row integer
---@param col integer
---@param opts? ContextOptions
---@return TreesitterContext?
function M.get_position_context(bufnr, row, col, opts)
	opts = opts or {}

	-- Get parser and tree
	local parser = vim.treesitter.get_parser(bufnr)
	if not parser then
		return nil
	end

	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	-- Get node at position
	local root = tree:root()
	local node = root:named_descendant_for_range(row, col, row, col)
	if not node then
		return nil
	end

	-- Build context
	local result = {
		node_type = node:type(),
		parent_types = get_parent_types(node, opts.max_parents),
		scope = nil,
		type_info = nil,
		symbol_info = nil,
	}

	-- Get scope information
	local scope_node = find_scope_node(node)
	if scope_node then
		result.scope = get_scope_info(scope_node, bufnr)
	end

	-- Get type information if requested
	if opts.include_types then
		result.type_info = require("diagnostic-extractor.lsp").get_type_info(bufnr, row, col)
	end

	-- Get symbol information if requested
	if opts.include_symbols then
		result.symbol_info = require("diagnostic-extractor.lsp").get_symbol_info(bufnr, row, col)
	end

	return result
end

return M
