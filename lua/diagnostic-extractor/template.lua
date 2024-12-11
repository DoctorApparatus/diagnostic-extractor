---@mod diagnostic-extractor.template
---@brief [[
---Template management for diagnostic extraction
---@brief ]]

local TemplateManager = require("diagnostic-extractor.template_engine").TemplateManager

-- Single template manager instance
local manager = nil

local M = {}

---Default diagnostic analysis template
local default_templates = {
	fix = [[
DIAGNOSTIC REPORT
===============
Language: {{ language|default "unknown" }}
File: {{ filename|default "unknown" }}

ERROR DETAILS
------------
Message: {{ diagnostic.diagnostic.message }}
Location: Line {{ diagnostic.range.start.row + 1 }}, Column {{ diagnostic.range.start.col + 1 }}
Severity: {{ diagnostic.severity_name }}
{% if diagnostic.code %}
Code: {{ diagnostic.code }}
{% endif %}
{% if diagnostic.source %}
Source: {{ diagnostic.source }}
{% endif %}

CODE CONTEXT
-----------
{% if diagnostic.context.lines %}
{% for line in diagnostic.context.lines %}
{{ diagnostic.range.start.row + 1 == diagnostic.context.start_line + loop.index - 1 ? ">" : " " }} {{ diagnostic.context.start_line + loop.index }}: {{ line }}
{% endfor %}
{% else %}
No code context available
{% endif %}

SYNTAX CONTEXT
-------------
{% if diagnostic.context.treesitter %}
Current Node: {{ diagnostic.context.treesitter.node_type|default "unknown" }}
Syntax Path: {{ diagnostic.context.treesitter.parent_types|join " -> "|default "unknown" }}
{% if diagnostic.context.treesitter.scope %}
Scope: {{ diagnostic.context.treesitter.scope.type|default "unknown" }}
{% endif %}

{% if diagnostic.context.treesitter.type_info %}
TYPE INFORMATION
---------------
Type: {{ diagnostic.context.treesitter.type_info.type|default "unknown" }}
{% if diagnostic.context.treesitter.type_info.source %}
Inferred From: {{ diagnostic.context.treesitter.type_info.source }}
{% endif %}
{% if diagnostic.context.treesitter.type_info.traits %}
Traits: {{ diagnostic.context.treesitter.type_info.traits|join ", " }}
{% endif %}
{% endif %}

{% if diagnostic.context.treesitter.symbol_info %}
SYMBOL INFORMATION
----------------
Name: {{ diagnostic.context.treesitter.symbol_info.name }}
{% if diagnostic.context.treesitter.symbol_info.type %}
Type: {{ diagnostic.context.treesitter.symbol_info.type }}
{% endif %}
{% if diagnostic.context.treesitter.symbol_info.kind %}
Kind: {{ diagnostic.context.treesitter.symbol_info.kind }}
{% endif %}
Reference Count: {{ diagnostic.context.treesitter.symbol_info.references|length }}
{% endif %}
{% endif %}

TASK
----
Please analyze this error and provide:
1. A clear explanation of the problem
2. The corrected code
3. Any best practices to prevent similar issues
]],
}

---Get global template manager
---@return TemplateManager
function M.get_manager()
	if not manager then
		manager = TemplateManager.new()

		-- Register default templates
		for name, source in pairs(default_templates) do
			local ok, err = manager:register(name, source)
			if not ok then
				error(string.format("Failed to register template '%s': %s", name, err))
			end
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

---Add a new template
---@param name string Template name
---@param source string Template source
---@param opts? {override?: boolean}
---@return boolean success
---@return string? error
function M.add_template(name, source, opts)
	return M.get_manager():register(name, source, opts)
end

return M
