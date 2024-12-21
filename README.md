# diagnostic-extractor.nvim

A Neovim plugin that extracts diagnostic information with rich context to help
with debugging and troubleshooting.
The plugin captures diagnostics from LSP servers, linters, and other sources
along with relevant code context, treesitter syntax information, and optional
type information.

## Features

- Extracts diagnostic messages with surrounding code context
- Captures treesitter syntax information for better context
- Retrieves type information and symbol references when available through LSP
- Generates structured JSON output for programmatic use
- Creates formatted prompts for LLM assistance 
- Supports filtering by diagnostic severity
- Customizable context size and templates

## Requirements

- Neovim >= 0.8.0
- treesitter (for syntax context)
- LSP server(s) (optional, for enhanced type information)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "username/diagnostic-extractor.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  config = true,
  event = "LspAttach", -- or another event of your choice
}
```

## Configuration

```lua
require("diagnostic-extractor").setup({
  -- Number of context lines to include before and after the diagnostic
  context_lines = 2,
  
  -- Filter which diagnostic severities to include
  filters = {
    ERROR = true,
    WARN = true,
    INFO = true,
    HINT = true,
  },
})
```

## Usage

### Commands

- `:DiagnosticExtract` - Extract diagnostics from current buffer and display as
  formatted JSON
- `:DiagnosticPrompt [template] [index]` - Generate a prompt using the specified
  template for the diagnostic at index

### Lua API

```lua
-- Get extracted diagnostic data
local data = require("diagnostic-extractor").extract()

-- Get JSON-formatted diagnostic data
local json = require("diagnostic-extractor").extract_json()

-- Generate a prompt for the first diagnostic using the "fix" template
local prompt = require("diagnostic-extractor").generate_prompt("fix", 1)
```

### Example Output

```json
{
  "filename": "src/main.rs",
  "language": "rust",
  "diagnostics": [
    {
      "diagnostic": {
        "severity": 1,
        "severity_name": "ERROR",
        "message": "cannot find type `Strign` in this scope",
        "source": "rustc",
        "code": "E0412"
      },
      "lines": [
        "fn main() {",
        "    let x: Strign = \"Hello\";",
        "    println!(\"{}\", x);",
        "}"
      ],
      "position": {
        "row": 1,
        "col": 9
      },
      "treesitter": {
        "node_type": "type_identifier",
        "parent_types": ["type_annotation", "let_declaration", "block"],
        "scope_type": "function_definition"
      }
    }
  ],
  "total_diagnostics": 1,
  "timestamp": 1703174400
}
```

## Custom Templates

You can add custom prompt templates for different use cases:

```lua
require("diagnostic-extractor.templates").add_template("minimal", [[
Error: {{ diagnostic.diagnostic.message }}
Code:
{% for line in diagnostic.lines %}
{{ line }}
{% endfor %}
]])
```

Available template variables:
- `language` - Source file language
- `filename` - Source file name
- `diagnostic` - Full diagnostic information including:
  - `diagnostic` - Core diagnostic data (message, severity, etc.)
  - `lines` - Context lines around the diagnostic
  - `position` - Cursor position information
  - `treesitter` - Syntax and type context

## Contributing

Contributions are welcome!
Please feel free to submit a Pull Request.

## License

MIT License.
See LICENSE for details.
