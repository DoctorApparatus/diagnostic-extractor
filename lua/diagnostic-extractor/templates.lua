local template_engine = require("diagnostic-extractor.template_engine")

local M = {}

M.templates = {
	fix = [[
Language: {{ language }}
Error Details:
  Message: {{ diagnostic.diagnostic.message }}
  Location: Line {{ diagnostic.position.row + 1 }}, Column {{ diagnostic.position.col + 1 }}
  Severity: {{ diagnostic.diagnostic.severity_name }}
{% if diagnostic.diagnostic.source %}
  Source: {{ diagnostic.diagnostic.source }}
{% endif %}

Context:
{{ diagnostic.lines | join('\n') }}

AST Information:
  Node Type: {{ diagnostic.treesitter.node_type }}
  Parent Nodes: {{ diagnostic.treesitter.parent_types | join(' -> ') }}
  Scope Type: {{ diagnostic.treesitter.scope_type }}

{% if diagnostic.treesitter.type_info %}
Type Information:
  Type: {{ diagnostic.treesitter.type_info.type }}
{% if diagnostic.treesitter.type_info.traits %}
  Traits: {{ diagnostic.treesitter.type_info.traits | join(', ') }}
{% endif %}
{% endif %}

{% if diagnostic.treesitter.symbol_references %}
Symbol Information:
  Name: {{ diagnostic.treesitter.symbol_references.name }}
  Type: {{ diagnostic.treesitter.symbol_references.type }}
  Kind: {{ diagnostic.treesitter.symbol_references.kind }}
  References: {{ diagnostic.treesitter.symbol_references.references | length }}
{% endif %}
]],
}

local engine = template_engine.Engine.new()

---Generate prompt from a template
---@param template_name string
---@param ctx table
---@return string
function M.generate_prompt(template_name, ctx)
	local template = M.templates[template_name]
	if not template then
		error(string.format("Template '%s' not found", template_name))
	end

	return engine:render(template, ctx)
end

return M
