-- XXTEA: eXtended eXtended TEA encryption algorithm in pure Lua
-- Encrypts and decrypts data using 128-bit key

local XXTEA = {}

-- XXTEA Constants
local DELTA = 0x9E3779B9
local ROUNDS = 6

--- Convert 4 bytes to 32-bit little-endian unsigned integer
local function bytes_to_uint32(b1, b2, b3, b4)
    return (b1 or 0) + 
           ((b2 or 0) * 256) + 
           ((b3 or 0) * 65536) + 
           ((b4 or 0) * 16777216)
end

--- Convert 32-bit unsigned integer to 4 bytes (little-endian)
local function uint32_to_bytes(n)
    n = n % 4294967296 -- Ensure 32-bit
    local b1 = n % 256
    n = math.floor(n / 256)
    local b2 = n % 256
    n = math.floor(n / 256)
    local b3 = n % 256
    n = math.floor(n / 256)
    local b4 = n % 256
    return b1, b2, b3, b4
end

--- 32-bit addition with wrap-around
local function add32(a, b)
    return (a + b) % 4294967296
end

--- 32-bit subtraction with wrap-around
local function sub32(a, b)
    return (a - b) % 4294967296
end

--- 32-bit left rotate
local function rotl32(n, b)
    n = n % 4294967296
    b = b % 32
    return ((n * (2 ^ b)) % 4294967296) + 
           math.floor(n / (2 ^ (32 - b)))
end

--- 32-bit right rotate
local function rotr32(n, b)
    return rotl32(n, 32 - b)
end

--- Prepare key (16 bytes = 128 bits, or pad if shorter)
local function prepare_key(key)
    if type(key) == "string" then
        key = { key:byte(1, -1) }
    end
    
    local k = {}
    for i = 1, 4 do
        local idx = (i - 1) * 4 + 1
        k[i] = bytes_to_uint32(key[idx], key[idx + 1], key[idx + 2], key[idx + 3])
    end
    
    return k
end

--- Prepare data for encryption (pad to multiple of 4 bytes)
local function prepare_data(data)
    if type(data) == "string" then
        data = { data:byte(1, -1) }
    end
    
    local len = #data
    local padded = {}
    
    for i = 1, len do
        padded[i] = data[i]
    end
    
    -- Store original length in last 4 bytes for decryption
    local padding = (4 - (len % 4)) % 4
    for i = 1, padding do
        padded[len + i] = 0
    end
    
    return padded, len
end

--- Encrypt data with XXTEA algorithm
function XXTEA.encrypt(data, key)
    key = prepare_key(key)
    local data_bytes, orig_len = prepare_data(data)
    
    local n = math.floor(#data_bytes / 4)
    local v = {}
    
    -- Convert bytes to 32-bit words
    for i = 1, n do
        local idx = (i - 1) * 4 + 1
        v[i] = bytes_to_uint32(
            data_bytes[idx],
            data_bytes[idx + 1],
            data_bytes[idx + 2],
            data_bytes[idx + 3]
        )
    end
    
    -- XXTEA encryption
    local z = v[n]
    local y = v[1]
    local sum = 0
    
    for round = 1, ROUNDS do
        sum = add32(sum, DELTA)
        local e = math.floor(sum / 33554432) % 4 -- (sum >> 5) & 3
        
        for i = 1, n do
            y = v[i]
            local mx = add32(
                rotl32(y, 5) + y,
                add32(sum, key[(math.floor(i / 2) % 4) + 1])
            )
            z = add32(z, mx)
            v[i] = z
            z = y
        end
    end
    
    -- Convert words back to bytes with length prefix
    local result = {}
    table.insert(result, orig_len % 256)
    table.insert(result, math.floor(orig_len / 256) % 256)
    table.insert(result, math.floor(orig_len / 65536) % 256)
    table.insert(result, math.floor(orig_len / 16777216) % 256)
    
    for i = 1, n do
        local b1, b2, b3, b4 = uint32_to_bytes(v[i])
        table.insert(result, b1)
        table.insert(result, b2)
        table.insert(result, b3)
        table.insert(result, b4)
    end
    
    return string.char(unpack(result))
end

--- Decrypt data with XXTEA algorithm
function XXTEA.decrypt(encrypted, key)
    key = prepare_key(key)
    
    if type(encrypted) == "string" then
        encrypted = { encrypted:byte(1, -1) }
    end
    
    if #encrypted < 4 then
        error("Encrypted data too short")
    end
    
    -- Extract original length
    local orig_len = encrypted[1] + 
                     (encrypted[2] * 256) + 
                     (encrypted[3] * 65536) + 
                     (encrypted[4] * 16777216)
    
    local n = math.floor((#encrypted - 4) / 4)
    local v = {}
    
    -- Convert bytes to 32-bit words
    for i = 1, n do
        local idx = 4 + (i - 1) * 4 + 1
        v[i] = bytes_to_uint32(
            encrypted[idx],
            encrypted[idx + 1],
            encrypted[idx + 2],
            encrypted[idx + 3]
        )
    end
    
    -- XXTEA decryption
    local z = v[n]
    local y = v[1]
    local sum = add32(DELTA * ROUNDS, 0)
    
    for round = 1, ROUNDS do
        local e = math.floor(sum / 33554432) % 4
        
        for i = n, 1, -1 do
            z = v[i]
            local mx = add32(
                rotl32(y, 5) + y,
                add32(sum, key[(math.floor((i + 1) / 2) % 4) + 1])
            )
            y = sub32(v[i - 1] or z, mx)
            v[i] = y
        end
        sum = sub32(sum, DELTA)
    end
    
    -- Convert words back to bytes and trim to original length
    local result = {}
    for i = 1, n do
        local b1, b2, b3, b4 = uint32_to_bytes(v[i])
        table.insert(result, b1)
        table.insert(result, b2)
        table.insert(result, b3)
        table.insert(result, b4)
    end
    
    return string.char(unpack(result, 1, orig_len))
end

--- Encrypt string (hex-encoded output)
function XXTEA.encrypt_hex(data, key)
    local encrypted = XXTEA.encrypt(data, key)
    local hex = ""
    for i = 1, #encrypted do
        hex = hex .. string.format("%02x", encrypted:byte(i))
    end
    return hex
end

--- Decrypt hex-encoded string
function XXTEA.decrypt_hex(hex, key)
    local encrypted = {}
    for i = 1, #hex, 2 do
        table.insert(encrypted, tonumber(hex:sub(i, i + 1), 16))
    end
    return XXTEA.decrypt(encrypted, key)
end

--- Generate random 16-byte key
function XXTEA.generate_key()
    math.randomseed(os.time() + math.random(1, 999999))
    local key = {}
    for i = 1, 16 do
        table.insert(key, math.random(0, 255))
    end
    return string.char(unpack(key))
end

return XXTEA
