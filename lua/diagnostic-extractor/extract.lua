local M = {}

---Get all diagnostics with context from the current buffer
---@param opts? Config
---@return DiagnosticContext[]
function M.extract_diagnostics(opts)
  opts = opts or {}
  local context_lines = opts.context_lines or 2

  -- Get all diagnostics from current buffer
  local diagnostics = vim.diagnostic.get(0)
  local contexts = {}
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for _, diagnostic in ipairs(diagnostics) do
    -- Apply severity filters if configured
    if opts.filters and not opts.filters[vim.diagnostic.severity[diagnostic.severity]] then
      goto continue
    end

    -- Calculate context range
    local start_line = math.max(0, diagnostic.lnum - context_lines)
    local end_line = math.min(#lines, diagnostic.lnum + context_lines + 1)
    
    -- Get context lines
    local context = {}
    for i = start_line, end_line - 1 do
      context[#context + 1] = lines[i + 1]
    end
    
    -- Create context object
    contexts[#contexts + 1] = {
      diagnostic = diagnostic,
      lines = context,
      start_line = start_line,
      end_line = end_line,
      position = {
        row = diagnostic.lnum,
        col = diagnostic.col,
      }
    }
    
    ::continue::
  end
  
  return contexts
end

return M
