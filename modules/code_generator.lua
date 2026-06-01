-- Code Generator: Convert AST back to code string
-- Walks AST tree and generates executable code with proper formatting

local CodeGenerator = {}
local ASTBuilder = require("ast_builder")

--- Code generation state
local Generator = {
    indent_level = 0,
    indent_size = 2,
    output = {}
}

--- Get current indentation string
local function get_indent()
    return string.rep(" ", Generator.indent_level * Generator.indent_size)
end

--- Add line to output
local function emit(line)
    if line and line ~= "" then
        table.insert(Generator.output, get_indent() .. line)
    else
        table.insert(Generator.output, "")
    end
end

--- Add line without indentation
local function emit_raw(line)
    table.insert(Generator.output, line or "")
end

--- Increase indentation
local function push_indent()
    Generator.indent_level = Generator.indent_level + 1
end

--- Decrease indentation
local function pop_indent()
    Generator.indent_level = math.max(0, Generator.indent_level - 1)
end

--- Forward declarations
local function generate_node(node)
end

local function generate_expression(node)
end

--- Generate identifier
local function generate_identifier(node)
    return node.name
end

--- Generate number
local function generate_number(node)
    return tostring(node.value)
end

--- Generate string (with proper escaping)
local function generate_string(node)
    local escaped = node.value
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
    return '"' .. escaped .. '"'
end

--- Generate boolean
local function generate_boolean(node)
    return tostring(node.value)
end

--- Generate nil
local function generate_nil()
    return "nil"
end

--- Generate table literal
local function generate_table(node)
    if #node.fields == 0 then
        return "{}"
    end
    
    local parts = { "{" }
    
    for i, field in ipairs(node.fields) do
        if field.key then
            -- Key-value pair
            table.insert(parts, field.key .. " = " .. generate_expression(field.value))
        else
            -- Array element
            table.insert(parts, generate_expression(field))
        end
        
        if i < #node.fields then
            parts[#parts] = parts[#parts] .. ","
        end
    end
    
    table.insert(parts, "}")
    return table.concat(parts, " ")
end

--- Generate index access
local function generate_index(node)
    return generate_expression(node.object) .. "[" .. generate_expression(node.index) .. "]"
end

--- Generate member access
local function generate_member(node)
    return generate_expression(node.object) .. "." .. node.member
end

--- Generate binary operation
local function generate_binary_op(node)
    local left = generate_expression(node.left)
    local right = generate_expression(node.right)
    return "(" .. left .. " " .. node.op .. " " .. right .. ")"
end

--- Generate unary operation
local function generate_unary_op(node)
    local operand = generate_expression(node.operand)
    return node.op .. "(" .. operand .. ")"
end

--- Generate function call with arguments
local function generate_function_call(node)
    local args = {}
    for _, arg in ipairs(node.args) do
        table.insert(args, generate_expression(arg))
    end
    return generate_expression(node.func) .. "(" .. table.concat(args, ", ") .. ")"
end

--- Generate expression (returns string, doesn't emit)
function generate_expression(node)
    if not node then
        return "nil"
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.IDENTIFIER then
        return generate_identifier(node)
    elseif node_type == ASTBuilder.NODE_TYPES.NUMBER then
        return generate_number(node)
    elseif node_type == ASTBuilder.NODE_TYPES.STRING then
        return generate_string(node)
    elseif node_type == ASTBuilder.NODE_TYPES.BOOLEAN then
        return generate_boolean(node)
    elseif node_type == ASTBuilder.NODE_TYPES.NIL then
        return generate_nil()
    elseif node_type == ASTBuilder.NODE_TYPES.TABLE then
        return generate_table(node)
    elseif node_type == ASTBuilder.NODE_TYPES.INDEX then
        return generate_index(node)
    elseif node_type == ASTBuilder.NODE_TYPES.MEMBER then
        return generate_member(node)
    elseif node_type == ASTBuilder.NODE_TYPES.BINARY_OP then
        return generate_binary_op(node)
    elseif node_type == ASTBuilder.NODE_TYPES.UNARY_OP then
        return generate_unary_op(node)
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        return generate_function_call(node)
    else
        error("Unknown expression type: " .. tostring(node_type))
    end
end

--- Generate assignment statement
local function generate_assign(node)
    local target = generate_expression(node.target)
    local value = generate_expression(node.value)
    emit(target .. " = " .. value)
end

--- Generate if statement
local function generate_if(node)
    emit("if " .. generate_expression(node.condition) .. " then")
    push_indent()
    for _, stmt in ipairs(node.then_block) do
        generate_node(stmt)
    end
    pop_indent()
    
    if #node.else_block > 0 then
        emit("else")
        push_indent()
        for _, stmt in ipairs(node.else_block) do
            generate_node(stmt)
        end
        pop_indent()
    end
    
    emit("end")
end

--- Generate while loop
local function generate_while(node)
    emit("while " .. generate_expression(node.condition) .. " do")
    push_indent()
    for _, stmt in ipairs(node.body) do
        generate_node(stmt)
    end
    pop_indent()
    emit("end")
end

--- Generate for loop
local function generate_for(node)
    local for_line = "for " .. node.var .. " = " .. generate_expression(node.start) .. 
                     ", " .. generate_expression(node.end_val)
    if node.step then
        for_line = for_line .. ", " .. generate_expression(node.step)
    end
    for_line = for_line .. " do"
    emit(for_line)
    
    push_indent()
    for _, stmt in ipairs(node.body) do
        generate_node(stmt)
    end
    pop_indent()
    
    emit("end")
end

--- Generate return statement
local function generate_return(node)
    if #node.values == 0 then
        emit("return")
    else
        local values = {}
        for _, val in ipairs(node.values) do
            table.insert(values, generate_expression(val))
        end
        emit("return " .. table.concat(values, ", "))
    end
end

--- Generate function declaration
local function generate_function_decl(node)
    local func_sig = "function"
    if node.name then
        func_sig = func_sig .. " " .. node.name
    end
    func_sig = func_sig .. "(" .. table.concat(node.params, ", ") .. ")"
    
    emit(func_sig)
    push_indent()
    
    for _, stmt in ipairs(node.body) do
        generate_node(stmt)
    end
    
    pop_indent()
    emit("end")
end

--- Generate statement node
function generate_node(node)
    if not node then
        return
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            generate_node(stmt)
        end
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        generate_assign(node)
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        generate_if(node)
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        generate_while(node)
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        generate_for(node)
    elseif node_type == ASTBuilder.NODE_TYPES.RETURN then
        generate_return(node)
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        generate_function_decl(node)
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        emit(generate_function_call(node))
    else
        error("Unknown node type: " .. tostring(node_type))
    end
end

--- Generate code from AST
function CodeGenerator.generate(ast)
    Generator.output = {}
    Generator.indent_level = 0
    
    generate_node(ast)
    
    return table.concat(Generator.output, "\n")
end

--- Generate code with custom formatting options
function CodeGenerator.generate_formatted(ast, options)
    options = options or {}
    Generator.indent_size = options.indent_size or 2
    Generator.output = {}
    Generator.indent_level = 0
    
    generate_node(ast)
    
    local code = table.concat(Generator.output, "\n")
    
    -- Optional: remove trailing whitespace
    if options.trim_trailing then
        code = code:gsub("%s+\n", "\n")
    end
    
    return code
end

--- Pretty print generated code (for debugging)
function CodeGenerator.print_generated(ast)
    local code = CodeGenerator.generate(ast)
    print(code)
end

return CodeGenerator
