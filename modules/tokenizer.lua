-- Custom Tokenizer: Pattern matching without LPEG
-- Supports: identifiers, numbers, strings, symbols

local Tokenizer = {}

-- Token types
local TOKEN_TYPES = {
    IDENTIFIER = "identifier",
    NUMBER = "number",
    STRING = "string",
    SYMBOL = "symbol",
    WHITESPACE = "whitespace",
    UNKNOWN = "unknown"
}

-- Pattern definitions
local PATTERNS = {
    -- Numbers: integers and floats (including scientific notation)
    number = "^[0-9]+%.?[0-9]*([eE][+-]?[0-9]+)?",
    
    -- Identifiers: variable names, keywords (letters, digits, underscore)
    identifier = "^[a-zA-Z_][a-zA-Z0-9_]*",
    
    -- Whitespace: spaces, tabs, newlines
    whitespace = "^[ \t\n\r]+",
    
    -- Symbols: operators and punctuation
    symbol = "^[%+%-*/%^=<>!~&|%.,:;%(%)%[%]{}#@$?]+"
}

-- String delimiters: single quote, double quote, and long bracket strings
local STRING_DELIMITERS = {
    ['"'] = { close = '"', escape = true },
    ["'"] = { close = "'", escape = true },
    ["[["] = { close = "]]", escape = false },
    ["[=["] = { close = "]=]", escape = false },
    ["[==["] = { close = "]==]", escape = false },
}

--- Match pattern at current position
local function match_pattern(text, pos, pattern)
    local start, finish = text:find(pattern, pos)
    if start == pos then
        return text:sub(start, finish)
    end
    return nil
end

--- Try to match a string at current position
local function match_string(text, pos)
    -- Try to match long bracket strings first (higher priority)
    for delimiter, config in pairs(STRING_DELIMITERS) do
        if text:sub(pos, pos + #delimiter - 1) == delimiter and config.escape == false then
            local close_pos = text:find(config.close, pos + #delimiter, true)
            if close_pos then
                return text:sub(pos, close_pos + #config.close - 1), config.close
            else
                -- Unterminated string, consume rest of input
                return text:sub(pos), nil
            end
        end
    end
    
    -- Try regular strings (quotes)
    local char = text:sub(pos, pos)
    if STRING_DELIMITERS[char] then
        local config = STRING_DELIMITERS[char]
        local i = pos + 1
        while i <= #text do
            local c = text:sub(i, i)
            
            if c == char and (not config.escape or text:sub(i - 1, i - 1) ~= "\\") then
                return text:sub(pos, i), char
            elseif c == "\\" and config.escape then
                i = i + 2 -- Skip escaped character
            else
                i = i + 1
            end
        end
        -- Unterminated string
        return text:sub(pos), nil
    end
    
    return nil
end

--- Tokenize input text
function Tokenizer.tokenize(text)
    local tokens = {}
    local pos = 1
    
    while pos <= #text do
        local matched = false
        
        -- Try to match string first (highest priority)
        local str_content = match_string(text, pos)
        if str_content then
            table.insert(tokens, {
                type = TOKEN_TYPES.STRING,
                value = str_content,
                pos = pos
            })
            pos = pos + #str_content
            matched = true
        end
        
        -- Try to match whitespace
        if not matched then
            local ws = match_pattern(text, pos, PATTERNS.whitespace)
            if ws then
                table.insert(tokens, {
                    type = TOKEN_TYPES.WHITESPACE,
                    value = ws,
                    pos = pos
                })
                pos = pos + #ws
                matched = true
            end
        end
        
        -- Try to match number
        if not matched then
            local num = match_pattern(text, pos, PATTERNS.number)
            if num then
                table.insert(tokens, {
                    type = TOKEN_TYPES.NUMBER,
                    value = num,
                    pos = pos
                })
                pos = pos + #num
                matched = true
            end
        end
        
        -- Try to match identifier
        if not matched then
            local id = match_pattern(text, pos, PATTERNS.identifier)
            if id then
                table.insert(tokens, {
                    type = TOKEN_TYPES.IDENTIFIER,
                    value = id,
                    pos = pos
                })
                pos = pos + #id
                matched = true
            end
        end
        
        -- Try to match symbol
        if not matched then
            local sym = match_pattern(text, pos, PATTERNS.symbol)
            if sym then
                table.insert(tokens, {
                    type = TOKEN_TYPES.SYMBOL,
                    value = sym,
                    pos = pos
                })
                pos = pos + #sym
                matched = true
            end
        end
        
        -- If nothing matched, consume single character as unknown
        if not matched then
            table.insert(tokens, {
                type = TOKEN_TYPES.UNKNOWN,
                value = text:sub(pos, pos),
                pos = pos
            })
            pos = pos + 1
        end
    end
    
    return tokens
end

--- Filter tokens by type (similar to gmatch)
function Tokenizer.filter(tokens, token_type)
    local filtered = {}
    for _, token in ipairs(tokens) do
        if token.type == token_type then
            table.insert(filtered, token)
        end
    end
    return filtered
end

--- Pretty print tokens
function Tokenizer.print_tokens(tokens, skip_whitespace)
    skip_whitespace = skip_whitespace ~= false
    
    for i, token in ipairs(tokens) do
        if not (skip_whitespace and token.type == TOKEN_TYPES.WHITESPACE) then
            local display_value = token.value:gsub("\n", "\\n"):gsub("\t", "\\t")
            print(string.format(
                "[%3d] %-12s | %-20s | pos: %d",
                i,
                token.type,
                display_value,
                token.pos
            ))
        end
    end
end

-- Expose token types
Tokenizer.TOKEN_TYPES = TOKEN_TYPES

return Tokenizer
