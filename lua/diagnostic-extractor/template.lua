---@mod diagnostic-extractor.template
---@brief [[
---Template management for diagnostic extraction
---@brief ]]

local TemplateEngine = require("diagnostic-extractor.template_engine").Engine
local manager = nil

local M = {}

local default_templates = {
	fix = [[
DIAGNOSTIC REPORT
===============
Language: {{ language }}
File: {{ filename }}

ERROR DETAILS
------------
Error: {{ diagnostic.message }}
Code: {{ diagnostic.code }} 
Location: Line {{ diagnostic.range.start.row + 1 }}, Column {{ diagnostic.range.start.col + 1 }}
Severity: {{ diagnostic.severity_name }}
Source: {{ diagnostic.source }}

DETAILED ERROR
-------------
{{ diagnostic.user_data.lsp.data.rendered }}

CODE CONTEXT
-----------
{% for line in diagnostic.context.lines %}
{{ line }}
{% endfor %}

SYNTAX CONTEXT
-------------
Node Type: {{ diagnostic.context.treesitter.node_type }}
Parent Types: {{ diagnostic.context.treesitter.parent_types|join " -> " }}
Scope Type: {{ diagnostic.context.treesitter.scope.type }}
Scope Content:
{{ diagnostic.context.treesitter.scope.text }}

TASK
----
Please analyze this error and provide:
1. A clear explanation of the problem
2. The corrected code
3. Any best practices to prevent similar issues
]],
}

---Get global template manager
---@return TemplateEngine
function M.get_manager()
	if not manager then
		manager = TemplateEngine.new()

		-- Register default templates
		for name, source in pairs(default_templates) do
			manager.templates[name] = source -- Directly set template
		end
	end
	return manager
end

---Get available templates
---@return table<string,boolean>
function M.get_templates()
	local templates = {}
	for name, _ in pairs(default_templates) do
		templates[name] = true
	end
	return templates
end

function M.add_template(name, source, opts)
	opts = opts or {}

	-- Create manager if it doesn't exist
	if not manager then
		manager = TemplateEngine.new()
	end

	if manager.templates[name] and not opts.override then
		return false, string.format("Template '%s' already exists", name)
	end

	-- Verify template is valid
	local ok, err = pcall(function()
		manager:render(source, {}) -- Try rendering with empty context
	end)

	if not ok then
		return false, string.format("Invalid template: %s", err)
	end

	-- Store the template
	manager.templates[name] = source

	return true
end

return M
