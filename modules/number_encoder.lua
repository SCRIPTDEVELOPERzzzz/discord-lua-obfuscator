-- Number Encoding: Encode numbers in various obfuscated formats
-- 100 → 50+50, 0x64, math.floor(99.999)+1, bit operations, etc.
-- Each number encoded differently to avoid pattern recognition

local NumberEncoder = {}
local ASTBuilder = require("ast_builder")

--- Encoding strategies
local ENCODING_STRATEGIES = {
    -- Binary arithmetic
    "arithmetic",      -- 100 → 50+50, 100 → 101-1, 100 → 10*10
    -- Hexadecimal
    "hexadecimal",     -- 100 → 0x64
    -- Octal
    "octal",           -- 100 → 0o144
    -- Math functions
    "math_floor",      -- 100 → math.floor(100.5)
    "math_ceil",       -- 100 → math.ceil(99.5)
    "math_abs",        -- 100 → math.abs(-100)
    "math_sqrt_sq",    -- 100 → math.sqrt(10000)
    -- Bitwise operations
    "bitwise_xor",     -- 100 → 99 XOR 3 (requires bit library, fallback to arithmetic)
    "bitwise_shift",   -- 100 → 50 << 1
    -- String conversions
    "tonumber_hex",    -- 100 → tonumber("64", 16)
    "tonumber_oct",    -- 100 → tonumber("144", 8)
    -- Complex expressions
    "nested_math",     -- 100 → (50+25)*2
    "division_chain",  -- 100 → 400/2/2
    "modulo_trick",    -- 100 → (110 % 200) + 90
}

--- Generate arithmetic encoding: a+b, a-b, a*b, a/b
local function encode_arithmetic(num)
    local strategies = {}
    
    -- Addition: num = a + b
    if num > 1 then
        local a = math.floor(num / 2)
        local b = num - a
        table.insert(strategies, {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "+",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = a },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = b }
        })
    end
    
    -- Subtraction: num = a - b
    if num > 0 then
        local a = num + math.random(1, 50)
        local b = a - num
        table.insert(strategies, {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "-",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = a },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = b }
        })
    end
    
    -- Multiplication: num = a * b
    if num > 0 and num % 2 == 0 then
        local a = num / 2
        table.insert(strategies, {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "*",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = a },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 2 }
        })
    end
    
    if num > 0 and num % 5 == 0 then
        local a = num / 5
        table.insert(strategies, {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "*",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = a },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 5 }
        })
    end
    
    if num > 0 and num % 10 == 0 then
        local a = num / 10
        table.insert(strategies, {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "*",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = a },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 10 }
        })
    end
    
    -- Division: num = a / b
    if num > 0 and num % 2 == 0 then
        local a = num * 2
        table.insert(strategies, {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "/",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = a },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 2 }
        })
    end
    
    return strategies
end

--- Generate hexadecimal encoding
local function encode_hexadecimal(num)
    -- Return as hex string that will be converted by code generator
    return {
        type = ASTBuilder.NODE_TYPES.NUMBER,
        value = num,
        _format = "hex" -- Custom flag for code generator
    }
end

--- Generate math.floor encoding
local function encode_math_floor(num)
    local decimal = num + math.random(1, 100) / 1000
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "math" },
            member = "floor"
        },
        args = {
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = decimal }
        }
    }
end

--- Generate math.ceil encoding
local function encode_math_ceil(num)
    local decimal = num - math.random(1, 100) / 1000
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "math" },
            member = "ceil"
        },
        args = {
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = decimal }
        }
    }
end

--- Generate math.abs encoding
local function encode_math_abs(num)
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "math" },
            member = "abs"
        },
        args = {
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = -num }
        }
    }
end

--- Generate math.sqrt(x^2) encoding
local function encode_math_sqrt(num)
    local squared = num * num
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "math" },
            member = "sqrt"
        },
        args = {
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = squared }
        }
    }
end

--- Generate tonumber hex encoding
local function encode_tonumber_hex(num)
    local hex_str = string.format("%x", num)
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "tonumber" },
        args = {
            { type = ASTBuilder.NODE_TYPES.STRING, value = hex_str },
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = 16 }
        }
    }
end

--- Generate tonumber octal encoding
local function encode_tonumber_octal(num)
    local oct_str = string.format("%o", num)
    
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "tonumber" },
        args = {
            { type = ASTBuilder.NODE_TYPES.STRING, value = oct_str },
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = 8 }
        }
    }
end

--- Generate nested math encoding
local function encode_nested_math(num)
    local factor1 = math.floor(num / 2)
    local factor2 = math.floor(num / factor1)
    
    return {
        type = ASTBuilder.NODE_TYPES.BINARY_OP,
        op = "*",
        left = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "+",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = factor1 },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = math.floor(num / 4) }
        },
        right = {
            type = ASTBuilder.NODE_TYPES.NUMBER,
            value = factor2
        }
    }
end

--- Generate modulo trick encoding
local function encode_modulo_trick(num)
    local base = num + math.random(50, 150)
    local mod = base % 200
    local add = num - mod
    
    return {
        type = ASTBuilder.NODE_TYPES.BINARY_OP,
        op = "+",
        left = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "%",
            left = { type = ASTBuilder.NODE_TYPES.NUMBER, value = base },
            right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = 200 }
        },
        right = { type = ASTBuilder.NODE_TYPES.NUMBER, value = add }
    }
end

