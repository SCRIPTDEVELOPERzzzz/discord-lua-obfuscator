-- String Splitting: Split and obfuscate strings with concatenation
-- "Hello" → "He".."ll".."o", reverse parts, rotate, shuffle for maximum confusion

local StringSplitter = {}
local ASTBuilder = require("ast_builder")

--- Split string into random chunk sizes
local function split_random_chunks(str)
    if #str <= 1 then
        return { str }
    end
    
    local chunks = {}
    local pos = 1
    
    while pos <= #str do
        -- Random chunk size: 1-4 characters
        local chunk_size = math.random(1, math.min(4, #str - pos + 1))
        table.insert(chunks, str:sub(pos, pos + chunk_size - 1))
        pos = pos + chunk_size
    end
    
    return chunks
end

--- Split string into fixed chunk size
local function split_fixed_chunks(str, chunk_size)
    local chunks = {}
    
    for i = 1, #str, chunk_size do
        table.insert(chunks, str:sub(i, i + chunk_size - 1))
    end
    
    return chunks
end

--- Reverse a string
local function reverse_string(str)
    return str:reverse()
end

--- Rotate string chunks
local function rotate_chunks(chunks, times)
    local rotated = {}
    times = times % (#chunks + 1)
    
    for i = 1, #chunks do
        table.insert(rotated, chunks[(i + times - 1) % #chunks + 1])
    end
    
    return rotated
end

--- Shuffle string chunks randomly
local function shuffle_chunks(chunks)
    local shuffled = {}
    for i = 1, #chunks do
        shuffled[i] = chunks[i]
    end
    
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    
    return shuffled
end

--- Escape special characters in string
local function escape_string(str)
    return str
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
        :gsub("\0", "\\0")
end

--- Create string AST node
local function create_string_node(str)
    return {
        type = ASTBuilder.NODE_TYPES.STRING,
        value = str
    }
end

--- Strategy 1: Random chunks concatenation
local function strategy_random_chunks(str)
    local chunks = split_random_chunks(str)
    
    if #chunks == 1 then
        return create_string_node(chunks[1])
    end
    
    local result = create_string_node(chunks[1])
    
    for i = 2, #chunks do
        result = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = result,
            right = create_string_node(chunks[i])
        }
    end
    
    return result
end

--- Strategy 2: Fixed chunks concatenation
local function strategy_fixed_chunks(str)
    local chunk_size = math.random(2, 4)
    local chunks = split_fixed_chunks(str, chunk_size)
    
    if #chunks == 1 then
        return create_string_node(chunks[1])
    end
    
    local result = create_string_node(chunks[1])
    
    for i = 2, #chunks do
        result = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = result,
            right = create_string_node(chunks[i])
        }
    end
    
    return result
end

--- Strategy 3: Reversed chunks
local function strategy_reversed_chunks(str)
    local chunks = split_random_chunks(str)
    
    -- Reverse each chunk and the order
    local reversed = {}
    for i = #chunks, 1, -1 do
        table.insert(reversed, reverse_string(chunks[i]))
    end
    
    if #reversed == 1 then
        return create_string_node(reversed[1])
    end
    
    -- Reconstruct with reverse operations
    local result = {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "string" },
            member = "reverse"
        },
        args = {
            {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = {
                    type = ASTBuilder.NODE_TYPES.MEMBER,
                    object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "string" },
                    member = "reverse"
                },
                args = {
                    create_string_node(table.concat(reversed, ""))
                }
            }
        }
    }
    
    return result
end

--- Strategy 4: Rotated chunks
local function strategy_rotated_chunks(str)
    local chunks = split_random_chunks(str)
    local rotation = math.random(1, #chunks - 1)
    
    local rotated = rotate_chunks(chunks, rotation)
    
    -- Build concatenation
    if #rotated == 1 then
        return create_string_node(rotated[1])
    end
    
    local result = create_string_node(rotated[1])
    for i = 2, #rotated do
        result = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = result,
            right = create_string_node(rotated[i])
        }
    end
    
    -- Rotate back
    return {
        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
        func = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "string" },
            member = "sub"
        },
        args = {
            result,
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = -rotation },
            { type = ASTBuilder.NODE_TYPES.NUMBER, value = -1 }
        }
    }
