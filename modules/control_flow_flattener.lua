-- Control Flow Flattening: Convert structured control flow to state machine
-- Transforms nested if/while/for into a single while(true) loop with state transitions
-- Makes code very difficult to reverse engineer and understand

local ControlFlowFlattener = {}
local ASTBuilder = require("ast_builder")

--- State machine generator
local Flattener = {
    state_counter = 0,
    blocks = {}, -- Map of state -> block statements
    transitions = {}, -- Map of state -> next state(s)
    current_state = 0,
    entry_state = 0,
}

--- Generate new state ID
local function new_state()
    Flattener.state_counter = Flattener.state_counter + 1
    return Flattener.state_counter
end

--- Create assignment: state = value
local function create_state_assign(value)
    return {
        type = ASTBuilder.NODE_TYPES.ASSIGN,
        target = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = "__state"
        },
        value = {
            type = ASTBuilder.NODE_TYPES.NUMBER,
            value = value
        }
    }
end

--- Create condition: state == value
local function create_state_condition(value)
    return {
        type = ASTBuilder.NODE_TYPES.BINARY_OP,
        op = "==",
        left = {
            type = ASTBuilder.NODE_TYPES.IDENTIFIER,
            name = "__state"
        },
        right = {
            type = ASTBuilder.NODE_TYPES.NUMBER,
            value = value
        }
    }
end

--- Create break statement (as return with nil)
local function create_break()
    return {
        type = ASTBuilder.NODE_TYPES.RETURN,
        values = {}
    }
end

