---@mod diagnostic-extractor.extract
---@brief [[
---Diagnostic extraction core functionality
---@brief ]]

local ts = require("diagnostic-extractor.treesitter")
local M = {}

---@param diagnostic vim.Diagnostic
---@param bufnr integer
---@param opts ExtractionOptions
---@return ExtractedDiagnostic
local function process_diagnostic(diagnostic, bufnr, opts)
    -- Get basic diagnostic info
    local result = {
        message = diagnostic.message,
        severity = diagnostic.severity,
        severity_name = vim.diagnostic.severity[diagnostic.severity],
        code = diagnostic.code,
        source = diagnostic.source,
        range = {
            start = { row = diagnostic.lnum, col = diagnostic.col },
            ["end"] = { row = diagnostic.end_lnum, col = diagnostic.end_col },
        },
    }

    -- Get context lines
    local ctx = M.get_diagnostic_context(bufnr, diagnostic, opts)
    result.context = ctx

    return result
end

---Get context around a diagnostic
---@param bufnr integer
---@param diagnostic vim.Diagnostic
---@param opts ExtractionOptions
---@return DiagnosticContext
function M.get_diagnostic_context(bufnr, diagnostic, opts)
    local result = {
        lines = {},
        treesitter = nil,
        start_line = 0,
        end_line = 0,
    }

    -- Get buffer lines
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    
    -- Calculate context range
    result.start_line = math.max(0, diagnostic.lnum - opts.context_lines)
    result.end_line = math.min(#lines, diagnostic.lnum + opts.context_lines + 1)

    -- Get context lines
    for i = result.start_line, result.end_line - 1 do
        table.insert(result.lines, lines[i + 1])
    end

    -- Get treesitter context if enabled
    if opts.include_treesitter then
        result.treesitter = ts.get_position_context(bufnr, diagnostic.lnum, diagnostic.col, {
            include_types = opts.include_types,
            include_symbols = opts.include_symbols,
        })
    end

    return result
end

---Extract diagnostics from a buffer
---@param opts? ExtractionOptions
---@return ExtractionResult
function M.extract_diagnostics(opts)
    opts = vim.tbl_deep_extend("force", {
        context_lines = 2,
        filters = {
            ERROR = true,
            WARN = true,
            INFO = true,
            HINT = true,
        },
        include_treesitter = true,
        include_types = true,
        include_symbols = true,
    }, opts or {})

    local bufnr = vim.api.nvim_get_current_buf()
    local diagnostics = vim.diagnostic.get(bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local ft = vim.bo[bufnr].filetype
    local language = vim.treesitter.language.get_lang(ft) or ft

    local result = {
        filename = filename,
        language = language,
        diagnostics = {},
        total = 0,
        timestamp = os.time(),
    }

    for _, diag in ipairs(diagnostics) do
        -- Apply severity filter
        if not opts.filters[vim.diagnostic.severity[diag.severity]] then
            goto continue
        end

        local processed = process_diagnostic(diag, bufnr, opts)
        table.insert(result.diagnostics, processed)
        result.total = result.total + 1

        ::continue::
    end

    return result
end

return M
