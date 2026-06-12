
-- src/Lexer/Token.lua

local Class = require("src.Core.Class")

--- @class Token
local Token = Class("Token")

--- Token 构造函数
--- @param type string TokenType 枚举值
--- @param value any Token 的实际值 (字符串或数字)
--- @param line number 行号
--- @param column number 列号 (在该行的起始索引)
--- @param startPos number 在源码字符串中的绝对起始位置
function Token:constructor(type, value, line, column, startPos)
    self.type = type
    self.value = value
    self.line = line
    self.column = column
    self.startPos = startPos
    -- 新增属性
    self.varType = nil      -- "local" | "global" | "upvalue" (仅标识符)
    self.style = nil        -- 语法模式标记 (如 "Table.Field", "Table:Method" 等)
    self.commentType = nil  -- "line" | "block" (仅注释 Token)
end

--- 获取 Token 的字符串表示，主要用于调试
--- @return string Token 的格式化字符串 "[Type] 'Value' (Ln:Col)"
function Token:toString()
    -- 格式化输出: [Type] 'Value' (Ln:Col)
    local valStr = tostring(self.value)
    if self.type == "String" then
        valStr = '"' .. valStr .. '"'
    end
    return string.format("[%s] '%s' (Ln:%d, Col:%d)", self.type, valStr, self.line, self.column)
end

return Token
