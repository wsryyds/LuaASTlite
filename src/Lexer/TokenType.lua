
-- src/Lexer/TokenType.lua

local TokenType = {
    -- 1. End of File
    EOF = "EOF",

    -- 2. 字面量 (Literals)
    Identifier = "Identifier", -- 变量名/函数名
    String = "String",         -- "text", 'text', [[text]]
    Number = "Number",         -- 123, 0xFF, 1.23, 1e-5

    -- 2.1 注释和空白 (新增)
    Comment = "Comment",       -- 注释 (单行/多行)
    WhiteSpace = "WhiteSpace", -- 空白字符 (可选保留)

    -- 3. 关键字 (Keywords) - Lua 5.3 完整列表
    KwAnd = "and",
    KwBreak = "break",
    KwDo = "do",
    KwElse = "else",
    KwElseif = "elseif",
    KwEnd = "end",
    KwFalse = "false",
    KwFor = "for",
    KwFunction = "function",
    KwGoto = "goto",
    KwIf = "if",
    KwIn = "in",
    KwLocal = "local",
    KwNil = "nil",
    KwNot = "not",
    KwOr = "or",
    KwRepeat = "repeat",
    KwReturn = "return",
    KwThen = "then",
    KwTrue = "true",
    KwUntil = "until",
    KwWhile = "while",

    -- 4. 运算符 (Operators)
    -- 算术运算符
    OpAdd = "+",
    OpSub = "-",
    OpMul = "*",
    OpDiv = "/",
    OpIDiv = "//", -- Lua 5.3 整除
    OpMod = "%",
    OpPow = "^",

    -- 关系运算符
    OpEq = "==",
    OpNe = "~=",
    OpLt = "<",
    OpGt = ">",
    OpLe = "<=",
    OpGe = ">=",

    -- 逻辑运算符
    -- (and, or, not 在关键字中已定义，但语法分析时可能视作操作符)

    -- 位运算符 (Lua 5.3)
    OpBitAnd = "&",
    OpBitOr = "|",
    OpBitXor = "~",
    OpShl = "<<",
    OpShr = ">>",

    -- 字符串连接
    OpConcat = "..",

    -- 长度运算符
    OpLen = "#",

    -- 4.1 复合赋值运算符 (新增 - 用于扩展语法支持)
    OpAddAssign = "+=",
    OpSubAssign = "-=",
    OpMulAssign = "*=",
    OpDivAssign = "/=",
    OpModAssign = "%=",
    OpPowAssign = "^=",
    OpIDivAssign = "//=",
    OpBitAndAssign = "&=",
    OpBitOrAssign = "|=",
    OpConcatAssign = "..=",
    OpShlAssign = "<<=",
    OpShrAssign = ">>=",
    OpArrow = "->",

    -- 5. 符号与定界符 (Punctuations & Delimiters)
    SymAssign = "=",
    SymLParen = "(",
    SymRParen = ")",
    SymLBrace = "{",
    SymRBrace = "}",
    SymLBracket = "[",
    SymRBracket = "]",
    SymSemi = ";",
    SymColon = ":",
    SymComma = ",",
    SymDot = ".",
    SymDoubleColon = "::", -- Lua 5.2+ 标签定义
    SymVararg = "..."      -- 变长参数
}

return TokenType
