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
		},
		filters = {
			join = function(value, sep)
				if type(value) ~= "table" then
					return tostring(value or "")
				end
				return table.concat(value, sep or ", ")
			end,
			length = function(value)
				if type(value) ~= "table" then
					return 0
				end
				return #value
			end,
			default = function(value, default_value)
				return value ~= nil and value or default_value
			end,
		},
	}, { __index = Engine })
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

	-- Handle number literals
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
	if var == "nil" or var == "null" then
		return nil
	end

	-- Handle table access
	local parts = vim.split(var, "%.", { plain = false })
	local value = context

	for _, part in ipairs(parts) do
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

---Apply filters to a value
---@param value any
---@param filter_str string
---@return any
function Engine:apply_filters(value, filter_str)
	local parts = vim.split(filter_str:gsub("^%s*(.-)%s*$", "%1"), " ")
	local filter_name = parts[1]
	local filter = self.filters[filter_name]

	if not filter then
		error(string.format("Unknown filter: %s", filter_name))
	end

	-- Remove filter name from parts to get args
	table.remove(parts, 1)
	return filter(value, unpack(parts))
end

---Evaluate a condition
---@param condition string
---@param context table
---@return boolean
function Engine:eval_condition(condition, context)
	local value = self:resolve_var(condition, context)
	return value ~= nil and value ~= false and value ~= ""
end

---Handle control blocks
---@param template string
---@param context table
---@return string
function Engine:handle_blocks(template, context)
	local result = template

	-- Handle if blocks
	while true do
		local if_start, if_end = result:find(self.patterns.if_start)
		if not if_start then
			break
		end

		local block_end = result:find(self.patterns.if_end, if_end)
		if not block_end then
			error("Unclosed if block")
		end

		local condition = result:match(self.patterns.if_start, if_start)
		local content = result:sub(if_end + 1, block_end - 1)

		local should_render = self:eval_condition(condition, context)
		local replacement = should_render and self:render(content, context) or ""

		result = result:sub(1, if_start - 1) .. replacement .. result:sub(block_end + 4)
	end

	-- Handle for blocks
	while true do
		local for_start, for_end = result:find(self.patterns.for_start)
		if not for_start then
			break
		end

		local block_end = result:find(self.patterns.for_end, for_end)
		if not block_end then
			error("Unclosed for block")
		end

		local var, collection = result:match(self.patterns.for_start, for_start)
		local content = result:sub(for_end + 1, block_end - 1)

		local items = self:resolve_var(collection, context)
		local replacements = {}

		if type(items) == "table" then
			for i, item in ipairs(items) do
				local loop_ctx = vim.tbl_extend("force", {}, context, {
					[var] = item,
					loop = {
						index = i,
						first = i == 1,
						last = i == #items,
					},
				})
				table.insert(replacements, self:render(content, loop_ctx))
			end
		end

		result = result:sub(1, for_start - 1) .. table.concat(replacements) .. result:sub(block_end + 6)
	end

	return result
end

---Render template with context
---@param template string
---@param context table
---@return string
function Engine:render(template, context)
	-- First handle control structures
	local result = self:handle_blocks(template, context)

	-- Then replace variables
	result = result:gsub(self.patterns.var, function(expr)
		local var_expr = expr:match("^%s*(.-)%s*$")
		local filter_pos = var_expr:find("|")
		local value

		if filter_pos then
			local var = var_expr:sub(1, filter_pos - 1)
			local filters = var_expr:sub(filter_pos + 1)
			value = self:resolve_var(var, context)

			for filter_expr in filters:gmatch("[^|]+") do
				value = self:apply_filters(value, filter_expr)
			end
		else
			value = self:resolve_var(var_expr, context)
		end

		if value == nil then
			return ""
		end
		if type(value) == "table" then
			return vim.inspect(value)
		end
		return tostring(value)
	end)

	return result
end

local M = {}
M.Engine = Engine
return M
