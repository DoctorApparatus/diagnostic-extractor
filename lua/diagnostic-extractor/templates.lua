local template_engine = require("diagnostic-extractor.template_engine")

local M = {}

---@type table<string,string>
M.templates = {
	fix = [[
DIAGNOSTIC REPORT
===============
Language: {{ language|default "unknown" }}
File: {{ filename|default "unknown" }}

ERROR DETAILS
------------
Message: {{ diagnostic.diagnostic.message }}
Location: Line {{ diagnostic.position.row + 1 }}, Column {{ diagnostic.position.col + 1 }}
Severity: {{ diagnostic.diagnostic.severity_name }}
{% if diagnostic.diagnostic.code %}
Code: {{ diagnostic.diagnostic.code }}
{% endif %}
{% if diagnostic.diagnostic.source %}
Source: {{ diagnostic.diagnostic.source }}
{% endif %}

CODE CONTEXT
-----------
{% if diagnostic.lines %}
{% for line in diagnostic.lines %}
{{ diagnostic.position.row + 1 == diagnostic.start_line + loop.index - 1 ? ">" : " " }} {{ diagnostic.start_line + loop.index }}: {{ line }}
{% endfor %}
{% else %}
No code context available
{% endif %}

SYNTAX CONTEXT
-------------
Current Node: {{ diagnostic.treesitter.node_type|default "unknown" }}
Syntax Path: {{ diagnostic.treesitter.parent_types|join " -> "|default "unknown" }}
Scope: {{ diagnostic.treesitter.scope_type|default "unknown" }}

{% if diagnostic.treesitter.type_info %}
TYPE INFORMATION
---------------
Type: {{ diagnostic.treesitter.type_info.type|default "unknown" }}
{% if diagnostic.treesitter.type_info.type_source %}
Inferred From: {{ diagnostic.treesitter.type_info.type_source }}
{% endif %}
{% if diagnostic.treesitter.type_info.traits %}
Traits: {{ diagnostic.treesitter.type_info.traits|join ", " }}
{% endif %}
{% endif %}

{% if diagnostic.treesitter.symbol_references %}
SYMBOL INFORMATION
----------------
Name: {{ diagnostic.treesitter.symbol_references.name }}
{% if diagnostic.treesitter.symbol_references.type %}
Type: {{ diagnostic.treesitter.symbol_references.type }}
{% endif %}
{% if diagnostic.treesitter.symbol_references.kind %}
Kind: {{ diagnostic.treesitter.symbol_references.kind }}
{% endif %}
Reference Count: {{ diagnostic.treesitter.symbol_references.references|length }}
{% endif %}

TASK
----
Please analyze this error and provide:
1. A clear explanation of the problem
2. The corrected code
3. Any best practices to prevent similar issues]],
}

---Generate prompt from a template
---@param template_name string
---@param ctx table
---@return string
function M.generate_prompt(template_name, ctx)
	local template = M.templates[template_name]
	if not template then
		error(
			string.format(
				"Template '%s' not found. Available templates: %s",
				template_name,
				table.concat(vim.tbl_keys(M.templates), ", ")
			)
		)
	end

	-- Ensure all required fields exist
	ctx = vim.tbl_deep_extend("keep", ctx, {
		language = "unknown",
		filename = "unknown",
		diagnostic = {
			diagnostic = {
				message = "",
				severity_name = "UNKNOWN",
			},
			position = {
				row = 0,
				col = 0,
			},
			start_line = 0,
			end_line = 0,
			lines = {},
			treesitter = {
				node_type = "unknown",
				parent_types = {},
				scope_type = "unknown",
			},
		},
	})

	local ok, result = pcall(template_engine.render, template_engine, template, ctx)
	if not ok then
		error(string.format("Failed to render template '%s': %s", template_name, result))
	end

	return result
end

return M
