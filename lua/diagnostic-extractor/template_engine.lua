---@class TemplateEngine
---@field private patterns table<string,string>
---@field private filters table<string,fun(value:any,...):any>
local Engine = {}

---Create a new template engine instance
---@return TemplateEngine
function Engine.new()
	return setmetatable({
		patterns = {
			var = "{{%s*([^}]+)%s*}}",
			if_start = "{%%%s*if%s+([^}]+)%s*%%}",
			if_end = "{%%%s*endif%s*%%}",
			for_start = "{%%%s*for%s+([^}]+)%s+in%s+([^}]+)%s*%%}",
			for_end = "{%%%s*endfor%s*%%}",
			filter = "([^|]+)|%s*([^:]+)(:?%s*[^}]*)",
		},
		filters = {
			join = function(value, sep)
				if type(value) ~= "table" then
					return tostring(value)
				end
				return table.concat(value, sep or ", ")
			end,
			length = function(value)
				if type(value) ~= "table" then
					return 0
				end
				local count = 0
				for _ in pairs(value) do
					count = count + 1
				end
				return count
			end,
			escape_xml = function(value)
				if type(value) ~= "string" then
					value = tostring(value)
				end
				local replacements = {
					["&"] = "&amp;",
					["<"] = "&lt;",
					[">"] = "&gt;",
					['"'] = "&quot;",
					["'"] = "&apos;",
				}
				return value:gsub("[&<>\"']", replacements)
			end,
		},
	}, { __index = Engine })
end

---Apply filters to a value
---@param value any
---@param filter_str string
---@return any
function Engine:apply_filters(value, filter_str)
	-- Split filter name and arguments
	local filter_name, args_str = filter_str:match("^([^%s]+)%s*(.*)$")
	local filter = self.filters[filter_name]
	if not filter then
		error(string.format("Unknown filter: %s", filter_name))
	end

	-- Parse filter arguments if they exist
	local filter_args = {}
	if args_str and args_str ~= "" then
		-- Handle quoted strings and basic values
		for arg in args_str:gmatch('"([^"]*)"') do
			table.insert(filter_args, arg)
		end
		if #filter_args == 0 then
			for arg in args_str:gmatch("([^,]+)") do
				local cleaned = arg:match("^%s*(.-)%s*$")
				table.insert(filter_args, cleaned)
			end
		end
	end

	return filter(value, unpack(filter_args))
end

---Resolve variable from context, including filters
---@param expr string
---@param context table
---@return any
function Engine:resolve_expr(expr, context)
	-- Check for filters
	local var_expr = expr
	local filters = {}

	-- Extract filters if present
	for value, filter, args in expr:gmatch(self.patterns.filter) do
		var_expr = value:match("^%s*(.-)%s*$")
		table.insert(filters, filter .. args)
	end

	-- Resolve the variable
	local value = self:resolve_var(var_expr, context)

	-- Apply filters in order
	for _, filter in ipairs(filters) do
		value = self:apply_filters(value, filter)
	end

	return value
end

---Resolve variable from context
---@param var string
---@param context table
---@return any
function Engine:resolve_var(var, context)
	-- Handle literal values
	if var:match("^'.*'$") or var:match('^".*"$') then
		return var:sub(2, -2)
	end

	-- Handle simple expressions
	if var:match("^%d+$") then
		return tonumber(var)
	end

	-- Handle boolean literals
	if var == "true" then
		return true
	end
	if var == "false" then
		return false
	end

	-- Handle nil
	if var == "nil" or var == "null" then
		return nil
	end

	-- Handle table access with dots
	local parts = vim.split(var, "%.", { plain = false })
	local value = context

	for _, part in ipairs(parts) do
		-- Handle array indexing
		local array_index = part:match("^(%d+)$")
		if array_index then
			part = tonumber(array_index)
		end

		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
		if value == nil then
			return nil
		end
	end

	return value
end

---Evaluate a condition
---@param condition string
---@param context table
---@return boolean
function Engine:eval_condition(condition, context)
	-- Handle basic comparisons
	local left, op, right = condition:match("(.+)%s*([=!]=)%s*(.+)")
	if left and op and right then
		local lval = self:resolve_expr(left, context)
		local rval = self:resolve_expr(right, context)
		if op == "==" then
			return lval == rval
		end
		if op == "!=" then
			return lval ~= rval
		end
	end

	-- Handle existence check
	local value = self:resolve_expr(condition, context)
	return value ~= nil and value ~= false and value ~= ""
end

---Handle if blocks in template
---@param template string
---@param context table
---@return string
function Engine:handle_if_blocks(template, context)
	local result = template
	local pattern = self.patterns.if_start .. "(.-)" .. self.patterns.if_end

	while true do
		local start, finish, condition, content = result:find(pattern)
		if not start then
			break
		end

		local should_render = self:eval_condition(condition, context)
		local replacement = should_render and content or ""
		result = result:sub(1, start - 1) .. replacement .. result:sub(finish + 1)
	end

	return result
end

---Handle for blocks in template
---@param template string
---@param context table
---@return string
function Engine:handle_for_blocks(template, context)
	local result = template
	local pattern = self.patterns.for_start .. "(.-)" .. self.patterns.for_end

	while true do
		local start, finish, var, collection, content = result:find(pattern)
		if not start then
			break
		end

		local items = self:resolve_expr(collection, context)
		local replacements = {}

		if type(items) == "table" then
			-- Handle both array-like and dictionary tables
			local is_array = #items > 0
			if is_array then
				for i, item in ipairs(items) do
					local loop_context = vim.tbl_extend("force", {}, context, {
						[var] = item,
						loop = {
							index = i,
							first = i == 1,
							last = i == #items,
						},
					})
					table.insert(replacements, self:render(content, loop_context))
				end
			else
				local i = 1
				local len = self.filters.length(items)
				for k, v in pairs(items) do
					local loop_context = vim.tbl_extend("force", {}, context, {
						[var] = { key = k, value = v },
						loop = {
							index = i,
							first = i == 1,
							last = i == len,
						},
					})
					table.insert(replacements, self:render(content, loop_context))
					i = i + 1
				end
			end
		end

		result = result:sub(1, start - 1) .. table.concat(replacements) .. result:sub(finish + 1)
	end

	return result
end

---Render template with context
---@param template string
---@param context table
---@return string
function Engine:render(template, context)
	local result = template

	-- Replace expressions with values
	result = result:gsub(self.patterns.var, function(expr)
		local value = self:resolve_expr(expr:match("^%s*(.-)%s*$"), context)
		if value == nil then
			return ""
		end
		if type(value) == "table" then
			return vim.inspect(value)
		end
		return tostring(value)
	end)

	-- Handle control structures
	result = self:handle_if_blocks(result, context)
	result = self:handle_for_blocks(result, context)

	return result
end

local M = {}
M.Engine = Engine

return M
