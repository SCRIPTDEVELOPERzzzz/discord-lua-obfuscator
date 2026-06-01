-- Loader Stub & Packer: 1-liner compatible bootloader
-- Unpacks and decrypts obfuscated code at runtime
-- Includes anti-tamper detection and banner

local LoaderStub = {}
local XXTEA = require("xxtea")

-- Anti-tamper banner
local MONOBOT_BANNER = [[
   __  __                       ____        _   
|  \/  | ___   ___  _ __     | __ )  ___ | |_ 
| |\/| |/ _ \ / _ \| '_ \    |  _ \ / _ \| __|
| |  | | (_) | (_) | | | |   | |_) | (_) | |_ 
|_|  |_|\___/ \___/|_| |_|   |____/ \___/ \__|
                         
MONOBOT - Code Protection System v1.0
WARNING: Unauthorized modification detected!
]]

--- Integrity checksum (simple hash)
local function calculate_checksum(data)
    local sum = 0
    for i = 1, #data do
        sum = (sum + data:byte(i) * i) % 4294967296
    end
    return sum
end

--- Verify integrity
local function verify_integrity(encrypted_code, stored_checksum)
    local actual = calculate_checksum(encrypted_code)
    return actual == stored_checksum
end

--- Create packed payload with metadata
function LoaderStub.pack(code, key, options)
    options = options or {}
    
    -- Encrypt code
    local encrypted = XXTEA.encrypt(code, key)
    local checksum = calculate_checksum(encrypted)
    
    -- Encrypt the checksum for extra security
    local checksum_str = string.char(
        checksum % 256,
        math.floor(checksum / 256) % 256,
        math.floor(checksum / 65536) % 256,
        math.floor(checksum / 16777216) % 256
    )
    
    local encrypted_checksum = XXTEA.encrypt(checksum_str, key)
    
    -- Create metadata
    local metadata = {
        version = 1,
        encrypted_code = XXTEA.encrypt_hex(encrypted, key),
        encrypted_checksum = XXTEA.encrypt_hex(encrypted_checksum, key),
        key_hex = ""
    }
    
    return metadata
end

--- Serialize metadata to Lua table format
function LoaderStub.serialize_metadata(metadata)
    return string.format(
        "{v=%d,c=%q,k=%q}",
        metadata.version,
        metadata.encrypted_code,
        metadata.encrypted_checksum
    )
end

--- Create 1-liner bootloader
function LoaderStub.create_bootloader(encrypted_hex, checksum_hex, key)
    -- Create compact loader in one line
    local loader = string.format(
        "local X=require('xxtea');local e=%q;local c=%q;local k=%q;local d=X.decrypt_hex(e,k);local s=X.decrypt_hex(c,k);load(d)()",
        encrypted_hex,
        checksum_hex,
        key
    )
    return loader
end

--- Create full stub with banner and anti-tamper
function LoaderStub.create_stub(code, key, options)
    options = options or {}
    
    -- Pack the code
    local metadata = LoaderStub.pack(code, key, options)
    
    -- Create banner comment
    local banner_str = "-- " .. MONOBOT_BANNER:gsub("\n", "\n-- ") .. "\n"
    
    -- Anti-tamper checks
    local anti_tamper = [[
-- Anti-Tamper Protection
local function __verify_integrity()
    local integrity_token = "MONOBOT_PROTECTED"
    if debug.gethook then
        error("Debugger detected! Code execution halted.")
    end
    if os.getenv("LUA_CPATH") then
        error("Modified environment detected!")
    end
end

__verify_integrity()
]]
    
    -- Main loader code
    local stub = banner_str .. "\n" .. anti_tamper .. "\n" .. [[
-- Loader Stub - Monobot Protection
local XXTEA = require("xxtea")

local __enc_code = ]] .. string.format("%q", metadata.encrypted_code) .. [[

local __enc_check = ]] .. string.format("%q", metadata.encrypted_checksum) .. [[

local __key = ]] .. string.format("%q", key) .. [[

-- Decrypt and verify
local function __load_protected()
    local decrypted_code = XXTEA.decrypt_hex(__enc_code, __key)
    local decrypted_check = XXTEA.decrypt_hex(__enc_check, __key)
    
    -- Verify integrity
    local actual_checksum = 0
    for i = 1, #decrypted_code do
        actual_checksum = (actual_checksum + decrypted_code:byte(i) * i) % 4294967296
    end
    
    local expected_checksum = 0
    for i = 1, #decrypted_check do
        expected_checksum = expected_checksum + decrypted_check:byte(i) * (2 ^ ((i-1) * 8))
    end
    
    if actual_checksum ~= expected_checksum then
        error("INTEGRITY CHECK FAILED! Code has been tampered with.")
    end
    
    -- Execute decrypted code
    return load(decrypted_code)()
end

return __load_protected()
]]
    
    return stub
