-- Variable Renaming & Obfuscation: Minify and obfuscate variable names
-- Renames all identifiers to short names (a, b, c, ..., aa, ab, etc.)
-- Makes code harder to reverse engineer while maintaining functionality

local Obfuscator = {}
local ASTBuilder = require("ast_builder")

--- Generate short variable names (a, b, c, ..., z, aa, ab, ...)
local function generate_short_name(index)
    if index < 26 then
        return string.char(97 + index) -- a-z
    end
    
    index = index - 26
    local base = math.floor(index / 26)
    local offset = index % 26
    
    if base < 26 then
        return string.char(97 + base) .. string.char(97 + offset)
    end
    
    -- For very deep nesting, use even shorter notation
    return "_" .. tostring(index)
end

--- Obfuscation state
local Obfuscator_State = {
    name_map = {}, -- Maps original names to short names
    name_counter = 0,
    scope_stack = {}, -- Stack of scope tables
    keywords = { -- Don't rename keywords
        ["if"] = true,
        ["then"] = true,
        ["else"] = true,
        ["elseif"] = true,
        ["end"] = true,
        ["while"] = true,
        ["do"] = true,
        ["for"] = true,
        ["in"] = true,
        ["function"] = true,
        ["return"] = true,
        ["local"] = true,
        ["and"] = true,
        ["or"] = true,
        ["not"] = true,
        ["nil"] = true,
        ["true"] = true,
        ["false"] = true,
        ["break"] = true,
    },
    -- Global libraries to preserve
    globals_to_preserve = {
        ["print"] = true,
        ["table"] = true,
        ["string"] = true,
        ["math"] = true,
        ["os"] = true,
        ["io"] = true,
        ["debug"] = true,
        ["pairs"] = true,
        ["ipairs"] = true,
        ["next"] = true,
        ["tonumber"] = true,
        ["tostring"] = true,
        ["type"] = true,
        ["unpack"] = true,
    }
}

--- Push new scope
local function push_scope()
    table.insert(Obfuscator_State.scope_stack, {})
end

--- Pop scope
local function pop_scope()
    table.remove(Obfuscator_State.scope_stack)
end

