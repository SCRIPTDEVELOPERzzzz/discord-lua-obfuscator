-- Anti-Debug Checks: Insert debug detection and halting code
-- Makes debugging nearly impossible by detecting and rejecting debugger access
-- Simple but effective: if debug.getinfo then error() end

local AntiDebug = {}
local ASTBuilder = require("ast_builder")

--- Anti-debug check strategies
local ANTI_DEBUG_STRATEGIES = {
    -- 1. Check debug.getinfo (most common debugger interface)
    "debug_getinfo",
    -- 2. Check debug.gethook (hook detection)
    "debug_gethook",
    -- 3. Check debug.getlocal (local variable inspection)
    "debug_getlocal",
    -- 4. Check debug.getupvalue (closure inspection)
    "debug_getupvalue",
    -- 5. Check debug.getinfo with specific function
    "debug_getinfo_func",
    -- 6. Multiple simultaneous checks
    "multi_check",
    -- 7. Indirect checks (timing, behavior analysis)
    "indirect_check",
    -- 8. Hook verification
    "hook_verify",
}

--- Create debug.getinfo check
local function create_debug_getinfo_check()
    return {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                member = "getinfo"
            }
        },
        then_block = {
            {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "error" },
                args = {
                    { type = ASTBuilder.NODE_TYPES.STRING, value = "Debug interface detected!" }
                }
            }
        },
        else_block = {}
    }
end

--- Create debug.gethook check
local function create_debug_gethook_check()
    return {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                member = "gethook"
            }
        },
        then_block = {
            {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "error" },
                args = {
                    { type = ASTBuilder.NODE_TYPES.STRING, value = "Debugger hook detected!" }
                }
            }
        },
        else_block = {}
    }
end

--- Create debug.getlocal check
local function create_debug_getlocal_check()
    return {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                member = "getlocal"
            }
        },
        then_block = {
            {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "error" },
                args = {
                    { type = ASTBuilder.NODE_TYPES.STRING, value = "Local inspection detected!" }
                }
            }
        },
        else_block = {}
    }
end

--- Create debug.getupvalue check
local function create_debug_getupvalue_check()
    return {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                member = "getupvalue"
            }
        },
        then_block = {
            {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "error" },
                args = {
                    { type = ASTBuilder.NODE_TYPES.STRING, value = "Closure inspection detected!" }
                }
            }
        },
        else_block = {}
    }
end

--- Create comprehensive multi-check
local function create_multi_check()
    -- Check multiple debug functions
    local condition = {
        type = ASTBuilder.NODE_TYPES.BINARY_OP,
        op = "or",
        left = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                member = "getinfo"
            }
        },
        right = {
            type = ASTBuilder.NODE_TYPES.BINARY_OP,
            op = "or",
            left = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = {
                    type = ASTBuilder.NODE_TYPES.MEMBER,
                    object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                    member = "gethook"
                }
            },
            right = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = {
                    type = ASTBuilder.NODE_TYPES.MEMBER,
                    object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                    member = "getlocal"
                }
            }
        }
    }
    
    return {
        type = ASTBuilder.NODE_TYPES.IF,
        condition = condition,
        then_block = {
            {
                type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
                func = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "error" },
                args = {
                    { type = ASTBuilder.NODE_TYPES.STRING, value = "Debug environment detected - execution halted!" }
                }
            }
        },
        else_block = {}
    }
end

--- Create indirect detection via timing
local function create_indirect_check()
    -- Use timing to detect debugger pauses
    return {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = "__t1",
            is_local = true
        },
        value = {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "os" },
                member = "clock"
            },
            args = {}
        }
    }
end

--- Create hook verification
local function create_hook_verify()
    -- Verify no debug hooks are installed
    return {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = "__hook",
            is_local = true
        },
        value = {
            type = ASTBuilder.NODE_TYPES.FUNCTION_CALL,
            func = {
                type = ASTBuilder.NODE_TYPES.MEMBER,
                object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
                member = "gethook"
            },
            args = {}
        }
    }
end

--- Select random anti-debug check
local function select_anti_debug_check()
    local checks = {
        create_debug_getinfo_check,
        create_debug_gethook_check,
        create_debug_getlocal_check,
        create_debug_getupvalue_check,
        create_multi_check,
    }
    
    local check_fn = checks[math.random(1, #checks)]
    return check_fn()
end

--- Create debug environment disabling code
local function create_debug_disable()
    local stmts = {}
    
    -- Disable debug functions
    table.insert(stmts, {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
            member = "getinfo"
        },
        value = { type = ASTBuilder.NODE_TYPES.NIL }
    })
    
    table.insert(stmts, {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
            member = "gethook"
        },
        value = { type = ASTBuilder.NODE_TYPES.NIL }
    })
    
    table.insert(stmts, {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
            member = "getlocal"
        },
        value = { type = ASTBuilder.NODE_TYPES.NIL }
    })
    
    table.insert(stmts, {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.MEMBER,
            object = { type = ASTBuilder.NODE_TYPES.IDENTIFIER, name = "debug" },
            member = "getupvalue"
        },
        value = { type = ASTBuilder.NODE_TYPES.NIL }
    })
    
    table.insert(stmts, {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = "_G.debug"
        },
        value = { type = ASTBuilder.NODE_TYPES.NIL }
    })
    
    return stmts
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