end

--- Create minimal 1-liner packer
function LoaderStub.create_oneliner(code, key)
    local encrypted_hex = XXTEA.encrypt_hex(code, key)
    
    -- Ultra-compact: remove all spaces where possible
    local oneliner = string.format(
        "load(require('xttea').decrypt_hex(%q,%q))()",
        encrypted_hex,
        key
    )
    
    return oneliner
end

--- Create stub with obfuscation markers
function LoaderStub.create_obfuscated_stub(code, key, obfuscation_stats)
    obfuscation_stats = obfuscation_stats or {}
    
    local stats_comment = string.format(
        "-- Obfuscation Stats: %d variables renamed, Control Flow Flattened: %s\n",
        obfuscation_stats.variables_renamed or 0,
        obfuscation_stats.control_flow_flattened and "Yes" or "No"
    )
    
    local banner_str = "-- " .. MONOBOT_BANNER:gsub("\n", "\n-- ") .. "\n"
    
    local full_stub = banner_str .. stats_comment .. LoaderStub.create_stub(code, key)
    
    return full_stub
end

--- Unpack and execute (for testing)
function LoaderStub.execute(packed_code, key)
    if type(packed_code) == "string" then
        -- If it's a hex string, decrypt it
        local decrypted = XXTEA.decrypt_hex(packed_code, key)
        return load(decrypted)()
    else
        error("Invalid packed code format")
    end
end

--- Create loader with timestamps and version info
function LoaderStub.create_versioned_stub(code, key, version, timestamp)
    version = version or "1.0"
    timestamp = timestamp or os.date("%Y-%m-%d %H:%M:%S")
    
    local version_comment = string.format(
        "-- Monobot Protected Code v%s [%s]\n",
        version,
        timestamp
    )
    
    local banner_str = "-- " .. MONOBOT_BANNER:gsub("\n", "\n-- ") .. "\n"
    
    local full_stub = banner_str .. version_comment .. LoaderStub.create_stub(code, key)
    
    return full_stub
end

--- Create stub with debugging disabled
function LoaderStub.create_debugproof_stub(code, key)
    local banner_str = "-- " .. MONOBOT_BANNER:gsub("\n", "\n-- ") .. "\n"
    
    local debug_proof = [[
-- Debug-Proof Protection
debug.sethook = function() end
debug.getlocal = function() end
debug.getupvalue = function() end
debug.getinfo = function() end
debug.traceback = function() return "" end

-- Disable common introspection
_G.debug = nil
]]
    
    local metadata = LoaderStub.pack(code, key)
    
    local stub = banner_str .. debug_proof .. "\n" .. [[
local XXTEA = require("xxtea")
local __ec = ]] .. string.format("%q", metadata.encrypted_code) .. [[

local __ck = ]] .. string.format("%q", key) .. [[

return load(XXTEA.decrypt_hex(__ec, __ck))()
]]
    
    return stub
end

--- Generate complete protected bundle
function LoaderStub.bundle(code, key, options)
    options = options or {}
    
    local output = {
        stub = LoaderStub.create_stub(code, key, options),
        oneliner = LoaderStub.create_oneliner(code, key),
        metadata = LoaderStub.pack(code, key, options)
    }
    
    if options.debugproof then
        output.debugproof_stub = LoaderStub.create_debugproof_stub(code, key)
    end
    
    if options.version then
        output.versioned_stub = LoaderStub.create_versioned_stub(
            code, 
            key, 
            options.version, 
            options.timestamp
        )
    end
    
    return output
end

--- Print banner
function LoaderStub.print_banner()
    print(MONOBOT_BANNER)
end

return LoaderStub
