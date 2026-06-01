-- Dead Code Insertion: Inject useless code to confuse reverse engineers
-- Adds fake variables, fake conditionals, fake loops, fake functions
-- Makes code bloated and hard to understand without changing functionality

local DeadCodeInserter = {}
local ASTBuilder = require("ast_builder")

--- Dead code patterns (variations)
local DEAD_CODE_PATTERNS = {
    -- Dead variables
    "local _x = 1",
    "local _y = 2 + 3",
    "local _z = 'unused'",
    "local _dummy = {}",
    "local _null = nil",
    "local _false = false",
    "local _junk = 'junk'..tostring(42)",
    
    -- Dead conditions
    "if false then end",
    "if nil then print('never') end",
    "if 0 == 1 then return end",
    "if true and false then end",
    
    -- Dead loops
    "for _i = 1, 0 do end",
    "while false do end",
    "repeat until true",
    
    -- Dead function calls (harmless functions)
    "type(1)",
    "tostring(nil)",
    "tonumber('42')",
    "next({})",
}

--- Generate random dead variable
local function generate_dead_variable()
    local var_names = {
        "__x", "__y", "__z", "__a", "__b", "__c", "__d", "__e", "__f",
        "_tmp", "_var", "_val", "_data", "_item", "_elem", "_node",
        "__unused", "__dead", "__fake", "__junk", "__padding"
    }
    
    local var_name = var_names[math.random(1, #var_names)]
    
    local values = {
        { type = ASTBuilder.NODE_TYPES.NUMBER, value = math.random(1, 1000) },
        { type = ASTBuilder.NODE_TYPES.NUMBER, value = math.random(-1000, 1000) },
        { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = true },
        { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = false },
        { type = ASTBuilder.NODE_TYPES.NIL },
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "+",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = math.random(1, 100) },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = math.random(1, 100) }
        },
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "*",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = math.random(1, 50) },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = math.random(1, 50) }
        },
        { type = ASTBuilder.NODE_TYPES.STRING, value = "dead_" .. tostring(math.random()) },
        { type = ASTBuilder.NODE_TYPES.TABLE, fields = {} },
    }
    
    return {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = var_name,
            is_local = true
        },
        value = values[math.random(1, #values)]
    }
end

--- Generate random dead condition
local function generate_dead_condition()
    local conditions = {
        {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = false },
            then_block = {
                {
                    type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                    func = {
                        type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                        name = "print"
                    },
                    args = {
                        { type = ASTBuilder.NODE_TYPES.STRING, value = "this never runs" }
                    }
                }
            },
            else_block = {}
        },
        {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = {
                type = ASTBuilder.NODE_TYPES.BINARY_OP,
                op = "==",
                left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 0 },
                right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
            },
            then_block = {
                {
                    type = ASTBuilder.NODE_TYPES.RETURN,
                    values = {}
                }
            },
            else_block = {}
        },
        {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = {
                type = ASTBuilder.NODE_TYPES.BOOLEAN,
                value = true
            },
            then_block = {
                {
                    type = ASTBuilder.NODE_TYPES.RETURN,
                    values = {}
                }
            },
            else_block = {
                {
                    type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                    func = {
                        type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                        name = "print"
                    },
                    args = {
                        { type = ASTBuilder.NODE_TYPES.STRING, value = "unreachable" }
                    }
                }
            }
        }
    }
    
    return conditions[math.random(1, #conditions)]
end

--- Generate random dead loop
local function generate_dead_loop()
    local loops = {
        {
            type = ASTBuilder.NODE_TYPES.FOR,
            var = "__deadloop",
            start = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 },
            end_val = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 0 },
            step = nil,
            body = {
                {
                    type = ASTBuilder.NODE_TYPES.ASSIGN,
                    target = {
                        type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                        name = "__nope"
                    },
                    value = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
                }
            }
        },
        {
            type = ASTBuilder.NODE_TYPES.WHILE,
            condition = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = false },
            body = {
                {
                    type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                    func = {
                        type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                        name = "print"
                    },
                    args = {
                        { type = ASTBuilder.NODE_TYPES.STRING, value = "loop never executes" }
                    }
                }
            }
        }
    }
    
    return loops[math.random(1, #loops)]
end

--- Generate random dead function
local function generate_dead_function()
    local func_names = {
        "__deadfunc", "__fake", "__unused", "__dummy", "__stub",
        "__noop", "__void", "__phantom", "__ghost", "__zombie"
    }
    
    local func_name = func_names[math.random(1, #func_names)]
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
        name = func_name,
        params = {},
        body = {
            {
                type = ASTBuilder.NODE_TYPES.ASSIGN,
                target = {
                    type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                    name = "__x"
                },
                value = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
            },
            {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = {
                    { type = ASTBuilder.NODE_TYPES.NIL }
                }
            }
        }
    }
end

--- Generate random dead function call
local function generate_dead_function_call()
    local calls = {
        {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "type" },
            args = { { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 } }
        },
        {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "tostring" },
            args = { { type = ASTBuilder.NODE_TYPES.NIL } }
        },
        {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "tonumber" },
            args = { { type = ASTBuilder.NODE_TYPES.STRING, value = "42" } }
        },
        {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "next" },
            args = { { type = ASTBuilder.NODE_TYPES.TABLE, fields = {} } }
        },
        {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "string" },
                member = "len"
            },
            args = { { type = ASTBuilder.NODE_TYPES.STRING, value = "x" } }
        }
    }
    
    return calls[math.random(1, #calls)]
end

--- Insert dead code into block
local function insert_dead_code_into_block(stmts, density)
    density = density or 0.3 -- 30% chance to insert dead code at each position
    
    local result = {}
    
    for i, stmt in ipairs(stmts) do
        table.insert(result, stmt)
        
        -- Randomly insert dead code after statement
        if math.random() < density then
            local dead_type = math.random(1, 5)
            
            if dead_type == 1 then
                table.insert(result, generate_dead_variable())
            elseif dead_type == 2 then
                table.insert(result, generate_dead_condition())
            elseif dead_type == 3 then
                table.insert(result, generate_dead_loop())
            elseif dead_type == 4 then
                table.insert(result, generate_dead_function())
            elseif dead_type == 5 then
                table.insert(result, generate_dead_function_call())
            end
        end
    end
    
    return result
end

--- Recursively insert dead code into AST
local function insert_dead_code_recursive(node, density)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        node.body = insert_dead_code_into_block(node.body, density)
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        node.body = insert_dead_code_into_block(node.body, density)
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_dead_code_recursive(stmt, density)
        end
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        node.then_block = insert_dead_code_into_block(node.then_block, density)
        node.else_block = insert_dead_code_into_block(node.else_block, density)
        
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = insert_dead_code_recursive(stmt, density)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = insert_dead_code_recursive(stmt, density)
        end
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        node.body = insert_dead_code_into_block(node.body, density)
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_dead_code_recursive(stmt, density)
        end
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        node.body = insert_dead_code_into_block(node.body, density)
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_dead_code_recursive(stmt, density)
        end
        return node
    end
    
    return node
end

--- Insert dead code with specified density
function DeadCodeInserter.insert_dead_code(ast, density)
    density = density or 0.3
    math.randomseed(os.time() + math.random(1, 999999))
    
    local ast_copy = DeadCodeInserter.deep_copy(ast)
    return insert_dead_code_recursive(ast_copy, density)
end

--- Deep copy AST node
function DeadCodeInserter.deep_copy(node)
    if type(node) ~= "table" then
        return node
    end
    
    local copy = {}
    for k, v in pairs(node) do
        if type(v) == "table" then
            copy[k] = DeadCodeInserter.deep_copy(v)
        else
            copy[k] = v
        end
    end
    
    return copy
end

--- Insert dead code with extreme density (max chaos)
function DeadCodeInserter.insert_extreme_dead_code(ast)
    return DeadCodeInserter.insert_dead_code(ast, 0.7) -- 70% insertion rate
end

--- Insert dead code with minimal density (barely noticeable)
function DeadCodeInserter.insert_light_dead_code(ast)
    return DeadCodeInserter.insert_dead_code(ast, 0.15) -- 15% insertion rate
end

--- Insert dead code with medium density (balanced)
function DeadCodeInserter.insert_medium_dead_code(ast)
    return DeadCodeInserter.insert_dead_code(ast, 0.4) -- 40% insertion rate
end

--- Count dead code statements in AST
local function count_dead_code(node, count)
    count = count or 0
    
    if not node then
        return count
    end
    
    if node.type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            count = count_dead_code(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        for _, stmt in ipairs(node.body) do
            count = count_dead_code(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.IF then
        for _, stmt in ipairs(node.then_block) do
            count = count_dead_code(stmt, count)
        end
        for _, stmt in ipairs(node.else_block) do
            count = count_dead_code(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.WHILE or node.type == ASTBuilder.NODE_TYPES.FOR then
        for _, stmt in ipairs(node.body) do
            count = count_dead_code(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.ASSIGN then
        -- Check if it's a dead assignment (variable name starts with __)
        if node.target.type == ASTBuilder.NODE_TYPES.IDENTIFIER and 
           node.target.name:sub(1, 2) == "__" then
            count = count + 1
        end
    end
    
    return count
end

--- Get statistics about dead code
function DeadCodeInserter.get_stats(ast)
    local dead_count = count_dead_code(ast)
    return {
        dead_statements = dead_count
    }
end

--- Print dead code statistics
function DeadCodeInserter.print_stats(ast)
    local stats = DeadCodeInserter.get_stats(ast)
    print("Dead Code Statistics:")
    print(string.rep("-", 40))
    print(string.format("Dead Statements: %d", stats.dead_statements))
end

return DeadCodeInserter
