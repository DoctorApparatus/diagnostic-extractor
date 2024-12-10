local M = {}

---Get a list of parent node types
---@param node TSNode Current node
---@param max_parents? integer Maximum number of parents to include
---@return string[] parent_types
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

---Find the smallest containing scope (e.g., function, class, block)
---@param node TSNode Starting node
---@return TSNode|nil scope_node
local function find_containing_scope(node)
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

---Get treesitter context for a position
---@param bufnr integer Buffer number
---@param row integer 0-based row number
---@param col integer 0-based column number
---@return TreesitterContext|nil
function M.get_position_context(bufnr, row, col)
	local parser = vim.treesitter.get_parser(bufnr)
	if not parser then
		return nil
	end

	local tree = parser:parse()[1]
	if not tree then
		return nil
	end

	local root = tree:root()
	local node = root:named_descendant_for_range(row, col, row, col)
	if not node then
		return nil
	end

	-- Get containing scope
	local scope_node = find_containing_scope(node)
	local scope_text, scope_type
	if scope_node then
		scope_text = vim.treesitter.get_node_text(scope_node, bufnr)
		scope_type = scope_node:type()
	end

	return {
		node_type = node:type(),
		parent_types = get_parent_types(node),
		scope_text = scope_text,
		scope_type = scope_type,
	}
end

return M
