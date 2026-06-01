-- Fake If/Else Chains: Insert redundant conditional branches that all return the same result
-- Creates confusing control flow: if 1==1 then X elseif 2==2 then X else X end
-- All branches execute the same code, making it impossible to determine which path matters

local FakeIfChainGenerator = {}
local ASTBuilder = require("ast_builder")

--- Generate always-true condition
local function generate_true_condition()
    return {
        type = ASTBuilder.NODE_TYPES.BINARY_OP,
        op = "==",
        left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 },
        right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
    }
end

--- Generate always-true condition (variant)
local function generate_variant_true_condition(variant)
    local conditions = {
        -- 1 == 1
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "==",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
        },
        -- true == true
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "==",
            left = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = true },
            right = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = true }
        },
        -- not false
        {
            type = ASTBuilder.NODE_TYPES.UNARY_OP,
            op = "not",
            operand = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = false }
        },
        -- 2 > 1
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = ">",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 2 },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
        },
        -- 10 >= 10
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = ">=",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 10 },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 10 }
        },
        -- 0 < 1
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "<",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 0 },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
        },
        -- "a" == "a"
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "==",
            left = { type = ASTBuilder.NODE_TYPES.STRING, value = "x" },
            right = { type = ASTBuilder.NODE_TYPES.STRING, value = "x" }
        },
        -- nil ~= true
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "~=",
            left = { type = ASTBuilder.NODE_TYPES.NIL },
            right = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = true }
        },
    }
    
    return conditions[variant % #conditions + 1]
end

--- Generate fake condition (looks real but always evaluates same way)
local function generate_fake_condition(variant)
    local fake_conditions = {
        -- ((1 + 1) == 2) and true
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "and",
            left = {
                type = ASTBuilder.NODE_TYPES.BINARY_OP,
                op = "==",
                left = {
                    type = ASTBuilder.NODE_TYPES.BINARY_OP,
                    op = "+",
                    left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 },
                    right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
                },
                right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 2 }
            },
            right = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = true }
        },
        -- (10 / 5) > 1
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = ">",
            left = {
                type = ASTBuilder.NODE_TYPES.BINARY_OP,
                op = "/",
                left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 10 },
                right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 5 }
            },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 }
        },
        -- (5 * 2) == 10
        {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "==",
            left = {
                type = ASTBuilder.NODE_TYPES.BINARY_OP,
                op = "*",
                left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 5 },
                right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 2 }
            },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 10 }
        },
        -- not (false and true)
        {
            type = ASTBuilder.NODE_TYPES.UNARY_OP,
            op = "not",
            operand = {
                type = ASTBuilder.NODE_TYPES.BINARY_OP,
                op = "and",
                left = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = false },
                right = { type = ASTBuilder.NODE_TYPES.BOOLEAN, value = true }
            }
        },
    }
    
    return fake_conditions[variant % #fake_conditions + 1]
end

--- Deep copy statement
local function deep_copy_stmt(stmt)
    if type(stmt) ~= "table" then
        return stmt
    end
    
    local copy = {}
    for k, v in pairs(stmt) do
        if type(v) == "table" then
            copy[k] = deep_copy_stmt(v)
        else
            copy[k] = v
        end
    end
    
    return copy
end

--- Create fake if-else chain wrapping a statement
local function create_fake_if_chain(stmt, chain_depth)
    chain_depth = chain_depth or math.random(2, 4)
    
    local stmt_copy = deep_copy_stmt(stmt)
    
    -- Build chain from inside out
    local result = {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = generate_variant_true_condition(1),
        then_block = { stmt_copy },
        else_block = {}
    }
    
    -- Add elseif branches
    for i = 2, chain_depth do
        local new_branch = {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = generate_variant_true_condition(i),
            then_block = { deep_copy_stmt(stmt) },
            else_block = {}
        }
        
        table.insert(result.else_block, new_branch)
        result = new_branch
    end
    
    -- Final else branch with same code
    local final_else = {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = generate_variant_true_condition(chain_depth + 1),
        then_block = { deep_copy_stmt(stmt) },
        else_block = { deep_copy_stmt(stmt) }
    }
    
    table.insert(result.else_block, final_else)
    
    return result
end

--- Wrap assignment in fake if chain
local function wrap_assignment_in_fake_if(stmt)
    if stmt.type ~= ASTBuilder.NODE_TYPES.ASSIGN then
        return stmt
    end
    
    -- Extract variable and value
    local var = stmt.target
    local val = stmt.value
    
    -- Create multiple assignments of same value
    local chain_depth = math.random(2, 4)
    
    local if_chain = {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = generate_variant_true_condition(1),
        then_block = {
            {
                type = ASTBuilder.NODE_TYPES.ASSIGN,
                target = deep_copy_stmt(var),
                value = deep_copy_stmt(val)
            }
        },
        else_block = {}
    }
    
    local current = if_chain
    
    -- Build elseif chain
    for i = 2, chain_depth do
        local elseif_branch = {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = generate_variant_true_condition(i),
            then_block = {
                {
                    type = ASTBuilder.NODE_TYPES.ASSIGN,
                    target = deep_copy_stmt(var),
                    value = deep_copy_stmt(val)
                }
            },
            else_block = {}
        }
        
        table.insert(current.else_block, elseif_branch)
        current = elseif_branch
    end
    
    -- Final else
    table.insert(current.else_block, {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = deep_copy_stmt(var),
        value = deep_copy_stmt(val)
    })
    
    return if_chain
end

--- Wrap function call in fake if chain
local function wrap_function_call_in_fake_if(stmt)
    if stmt.type ~= ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        return stmt
    end
    
    local func_call = stmt
    local chain_depth = math.random(2, 3)
    
    local if_chain = {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = generate_variant_true_condition(1),
        then_block = { deep_copy_stmt(func_call) },
        else_block = {}
    }
    
    local current = if_chain
    
    for i = 2, chain_depth do
        local elseif_branch = {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = generate_variant_true_condition(i),
            then_block = { deep_copy_stmt(func_call) },
            else_block = {}
        }
        
        table.insert(current.else_block, elseif_branch)
        current = elseif_branch
    end
    
    table.insert(current.else_block, deep_copy_stmt(func_call))
    
    return if_chain
end

--- Insert fake if chains into block statements
local function insert_fake_if_chains_into_block(stmts, insertion_rate)
    insertion_rate = insertion_rate or 0.4
    
    local result = {}
    
    for i, stmt in ipairs(stmts) do
        -- Decide whether to wrap this statement
        if math.random() < insertion_rate then
            if stmt.type == ASTBuilder.NODE_TYPES.ASSIGN then
                table.insert(result, wrap_assignment_in_fake_if(stmt))
            elseif stmt.type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
                table.insert(result, wrap_function_call_in_fake_if(stmt))
            else
                table.insert(result, stmt)
            end
        else
            table.insert(result, stmt)
        end
    end
    
    return result
end

--- Recursively insert fake if chains
local function insert_fake_if_chains_recursive(node, insertion_rate)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        node.body = insert_fake_if_chains_into_block(node.body, insertion_rate)
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_fake_if_chains_recursive(stmt, insertion_rate)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        node.body = insert_fake_if_chains_into_block(node.body, insertion_rate)
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_fake_if_chains_recursive(stmt, insertion_rate)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        node.then_block = insert_fake_if_chains_into_block(node.then_block, insertion_rate)
        node.else_block = insert_fake_if_chains_into_block(node.else_block, insertion_rate)
        
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = insert_fake_if_chains_recursive(stmt, insertion_rate)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = insert_fake_if_chains_recursive(stmt, insertion_rate)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        node.body = insert_fake_if_chains_into_block(node.body, insertion_rate)
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_fake_if_chains_recursive(stmt, insertion_rate)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        node.body = insert_fake_if_chains_into_block(node.body, insertion_rate)
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_fake_if_chains_recursive(stmt, insertion_rate)
        end
    end
    
    return node
end

--- Deep copy AST
local function deep_copy_ast(node)
    if type(node) ~= "table" then
        return node
    end
    
    local copy = {}
    for k, v in pairs(node) do
        if type(v) == "table" then
            copy[k] = deep_copy_ast(v)
        else
            copy[k] = v
        end
    end
    
    return copy
end

--- Insert fake if-else chains into AST
function FakeIfChainGenerator.insert_fake_if_chains(ast, insertion_rate)
    insertion_rate = insertion_rate or 0.4
    
    math.randomseed(os.time() + math.random(1, 999999))
    
    local ast_copy = deep_copy_ast(ast)
    return insert_fake_if_chains_recursive(ast_copy, insertion_rate)
end

--- Insert with aggressive rate (60%)
function FakeIfChainGenerator.insert_aggressive(ast)
    return FakeIfChainGenerator.insert_fake_if_chains(ast, 0.6)
end

--- Insert with light rate (20%)
function FakeIfChainGenerator.insert_light(ast)
    return FakeIfChainGenerator.insert_fake_if_chains(ast, 0.2)
end

--- Insert with extreme rate (80%)
function FakeIfChainGenerator.insert_extreme(ast)
    return FakeIfChainGenerator.insert_fake_if_chains(ast, 0.8)
end

--- Count fake if chains in AST
local function count_fake_chains(node, count)
    count = count or 0
    
    if not node then
        return count
    end
    
    if node.type == ASTBuilder.NODE_TYPES.IF then
        -- Check if it's a fake if chain (all branches have same content)
        if node.condition.type == ASTBuilder.NODE_TYPES.BINARY_OP or
           node.condition.type == ASTBuilder.NODE_TYPES.UNARY_OP then
            count = count + 1
        end
        
        for _, stmt in ipairs(node.then_block) do
            count = count_fake_chains(stmt, count)
        end
        for _, stmt in ipairs(node.else_block) do
            count = count_fake_chains(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            count = count_fake_chains(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        for _, stmt in ipairs(node.body) do
            count = count_fake_chains(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.WHILE then
        for _, stmt in ipairs(node.body) do
            count = count_fake_chains(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FOR then
        for _, stmt in ipairs(node.body) do
            count = count_fake_chains(stmt, count)
        end
    end
    
    return count
end

--- Get statistics
function FakeIfChainGenerator.get_stats(ast)
    local chain_count = count_fake_chains(ast)
    return {
        fake_chains = chain_count
    }
end

--- Print statistics
function FakeIfChainGenerator.print_stats(ast)
    local stats = FakeIfChainGenerator.get_stats(ast)
    print("Fake If-Else Chain Statistics:")
    print(string.rep("-", 40))
    print(string.format("Fake If Chains: %d", stats.fake_chains))
end

return FakeIfChainGenerator