--- Insert anti-debug checks at specific locations
local function insert_anti_debug_recursive(node, insertion_rate, strategy)
    if not node then
        return node
    end
    
    local node_type = node.type
    
    if node_type == ASTBuilder.NODE_TYPES.PROGRAM then
        -- Add check at start of program
        if math.random() < insertion_rate then
            table.insert(node.body, 1, select_anti_debug_check())
        end
        
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_anti_debug_recursive(stmt, insertion_rate, strategy)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        -- Add check at start of each function
        if math.random() < insertion_rate then
            table.insert(node.body, 1, select_anti_debug_check())
        end
        
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_anti_debug_recursive(stmt, insertion_rate, strategy)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.IF then
        for i, stmt in ipairs(node.then_block) do
            node.then_block[i] = insert_anti_debug_recursive(stmt, insertion_rate, strategy)
        end
        for i, stmt in ipairs(node.else_block) do
            node.else_block[i] = insert_anti_debug_recursive(stmt, insertion_rate, strategy)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.WHILE then
        if math.random() < insertion_rate then
            table.insert(node.body, 1, select_anti_debug_check())
        end
        
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_anti_debug_recursive(stmt, insertion_rate, strategy)
        end
    
    elseif node_type == ASTBuilder.NODE_TYPES.FOR then
        if math.random() < insertion_rate then
            table.insert(node.body, 1, select_anti_debug_check())
        end
        
        for i, stmt in ipairs(node.body) do
            node.body[i] = insert_anti_debug_recursive(stmt, insertion_rate, strategy)
        end
    end
    
    return node
end

--- Create anti-debug banner/header
function AntiDebug.create_anti_debug_header()
    return {
        type = ASTBuilder.NODE_TYPES.PROGRAM,
        body = {
            -- Multi-check at start
            create_multi_check(),
            -- Disable debug functions
            {
                type = ASTBuilder.NODE_TYPES.ASSIGN,
                target = {
                    type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                    name = "_G.debug",
                    is_local = false
                },
                value = { type = ASTBuilder.NODE_TYPES.NIL }
            }
        }
    }
end

--- Insert anti-debug checks into AST
function AntiDebug.insert_anti_debug(ast, insertion_rate, aggressive)
    insertion_rate = insertion_rate or 0.3
    
    math.randomseed(os.time() + math.random(1, 999999))
    
    local ast_copy = deep_copy(ast)
    
    -- If aggressive, disable debug first
    if aggressive then
        for _, stmt in ipairs(create_debug_disable()) do
            table.insert(ast_copy.body, 1, stmt)
        end
    end
    
    return insert_anti_debug_recursive(ast_copy, insertion_rate, aggressive)
end

--- Insert with light checks (20%)
function AntiDebug.insert_light(ast)
    return AntiDebug.insert_anti_debug(ast, 0.2, false)
end

--- Insert with medium checks (40%)
function AntiDebug.insert_medium(ast)
    return AntiDebug.insert_anti_debug(ast, 0.4, false)
end

--- Insert with aggressive checks (60% + disable debug)
function AntiDebug.insert_aggressive(ast)
    return AntiDebug.insert_anti_debug(ast, 0.6, true)
end

--- Insert with extreme checks (90% + aggressive disabling)
function AntiDebug.insert_extreme(ast)
    return AntiDebug.insert_anti_debug(ast, 0.9, true)
end

--- Create anti-debug initialization code
function AntiDebug.create_init_code()
    local code = [[
-- Anti-Debug Initialization
if debug.getinfo then error("Debug detected!") end
if debug.gethook then error("Hook detected!") end
if debug.getlocal then error("Local inspection detected!") end
debug.getinfo = nil
debug.gethook = nil
debug.getlocal = nil
debug.getupvalue = nil
_G.debug = nil
]]
    return code
end

--- Generate anti-debug code as string (for direct insertion)
function AntiDebug.generate_anti_debug_code()
    return {
        {
            check = "getinfo",
            code = 'if debug.getinfo then error("Debug: getinfo") end'
        },
        {
            check = "gethook",
            code = 'if debug.gethook then error("Debug: gethook") end'
        },
        {
            check = "getlocal",
            code = 'if debug.getlocal then error("Debug: getlocal") end'
        },
        {
            check = "getupvalue",
            code = 'if debug.getupvalue then error("Debug: getupvalue") end'
        },
        {
            check = "multi",
            code = 'if debug.getinfo or debug.gethook or debug.getlocal then error("Debug detected") end'
        },
        {
            check = "disable",
            code = 'debug.getinfo = nil; debug.gethook = nil; debug.getlocal = nil; debug.getupvalue = nil; _G.debug = nil'
        }
    }
end

--- Count anti-debug checks
local function count_anti_debug_checks(node, count)
    count = count or 0
    
    if not node then
        return count
    end
    
    if node.type == ASTBuilder.NODE_TYPES.IF then
        -- Check if condition involves debug
        local condition_str = tostring(node.condition)
        if condition_str:find("debug") then
            count = count + 1
        end
        
        for _, stmt in ipairs(node.then_block) do
            count = count_anti_debug_checks(stmt, count)
        end
        for _, stmt in ipairs(node.else_block) do
            count = count_anti_debug_checks(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.PROGRAM then
        for _, stmt in ipairs(node.body) do
            count = count_anti_debug_checks(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        for _, stmt in ipairs(node.body) do
            count = count_anti_debug_checks(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.WHILE then
        for _, stmt in ipairs(node.body) do
            count = count_anti_debug_checks(stmt, count)
        end
    elseif node.type == ASTBuilder.NODE_TYPES.FOR then
        for _, stmt in ipairs(node.body) do
            count = count_anti_debug_checks(stmt, count)
        end
    end
    
    return count
end

--- Get statistics
function AntiDebug.get_stats(ast)
    local check_count = count_anti_debug_checks(ast)
    return {
        anti_debug_checks = check_count
    }
end

--- Print statistics
function AntiDebug.print_stats(ast)
    local stats = AntiDebug.get_stats(ast)
    print("Anti-Debug Statistics:")
    print(string.rep("-", 40))
    print(string.format("Debug Checks: %d", stats.anti_debug_checks))
end

return AntiDebug
