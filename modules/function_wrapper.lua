-- Function Wrapping: Wrap all functions in multiple layers of indirection
-- function() return function() actual_code end() - double (or more) wrapping
-- Makes call stacks confusing and harder to trace execution flow

local FunctionWrapper = {}
local ASTBuilder = require("ast_builder")

--- Create single wrapper around function body
local function create_single_wrapper(func_body, func_params)
    -- Wrapper: function(...) return function(...) actual_body end end
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = nil,
        params = func_params or {},
        body = {
            {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = {
                    {
                        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
                        name = nil,
                        params = func_params or {},
                        body = func_body
                    }
                }
            }
        }
    }
end

--- Create double wrapper
local function create_double_wrapper(func_body, func_params)
    -- Wrapper level 1: function(...) return LEVEL2 end
    -- Wrapper level 2: function(...) return function(...) actual_body end end
    
    local level2_func = {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = nil,
        params = func_params or {},
        body = {
            {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = {
                    {
                        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
                        name = nil,
                        params = func_params or {},
                        body = func_body
                    }
                }
            }
        }
    }
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = nil,
        params = func_params or {},
        body = {
            {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = { level2_func }
            }
        }
    }
end

--- Create triple wrapper
local function create_triple_wrapper(func_body, func_params)
    local level3_func = {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = nil,
        params = func_params or {},
        body = {
            {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = {
                    {
                        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
                        name = nil,
                        params = func_params or {},
                        body = func_body
                    }
                }
            }
        }
    }
    
    local level2_func = {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = nil,
        params = func_params or {},
        body = {
            {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = { level3_func }
            }
        }
    }
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = nil,
        params = func_params or {},
        body = {
            {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = { level2_func }
            }
        }
    }
end

--- Deep copy node
local function deep_copy(node)
    if type(node) ~= "table" then
        return node
    end
    
    local copy = {}
    for k, v in pairs(node) do
        if type(v) == "table" then
            copy[k] = deep_copy(v)
        else
            copy[k] = v
        end
    end
    
    return copy
end

--- Wrap function declaration
local function wrap_function_decl(func_decl, wrapping_level)
    wrapping_level = wrapping_level or 2
    
    -- Don't wrap if it's already a wrapper function
    if func_decl.name and func_decl.name:sub(1, 2) == "__" then
        return func_decl
    end
    
    local body_copy = {}
    for _, stmt in ipairs(func_decl.body) do
        table.insert(body_copy, deep_copy(stmt))
    end
    
    local params_copy = {}
    for _, param in ipairs(func_decl.params) do
        table.insert(params_copy, param)
    end
    
    local wrapped_func = func_decl
    
    if wrapping_level >= 1 then
        wrapped_func = create_single_wrapper(body_copy, params_copy)
    end
    
    if wrapping_level >= 2 then
        body_copy = {}
        table.insert(body_copy, deep_copy(wrapped_func))
        wrapped_func = create_single_wrapper(body_copy, {})
    end
    
    if wrapping_level >= 3 then
        body_copy = {}
        table.insert(body_copy, deep_copy(wrapped_func))
        wrapped_func = create_single_wrapper(body_copy, {})
    end
    
    -- Re-attach original name to outermost wrapper
    wrapped_func.name = func_decl.name
    
    -- Create assignment that calls wrapper to unwrap
    if func_decl.name then
        return {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = func_decl.name,
                is_local = false
            },
            value = {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = {
                    type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                    func = {
                        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                        func = wrapped_func,
                        args = {}
                    },
                    args = {}
                },
                args = {}
            }
        }
    end
    
    return wrapped_func
end

--- Create wrapper assignment for named function
local function create_wrapper_assignment(func_name, original_func, wrapping_level)
    wrapping_level = wrapping_level or 2
    
    local body_copy = {}
    for _, stmt in ipairs(original_func.body) do
        table.insert(body_copy, deep_copy(stmt))
    end
    
    local params_copy = {}
    for _, param in ipairs(original_func.params) do
        table.insert(params_copy, param)
    end
    
    -- Create the innermost actual function
    local innermost = {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = nil,
        params = params_copy,
        body = body_copy
    }
    
    local wrapped = innermost
    
    -- Apply wrapping layers
    for _ = 1, wrapping_level do
        local current_params = wrapped.params or params_copy
        
        wrapped = {
            type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
            name = nil,
            params = {},  -- Wrapper takes no params
            body = {
                {
                    type = ASTBuilder.NODE_TYPES.RETURN,
                    values = { wrapped }
                }
            }
        }
    end
    
    -- Create: local func_name = wrapper()()()
    local unwrap_call = {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = wrapped,
        args = {}
    }
    
    -- Add additional call layers to unwrap
    for _ = 1, wrapping_level - 1 do
        unwrap_call = {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = unwrap_call,
            args = {}
        }
    end
    
    return {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = func_name,
            is_local = true
        },
        value = unwrap_call
    }
end