--- Get current scope
local function current_scope()
    return Obfuscator_State.scope_stack[#Obfuscator_State.scope_stack] or {}
end

--- Register variable in current scope
local function register_variable(name)
    if Obfuscator_State.keywords[name] or Obfuscator_State.globals_to_preserve[name] then
        return name -- Don't rename keywords or preserved globals
    end
    
    if not Obfuscator_State.name_map[name] then
        Obfuscator_State.name_map[name] = generate_short_name(Obfuscator_State.name_counter)
        Obfuscator_State.name_counter = Obfuscator_State.name_counter + 1
    end
    
    local scope = current_scope()
    scope[name] = Obfuscator_State.name_map[name]
end

--- Rename variable (lookup in name map)
local function rename_variable(name)
    if Obfuscator_State.keywords[name] or Obfuscator_State.globals_to_preserve[name] then
        return name
    end
    
    return Obfuscator_State.name_map[name] or name
end

--- Collect all variable names in AST
local function collect_variables(node)
    if not node then
        return
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            collect_variables(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        -- Register assignment targets
        if node.target.type == ASTBuilder.NODE_TYPES.IDENTIFIER then
            register_variable(node.target.name)
        end
        collect_variables(node.value)
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        if node.name then
            register_variable(node.name)
        end
        -- Register parameters as local variables
        for _, param in ipairs(node.params) do
            register_variable(param)
        end
        for _, stmt in ipairs(node.body) do
            collect_variables(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        collect_variables(node.condition)
        for _, stmt in ipairs(node.then_block) do
            collect_variables(stmt)
        end
        for _, stmt in ipairs(node.else_block) do
            collect_variables(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        collect_variables(node.condition)
        for _, stmt in ipairs(node.body) do
            collect_variables(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        register_variable(node.var)
        collect_variables(node.start)
        collect_variables(node.end_val)
        collect_variables(node.step)
        for _, stmt in ipairs(node.body) do
            collect_variables(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.RETURN then
        for _, val in ipairs(node.values) do
            collect_variables(val)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.IDENTIFIER then
        register_variable(node.name)
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        collect_variables(node.func)
        for _, arg in ipairs(node.args) do
            collect_variables(arg)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.BINARY_OP then
        collect_variables(node.left)
        collect_variables(node.right)
    elseif node_type == ASTBuilder.NODE_TYPES.UNARY_OP then
        collect_variables(node.operand)
    elseif node_type == ASTBuilder.NODE_TYPES.TABLE then
        for _, field in ipairs(node.fields) do
            if field.key then
                collect_variables(field.value)
            else
                collect_variables(field)
            end
        end
    elseif node_type == ASTBuilder.NODE_TYPES.INDEX then
        collect_variables(node.object)
        collect_variables(node.index)
    elseif node_type == ASTBuilder.NODE_TYPES.MEMBER then
        collect_variables(node.object)
    end
end

--- Rename identifiers in AST recursively
local function obfuscate_node(node)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        for i, stmt in ipairs(node.body) do
            node.body[i] = obfuscate_node(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        if node.target.type == ASTBuilder.NODE_TYPES.IDENTIFIER then
            node.target.name = rename_variable(node.target.name)
        else
            node.target = obfuscate_node(node.target)
        end
        node.value = obfuscate_node(node.value)
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        if node.name then
            node.name = rename_variable(node.name)
        end
        for i, param in ipairs(node.params) do
            node.params[i] = rename_variable(param)
        end
        for i, stmt in ipairs(node.body) do
            node.body[i] = obfuscate_node(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        node.condition = obfuscate_node(node.condition)
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = obfuscate_node(stmt)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = obfuscate_node(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        node.condition = obfuscate_node(node.condition)
        for i, stmt in ipairs(node.body) do
            node.body[i] = obfuscate_node(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        node.var = rename_variable(node.var)
        node.start = obfuscate_node(node.start)
        node.end_val = obfuscate_node(node.end_val)
        node.step = obfuscate_node(node.step)
        for i, stmt in ipairs(node.body) do
            node.body[i] = obfuscate_node(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.RETURN then
        for i, val in ipairs(node.values) do
            node.values[i] = obfuscate_node(val)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.IDENTIFIER then
        node.name = rename_variable(node.name)
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        node.func = obfuscate_node(node.func)
        for i, arg in ipairs(node.args) do
            node.args[i] = obfuscate_node(arg)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.BINARY_OP then
        node.left = obfuscate_node(node.left)
        node.right = obfuscate_node(node.right)
    elseif node_type == ASTBuilder.NODE_TYPES.UNARY_OP then
        node.operand = obfuscate_node(node.operand)
    elseif node_type == ASTBuilder.NODE_TYPES.TABLE then
        for i, field in ipairs(node.fields) do
            if field.key then
                -- Keys are strings, keep them as-is for now
                -- Or obfuscate them too for extra security
                node.fields[i].value = obfuscate_node(field.value)
            else
                node.fields[i] = obfuscate_node(field)
            end
        end
    elseif node_type == ASTBuilder.NODE_TYPES.INDEX then
        node.object = obfuscate_node(node.object)
        node.index = obfuscate_node(node.index)
    elseif node_type == ASTBuilder.NODE_TYPES.MEMBER then
        node.object = obfuscate_node(node.object)
        -- Keep member names unchanged (they're property names)
    end
    
    return node
end

--- Obfuscate AST by renaming all variables
function Obfuscator.obfuscate_ast(ast)
    Obfuscator_State.name_map = {}
    Obfuscator_State.name_counter = 0
    
    -- First pass: collect all variable names
    collect_variables(ast)
    
    -- Second pass: rename identifiers
    return obfuscate_node(ast)
end

--- Get mapping of original -> obfuscated names
function Obfuscator.get_name_map()
    return Obfuscator_State.name_map
end

--- Print name mapping (for debugging)
function Obfuscator.print_name_map()
    print("Variable Name Mapping:")
    print(string.rep("-", 40))
    
    local sorted_names = {}
    for orig, short in pairs(Obfuscator_State.name_map) do
        table.insert(sorted_names, { orig, short })
    end
    table.sort(sorted_names, function(a, b) return a[1] < b[1] end)
    
    for _, pair in ipairs(sorted_names) do
        print(string.format("  %-20s => %s", pair[1], pair[2]))
    end
end

return Obfuscator