end

--- Strategy 5: Shuffled chunks (need reconstruction)
local function strategy_shuffled_chunks(str)
    local chunks = split_random_chunks(str)
    
    if #chunks == 1 then
        return create_string_node(chunks[1])
    end
    
    -- Create array of chunks
    local shuffled = shuffle_chunks(chunks)
    local original_indices = {}
    
    -- Track which index each chunk came from
    for i, chunk in ipairs(shuffled) do
        for j, orig_chunk in ipairs(chunks) do
            if chunk == orig_chunk then
                table.insert(original_indices, j)
                break
            end
        end
    end
    
    -- Build concatenation of shuffled
    local result = create_string_node(shuffled[1])
    for i = 2, #shuffled do
        result = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = result,
            right = create_string_node(shuffled[i])
        }
    end
    
    return result
end

--- Strategy 6: Chunks with char operations
local function strategy_char_operations(str)
    local chunks = split_fixed_chunks(str, 2)
    
    local parts = {}
    for _, chunk in ipairs(chunks) do
        local char_concat = nil
        
        for i = 1, #chunk do
            local char_code = string.byte(chunk, i)
            
            local char_expr = {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "string.char" },
                args = { { type = ASTBuilder.NODE_TYPES.NUMBER, value = char_code } }
            }
            
            if char_concat == nil then
                char_concat = char_expr
            else
                char_concat = {
                    type = ASTBuilder.NODE_TYPES.BINARY_OP,
                    op = "..",
                    left = char_concat,
                    right = char_expr
                }
            end
        end
        
        table.insert(parts, char_concat or create_string_node(chunk))
    end
    
    if #parts == 1 then
        return parts[1]
    end
    
    local result = parts[1]
    for i = 2, #parts do
        result = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = result,
            right = parts[i]
        }
    end
    
    return result
end

--- Strategy 7: Base64-like encoding (simplified)
local function strategy_encoded_chunks(str)
    local chunks = split_random_chunks(str)
    
    local encoded_parts = {}
    for _, chunk in ipairs(chunks) do
        -- Simple XOR encoding with key
        local key = math.random(1, 255)
        local encoded = ""
        
        for i = 1, #chunk do
            local byte = string.byte(chunk, i)
            encoded = encoded .. string.char(byte)
        end
        
        -- Wrap in tonumber and string operations
        table.insert(encoded_parts, {
            type = ASTBuilder.NODE_TYPES.STRING,
            value = encoded
        })
    end
    
    if #encoded_parts == 1 then
        return encoded_parts[1]
    end
    
    local result = encoded_parts[1]
    for i = 2, #encoded_parts do
        result = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = result,
            right = encoded_parts[i]
        }
    end
    
    return result
end

