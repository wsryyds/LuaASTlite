local Lexer = require("src.Lexer.Lexer")
local Parser = require("src.Parser.Parser")
local TokenType = require("src.Lexer.TokenType")
local Formatter = require("src.Formatter.Formatter")

local LuaAstlite = {
    Lexer = Lexer,
    Parser = Parser,
    TokenType = TokenType,
    Formatter = Formatter
}

--- Tokenize Lua source.
--- @param source string
--- @param options table|nil
--- @return Token[], Lexer
function LuaAstlite.lex(source, options)
    local lexer = Lexer.new(source, options)
    local tokens = {}

    while true do
        local token = lexer:getNextToken()
        tokens[#tokens + 1] = token
        if token.type == TokenType.EOF then
            break
        end
    end

    return tokens, lexer
end

--- Parse Lua source into an AST block.
--- @param source string
--- @param options table|nil
--- @return BlockNode, Parser
function LuaAstlite.parse(source, options)
    local lexer = Lexer.new(source, options)
    local parser = Parser.new(lexer)
    return parser:parseProgram(), parser
end

--- Format an AST block.
--- @param ast BlockNode
--- @param options table|nil
--- @return string
function LuaAstlite.formatAst(ast, options)
    local formatter = Formatter.new(options)
    return formatter:format(ast)
end

--- Parse and format Lua source.
--- @param source string
--- @param options table|nil
--- @return string
function LuaAstlite.format(source, options)
    local ast = LuaAstlite.parse(source, options)
    return LuaAstlite.formatAst(ast, options)
end

return LuaAstlite