--- Flatten statement and return entry state, exit state
local function flatten_statement(stmt, entry_state)
    if not stmt then
        return entry_state, entry_state
    end
    
    local stmt_type = stmt.type
    
    if stmt_type == ASTBuilder.NODE_TYPES.ASSIGN then
        -- Simple assignment: add to current block
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        table.insert(Flattener.blocks[entry_state], stmt)
        return entry_state, entry_state
    
    elseif stmt_type == ASTBuilder.NODE_TYPES.FUNCTION_CALL then
        -- Function call: add to current block
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        table.insert(Flattener.blocks[entry_state], stmt)
        return entry_state, entry_state
    
    elseif stmt_type == ASTBuilder.NODE_TYPES.IF then
        -- If statement: create branching states
        local then_entry = new_state()
        local else_entry = new_state()
        local exit_state = new_state()
        
        -- Entry state: conditional jump
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        
        -- Store condition in a temporary variable for complex conditions
        local condition = stmt.condition
        
        -- Create conditional state assignment
        local cond_state = new_state()
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        
        -- Jump based on condition
        local true_next = then_entry
        local false_next = (#stmt.else_block > 0) and else_entry or exit_state
        
        -- Add state-based conditional
        if not Flattener.blocks[cond_state] then
            Flattener.blocks[cond_state] = {}
        end
        
        table.insert(Flattener.blocks[cond_state], {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = condition,
            then_block = { create_state_assign(then_entry) },
            else_block = { create_state_assign(false_next) }
        })
        
        table.insert(Flattener.blocks[entry_state], create_state_assign(cond_state))
        
        -- Flatten then block
        local then_last = cond_state
        for _, s in ipairs(stmt.then_block) do
            local _, last = flatten_statement(s, then_entry)
            then_last = last
        end
        
        if not Flattener.blocks[then_last] then
            Flattener.blocks[then_last] = {}
        end
        table.insert(Flattener.blocks[then_last], create_state_assign(exit_state))
        
        -- Flatten else block
        if #stmt.else_block > 0 then
            local else_last = else_entry
            for _, s in ipairs(stmt.else_block) do
                local _, last = flatten_statement(s, else_entry)
                else_last = last
            end
            
            if not Flattener.blocks[else_last] then
                Flattener.blocks[else_last] = {}
            end
            table.insert(Flattener.blocks[else_last], create_state_assign(exit_state))
        end
        
        return entry_state, exit_state
    
    elseif stmt_type == ASTBuilder.NODE_TYPES.WHILE then
        -- While loop: create state loop
        local loop_check = new_state()
        local loop_body = new_state()
        local loop_exit = new_state()
        
        -- Entry goes to loop check
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        table.insert(Flattener.blocks[entry_state], create_state_assign(loop_check))
        
        -- Loop check: conditional
        if not Flattener.blocks[loop_check] then
            Flattener.blocks[loop_check] = {}
        end
        
        table.insert(Flattener.blocks[loop_check], {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = stmt.condition,
            then_block = { create_state_assign(loop_body) },
            else_block = { create_state_assign(loop_exit) }
        })
        
        -- Flatten loop body
        local last_in_body = loop_body
        for _, s in ipairs(stmt.body) do
            local _, last = flatten_statement(s, loop_body)
            last_in_body = last
        end
        
        -- Loop back to check
        if not Flattener.blocks[last_in_body] then
            Flattener.blocks[last_in_body] = {}
        end
        table.insert(Flattener.blocks[last_in_body], create_state_assign(loop_check))
        
        return entry_state, loop_exit
    
    elseif stmt_type == ASTBuilder.NODE_TYPES.FOR then
        -- For loop: convert to while with state machine
        local init_state = new_state()
        local check_state = new_state()
        local body_state = new_state()
        local increment_state = new_state()
        local exit_state = new_state()
        
        -- Initialize loop variable
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        table.insert(Flattener.blocks[entry_state], create_state_assign(init_state))
        
        if not Flattener.blocks[init_state] then
            Flattener.blocks[init_state] = {}
        end
        
        -- Initial assignment: var = start
        table.insert(Flattener.blocks[init_state], {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = stmt.var
            },
            value = stmt.start
        })
        
        table.insert(Flattener.blocks[init_state], create_state_assign(check_state))
        
        -- Check state: var <= end
        if not Flattener.blocks[check_state] then
            Flattener.blocks[check_state] = {}
        end
        
        local step_val = stmt.step or {
            type = ASTBuilder.NODE_TYPES.NUMBER,
            value = 1
        }
        
        table.insert(Flattener.blocks[check_state], {
            type = ASTBuilder.NODE_TYPES.IF,
            condition = {
                type = ASTBuilder.NODE_TYPES.BINARY_OP,
                op = "<=",
                left = {
                    type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                    name = stmt.var
                },
                right = stmt.end_val
            },
            then_block = { create_state_assign(body_state) },
            else_block = { create_state_assign(exit_state) }
        })
        
        -- Body state: execute loop body
        local last_in_body = body_state
        for _, s in ipairs(stmt.body) do
            local _, last = flatten_statement(s, body_state)
            last_in_body = last
        end
        
        -- Increment state: var = var + step
        if not Flattener.blocks[last_in_body] then
            Flattener.blocks[last_in_body] = {}
        end
        table.insert(Flattener.blocks[last_in_body], create_state_assign(increment_state))
        
        if not Flattener.blocks[increment_state] then
            Flattener.blocks[increment_state] = {}
        end
        
        table.insert(Flattener.blocks[increment_state], {
            type = ASTBuilder.NODE_TYPES.ASSIGN,
            target = {
                type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                name = stmt.var
            },
            value = {
                type = ASTBuilder.NODE_TYPES.BINARY_OP,
                op = "+",
                left = {
                    type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                    name = stmt.var
                },
                right = step_val
            }
        })
        
        table.insert(Flattener.blocks[increment_state], create_state_assign(check_state))
        
        return entry_state, exit_state
    
    elseif stmt_type == ASTBuilder.NODE_TYPES.RETURN then
        -- Return: end state machine
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        table.insert(Flattener.blocks[entry_state], stmt)
        return entry_state, entry_state
    
    elseif stmt_type == ASTBuilder.NODE_TYPES.FUNCTION_DECL then
        -- Function declaration: keep as-is but flatten body
        local func_copy = {
            type = stmt.type,
            name = stmt.name,
            params = stmt.params,
            body = {}
        }
        
        for _, s in ipairs(stmt.body) do
            flatten_statement(s, entry_state)
        end
        
        if not Flattener.blocks[entry_state] then
            Flattener.blocks[entry_state] = {}
        end
        
        -- Rebuild function with flattened body
        table.insert(Flattener.blocks[entry_state], {
            type = ASTBuilder.NODE_TYPES.FUNCTION_DECL,
            name = stmt.name,
            params = stmt.params,
            body = ControlFlowFlattener.flatten_ast({
                type = ASTBuilder.NODE_TYPES.PROGRAM,
                body = stmt.body
            }).body
        })
        
        return entry_state, entry_state
    end
    
    return entry_state, entry_state
