---@class DiagnosticContext
---@field diagnostic {severity: integer, message: string, source: string|nil, code: integer|string|nil} The LSP diagnostic info
---@field lines string[] The context lines around the diagnostic
---@field start_line integer Starting line number of the context
---@field end_line integer Ending line number of the context
---@field position {row: integer, col: integer} Position of the diagnostic

---@class Config
---@field context_lines integer Number of lines before and after diagnostic
---@field filters table<string,boolean> Filters for diagnostic severities
