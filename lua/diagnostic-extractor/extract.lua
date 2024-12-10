local ts = require("diagnostic-extractor.treesitter")

local M = {}

---Convert diagnostic to a JSON-friendly format
---@param diagnostic vim.Diagnostic
---@return table
local function convert_diagnostic(diagnostic)
  return {
    severity = diagnostic.severity,
    severity_name = vim.diagnostic.severity[diagnostic.severity],
    message = diagnostic.message,
    source = diagnostic.source,
    code = diagnostic.code,
  }
end

---Get all diagnostics with context from the current buffer
---@param opts? Config
---@return table JSON-serializable diagnostic data
function M.extract_diagnostics(opts)
  opts = opts or {}
  local context_lines = opts.context_lines or 2
  
  local diagnostics = vim.diagnostic.get(0)
  local contexts = {}
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  
  -- Get buffer language for additional context
  local ft = vim.bo[bufnr].filetype
  local language = vim.treesitter.language.get_lang(ft) or ft
  
  for _, diagnostic in ipairs(diagnostics) do
    if opts.filters and not opts.filters[vim.diagnostic.severity[diagnostic.severity]] then
      goto continue
    end
    
    -- Get regular context
    local start_line = math.max(0, diagnostic.lnum - context_lines)
    local end_line = math.min(#lines, diagnostic.lnum + context_lines + 1)
    
    local context = {}
    for i = start_line, end_line - 1 do
      context[#context + 1] = lines[i + 1]
    end
    
    -- Get treesitter context
    local ts_context = ts.get_position_context(bufnr, diagnostic.lnum, diagnostic.col)
    
    -- Create context object
    contexts[#contexts + 1] = {
      diagnostic = convert_diagnostic(diagnostic),
      lines = context,
      start_line = start_line,
      end_line = end_line - 1,
      position = {
        row = diagnostic.lnum,
        col = diagnostic.col,
      },
      treesitter = ts_context or {
        node_type = "unknown",
        parent_types = {},
      }
    }
    
    ::continue::
  end
  
  return {
    filename = filename,
    language = language,
    diagnostics = contexts,
    total_diagnostics = #contexts,
    timestamp = os.time(),
  }
end

return M
