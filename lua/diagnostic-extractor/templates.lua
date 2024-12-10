local template_engine = require("diagnostic-extractor.template_engine")

local M = {}

---@type table<string,string>
M.templates = {
	-- Fix template focused on solving the issue
	fix = [[
DIAGNOSTIC REPORT
===============
Language: {{ language }}
File: {{ filename }}

ERROR DETAILS
------------
Message: {{ diagnostic.diagnostic.message }}
Location: Line {{ diagnostic.position.row + 1 }}, Column {{ diagnostic.position.col + 1 }}
Severity: {{ diagnostic.diagnostic.severity_name }}
{% if diagnostic.diagnostic.code %}Code: {{ diagnostic.diagnostic.code }}{% endif %}
{% if diagnostic.diagnostic.source %}Source: {{ diagnostic.diagnostic.source }}{% endif %}

CODE CONTEXT
-----------
{% for line in diagnostic.lines %}
{{ loop.first ? "..." : "" }}{{ diagnostic.position.row + 1 == diagnostic.start_line + loop.index - 1 ? ">" : " " }} {{ diagnostic.start_line + loop.index }}: {{ line }}{{ loop.last ? "..." : "" }}
{% endfor %}

SYNTAX CONTEXT
-------------
Current Node: {{ diagnostic.treesitter.node_type }}
Syntax Path: {{ diagnostic.treesitter.parent_types|join " -> " }}
Scope: {{ diagnostic.treesitter.scope_type }}

{% if diagnostic.treesitter.type_info %}
TYPE INFORMATION
---------------
{% if diagnostic.treesitter.type_info.type %}Type: {{ diagnostic.treesitter.type_info.type }}{% endif %}
{% if diagnostic.treesitter.type_info.type_source %}Inferred From: {{ diagnostic.treesitter.type_info.type_source }}{% endif %}
{% if diagnostic.treesitter.type_info.traits %}Traits: {{ diagnostic.treesitter.type_info.traits|join ", " }}{% endif %}
{% endif %}

{% if diagnostic.treesitter.symbol_references %}
SYMBOL INFORMATION
----------------
Name: {{ diagnostic.treesitter.symbol_references.name }}
{% if diagnostic.treesitter.symbol_references.type %}Type: {{ diagnostic.treesitter.symbol_references.type }}{% endif %}
{% if diagnostic.treesitter.symbol_references.kind %}Kind: {{ diagnostic.treesitter.symbol_references.kind }}{% endif %}
Reference Count: {{ diagnostic.treesitter.symbol_references.references|length }}
{% endif %}

TASK
----
Please analyze this error and provide:
1. A clear explanation of the problem
2. The corrected code
3. Any best practices to prevent similar issues]],

	-- XML format for structured data
	xml = [[<?xml version="1.0" encoding="UTF-8"?>
<diagnostic-report>
  <metadata>
    <language>{{ language|escape_xml }}</language>
    <filename>{{ filename|escape_xml }}</filename>
    <timestamp>{{ timestamp }}</timestamp>
  </metadata>

  <error>
    <message>{{ diagnostic.diagnostic.message|escape_xml }}</message>
    <location>
      <line>{{ diagnostic.position.row + 1 }}</line>
      <column>{{ diagnostic.position.col + 1 }}</column>
    </location>
    <severity>{{ diagnostic.diagnostic.severity_name|escape_xml }}</severity>
    {% if diagnostic.diagnostic.code %}<code>{{ diagnostic.diagnostic.code|escape_xml }}</code>{% endif %}
    {% if diagnostic.diagnostic.source %}<source>{{ diagnostic.diagnostic.source|escape_xml }}</source>{% endif %}
  </error>

  <context>
    <lines start-line="{{ diagnostic.start_line + 1 }}" end-line="{{ diagnostic.end_line + 1 }}">
      {% for line in diagnostic.lines %}
      <line number="{{ diagnostic.start_line + loop.index }}"{% if diagnostic.position.row + 1 == diagnostic.start_line + loop.index %} current="true"{% endif %}>
        <![CDATA[{{ line }}\]\]>
      </line>
      {% endfor %}
    </lines>
  </context>

  <syntax-info>
    <node-type>{{ diagnostic.treesitter.node_type|escape_xml }}</node-type>
    <syntax-path>{{ diagnostic.treesitter.parent_types|join " -> "|escape_xml }}</syntax-path>
    <scope-type>{{ diagnostic.treesitter.scope_type|escape_xml }}</scope-type>
  </syntax-info>

  {% if diagnostic.treesitter.type_info %}
  <type-info>
    {% if diagnostic.treesitter.type_info.type %}<type>{{ diagnostic.treesitter.type_info.type|escape_xml }}</type>{% endif %}
    {% if diagnostic.treesitter.type_info.type_source %}<inference-source>{{ diagnostic.treesitter.type_info.type_source|escape_xml }}</inference-source>{% endif %}
    {% if diagnostic.treesitter.type_info.traits %}
    <traits>
      {% for trait in diagnostic.treesitter.type_info.traits %}
      <trait>{{ trait|escape_xml }}</trait>
      {% endfor %}
    </traits>
    {% endif %}
  </type-info>
  {% endif %}

  {% if diagnostic.treesitter.symbol_references %}
  <symbol-info>
    <name>{{ diagnostic.treesitter.symbol_references.name|escape_xml }}</name>
    {% if diagnostic.treesitter.symbol_references.type %}<type>{{ diagnostic.treesitter.symbol_references.type|escape_xml }}</type>{% endif %}
    {% if diagnostic.treesitter.symbol_references.kind %}<kind>{{ diagnostic.treesitter.symbol_references.kind|escape_xml }}</kind>{% endif %}
    <references count="{{ diagnostic.treesitter.symbol_references.references|length }}">
      {% for ref in diagnostic.treesitter.symbol_references.references %}
      <reference>
        <line>{{ ref.row + 1 }}</line>
        <column>{{ ref.col + 1 }}</column>
      </reference>
      {% endfor %}
    </references>
  </symbol-info>
  {% endif %}
</diagnostic-report>]],

	-- Minimal template focusing only on the essential information
	minimal = [[
{{ diagnostic.diagnostic.severity_name }}: {{ diagnostic.diagnostic.message }}
Location: Line {{ diagnostic.position.row + 1 }}, Column {{ diagnostic.position.col + 1 }}

{% for line in diagnostic.lines %}
{{ diagnostic.position.row + 1 == diagnostic.start_line + loop.index - 1 ? ">" : " " }} {{ line }}
{% endfor %}

Node: {{ diagnostic.treesitter.node_type }}
{% if diagnostic.treesitter.type_info and diagnostic.treesitter.type_info.type %}Type: {{ diagnostic.treesitter.type_info.type }}{% endif %}]],

	-- JSONL format for streaming processing
	jsonl = [[{"type": "metadata", "language": "{{ language }}", "filename": "{{ filename }}", "timestamp": {{ timestamp }} }
{"type": "error", "message": "{{ diagnostic.diagnostic.message }}", "severity": "{{ diagnostic.diagnostic.severity_name }}", "line": {{ diagnostic.position.row + 1 }}, "column": {{ diagnostic.position.col + 1 }}{% if diagnostic.diagnostic.code %}, "code": "{{ diagnostic.diagnostic.code }}"{% endif %}{% if diagnostic.diagnostic.source %}, "source": "{{ diagnostic.diagnostic.source }}"{% endif %}}
{% for line in diagnostic.lines %}{"type": "context", "line_number": {{ diagnostic.start_line + loop.index }}, "content": "{{ line|replace('"', '\\"') }}", "is_error_line": {{ diagnostic.position.row + 1 == diagnostic.start_line + loop.index - 1 }}}
{% endfor %}{"type": "syntax", "node_type": "{{ diagnostic.treesitter.node_type }}", "syntax_path": "{{ diagnostic.treesitter.parent_types|join " -> " }}", "scope_type": "{{ diagnostic.treesitter.scope_type }}"}
{% if diagnostic.treesitter.type_info %}{"type": "type_info"{% if diagnostic.treesitter.type_info.type %}, "type": "{{ diagnostic.treesitter.type_info.type }}"{% endif %}{% if diagnostic.treesitter.type_info.type_source %}, "inference_source": "{{ diagnostic.treesitter.type_info.type_source }}"{% endif %}{% if diagnostic.treesitter.type_info.traits %}, "traits": [{% for trait in diagnostic.treesitter.type_info.traits %}"{{ trait }}"{{ not loop.last ? "," : "" }}{% endfor %}]{% endif %}}{% endif %}
{% if diagnostic.treesitter.symbol_references %}{"type": "symbol_info", "name": "{{ diagnostic.treesitter.symbol_references.name }}"{% if diagnostic.treesitter.symbol_references.type %}, "type": "{{ diagnostic.treesitter.symbol_references.type }}"{% endif %}{% if diagnostic.treesitter.symbol_references.kind %}, "kind": "{{ diagnostic.treesitter.symbol_references.kind }}"{% endif %}, "reference_count": {{ diagnostic.treesitter.symbol_references.references|length }}, "references": [{% for ref in diagnostic.treesitter.symbol_references.references %}{"line": {{ ref.row + 1 }}, "column": {{ ref.col + 1 }}}{{ not loop.last ? "," : "" }}{% endfor %}]}{% endif %}]],
}

-- Create the template engine instance
local engine = template_engine.Engine.new()

---Generate prompt from a template
---@param template_name string
---@param ctx table Context containing diagnostic information
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

	-- Add timestamp if not present
	ctx.timestamp = ctx.timestamp or os.time()

	-- Handle errors gracefully
	local ok, result = pcall(engine.render, engine, template, ctx)
	if not ok then
		error(string.format("Failed to render template '%s': %s", template_name, result))
	end

	return result
end

---Add a new template
---@param name string Template name
---@param template string Template content
---@param override? boolean Whether to override existing template
function M.add_template(name, template, override)
	if M.templates[name] and not override then
		error(string.format("Template '%s' already exists. Use override=true to replace it.", name))
	end
	M.templates[name] = template
end

return M