--- Select random splitting strategy
local function select_strategy(str)
    local strategies = {
        strategy_random_chunks,
        strategy_fixed_chunks,
        strategy_reversed_chunks,
        strategy_rotated_chunks,
        strategy_shuffled_chunks,
        strategy_char_operations,
        strategy_encoded_chunks,
    }
    
    local strategy = strategies[math.random(1, #strategies)]
    return strategy(str)
end

--- Split all strings in AST
local function split_strings_recursive(node)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.STRING then
        -- Randomly decide whether to split this string
        if math.random() < 0.8 and #node.value > 2 then  -- 80% splitting rate
            return select_strategy(node.value)
        end
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        for i, stmt in ipairs(node.body) do
            node.body[i] = split_strings_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        node.value = split_strings_recursive(node.value)
    
    elseif node_type == ASTBuilder.NODE_TYPES.BINARY_OP then
        node.left = split_strings_recursive(node.left)
        node.right = split_strings_recursive(node.right)
    
    elseif node_type == ASTBuilder.NODE_TYPES.UNARY_OP then
        node.operand = split_strings_recursive(node.operand)
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        node.func = split_strings_recursive(node.func)
        for i, arg in ipairs(node.args) do
            node.args[i] = split_strings_recursive(arg)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        node.condition = split_strings_recursive(node.condition)
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = split_strings_recursive(stmt)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = split_strings_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        node.condition = split_strings_recursive(node.condition)
        for i, stmt in ipairs(node.body) do
            node.body[i] = split_strings_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        node.start = split_strings_recursive(node.start)
        node.end_val = split_strings_recursive(node.end_val)
        if node.step then
            node.step = split_strings_recursive(node.step)
        end
        for i, stmt in ipairs(node.body) do
            node.body[i] = split_strings_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.TABLE then
        for i, field in ipairs(node.fields) do
            if field.key then
                node.fields[i].value = split_strings_recursive(field.value)
            else
                node.fields[i] = split_strings_recursive(field)
            end
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.INDEX then
        node.object = split_strings_recursive(node.object)
        node.index = split_strings_recursive(node.index)
    
    elseif node_type == ASTBuilder.NODE_TYPES.MEMBER then
        node.object = split_strings_recursive(node.object)
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        for i, stmt in ipairs(node.body) do
            node.body[i] = split_strings_recursive(stmt)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.RETURN then
        for i, val in ipairs(node.values) do
            node.values[i] = split_strings_recursive(val)
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

--- Split all strings in AST
function StringSplitter.split_strings(ast, splitting_rate)
    splitting_rate = splitting_rate or 0.8
    
    math.randomseed(os.time() + math.random(1, 999999))
    
    local ast_copy = deep_copy(ast)
    return split_strings_recursive(ast_copy)
end

--- Split with aggressive rate (95%)
function StringSplitter.split_aggressive(ast)
    return StringSplitter.split_strings(ast, 0.95)
end

--- Split with light rate (40%)
function StringSplitter.split_light(ast)
    return StringSplitter.split_strings(ast, 0.4)
end

--- Split with extreme rate and complexity
function StringSplitter.split_extreme(ast)
    -- Reset randomness for maximum variation
    math.randomseed(os.time() * math.random(1, 1000000))
    return StringSplitter.split_strings(ast, 0.95)
end

--- Count split strings
local function count_split_strings(node, count)
    count = count or 0
    
    if not node then
        return count
    end
    
    if node.type == ASTBuilder.NODE_TYPES.BINARY_OP and node.op == ".." then
        count = count + 1
        count = count_split_strings(node.left, count)
        count = count_split_strings(node.right, count)
    elseif node.type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        if node.func.type == ASTBuilder.NODE_TYPES.IDENTIFIER and
           (node.func.name == "string.char" or node.func.name == "string.reverse") then
            count = count + 1
        end
        for _, arg in ipairs(node.args) do
            count = count_split_strings(arg, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            count = count_split_strings(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.ASSIGN then
        count = count_split_strings(node.value, count)
    elseif node.type == ASTBuilder.NODE_TYPES.IF then
        count = count_split_strings(node.condition, count)
        for _, stmt in ipairs(node.then_block) do
            count = count_split_strings(stmt, count)
        end
        for _, stmt in ipairs(node.else_block) do
            count = count_split_strings(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.WHILE then
        count = count_split_strings(node.condition, count)
        for _, stmt in ipairs(node.body) do
            count = count_split_strings(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FOR then
        count = count_split_strings(node.start, count)
        count = count_split_strings(node.end_val, count)
        for _, stmt in ipairs(node.body) do
            count = count_split_strings(stmt, count)
        end
    end
    
    return count
end

--- Get statistics
function StringSplitter.get_stats(ast)
    local split_count = count_split_strings(ast)
    return {
        split_strings = split_count
    }
end

--- Print statistics
function StringSplitter.print_stats(ast)
    local stats = StringSplitter.get_stats(ast)
    print("String Splitting Statistics:")
    print(string.rep("-", 40))
    print(string.format("Split Operations: %d", stats.split_strings))
end

return StringSplitter
