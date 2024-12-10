local M = {}

---@class TemplateEngine
---@field private patterns table<string,string>
local Engine = {}

function Engine.new()
	return setmetatable({
		patterns = {
			var = "{{%s*([^}]+)%s*}}",
			if_start = "{%%%s*if%s+([^}]+)%s*%%}",
			if_end = "{%%%s*endif%s*%%}",
			for_start = "{%%%s*for%s+([^}]+)%s*%%}",
			for_end = "{%%%s*endfor%s*%%}",
		},
	}, { __index = Engine })
end

---Render template with context
---@param template string
---@param context table
---@return string
function Engine:render(template, context)
	local result = template

	-- Replace simple variables
	result = result:gsub(self.patterns.var, function(var)
		local value = self:resolve_var(var:match("^%s*(.-)%s*$"), context)
		if type(value) == "table" then
			return vim.inspect(value)
		end
		return tostring(value or "")
	end)

	-- Handle if statements
	result = self:handle_if_blocks(result, context)

	-- Handle for loops
	result = self:handle_for_blocks(result, context)

	return result
end

---Resolve variable from context
---@param var string
---@param context table
---@return any
function Engine:resolve_var(var, context)
	local parts = vim.split(var, ".", { plain = true })
	local value = context

	for _, part in ipairs(parts) do
		if type(value) ~= "table" then
			return nil
		end
		value = value[part]
	end

	return value
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

		local value = self:resolve_var(condition, context)
		local replacement = value and content or ""
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
		local start, finish, iterator, content = result:find(pattern)
		if not start then
			break
		end

		local var, collection = iterator:match("(%w+)%s+in%s+(.+)")
		local items = self:resolve_var(collection, context)

		if type(items) == "table" then
			local replacements = {}
			for _, item in ipairs(items) do
				local item_context = vim.tbl_extend("force", {}, context, { [var] = item })
				table.insert(replacements, self:render(content, item_context))
			end
			result = result:sub(1, start - 1) .. table.concat(replacements) .. result:sub(finish + 1)
		else
			result = result:sub(1, start - 1) .. result:sub(finish + 1)
		end
	end

	return result
end

M.Engine = Engine
return M
