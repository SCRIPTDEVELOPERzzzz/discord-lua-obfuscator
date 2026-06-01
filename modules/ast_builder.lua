-- AST Builder: Parse tokens into Abstract Syntax Tree
-- Handles blocks, assignments, functions, control flow with recursive descent

local ASTBuilder = {}
local Tokenizer = require("tokenizer")

-- Node types for AST
local NODE_TYPES = {
    PROGRAM = "Program",
    BLOCK = "Block",
    ASSIGN = "Assign",
    FUNCTION_DECL = "FunctionDecl",
    FUNCTION_CALL = "FunctionCall",
    RETURN = "Return",
    IF = "If",
    WHILE = "While",
    FOR = "For",
    BINARY_OP = "BinaryOp",
    UNARY_OP = "UnaryOp",
    IDENTIFIER = "Identifier",
    NUMBER = "Number",
    STRING = "String",
    TABLE = "Table",
    INDEX = "Index",
    MEMBER = "Member",
    NIL = "Nil",
    BOOLEAN = "Boolean",
}

-- Keywords
local KEYWORDS = {
    ["function"] = true,
    ["end"] = true,
    ["local"] = true,
    ["return"] = true,
    ["if"] = true,
    ["then"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["while"] = true,
    ["do"] = true,
    ["for"] = true,
    ["in"] = true,
    ["break"] = true,
    ["true"] = true,
    ["false"] = true,
    ["nil"] = true,
    ["and"] = true,
    ["or"] = true,
    ["not"] = true,
}

-- Binary operators (with precedence)
local BINARY_OPS = {
    ["+"] = 10, ["-"] = 10,
    ["*"] = 20, ["/"] = 20, ["%"] = 20,
    ["^"] = 30,
    ["=="] = 5, ["~="] = 5, ["!="] = 5,
    ["<"] = 5, [">"] = 5, ["<="] = 5, [">="] = 5,
    ["and"] = 3, ["or"] = 2,
    [".."] = 8,
}

local UNARY_OPS = { ["-"] = true, ["not"] = true, ["#"] = true }

--- Parser state
local Parser = {
    tokens = {},
    pos = 1,
    current_token = nil,
}

--- Initialize parser
local function init_parser(tokens)
    -- Filter out whitespace tokens
    local filtered = {}
    for _, token in ipairs(tokens) do
        if token.type ~= Tokenizer.TOKEN_TYPES.WHITESPACE then
            table.insert(filtered, token)
        end
    end
    
    Parser.tokens = filtered
    Parser.pos = 1
    Parser.current_token = filtered[1]
end

--- Check if current token is of type
local function check(token_type)
    return Parser.current_token and Parser.current_token.type == token_type
end

--- Check if current value is specific value
local function check_value(value)
    return Parser.current_token and Parser.current_token.value == value
end

--- Check if current value is keyword
local function is_keyword(word)
    return KEYWORDS[word] == true
end

--- Advance to next token
local function advance()
    Parser.pos = Parser.pos + 1
    Parser.current_token = Parser.tokens[Parser.pos]
end

--- Expect and consume token
local function expect(value)
    if not Parser.current_token or Parser.current_token.value ~= value then
        error("Expected '" .. value .. "' but got '" .. 
              (Parser.current_token and Parser.current_token.value or "EOF") .. "'")
    end
    advance()
end

--- Match and consume if value matches
local function match(value)
    if check_value(value) then
        advance()
        return true
    end
    return false
end

--- Forward declarations
local function parse_statement()
end

local function parse_expression()
end

--- Parse primary expression (numbers, strings, identifiers, tables)
local function parse_primary()
    -- Number
    if check(Tokenizer.TOKEN_TYPES.NUMBER) then
        local value = Parser.current_token.value
        advance()
        return {
            type = NODE_TYPES.NUMBER,
            value = tonumber(value)
        }
    end
    
    -- String
    if check(Tokenizer.TOKEN_TYPES.STRING) then
        local value = Parser.current_token.value
        -- Remove quotes
        value = value:sub(2, -2)
        advance()
        return {
            type = NODE_TYPES.STRING,
            value = value
        }
    end
    
    -- Keywords
    if check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
        local value = Parser.current_token.value
        
        if value == "nil" then
            advance()
            return { type = NODE_TYPES.NIL }
        end
        
        if value == "true" then
            advance()
            return { type = NODE_TYPES.BOOLEAN, value = true }
        end
        
        if value == "false" then
            advance()
            return { type = NODE_TYPES.BOOLEAN, value = false }
        end
    end
    
    -- Parenthesized expression
    if match("(") then
        local expr = parse_expression()
        expect(")")
        return expr
    end
    
    -- Table literal
    if match("{") then
        local fields = {}
        while not check_value("}") and Parser.current_token do
            if check(Tokenizer.TOKEN_TYPES.IDENTIFIER) and 
               Parser.tokens[Parser.pos + 1] and 
               Parser.tokens[Parser.pos + 1].value == "=" then
                -- Key-value pair
                local key = Parser.current_token.value
                advance()
                expect("=")
                local value = parse_expression()
                table.insert(fields, { key = key, value = value })
            else
                -- Array element
                table.insert(fields, parse_expression())
            end
            
            if not match(",") then
                break
            end
        end
        expect("}")
        return {
            type = NODE_TYPES.TABLE,
            fields = fields
        }
    end
    
    -- Identifier
    if check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
        local name = Parser.current_token.value
        advance()
        return {
            type = NODE_TYPES.IDENTIFIER,
            name = name
        }
    end
    
    error("Unexpected token: " .. (Parser.current_token and Parser.current_token.value or "EOF"))
end

--- Parse postfix operations (indexing, member access, function calls)
local function parse_postfix()
    local expr = parse_primary()
    
    while Parser.current_token do
        if match("[") then
            -- Index: obj[expr]
            local index = parse_expression()
            expect("]")
            expr = {
                type = NODE_TYPES.INDEX,
                object = expr,
                index = index
            }
        elseif match(".") then
            -- Member: obj.member
            if not check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
                error("Expected identifier after '.'")
            end
            local member = Parser.current_token.value
            advance()
            expr = {
                type = NODE_TYPES.MEMBER,
                object = expr,
                member = member
            }
        elseif match("(") then
            -- Function call: func(args)
            local args = {}
            while not check_value(")") and Parser.current_token do
                table.insert(args, parse_expression())
                if not match(",") then
                    break
                end
            end
            expect(")")
            expr = {
                type = NODE_TYPES.FUNCTION_CALL,
                func = expr,
                args = args
            }
        else
            break
        end
    end
    
    return expr
end

--- Parse unary expressions
local function parse_unary()
    if check(Tokenizer.TOKEN_TYPES.SYMBOL) or check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
        local value = Parser.current_token.value
        if UNARY_OPS[value] then
            advance()
            return {
                type = NODE_TYPES.UNARY_OP,
                op = value,
                operand = parse_unary()
            }
        end
    end
    return parse_postfix()
end

--- Parse binary expressions with operator precedence
local function parse_binary(min_precedence)
    local left = parse_unary()
    
    while Parser.current_token do
        local op = Parser.current_token.value
        local precedence = BINARY_OPS[op]
        
        if not precedence or precedence < min_precedence then
            break
        end
        
        advance()
        local right = parse_binary(precedence + 1)
        left = {
            type = NODE_TYPES.BINARY_OP,
            op = op,
            left = left,
            right = right
        }
    end
    
    return left
end

--- Parse expression
function parse_expression()
    return parse_binary(0)
end

--- Parse assignment or expression statement
local function parse_assignment_or_expr()
    local expr = parse_expression()
    
    -- Check for assignment
    if check_value("=") then
        if expr.type ~= NODE_TYPES.IDENTIFIER and 
           expr.type ~= NODE_TYPES.INDEX and 
           expr.type ~= NODE_TYPES.MEMBER then
            error("Invalid assignment target")
        end
        advance()
        local value = parse_expression()
        return {
            type = NODE_TYPES.ASSIGN,
            target = expr,
            value = value
        }
    end
    
    return expr
end

--- Parse if statement
local function parse_if()
    expect("if")
    local condition = parse_expression()
    expect("then")
    
    local then_block = {}
    while not check_value("end") and not check_value("else") and 
          not check_value("elseif") and Parser.current_token do
        table.insert(then_block, parse_statement())
    end
    
    local else_block = {}
    if match("else") then
        while not check_value("end") and Parser.current_token do
            table.insert(else_block, parse_statement())
        end
    end
    
    expect("end")
    
    return {
        type = NODE_TYPES.IF,
        condition = condition,
        then_block = then_block,
        else_block = else_block
    }
end

--- Parse while loop
local function parse_while()
    expect("while")
    local condition = parse_expression()
    expect("do")
    
    local body = {}
    while not check_value("end") and Parser.current_token do
        table.insert(body, parse_statement())
    end
    
    expect("end")
    
    return {
        type = NODE_TYPES.WHILE,
        condition = condition,
        body = body
    }
end

--- Parse for loop
local function parse_for()
    expect("for")
    if not check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
        error("Expected identifier in for loop")
    end
    local var = Parser.current_token.value
    advance()
    expect("=")
    
    local start = parse_expression()
    expect(",")
    local end_expr = parse_expression()
    
    local step = nil
    if match(",") then
        step = parse_expression()
    end
    
    expect("do")
    
    local body = {}
    while not check_value("end") and Parser.current_token do
        table.insert(body, parse_statement())
    end
    
    expect("end")
    
    return {
        type = NODE_TYPES.FOR,
        var = var,
        start = start,
        end_val = end_expr,
        step = step,
        body = body
    }
end

--- Parse return statement
local function parse_return()
    expect("return")
    local values = {}
    
    if not check_value("end") and not check_value("else") and 
       not check_value("elseif") and Parser.current_token then
        table.insert(values, parse_expression())
        while match(",") do
            table.insert(values, parse_expression())
        end
    end
    
    return {
        type = NODE_TYPES.RETURN,
        values = values
    }
end

--- Parse function declaration
local function parse_function()
    expect("function")
    
    local name = nil
    if check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
        name = Parser.current_token.value
        advance()
    end
    
    expect("(")
    local params = {}
    while not check_value(")") and Parser.current_token do
        if not check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
            error("Expected parameter name")
        end
        table.insert(params, Parser.current_token.value)
        advance()
        if not match(",") then
            break
        end
    end
    expect(")")
    
    local body = {}
    while not check_value("end") and Parser.current_token do
        table.insert(body, parse_statement())
    end
    
    expect("end")
    
    return {
        type = NODE_TYPES.FUNCTION_DECL,
        name = name,
        params = params,
        body = body
    }
end

--- Parse statement
function parse_statement()
    if not Parser.current_token then
        return nil
    end
    
    -- Function declaration
    if check_value("function") then
        return parse_function()
    end
    
    -- If statement
    if check_value("if") then
        return parse_if()
    end
    
    -- While loop
    if check_value("while") then
        return parse_while()
    end
    
    -- For loop
    if check_value("for") then
        return parse_for()
    end
    
    -- Return statement
    if check_value("return") then
        return parse_return()
    end
    
    -- Local declaration
    if match("local") then
        if not check(Tokenizer.TOKEN_TYPES.IDENTIFIER) then
            error("Expected identifier after 'local'")
        end
        local name = Parser.current_token.value
        advance()
        
        local value = nil
        if match("=") then
            value = parse_expression()
        end
        
        return {
            type = NODE_TYPES.ASSIGN,
            target = {
                type = NODE_TYPES.IDENTIFIER,
                name = name,
                is_local = true
            },
            value = value
        }
    end
    
    -- Expression or assignment
    return parse_assignment_or_expr()
end

--- Parse full program
function ASTBuilder.parse(code)
    local tokens = Tokenizer.tokenize(code)
    init_parser(tokens)
    
    local statements = {}
    while Parser.current_token do
        local stmt = parse_statement()
        if stmt then
            table.insert(statements, stmt)
        end
    end
    
    return {
        type = NODE_TYPES.PROGRAM,
        body = statements
    }
end

--- Pretty print AST
function ASTBuilder.print_ast(node, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    
    if node.type == NODE_TYPES.PROGRAM then
        print(prefix .. "Program")
        for _, stmt in ipairs(node.body) do
            ASTBuilder.print_ast(stmt, indent + 1)
        end
    elseif node.type == NODE_TYPES.ASSIGN then
        print(prefix .. "Assign")
        print(prefix .. "  target:")
        ASTBuilder.print_ast(node.target, indent + 2)
        print(prefix .. "  value:")
        if node.value then
            ASTBuilder.print_ast(node.value, indent + 2)
        else
            print(prefix .. "    nil")
        end
    elseif node.type == NODE_TYPES.FUNCTION_CALL then
        print(prefix .. "FunctionCall")
        print(prefix .. "  func:")
        ASTBuilder.print_ast(node.func, indent + 2)
        print(prefix .. "  args:")
        for _, arg in ipairs(node.args) do
            ASTBuilder.print_ast(arg, indent + 2)
        end
    elseif node.type == NODE_TYPES.BINARY_OP then
        print(prefix .. "BinaryOp (" .. node.op .. ")")
        print(prefix .. "  left:")
        ASTBuilder.print_ast(node.left, indent + 2)
        print(prefix .. "  right:")
        ASTBuilder.print_ast(node.right, indent + 2)
    elseif node.type == NODE_TYPES.UNARY_OP then
        print(prefix .. "UnaryOp (" .. node.op .. ")")
        print(prefix .. "  operand:")
        ASTBuilder.print_ast(node.operand, indent + 2)
    elseif node.type == NODE_TYPES.IF then
        print(prefix .. "If")
        print(prefix .. "  condition:")
        ASTBuilder.print_ast(node.condition, indent + 2)
        print(prefix .. "  then:")
        for _, stmt in ipairs(node.then_block) do
            ASTBuilder.print_ast(stmt, indent + 2)
        end
        if #node.else_block > 0 then
            print(prefix .. "  else:")
            for _, stmt in ipairs(node.else_block) do
                ASTBuilder.print_ast(stmt, indent + 2)
            end
        end
    elseif node.type == NODE_TYPES.WHILE then
        print(prefix .. "While")
        print(prefix .. "  condition:")
        ASTBuilder.print_ast(node.condition, indent + 2)
        print(prefix .. "  body:")
        for _, stmt in ipairs(node.body) do
            ASTBuilder.print_ast(stmt, indent + 2)
        end
    elseif node.type == NODE_TYPES.FOR then
        print(prefix .. "For (" .. node.var .. ")")
        print(prefix .. "  start:")
        ASTBuilder.print_ast(node.start, indent + 2)
        print(prefix .. "  end:")
        ASTBuilder.print_ast(node.end_val, indent + 2)
        if node.step then
            print(prefix .. "  step:")
            ASTBuilder.print_ast(node.step, indent + 2)
        end
        print(prefix .. "  body:")
        for _, stmt in ipairs(node.body) do
            ASTBuilder.print_ast(stmt, indent + 2)
        end
    elseif node.type == NODE_TYPES.FUNCTION_DECL then
        print(prefix .. "FunctionDecl (" .. (node.name or "anonymous") .. ")")
        print(prefix .. "  params: " .. table.concat(node.params, ", "))
        print(prefix .. "  body:")
        for _, stmt in ipairs(node.body) do
            ASTBuilder.print_ast(stmt, indent + 2)
        end
    elseif node.type == NODE_TYPES.RETURN then
        print(prefix .. "Return")
        for _, val in ipairs(node.values) do
            ASTBuilder.print_ast(val, indent + 1)
        end
    elseif node.type == NODE_TYPES.IDENTIFIER then
        local local_str = node.is_local and " (local)" or ""
        print(prefix .. "Identifier: " .. node.name .. local_str)
    elseif node.type == NODE_TYPES.NUMBER then
        print(prefix .. "Number: " .. node.value)
    elseif node.type == NODE_TYPES.STRING then
        print(prefix .. "String: \"" .. node.value .. "\"")
    elseif node.type == NODE_TYPES.TABLE then
        print(prefix .. "Table")
        for _, field in ipairs(node.fields) do
            if field.key then
                print(prefix .. "  [" .. field.key .. "]:")
                ASTBuilder.print_ast(field.value, indent + 2)
            else
                ASTBuilder.print_ast(field, indent + 1)
            end
        end
    elseif node.type == NODE_TYPES.INDEX then
        print(prefix .. "Index")
        print(prefix .. "  object:")
        ASTBuilder.print_ast(node.object, indent + 2)
        print(prefix .. "  index:")
        ASTBuilder.print_ast(node.index, indent + 2)
    elseif node.type == NODE_TYPES.MEMBER then
        print(prefix .. "Member: " .. node.member)
        print(prefix .. "  object:")
        ASTBuilder.print_ast(node.object, indent + 2)
    elseif node.type == NODE_TYPES.BOOLEAN then
        print(prefix .. "Boolean: " .. tostring(node.value))
    elseif node.type == NODE_TYPES.NIL then
        print(prefix .. "Nil")
    else
        print(prefix .. node.type)
    end
end

ASTBuilder.NODE_TYPES = NODE_TYPES

return ASTBuilder
