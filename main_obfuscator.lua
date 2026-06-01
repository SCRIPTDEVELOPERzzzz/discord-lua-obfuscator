local Tokenizer = require("tokenizer")
local ASTBuilder = require("ast_builder")
local CodeGenerator = require("code_generator")
local Obfuscator = require("obfuscator")
local NumberEncoder = require("number_encoder")
local StringSplitter = require("string_splitter")
local DeadCodeInserter = require("dead_code_inserter")
local FakeIfChainGenerator = require("fake_if_chain_generator")
local FunctionWrapper = require("function_wrapper")
local AntiDebug = require("anti_debug")

local input_file = arg[1]
local output_file = arg[2]

if not input_file or not output_file then
    error("Usage: lua main_obfuscator.lua <input.lua> <output.lua>")
end

local file = io.open(input_file, 'r')
if not file then
    error("Cannot open input file: " .. input_file)
end
local code = file:read('*a')
file:close()

if not code or #code == 0 then
    error("Input file is empty")
end

print("🔄 Obfuscating...")

local ast = ASTBuilder.parse(code)
ast = Obfuscator.obfuscate_ast(ast)
ast = NumberEncoder.encode_numbers(ast, 0.7)
ast = StringSplitter.split_strings(ast, 0.8)
ast = DeadCodeInserter.insert_dead_code(ast, 0.3)
ast = FakeIfChainGenerator.insert_fake_if_chains(ast, 0.4)
ast = FunctionWrapper.wrap_functions(ast, 2)
ast = AntiDebug.insert_anti_debug(ast, 0.3)

local obfuscated = CodeGenerator.generate(ast)

local out_file = io.open(output_file, 'w')
if not out_file then
    error("Cannot open output file: " .. output_file)
end
out_file:write(obfuscated)
out_file:close()

print("✅ Complete!")