--- Select random encoding strategy
local function select_encoding(num)
    local strategies = {}
    
    -- Arithmetic operations (always available)
    local arith = encode_arithmetic(num)
    for _, enc in ipairs(arith) do
        table.insert(strategies, enc)
    end
    
    -- Math functions
    table.insert(strategies, encode_math_floor(num))
    table.insert(strategies, encode_math_ceil(num))
    table.insert(strategies, encode_math_abs(num))
    
    if num > 0 then
        table.insert(strategies, encode_math_sqrt(num))
    end
    
    -- String conversions
    table.insert(strategies, encode_tonumber_hex(num))
    if num % 8 == num then  -- Only for small numbers
        table.insert(strategies, encode_tonumber_octal(num))
    end
    
    -- Complex encodings
    table.insert(strategies, encode_nested_math(num))
    table.insert(strategies, encode_modulo_trick(num))
    
    -- Return random strategy
    if #strategies > 0 then
        return strategies[math.random(1, #strategies)]
    end
    
    -- Fallback: return as-is
    return { type = ASTBuilder.NODE_TYPES.NUMBER, value = num }
end

--- Encode all numbers in AST
local function encode_numbers_recursive(node)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.NUMBER then
        -- Randomly decide whether to encode this number
        if math.random() < 0.7 then  -- 70% encoding rate
            return select_encoding(node.value)
        end
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        for i, stmt in ipairs(node.body) do
            node.body[i] = encode_numbers_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        node.value = encode_numbers_recursive(node.value)
    
    elseif node_type == ASTBuilder.NODE_TYPES.BINARY_OP then
        node.left = encode_numbers_recursive(node.left)
        node.right = encode_numbers_recursive(node.right)
    
    elseif node_type == ASTBuilder.NODE_TYPES.UNARY_OP then
        node.operand = encode_numbers_recursive(node.operand)
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        for i, arg in ipairs(node.args) do
            node.args[i] = encode_numbers_recursive(arg)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        node.condition = encode_numbers_recursive(node.condition)
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = encode_numbers_recursive(stmt)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = encode_numbers_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        node.condition = encode_numbers_recursive(node.condition)
        for i, stmt in ipairs(node.body) do
            node.body[i] = encode_numbers_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        node.start = encode_numbers_recursive(node.start)
        node.end_val = encode_numbers_recursive(node.end_val)
        if node.step then
            node.step = encode_numbers_recursive(node.step)
        end
        for i, stmt in ipairs(node.body) do
            node.body[i] = encode_numbers_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.TABLE then
        for i, field in ipairs(node.fields) do
            if field.key then
                node.fields[i].value = encode_numbers_recursive(field.value)
            else
                node.fields[i] = encode_numbers_recursive(field)
            end
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.INDEX then
        node.object = encode_numbers_recursive(node.object)
        node.index = encode_numbers_recursive(node.index)
    
    elseif node_type == ASTBuilder.NODE_TYPES.MEMBER then
        node.object = encode_numbers_recursive(node.object)
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        for i, stmt in ipairs(node.body) do
            node.body[i] = encode_numbers_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.RETURN then
        for i, val in ipairs(node.values) do
            node.values[i] = encode_numbers_recursive(val)
        end
    end
    
    return node
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

--- Encode all numbers in AST
function NumberEncoder.encode_numbers(ast, encoding_rate)
    encoding_rate = encoding_rate or 0.7
    
    math.randomseed(os.time() + math.random(1, 999999))
    
    local ast_copy = deep_copy(ast)
    return encode_numbers_recursive(ast_copy)
end

--- Encode with aggressive encoding (90%)
function NumberEncoder.encode_aggressive(ast)
    return NumberEncoder.encode_numbers(ast, 0.9)
end

--- Encode with light encoding (30%)
function NumberEncoder.encode_light(ast)
    return NumberEncoder.encode_numbers(ast, 0.3)
end

--- Count encoded numbers
local function count_encoded(node, count)
    count = count or 0
    
    if not node then
        return count
    end
    
    if node.type == ASTBuilder.NODE_TYPES.BINARY_OP then
        count = count + 1
        count = count_encoded(node.left, count)
        count = count_encoded(node.right, count)
    elseif node.type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        count = count + 1
        for _, arg in ipairs(node.args) do
            count = count_encoded(arg, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            count = count_encoded(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.ASSIGN then
        count = count_encoded(node.value, count)
    elseif node.type == ASTBuilder.NODE_TYPES.IF then
        count = count_encoded(node.condition, count)
        for _, stmt in ipairs(node.then_block) do
            count = count_encoded(stmt, count)
        end
        for _, stmt in ipairs(node.else_block) do
            count = count_encoded(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.WHILE then
        count = count_encoded(node.condition, count)
        for _, stmt in ipairs(node.body) do
            count = count_encoded(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FOR then
        count = count_encoded(node.start, count)
        count = count_encoded(node.end_val, count)
        for _, stmt in ipairs(node.body) do
            count = count_encoded(stmt, count)
        end
    end
    
    return count
end

--- Get encoding statistics
function NumberEncoder.get_stats(ast)
    local encoded_count = count_encoded(ast)
    return {
        encoded_numbers = encoded_count
    }
end

--- Print statistics
function NumberEncoder.print_stats(ast)
    local stats = NumberEncoder.get_stats(ast)
    print("Number Encoding Statistics:")
    print(string.rep("-", 40))
    print(string.format("Encoded Numbers: %d", stats.encoded_numbers))
end

return NumberEncoder
