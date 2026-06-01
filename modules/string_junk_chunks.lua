-- String Junk Chunks: Fragment encrypted strings into small chunks
-- Concatenate at runtime: encrypted_a..encrypted_b..encrypted_c..encrypted_d
-- Makes it nearly impossible to grep/scan for patterns in binary

local StringJunkChunks = {}
local ASTBuilder = require("ast_builder")
local XXTEA = require("xxtea")

--- Split encrypted string into random-sized chunks
local function split_encrypted_chunks(encrypted_string, chunk_config)
    chunk_config = chunk_config or {}
    local min_chunk = chunk_config.min_size or 2
    local max_chunk = chunk_config.max_size or 6
    
    local chunks = {}
    local pos = 1
    
    while pos <= #encrypted_string do
        local chunk_size = math.random(min_chunk, math.min(max_chunk, #encrypted_string - pos + 1))
        table.insert(chunks, encrypted_string:sub(pos, pos + chunk_size - 1))
        pos = pos + chunk_size
    end
    
    return chunks
end

--- Create chunk variable assignments
local function create_chunk_variables(chunks, base_name)
    local chunk_vars = {}
    
    for i, chunk in ipairs(chunks) do
        local var_name = base_name .. "_" .. i
        local hex_chunk = ""
        
        -- Convert chunk to hex for safe storage
        for j = 1, #chunk do
            hex_chunk = hex_chunk .. string.format("%02x", string.byte(chunk, j))
        end
        
        table.insert(chunk_vars, {
            var_name = var_name,
            hex_value = hex_chunk,
            chunk = chunk
        })
    end
    
    return chunk_vars
end

--- Create chunk assignments in AST
local function create_chunk_assignment_stmts(chunks, base_name)
    local stmts = {}
    
    for i, chunk in ipairs(chunks) do
        local var_name = base_name .. "_" .. i
        local hex_chunk = ""
        
        -- Convert to hex
        for j = 1, #chunk do
            hex_chunk = hex_chunk .. string.format("%02x", string.byte(chunk, j))
        end
        
        -- Create: __chunk_1 = "hex1hex2hex3..."
        table.insert(stmts, {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = var_name,
                is_local = true
            },
            value = {
                type = ASTBuilder.NODE_TYPES.STRING,
                value = hex_chunk
            }
        })
    end
    
    return stmts
end

--- Create chunk reconstruction (hex to binary)
local function create_chunk_reconstruction_stmts(num_chunks, base_name)
    local stmts = {}
    
    -- Reconstruct each chunk from hex
    for i = 1, num_chunks do
        local var_name = base_name .. "_" .. i
        local hex_var = base_name .. "_hex_" .. i
        
        -- Create: __chunk_hex_1 = tonumber(__chunk_1:sub(1,2), 16)
        -- But we'll do it more complex...
        table.insert(stmts, {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = hex_var,
                is_local = true
            },
            value = {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = {
                    type = ASTBuilder.NODE_TYPES.MEMBER,
                    object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "string" },
                    member = "char"
                },
                args = {
                    {
                        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                        func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "tonumber" },
                        args = {
                            {
                                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                                func = {
                                    type = ASTBuilder.NODE_TYPES.MEMBER,
                                    object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = var_name },
                                    member = "sub"
                                },
                                args = {
                                    { type = ASTBuilder.NODE_TYPES.NUMBER, value = 1 },
                                    { type = ASTBuilder.NODE_TYPES.NUMBER, value = 2 }
                                }
                            },
                            { type = ASTBuilder.NODE_TYPES.NUMBER, value = 16 }
                        }
                    }
                }
            }
        })
    end
    
    return stmts
end

--- Create concatenation expression
local function create_concatenation_expr(num_chunks, base_name, hex_convert)
    hex_convert = hex_convert == nil and true or hex_convert
    
    local chunk_prefix = hex_convert and (base_name .. "_hex_") or (base_name .. "_")
    
    -- Create: __chunk_1 .. __chunk_2 .. __chunk_3 ...
    local expr = {
        type = ASTBuilder.NODE_TYPES.IDENTIFIER,
        name = chunk_prefix .. "1"
    }
    
    for i = 2, num_chunks do
        expr = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = expr,
            right = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = chunk_prefix .. i
            }
        }
    end
    
    return expr
end

