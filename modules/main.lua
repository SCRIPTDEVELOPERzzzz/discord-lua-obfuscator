local ASTBuilder = require("ast_builder")
local Obfuscator = require("obfuscator")
local CodeGenerator = require("code_generator")

local code = ...

local ast = ASTBuilder.parse(code)

ast = Obfuscator.obfuscate_ast(ast)

local result = CodeGenerator.generate(ast)

return result
