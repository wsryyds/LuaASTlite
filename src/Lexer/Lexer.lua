-- src/Lexer/Lexer.lua

local Class = require("src.Core.Class")
local Token = require("src.Lexer.Token")
local TokenType = require("src.Lexer.TokenType")

local hasUtf8, utf8Lib = pcall(require, "utf8")
if not hasUtf8 then
    utf8Lib = nil
end

--- @class Lexer
local Lexer = Class("Lexer")

-- 关键字映射表
local KEYWORDS = {
    ["and"] = TokenType.KwAnd,
    ["break"] = TokenType.KwBreak,
    ["do"] = TokenType.KwDo,
    ["else"] = TokenType.KwElse,
    ["elseif"] = TokenType.KwElseif,
    ["end"] = TokenType.KwEnd,
    ["false"] = TokenType.KwFalse,
    ["for"] = TokenType.KwFor,
    ["function"] = TokenType.KwFunction,
    ["goto"] = TokenType.KwGoto,
    ["if"] = TokenType.KwIf,
    ["in"] = TokenType.KwIn,
    ["local"] = TokenType.KwLocal,
    ["nil"] = TokenType.KwNil,
    ["not"] = TokenType.KwNot,
    ["or"] = TokenType.KwOr,
    ["repeat"] = TokenType.KwRepeat,
    ["return"] = TokenType.KwReturn,
    ["then"] = TokenType.KwThen,
    ["true"] = TokenType.KwTrue,
    ["until"] = TokenType.KwUntil,
    ["while"] = TokenType.KwWhile
}