--- Recursively wrap functions in AST
local function wrap_functions_recursive(node, wrapping_level)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        local new_body = {}
        
        for _, stmt in ipairs(node.body) do
            if stmt.type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
                -- Wrap function declaration
                local wrapped_stmt = create_wrapper_assignment(stmt.name, stmt, wrapping_level)
                table.insert(new_body, wrapped_stmt)
            else
                table.insert(new_body, wrap_functions_recursive(stmt, wrapping_level))
            end
        end
        
        node.body = new_body
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        -- Wrap nested function bodies
        for i, stmt in ipairs(node.body) do
            node.body[i] = wrap_functions_recursive(stmt, wrapping_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        -- If assigning a function, wrap it
        if node.value.type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
            local func = node.value
            local wrapped = create_wrapper_assignment(node.target.name, func, wrapping_level)
            return wrapped
        end
        
        node.value = wrap_functions_recursive(node.value, wrapping_level)
    
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        node.condition = wrap_functions_recursive(node.condition, wrapping_level)
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = wrap_functions_recursive(stmt, wrapping_level)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = wrap_functions_recursive(stmt, wrapping_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        node.condition = wrap_functions_recursive(node.condition, wrapping_level)
        for i, stmt in ipairs(node.body) do
            node.body[i] = wrap_functions_recursive(stmt, wrapping_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        for i, stmt in ipairs(node.body) do
            node.body[i] = wrap_functions_recursive(stmt, wrapping_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        node.func = wrap_functions_recursive(node.func, wrapping_level)
        for i, arg in ipairs(node.args) do
            node.args[i] = wrap_functions_recursive(arg, wrapping_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.BINARY_OP then
        node.left = wrap_functions_recursive(node.left, wrapping_level)
        node.right = wrap_functions_recursive(node.right, wrapping_level)
    
    elseif node_type == ASTBuilder.NODE_TYPES.UNARY_OP then
        node.operand = wrap_functions_recursive(node.operand, wrapping_level)
    
    elseif node_type == ASTBuilder.NODE_TYPES.TABLE then
        for i, field in ipairs(node.fields) do
            if field.key then
                node.fields[i].value = wrap_functions_recursive(field.value, wrapping_level)
            else
                node.fields[i] = wrap_functions_recursive(field, wrapping_level)
            end
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.INDEX then
        node.object = wrap_functions_recursive(node.object, wrapping_level)
        node.index = wrap_functions_recursive(node.index, wrapping_level)
    
    elseif node_type == ASTBuilder.NODE_TYPES.MEMBER then
        node.object = wrap_functions_recursive(node.object, wrapping_level)
    
    elseif node_type == ASTBuilder.NODE_TYPES.RETURN then
        for i, val in ipairs(node.values) do
            node.values[i] = wrap_functions_recursive(val, wrapping_level)
        end
    end
    
    return node
end

--- Wrap all functions in AST
function FunctionWrapper.wrap_functions(ast, wrapping_level)
    wrapping_level = wrapping_level or 2
    
    if wrapping_level < 1 then
        wrapping_level = 1
    end
    if wrapping_level > 5 then
        wrapping_level = 5
    end
    
    math.randomseed(os.time() + math.random(1, 999999))
    
    local ast_copy = deep_copy(ast)
    return wrap_functions_recursive(ast_copy, wrapping_level)
end

--- Wrap with double wrapping (default)
function FunctionWrapper.wrap_double(ast)
    return FunctionWrapper.wrap_functions(ast, 2)
end

--- Wrap with triple wrapping
function FunctionWrapper.wrap_triple(ast)
    return FunctionWrapper.wrap_functions(ast, 3)
end

--- Wrap with extreme wrapping (5 layers)
function FunctionWrapper.wrap_extreme(ast)
    return FunctionWrapper.wrap_functions(ast, 5)
end

--- Wrap with light wrapping (single layer)
function FunctionWrapper.wrap_light(ast)
    return FunctionWrapper.wrap_functions(ast, 1)
end

--- Count wrapped functions
local function count_wrapped_functions(node, count)
    count = count or 0
    
    if not node then
        return count
    end
    
    if node.type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            count = count_wrapped_functions(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.ASSIGN then
        -- Count if assignment contains function call chain
        if node.value.type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
            count = count + 1
        end
        count = count_wrapped_functions(node.value, count)
    elseif node.type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        for _, stmt in ipairs(node.body) do
            count = count_wrapped_functions(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.IF then
        for _, stmt in ipairs(node.then_block) do
            count = count_wrapped_functions(stmt, count)
        end
        for _, stmt in ipairs(node.else_block) do
            count = count_wrapped_functions(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.WHILE then
        for _, stmt in ipairs(node.body) do
            count = count_wrapped_functions(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FOR then
        for _, stmt in ipairs(node.body) do
            count = count_wrapped_functions(stmt, count)
        end
    end
    
    return count
end

--- Get statistics
function FunctionWrapper.get_stats(ast)
    local wrapped_count = count_wrapped_functions(ast)
    return {
        wrapped_functions = wrapped_count
    }
end

--- Print statistics
function FunctionWrapper.print_stats(ast)
    local stats = FunctionWrapper.get_stats(ast)
    print("Function Wrapping Statistics:")
    print(string.rep("-", 40))
    print(string.format("Wrapped Functions: %d", stats.wrapped_functions))
end

return FunctionWrapper
