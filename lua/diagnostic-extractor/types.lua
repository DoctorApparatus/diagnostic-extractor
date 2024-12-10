---@class SymbolReference
---@field name string The symbol name
---@field type string? The symbol type if available
---@field kind string? The symbol kind (variable, function, etc)
---@field definition_range? {start_row: integer, start_col: integer, end_row: integer, end_col: integer}
---@field references {row: integer, col: integer}[] List of reference positions

---@class TypeInfo
---@field type string? The inferred type if available
---@field type_source string? Source of type information (annotation, inference)
---@field generic_params string[]? List of generic type parameters
---@field traits string[]? List of implemented traits (Rust-specific)

---@class TreesitterContext
---@field node_type string Type of the current node
---@field parent_types string[] Types of parent nodes
---@field scope_text string? Text of the containing scope
---@field scope_type string? Type of the containing scope
---@field type_info TypeInfo? Type information if available
---@field symbol_references SymbolReference? Symbol reference information
