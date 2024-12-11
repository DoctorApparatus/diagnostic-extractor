---@meta

---@class DiagnosticLocation
---@field row integer 0-based row number
---@field col integer 0-based column number

---@class DiagnosticRange
---@field start DiagnosticLocation
---@field end DiagnosticLocation

---@class TypeInfo
---@field type string? The inferred type
---@field source string? How the type was determined
---@field traits string[]? List of implemented traits (Rust-specific)
---@field generics string[]? Generic type parameters

---@class SymbolInfo
---@field name string Symbol name
---@field type string? Symbol type
---@field kind string? Symbol kind (variable, function, etc)
---@field definition DiagnosticRange? Definition location
---@field references DiagnosticLocation[] Usage locations

---@class TreesitterContext
---@field node_type string Current node type
---@field parent_types string[] Parent node types
---@field scope TreesitterScope? Containing scope information
---@field type_info TypeInfo? Type information if available
---@field symbol_info SymbolInfo? Symbol information

---@class TreesitterScope
---@field type string Scope type (function, block, etc)
---@field text string? Scope text content
---@field range DiagnosticRange Scope range

---@class ExtractedDiagnostic
---@field message string Diagnostic message
---@field severity integer Diagnostic severity level
---@field severity_name string Human readable severity
---@field code string? Diagnostic code
---@field source string? Diagnostic source
---@field range DiagnosticRange Position information
---@field context DiagnosticContext Additional context

---@class DiagnosticContext
---@field lines string[] Lines around the diagnostic
---@field treesitter TreesitterContext? Treesitter analysis
---@field start_line integer First line of context
---@field end_line integer Last line of context

---@class ExtractionOptions
---@field context_lines integer Number of context lines
---@field filters table<string,boolean> Severity filters
---@field include_treesitter boolean Include treesitter analysis
---@field include_types boolean Include type information
---@field include_symbols boolean Include symbol information

---@class ExtractionResult
---@field filename string Source filename
---@field language string Source language
---@field diagnostics ExtractedDiagnostic[]
---@field total integer Total number of diagnostics
---@field timestamp integer Extraction timestamp