--- Fragment encrypted string and create loader stubs
function StringJunkChunks.fragment_encrypted_string(encrypted_hex, num_chunks, base_name)
    base_name = base_name or "__str"
    
    -- Convert hex string back to binary for chunking
    local encrypted_binary = ""
    for i = 1, #encrypted_hex, 2 do
        encrypted_binary = encrypted_binary .. string.char(tonumber(encrypted_hex:sub(i, i + 1), 16))
    end
    
    -- Split into chunks
    local chunks = split_encrypted_chunks(encrypted_binary, {
        min_size = 2,
        max_size = math.max(4, math.floor(#encrypted_binary / num_chunks))
    })
    
    -- Create chunk info
    local chunk_data = {}
    for i, chunk in ipairs(chunks) do
        local hex_chunk = ""
        for j = 1, #chunk do
            hex_chunk = hex_chunk .. string.format("%02x", string.byte(chunk, j))
        end
        
        table.insert(chunk_data, {
            index = i,
            hex = hex_chunk,
            var_name = base_name .. "_" .. i
        })
    end
    
    return {
        chunks = chunk_data,
        total_chunks = #chunk_data,
        base_name = base_name
    }
end

--- Create chunk assignment code (returns Lua code string)
function StringJunkChunks.generate_chunk_code(fragment_data)
    local code_lines = {}
    
    -- Create chunk assignments
    for _, chunk_info in ipairs(fragment_data.chunks) do
        table.insert(code_lines, string.format(
            "local %s = %q",
            chunk_info.var_name,
            chunk_info.hex
        ))
    end
    
    -- Create reconstruction
    for _, chunk_info in ipairs(fragment_data.chunks) do
        local hex_var = chunk_info.var_name .. "_bin"
        table.insert(code_lines, string.format(
            "local %s = (%s:gsub('..', function(c) return string.char(tonumber(c, 16)) end))",
            hex_var,
            chunk_info.var_name
        ))
    end
    
    -- Create concatenation
    local concat_parts = {}
    for i = 1, fragment_data.total_chunks do
        table.insert(concat_parts, fragment_data.base_name .. "_" .. i .. "_bin")
    end
    
    local concat_expr = table.concat(concat_parts, "..")
    table.insert(code_lines, string.format(
        "local %s_reconstructed = %s",
        fragment_data.base_name,
        concat_expr
    ))
    
    return table.concat(code_lines, "\n")
end

--- Create AST nodes for chunk assembly
function StringJunkChunks.create_chunk_assembly_ast(fragment_data, key)
    local stmts = {}
    
    -- 1. Create chunk variable assignments
    for _, chunk_info in ipairs(fragment_data.chunks) do
        table.insert(stmts, {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = chunk_info.var_name,
                is_local = true
            },
            value = {
                type = ASTBuilder.NODE_TYPES.STRING,
                value = chunk_info.hex
            }
        })
    end
    
    -- 2. Create binary reconstruction for each chunk
    for _, chunk_info in ipairs(fragment_data.chunks) do
        local hex_var = chunk_info.var_name .. "_bin"
        
        -- Convert hex string to binary
        table.insert(stmts, {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = hex_var,
                is_local = true
            },
            value = {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = {
                    type = ASTBuilder.NODE_TYPES.MEMBER,
                    object = {
                        type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                        name = chunk_info.var_name
                    },
                    member = "gsub"
                },
                args = {
                    { type = ASTBuilder.NODE_TYPES.STRING, value = ".." },
                    {
                        type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
                        name = nil,
                        params = { "c" },
                        body = {
                            {
                                type = ASTBuilder.NODE_TYPES.RETURN,
                                values = {
                                    {
                                        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                                        func = {
                                            type = ASTBuilder.NODE_TYPES.MEMBER,
                                            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "string" },
                                            member = "char"
                                        },
                                        args = {
                                            {
                                                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                                                func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "tonumber" },
                                                args = {
                                                    { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "c" },
                                                    { type = ASTBuilder.NODE_TYPES.NUMBER, value = 16 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        })
    end
    
    -- 3. Create concatenation
    local concat_expr = {
        type = ASTBuilder.NODE_TYPES.IDENTIFIER,
        name = fragment_data.base_name .. "_1_bin"
    }
    
    for i = 2, fragment_data.total_chunks do
        concat_expr = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "..",
            left = concat_expr,
            right = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = fragment_data.base_name .. "_" .. i .. "_bin"
            }
        }
    end
    
    table.insert(stmts, {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = fragment_data.base_name .. "_reconstructed",
            is_local = true
        },
        value = concat_expr
    })
    
    -- 4. Create decryption call
    if key then
        table.insert(stmts, {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = fragment_data.base_name .. "_decrypted",
                is_local = true
            },
            value = {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = {
                    type = ASTBuilder.NODE_TYPES.MEMBER,
                    object = {
                        type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                        func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "require" },
                        args = { { type = ASTBuilder.NODE_TYPES.STRING, value = "xxtea" } }
                    },
                    member = "decrypt_hex"
                },
                args = {
                    { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = fragment_data.base_name .. "_reconstructed" },
                    { type = ASTBuilder.NODE_TYPES.STRING, value = key }
                }
            }
        })
    end
    
    return stmts
end

--- Fragment all encrypted strings in AST
local function fragment_strings_recursive(node, fragmentation_level)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.STRING then
        -- Strings aren't encrypted yet at AST level, skip
        return node
    
    elseif node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        for i, stmt in ipairs(node.body) do
            node.body[i] = fragment_strings_recursive(stmt, fragmentation_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.ASSIGN then
        node.value = fragment_strings_recursive(node.value, fragmentation_level)
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        node.func = fragment_strings_recursive(node.func, fragmentation_level)
        for i, arg in ipairs(node.args) do
            node.args[i] = fragment_strings_recursive(arg, fragmentation_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        node.condition = fragment_strings_recursive(node.condition, fragmentation_level)
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = fragment_strings_recursive(stmt, fragmentation_level)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = fragment_strings_recursive(stmt, fragmentation_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        node.condition = fragment_strings_recursive(node.condition, fragmentation_level)
        for i, stmt in ipairs(node.body) do
            node.body[i] = fragment_strings_recursive(stmt, fragmentation_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        for i, stmt in ipairs(node.body) do
            node.body[i] = fragment_strings_recursive(stmt, fragmentation_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        for i, stmt in ipairs(node.body) do
            node.body[i] = fragment_strings_recursive(stmt, fragmentation_level)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.RETURN then
        for i, val in ipairs(node.values) do
            node.values[i] = fragment_strings_recursive(val, fragmentation_level)
        end
    end
    
    return node
end

--- Deep copy
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

--- Fragment encrypted strings (for use after encryption)
function StringJunkChunks.fragment_encrypted_strings(encrypted_hex_map)
    -- encrypted_hex_map: { string_id = encrypted_hex, ... }
    -- Returns: { string_id = fragment_data, ... }
    
    local fragmented = {}
    
    for string_id, encrypted_hex in pairs(encrypted_hex_map) do
        local num_chunks = math.random(3, 6)
        fragmented[string_id] = StringJunkChunks.fragment_encrypted_string(
            encrypted_hex,
            num_chunks,
            "__str_" .. string_id
        )
    end
    
    return fragmented
end

--- Create loader code for fragmented strings
function StringJunkChunks.create_fragmented_loader(fragment_data_list, key)
    local stmts = {}
    
    for _, fragment_data in ipairs(fragment_data_list) do
        local assembly_stmts = StringJunkChunks.create_chunk_assembly_ast(fragment_data, key)
        for _, stmt in ipairs(assembly_stmts) do
            table.insert(stmts, stmt)
        end
    end
    
    return {
        type = ASTBuilder.NODE_TYPES.PROGRAM,
        body = stmts
    }
end

--- Get fragmentation statistics
function StringJunkChunks.get_stats(fragment_data_list)
    local total_chunks = 0
    local total_strings = #fragment_data_list
    
    for _, fragment_data in ipairs(fragment_data_list) do
        total_chunks = total_chunks + fragment_data.total_chunks
    end
    
    return {
        total_strings = total_strings,
        total_chunks = total_chunks,
        avg_chunks_per_string = total_chunks / math.max(1, total_strings)
    }
end

--- Print statistics
function StringJunkChunks.print_stats(fragment_data_list)
    local stats = StringJunkChunks.get_stats(fragment_data_list)
    print("String Junk Chunks Statistics:")
    print(string.rep("-", 50))
    print(string.format("Total Strings: %d", stats.total_strings))
    print(string.format("Total Chunks: %d", stats.total_chunks))
    print(string.format("Avg Chunks/String: %.2f", stats.avg_chunks_per_string))
end

return StringJunkChunks