--- Lexer 构造函数
--- @param source string 源代码字符串
--- @param options table|nil 配置选项 {preserveComments: boolean, preserveWhitespace: boolean}
function Lexer:constructor(source, options)
    self.source = source
    self.length = #source
    self.pos = 1
    self.line = 1
    self.lineStart = 1
    self.current = nil

    -- 新增: options 参数支持
    self.options = options or {}
    self.preserveComments = self.options.preserveComments or false
    self.preserveWhitespace = self.options.preserveWhitespace or false
    self.comments = {}  -- 收集的注释列表

    -- 1. 处理 UTF-8 BOM (0xEF, 0xBB, 0xBF)
    -- 很多带有中文的 Lua 文件会有这个不可见的文件头
    if self.length >= 3 and string.sub(self.source, 1, 3) == "\239\187\191" then
        self.pos = 4
    end

    self:_updateCurrent()

    -- 2. 处理 Shebang (#!/usr/bin/lua)
    self:skipShebang()
end

--- 更新当前字符（内部方法）
function Lexer:_updateCurrent()
    if self.pos > self.length then
        self.current = nil
    else
        self.current = string.sub(self.source, self.pos, self.pos)
    end
end

--- 前进指定步数
--- @param steps number|nil 前进步数，默认为 1
function Lexer:advance(steps)
    steps = steps or 1
    for _ = 1, steps do
        if self.current == "\n" then
            self.line = self.line + 1
            self.lineStart = self.pos + 1
        end
        self.pos = self.pos + 1
        self:_updateCurrent()
    end
end

--- 查看指定偏移位置的字符
--- @param offset number 相对当前位置的偏移量
--- @return string|nil 该位置的字符，超出范围返回 nil
function Lexer:peek(offset)
    local p = self.pos + offset
    if p > self.length then return nil end
    return string.sub(self.source, p, p)
end

--- 判断字符是否为数字
--- @param char string|nil 待检查的字符
--- @return boolean
function Lexer:isDigit(char) return char and string.match(char, "%d") end

--- 判断字符是否为十六进制数字
--- @param char string|nil 待检查的字符
--- @return boolean
function Lexer:isHexDigit(char) return char and string.match(char, "%x") end

--- 判断字符是否为字母或下划线
--- @param char string|nil 待检查的字符
--- @return boolean
function Lexer:isAlpha(char) return char and string.match(char, "[%a_]") end

--- 判断字符是否为字母、数字或下划线
--- @param char string|nil 待检查的字符
--- @return boolean
function Lexer:isAlphaNumeric(char) return char and string.match(char, "[%w_]") end

--- 创建 Token 对象
--- @param type string Token 类型
--- @param value any Token 值
--- @param startPos number 起始位置
--- @return Token 新创建的 Token 对象
function Lexer:makeToken(type, value, startPos)
    local column = startPos - self.lineStart + 1
    return Token.new(type, value, self._savedStartLine or self.line, column, startPos)
end

--- 获取当前位置附近的源代码片段用于错误提示
--- @param maxLen number|nil 最大长度，默认20
--- @return string 源代码片段
function Lexer:getNearbySource(maxLen)
    maxLen = maxLen or 20
    local endPos = math.min(self.pos + maxLen, self.length)
    local snippet = string.sub(self.source, self.pos, endPos)
    -- 截断到第一个换行符
    local newlinePos = string.find(snippet, "\n")
    if newlinePos then
        snippet = string.sub(snippet, 1, newlinePos - 1)
    end
    if #snippet == 0 then
        return "<eof>"
    end
    return snippet
end

--- 抛出词法错误，包含详细的位置和上下文信息
--- @param message string 错误描述
--- @param errorType string|nil 错误类型（可选）
function Lexer:error(message, errorType)
    local line = self.line
    local column = self.pos - self.lineStart + 1
    local nearby = self:getNearbySource()
    local errTypeStr = errorType and ("[" .. errorType .. "] ") or ""
    error(string.format("Lexical Error at line %d, col %d: %s%s (near '%s')",
        line, column, errTypeStr, message, nearby))
end

--- 跳过 Shebang #!...
function Lexer:skipShebang()
    -- 如果是 BOM 之后或者文件开头就是 #
    if self.current == "#" and self:peek(1) == "!" then
        while self.current and self.current ~= "\n" do
            self:advance()
        end
        -- 注意：这里不消耗换行符，留给 skipWhitespace 处理行号增加
    end
end

--- 跳过空白字符和注释
--- @return Token|nil 如果 preserveComments 为 true 且遇到注释，返回注释 Token
function Lexer:skipWhitespaceAndComments()
    while true do
        local c = self.current
        if c == " " or c == "\t" or c == "\n" or c == "\r" then
            self:advance()
        elseif c == "-" and self:peek(1) == "-" then
            -- 使用新的 readComment 方法处理注释
            local commentToken = self:readComment()
            if commentToken then
                -- 如果 preserveComments 为 true，返回注释 Token
                return commentToken
            end
            -- 否则继续跳过
        else
            break
        end
    end
    return nil
end

--- 跳过单行注释
function Lexer:skipLineComment()
    while self.current and self.current ~= "\n" do
        self:advance()
    end
end

--- 读取注释 (新增方法)
--- @return Token|nil 注释 Token (如果 preserveComments 为 true)
function Lexer:readComment()
    local startPos = self.pos
    local startLine = self.line
    local startColumn = self.pos - self.lineStart + 1
    
    self:advance(2) -- Skip --
    
    local isBlock = false
    local content = ""
    
    if self.current == "[" then
        local sepLevel = self:checkLongBracketLevel()
        if sepLevel >= 0 then
            isBlock = true
            content = self:readLongCommentBody(sepLevel)
        end
    end
    
    if not isBlock then
        -- 单行注释
        local contentStart = self.pos
        while self.current and self.current ~= "\n" do
            self:advance()
        end
        content = string.sub(self.source, contentStart, self.pos - 1)
    end
    
    local token = Token.new(
        TokenType.Comment,
        content,
        startLine,
        startColumn,
        startPos
    )
    token.commentType = isBlock and "block" or "line"
    
    self.comments[#self.comments + 1] = token
    
    if self.preserveComments then
        return token
    end
    
    return nil
end

--- 读取长注释内容 (新增方法)
--- @param sepLevel number 分隔符等级
--- @return string 注释内容
function Lexer:readLongCommentBody(sepLevel)
    local startLine = self.line
    local startColumn = self.pos - self.lineStart + 1
    self:advance(2 + sepLevel) -- Skip [=..=[
    if self.current == "\n" then self:advance() end
    local contentStart = self.pos
    local contentEnd = self.pos
    while self.current do
        if self.current == "]" then
            local p = 1
            local potentialEndLevel = 0
            while self:peek(p) == "=" do
                potentialEndLevel = potentialEndLevel + 1
                p = p + 1
            end
            if self:peek(p) == "]" and potentialEndLevel == sepLevel then
                contentEnd = self.pos - 1
                self:advance(2 + sepLevel)
                return string.sub(self.source, contentStart, contentEnd)
            end
        end
        self:advance()
    end
    local expectedClose = "]" .. string.rep("=", sepLevel) .. "]"
    self:error(string.format("Unterminated long comment started at line %d, col %d, expected '%s'", 
        startLine, startColumn, expectedClose), "UnfinishedLongComment")
end

--- 检查长括号等级 (用于长字符串和长注释)
--- @return number 等级数，-1 表示不是长括号
function Lexer:checkLongBracketLevel()
    local p = 0
    if self:peek(p) ~= "[" then return -1 end
    p = p + 1
    local level = 0
    while self:peek(p) == "=" do
        level = level + 1
        p = p + 1
    end
    if self:peek(p) == "[" then return level end
    return -1
end

--- 读取数字字面量
--- @return Token 数字 Token
function Lexer:readNumber()
    local startPos = self.pos
    local startLine = self.line
    local startColumn = self.pos - self.lineStart + 1
    local isHex = false
    if self.current == "0" and (self:peek(1) == "x" or self:peek(1) == "X") then
        isHex = true
        self:advance(2)
    end
    local function consumeDigits(checkHex)
        while checkHex and self:isHexDigit(self.current) or (not checkHex and self:isDigit(self.current)) do
            self:advance()
        end
    end
    consumeDigits(isHex)
    if self.current == "." and self:peek(1) ~= "." then
        self:advance()
        consumeDigits(isHex)
    end
    local exponentChar = isHex and "[pP]" or "[eE]"
    if self.current and string.match(self.current, exponentChar) then
        self:advance()
        if self.current == "+" or self.current == "-" then self:advance() end
        consumeDigits(false)
    end

    local text = string.sub(self.source, startPos, self.pos - 1)
    local value = tonumber(text)
    if not value then 
        self:error(string.format("Malformed number '%s' at line %d, col %d", 
            text, startLine, startColumn), "InvalidNumber") 
    end
    return self:makeToken(TokenType.Number, value, startPos)
end

--- 读取标识符或关键字
--- @return Token 标识符或关键字 Token
function Lexer:readIdentifier()
    local startPos = self.pos
    while self:isAlphaNumeric(self.current) do
        self:advance()
    end
    local text = string.sub(self.source, startPos, self.pos - 1)
    local type = KEYWORDS[text] or TokenType.Identifier
    return self:makeToken(type, text, startPos)
end

--- 读取字符串字面量（支持转义序列）
--- @param quote string 引号字符 ('"' 或 "'")
--- @return Token 字符串 Token
function Lexer:readString(quote)
    local startPos = self.pos
    local startLine = self.line
    local startColumn = self.pos - self.lineStart + 1
    self:advance() -- eat quote
    local parts = {}

    while self.current and self.current ~= quote do
        if self.current == "\\" then
            self:advance() -- eat \
            local esc = self.current

            if not esc then 
                self:error(string.format("Unfinished string escape sequence near <eof>, string started at line %d, col %d", 
                    startLine, startColumn), "UnfinishedString") 
            end

            if esc == "a" then
                parts[#parts + 1] = "\a"; self:advance()
            elseif esc == "b" then
                parts[#parts + 1] = "\b"; self:advance()
            elseif esc == "f" then
                parts[#parts + 1] = "\f"; self:advance()
            elseif esc == "n" then
                parts[#parts + 1] = "\n"; self:advance()
            elseif esc == "r" then
                parts[#parts + 1] = "\r"; self:advance()
            elseif esc == "t" then
                parts[#parts + 1] = "\t"; self:advance()
            elseif esc == "v" then
                parts[#parts + 1] = "\v"; self:advance()
            elseif esc == "\\" then
                parts[#parts + 1] = "\\"; self:advance()
            elseif esc == "\"" then
                parts[#parts + 1] = "\""; self:advance()
            elseif esc == "'" then
                parts[#parts + 1] = "'"; self:advance()
            elseif esc == "\n" then
                parts[#parts + 1] = "\n"; self:advance()
            elseif esc == "z" then
                self:advance()
                while self.current and string.match(self.current, "%s") do self:advance() end
            elseif self:isDigit(esc) then -- \ddd
                local numStr = esc
                self:advance()
                if self:isDigit(self.current) then
                    numStr = numStr .. self.current
                    self:advance()
                    if self:isDigit(self.current) then
                        numStr = numStr .. self.current
                        self:advance()
                    end
                end
                local n = tonumber(numStr)
                if not n or n > 255 then 
                    self:error(string.format("Decimal escape '\\%s' too large (max 255)", numStr), "InvalidEscape") 
                end
                parts[#parts + 1] = string.char(n)
            elseif esc == "x" then -- \xXX
                self:advance()
                local h1 = self.current
                self:advance()
                local h2 = self.current
                self:advance()
                if not h1 or not h2 then 
                    self:error("Hexadecimal escape '\\x' requires exactly 2 hex digits", "InvalidEscape") 
                end
                local hex = h1 .. h2
                local n = tonumber(hex, 16)
                if not n then 
                    self:error(string.format("Invalid hexadecimal escape '\\x%s'", hex), "InvalidEscape") 
                end
                parts[#parts + 1] = string.char(n)
            elseif esc == "u" then
                self:advance()
                if self.current ~= "{" then 
                    self:error("Missing '{' in Unicode escape '\\u', expected '\\u{XXXX}'", "InvalidEscape") 
                end
                self:advance()

                local hexStart = self.pos
                while self.current and self.current ~= "}" do
                    self:advance()
                end

                if self.current ~= "}" then 
                    self:error("Missing '}' in Unicode escape '\\u{...}'", "InvalidEscape") 
                end
                local hex = string.sub(self.source, hexStart, self.pos - 1)
                self:advance()

                if hex == "" then 
                    self:error("Empty Unicode escape '\\u{}'", "InvalidEscape") 
                end

                local n = tonumber(hex, 16)
                if not n or n > 0x10FFFF then 
                    self:error(string.format("Invalid Unicode escape '\\u{%s}' (max 10FFFF)", hex), "InvalidEscape") 
                end

                if utf8Lib then
                    parts[#parts + 1] = utf8Lib.char(n)
                else
                    error("Runtime Error: parser requires Lua 5.3+ 'utf8' library to process \\u escapes")
                end
            else
                self:error(string.format("Invalid escape sequence '\\%s'", tostring(esc)), "InvalidEscape")
            end
        elseif self.current == "\n" or self.current == "\r" then
            self:error(string.format("Unfinished string before line break, string started at line %d, col %d",
                startLine, startColumn), "UnfinishedString")
        else
            parts[#parts + 1] = self.current
            self:advance()
        end
    end

    if self.current ~= quote then 
        self:error(string.format("Unfinished string near <eof>, string started at line %d, col %d", 
            startLine, startColumn), "UnfinishedString") 
    end
    self:advance()
    return self:makeToken(TokenType.String, table.concat(parts), startPos)
end

--- 读取长字符串内容
--- @param sepLevel number 分隔符等级
--- @param isComment boolean 是否为注释
--- @return Token|nil 字符串 Token，如果是注释则返回 nil
function Lexer:readLongStringBody(sepLevel, isComment)
    local startPos = self.pos
    local startLine = self.line
    local startColumn = self.pos - self.lineStart + 1
    self:advance(2 + sepLevel)
    if self.current == "\n" then self:advance() end
    local contentStart = self.pos
    local contentEnd = self.pos
    while self.current do
        if self.current == "]" then
            local p = 1
            local potentialEndLevel = 0
            while self:peek(p) == "=" do
                potentialEndLevel = potentialEndLevel + 1
                p = p + 1
            end
            if self:peek(p) == "]" and potentialEndLevel == sepLevel then
                contentEnd = self.pos - 1
                self:advance(2 + sepLevel)
                if isComment then return nil end
                local content = string.sub(self.source, contentStart, contentEnd)
                return self:makeToken(TokenType.String, content, startPos)
            end
        end
        self:advance()
    end
    local expectedClose = "]" .. string.rep("=", sepLevel) .. "]"
    local itemType = isComment and "long comment" or "long string"
    self:error(string.format("Unfinished %s near <eof>, started at line %d, col %d, expected '%s'", 
        itemType, startLine, startColumn, expectedClose), "UnfinishedLongString")
end

--- 获取下一个 Token
--- @return Token 下一个 Token
function Lexer:getNextToken()
    -- 处理空白和注释，如果 preserveComments 为 true 则返回注释 Token
    local commentToken = self:skipWhitespaceAndComments()
    if commentToken then
        return commentToken
    end
    
    self._savedStartLine = self.line
    local startPos = self.pos
    local c = self.current

    if not c then return self:makeToken(TokenType.EOF, "EOF", startPos) end
    if self:isAlpha(c) then return self:readIdentifier() end
    if self:isDigit(c) then return self:readNumber() end
    if c == '"' or c == "'" then return self:readString(c) end

    if c == "." then
        if self:isDigit(self:peek(1)) then
            return self:readNumber()
        elseif self:peek(1) == "." then
            if self:peek(2) == "." then
                self:advance(3); return self:makeToken(TokenType.SymVararg, "...", startPos)
            elseif self:peek(2) == "=" then
                -- 新增: ..= 复合赋值运算符
                self:advance(3); return self:makeToken(TokenType.OpConcatAssign, "..=", startPos)
            else
                self:advance(2); return self:makeToken(TokenType.OpConcat, "..", startPos)
            end
        else
            self:advance(); return self:makeToken(TokenType.SymDot, ".", startPos)
        end
    end

    if c == "[" then
        local sepLevel = self:checkLongBracketLevel()
        if sepLevel >= 0 then
            return self:readLongStringBody(sepLevel, false)
        else
            self:advance(); return self:makeToken(TokenType.SymLBracket, "[", startPos)
        end
    end

    local nextC = self:peek(1)
    local thirdC = self:peek(2)
    
    -- 新增: 三字符运算符检查
    if nextC and thirdC then
        local threeChar = c .. nextC .. thirdC
        local threeCharMap = {
            ["//="] = TokenType.OpIDivAssign,
            ["<<="] = TokenType.OpShlAssign,
            [">>="] = TokenType.OpShrAssign
        }
        if threeCharMap[threeChar] then
            self:advance(3); return self:makeToken(threeCharMap[threeChar], threeChar, startPos)
        end
    end
    
    -- 两字符运算符检查 (包含新增的复合赋值运算符)
    local twoCharMap = {
        ["=="] = TokenType.OpEq,
        ["~="] = TokenType.OpNe,
        ["<="] = TokenType.OpLe,
        [">="] = TokenType.OpGe,
        ["//"] = TokenType.OpIDiv,
        ["<<"] = TokenType.OpShl,
        [">>"] = TokenType.OpShr,
        ["::"] = TokenType.SymDoubleColon,
        -- 新增: 复合赋值运算符
        ["+="] = TokenType.OpAddAssign,
        ["-="] = TokenType.OpSubAssign,
        ["*="] = TokenType.OpMulAssign,
        ["/="] = TokenType.OpDivAssign,
        ["%="] = TokenType.OpModAssign,
        ["^="] = TokenType.OpPowAssign,
        ["&="] = TokenType.OpBitAndAssign,
        ["|="] = TokenType.OpBitOrAssign,
        ["->"] = TokenType.OpArrow
    }
    if nextC then
        local twoChar = c .. nextC
        if twoCharMap[twoChar] then
            self:advance(2); return self:makeToken(twoCharMap[twoChar], twoChar, startPos)
        end
    end

    local oneCharMap = {
        ["+"] = TokenType.OpAdd,
        ["-"] = TokenType.OpSub,
        ["*"] = TokenType.OpMul,
        ["/"] = TokenType.OpDiv,
        ["%"] = TokenType.OpMod,
        ["^"] = TokenType.OpPow,
        ["#"] = TokenType.OpLen,
        ["&"] = TokenType.OpBitAnd,
        ["|"] = TokenType.OpBitOr,
        ["~"] = TokenType.OpBitXor,
        ["<"] = TokenType.OpLt,
        [">"] = TokenType.OpGt,
        ["="] = TokenType.SymAssign,
        ["("] = TokenType.SymLParen,
        [")"] = TokenType.SymRParen,
        ["{"] = TokenType.SymLBrace,
        ["}"] = TokenType.SymRBrace,
        ["]"] = TokenType.SymRBracket,
        [";"] = TokenType.SymSemi,
        [":"] = TokenType.SymColon,
        [","] = TokenType.SymComma
    }
    if oneCharMap[c] then
        self:advance(); return self:makeToken(oneCharMap[c], c, startPos)
    end

    -- 提供更详细的非法字符错误信息
    local charCode = string.byte(c)
    local charDesc = c
    if charCode < 32 or charCode > 126 then
        charDesc = string.format("\\x%02X", charCode)
    end
    self:error(string.format("Unexpected character '%s' (code: %d)", charDesc, charCode), "UnexpectedCharacter")
end

return Lexer