end

--- Build state machine from flattened blocks
local function build_state_machine()
    local cases = {}
    
    for state_id, block_stmts in pairs(Flattener.blocks) do
        if block_stmts and #block_stmts > 0 then
            table.insert(cases, {
                state = state_id,
                stmts = block_stmts
            })
        end
    end
    
    -- Sort by state ID for consistent ordering
    table.sort(cases, function(a, b) return a.state < b.state end)
    
    -- Create giant if-elseif chain
    local state_chain = nil
    
    for i = #cases, 1, -1 do
        local case = cases[i]
        local condition = create_state_condition(case.state)
        
        if state_chain == nil then
            state_chain = {
                type = ASTBuilder.NODE_TYPES.IF,
                condition = condition,
                then_block = case.stmts,
                else_block = {}
            }
        else
            state_chain = {
                type = ASTBuilder.NODE_TYPES.IF,
                condition = condition,
                then_block = case.stmts,
                else_block = { state_chain }
            }
        end
    end
    
    -- Wrap in while(true) loop with state machine
    local while_loop = {
        type = ASTBuilder.NODE_TYPES.WHILE,
        condition = {
            type = ASTBuilder.NODE_TYPES.BOOLEAN,
            value = true
        },
        body = {
            state_chain or {
                type = ASTBuilder.NODE_TYPES.RETURN,
                values = {}
            }
        }
    }
    
    return while_loop
end

--- Flatten AST into state machine
function ControlFlowFlattener.flatten_ast(ast)
    Flattener.state_counter = 0
    Flattener.blocks = {}
    Flattener.entry_state = new_state()
    
    local current = Flattener.entry_state
    
    for _, stmt in ipairs(ast.body) do
        local _, exit = flatten_statement(stmt, current)
        current = exit
    end
    
    -- Finalize with exit
    local final_state = new_state()
    if not Flattener.blocks[current] then
        Flattener.blocks[current] = {}
    end
    table.insert(Flattener.blocks[current], create_state_assign(final_state))
    
    if not Flattener.blocks[final_state] then
        Flattener.blocks[final_state] = {}
    end
    table.insert(Flattener.blocks[final_state], create_break())
    
    -- Build state machine
    local state_machine = build_state_machine()
    
    -- Wrap in function initialization
    return {
        type = ASTBuilder.NODE_TYPES.PROGRAM,
        body = {
            {
                type = ASTBuilder.NODE_TYPES.ASSIGN,
                target = {
                    type = ASTBuilder.NODE_TYPES.IDENTIFIER,
                    name = "__state",
                    is_local = true
                },
                value = {
                    type = ASTBuilder.NODE_TYPES.NUMBER,
                    value = Flattener.entry_state
                }
            },
            state_machine
        }
    }
end

--- Get statistics about flattening
function ControlFlowFlattener.get_stats()
    return {
        total_states = Flattener.state_counter,
        total_blocks = table.getn(Flattener.blocks),
        entry_state = Flattener.entry_state
    }
end

--- Print state machine structure (for debugging)
function ControlFlowFlattener.print_state_machine()
    print("State Machine Structure:")
    print(string.rep("=", 50))
    
    local states = {}
    for state_id in pairs(Flattener.blocks) do
        table.insert(states, state_id)
    end
    table.sort(states)
    
    for _, state_id in ipairs(states) do
        local block = Flattener.blocks[state_id]
        print(string.format("\nState %d:", state_id))
        print("  Statements: " .. #block)
        for i, stmt in ipairs(block) do
            print(string.format("    [%d] %s", i, stmt.type))
        end
    end
    
    print("\n" .. string.rep("=", 50))
    local stats = ControlFlowFlattener.get_stats()
    print(string.format("Total States: %d", stats.total_states))
    print(string.format("Total Blocks: %d", stats.total_blocks))
    print(string.format("Entry State: %d", stats.entry_state))
end

return ControlFlowFlattener
