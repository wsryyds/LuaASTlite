-- src/Parser/Parser.lua

local Class = require("src.Core.Class")
local TokenType = require("src.Lexer.TokenType")
local Expr = require("src.Ast.Expression")
local Stmt = require("src.Ast.Statement")
local ScopeManager = require("src.Scope.ScopeManager")

--- @class Parser
local Parser = Class("Parser")

-- 优先级常量
local PRECEDENCE = {
    [TokenType.KwOr] = 1,
    [TokenType.KwAnd] = 2,
    [TokenType.OpEq] = 3,
    [TokenType.OpNe] = 3,
    [TokenType.OpLt] = 3,
    [TokenType.OpGt] = 3,
    [TokenType.OpLe] = 3,
    [TokenType.OpGe] = 3,
    [TokenType.OpBitOr] = 4,
    [TokenType.OpBitXor] = 5,
    [TokenType.OpBitAnd] = 6,
    [TokenType.OpShl] = 7,
    [TokenType.OpShr] = 7,
    [TokenType.OpConcat] = 8,
    [TokenType.OpAdd] = 9,
    [TokenType.OpSub] = 9,
    [TokenType.OpMul] = 10,
    [TokenType.OpDiv] = 10,
    [TokenType.OpIDiv] = 10,
    [TokenType.OpMod] = 10,
    [TokenType.OpPow] = 12
}

--- Parser 构造函数
--- @param lexer Lexer 词法分析器实例
function Parser:constructor(lexer)
    self.lexer = lexer
    self.currentToken = nil
    self.peekToken = nil
    self.loopDepth = 0
    -- 新增：作用域管理器
    self.scopeManager = ScopeManager.new()
    self:advance()
end

--- 前进到下一个 Token
function Parser:advance()
    self.previousToken = self.currentToken
    self.currentToken = self.peekToken
    if self.lexer then
        self.peekToken = self.lexer:getNextToken()
    else
        self.peekToken = nil
    end
    if self.currentToken == nil and self.previousToken == nil then
        self.currentToken = self.peekToken
        self.peekToken = self.lexer:getNextToken()
    end
end

--- 消费指定类型的 Token
--- @param tokenType string 期望的 Token 类型
--- @return Token 被消费的 Token
function Parser:eat(tokenType)
    if self.currentToken.type == tokenType then
        self:advance()
        return self.previousToken
    else
        self:error(string.format("Expected '%s', got '%s' (value: '%s')", 
            tokenType, self.currentToken.type, tostring(self.currentToken.value)))
    end
end

--- 检查当前 Token 是否为指定类型
--- @param tokenType string Token 类型
--- @return boolean
function Parser:check(tokenType)
    return self.currentToken.type == tokenType
end

--- 获取 Token 的友好描述
--- @param token table Token 对象
--- @return string Token 描述
function Parser:getTokenDescription(token)
    if not token then return "<nil>" end
    if token.type == TokenType.EOF then return "<eof>" end
    if token.type == TokenType.Identifier then
        return string.format("identifier '%s'", token.value)
    elseif token.type == TokenType.Number then
        return string.format("number '%s'", token.value)
    elseif token.type == TokenType.String then
        local strVal = tostring(token.value)
        if #strVal > 20 then
            strVal = string.sub(strVal, 1, 17) .. "..."
        end
        return string.format("string '%s'", strVal)
    else
        return string.format("'%s'", token.value or token.type)
    end
end

--- 抛出语法错误，包含详细的位置和上下文信息
--- @param message string 错误描述
--- @param errorType string|nil 错误类型（可选）
function Parser:error(message, errorType)
    local token = self.currentToken
    local tokenDesc = self:getTokenDescription(token)
    local errTypeStr = errorType and ("[" .. errorType .. "] ") or ""
    local msg = string.format("Syntax Error at line %d, col %d: %s%s\n  Got: %s",
        token.line, token.column, errTypeStr, message, tokenDesc)
    error(msg)
end

-- ============================================================
--  Expression Parsing
-- ============================================================

--- 解析表达式（使用优先级爬升算法）
--- @param minPrecedence number|nil 最小优先级，默认为 0
--- @return Expression 表达式 AST 节点
function Parser:parseExpression(minPrecedence)
    minPrecedence = minPrecedence or 0
    local node = self:parsePrefixExpression()

    while true do
        local opType = self.currentToken.type
        local precedence = PRECEDENCE[opType] or 0
        if precedence <= minPrecedence then break end

        local nextMinPrecedence = precedence
        if opType == TokenType.OpPow or opType == TokenType.OpConcat then
            nextMinPrecedence = precedence - 1
        end

        local operator = self.currentToken
        self:advance()

        local right = self:parseExpression(nextMinPrecedence)
        local binaryNode = Expr.BinaryExpressionNode.new(operator, node, right)
        binaryNode:setLocation(node.startToken, right.endToken)
        node = binaryNode
    end
    return node
end

--- 解析前缀表达式（一元运算符）
--- @return Expression 表达式 AST 节点
function Parser:parsePrefixExpression()
    local token = self.currentToken
    if token.type == TokenType.KwNot or token.type == TokenType.OpLen or
        token.type == TokenType.OpSub or token.type == TokenType.OpBitXor then
        self:advance()
        local operand = self:parseExpression(11)
        local node = Expr.UnaryExpressionNode.new(token, operand)
        node:setLocation(token, operand.endToken)
        return node
    end
    return self:parseSuffixedExpression()
end

--- 解析后缀表达式（成员访问、函数调用等）
--- @return Expression 表达式 AST 节点
function Parser:parseSuffixedExpression()
    local node = self:parsePrimaryExpression()
    while true do
        if self.currentToken.type == TokenType.SymDot then
            self:advance()
            local nameToken = self:eat(TokenType.Identifier)
            local identifier = Expr.IdentifierNode.new(nameToken.value)
            identifier:setLocation(nameToken, nameToken)
            local newNode = Expr.MemberExpressionNode.new(node, ".", identifier)
            newNode:setLocation(node.startToken, nameToken)
            node = newNode
        elseif self.currentToken.type == TokenType.SymLBracket then
            self:advance()
            local indexExp = self:parseExpression()
            local endToken = self:eat(TokenType.SymRBracket)
            local newNode = Expr.MemberExpressionNode.new(node, "[", indexExp)
            newNode:setLocation(node.startToken, endToken)
            node = newNode
        elseif self.currentToken.type == TokenType.SymColon then
            self:advance()
            local nameToken = self:eat(TokenType.Identifier)
            local methodId = Expr.IdentifierNode.new(nameToken.value)
            methodId._isMethodName = true
            methodId:setLocation(nameToken, nameToken)
            local args, endToken = self:parseFunctionArguments()
            local newNode = Expr.CallExpressionNode.new(node, args, methodId)
            newNode:setLocation(node.startToken, endToken)
            node = newNode
        elseif self:isFunctionArgumentStart() then
            local args, endToken = self:parseFunctionArguments()
            local newNode = Expr.CallExpressionNode.new(node, args, nil)
            newNode:setLocation(node.startToken, endToken)
            node = newNode
        else
            break
        end
    end
    return node
end

--- 检查是否为函数参数开始
--- @return boolean
function Parser:isFunctionArgumentStart()
    local t = self.currentToken.type
    return t == TokenType.SymLParen or t == TokenType.SymLBrace or t == TokenType.String
end

--- 解析函数调用参数
--- @return Expression[], Token 参数列表和结束 Token
function Parser:parseFunctionArguments()
    local args = {}
    local endToken
    if self.currentToken.type == TokenType.SymLParen then
        self:advance()
        if self.currentToken.type ~= TokenType.SymRParen then
            args[#args + 1] = self:parseExpression()
            while self.currentToken.type == TokenType.SymComma do
                self:advance()
                args[#args + 1] = self:parseExpression()
            end
        end
        endToken = self:eat(TokenType.SymRParen)
    elseif self.currentToken.type == TokenType.SymLBrace then
        local tableNode = self:parseTableConstructor()
        args[#args + 1] = tableNode
        endToken = tableNode.endToken
    elseif self.currentToken.type == TokenType.String then
        local strToken = self.currentToken
        self:advance()
        local strNode = Expr.LiteralNode.new(strToken.value, strToken.value)
        strNode:setLocation(strToken, strToken)
        args[#args + 1] = strNode
        endToken = strToken
    else
        self:error("Expected function arguments: '(', '{', or string literal", "InvalidFunctionCall")
    end
    return args, endToken
end

--- 解析基本表达式（字面量、标识符、括号表达式等）
--- @return Expression 表达式 AST 节点
function Parser:parsePrimaryExpression()
    local token = self.currentToken
    if token.type == TokenType.Number or token.type == TokenType.String then
        self:advance()
        -- 尝试将原始 token 值作为 rawValue 传递
        local node = Expr.LiteralNode.new(token.value, tostring(token.value))
        node:setLocation(token, token)
        return node
    elseif token.type == TokenType.KwNil then
        self:advance()
        local node = Expr.LiteralNode.new(nil, "nil")
        node:setLocation(token, token)
        return node
    elseif token.type == TokenType.KwTrue then
        self:advance()
        local node = Expr.LiteralNode.new(true, "true")
        node:setLocation(token, token)
        return node
    elseif token.type == TokenType.KwFalse then
        self:advance()
        local node = Expr.LiteralNode.new(false, "false")
        node:setLocation(token, token)
        return node
    elseif token.type == TokenType.SymVararg then
        self:advance()
        local node = Expr.VarargNode.new()
        node:setLocation(token, token)
        return node
    elseif token.type == TokenType.Identifier then
        self:advance()
        local node = Expr.IdentifierNode.new(token.value)
        node:setLocation(token, token)
        -- 解析变量引用，设置 varType 和 variable
        local variable, varType = self.scopeManager:resolveVariable(token.value, node)
        node.variable = variable
        node.varType = varType
        return node
    elseif token.type == TokenType.SymLParen then
        self:advance()
        local expr = self:parseExpression()
        self:eat(TokenType.SymRParen)
        return expr
    elseif token.type == TokenType.SymLBrace then
        return self:parseTableConstructor()
    elseif token.type == TokenType.KwFunction then
        return self:parseFunctionDefinition()
    else
        self:error(string.format("Unexpected token in expression: %s", self:getTokenDescription(token)), "UnexpectedToken")
    end
end

--- 解析表构造器
--- @return TableConstructorNode 表构造器 AST 节点
function Parser:parseTableConstructor()
    local startToken = self:eat(TokenType.SymLBrace)
    local fields = {}
    while self.currentToken.type ~= TokenType.SymRBrace do
        if self.currentToken.type == TokenType.SymLBracket then
            local fieldStartToken = self.currentToken
            self:advance()
            local key = self:parseExpression()
            self:eat(TokenType.SymRBracket)
            self:eat(TokenType.SymAssign)
            local value = self:parseExpression()
            local fieldNode = Expr.TableFieldNode.new(key, value, "Map")
            fieldNode:setLocation(fieldStartToken, value.endToken)
            fields[#fields + 1] = fieldNode
        elseif self.currentToken.type == TokenType.Identifier and self.peekToken.type == TokenType.SymAssign then
            local keyToken = self.currentToken
            self:advance()
            self:advance()
            local keyNode = Expr.IdentifierNode.new(keyToken.value)
            keyNode:setLocation(keyToken, keyToken)
            local value = self:parseExpression()
            local fieldNode = Expr.TableFieldNode.new(keyNode, value, "Rec")
            fieldNode:setLocation(keyToken, value.endToken)
            fields[#fields + 1] = fieldNode
        else
            local val = self:parseExpression()
            local fieldNode = Expr.TableFieldNode.new(nil, val, "List")
            fieldNode:setLocation(val.startToken, val.endToken)
            fields[#fields + 1] = fieldNode
        end

        if self.currentToken.type == TokenType.SymComma or self.currentToken.type == TokenType.SymSemi then
            self:advance()
        else
            if self.currentToken.type ~= TokenType.SymRBrace then
                self:error("Expected ',' or '}' in table constructor", "InvalidTableConstructor")
            end
        end
    end
    local endToken = self:eat(TokenType.SymRBrace)
    local node = Expr.TableConstructorNode.new(fields)
    node:setLocation(startToken, endToken)
    return node
end

--- 解析匿名函数定义
--- @return FunctionExpressionNode 函数表达式 AST 节点
function Parser:parseFunctionDefinition()
    local startToken = self:eat(TokenType.KwFunction)
    local params = {}
    local isVararg = false
    
    -- 进入函数作用域
    local functionScope = self.scopeManager:enterFunctionScope()
    
    self:eat(TokenType.SymLParen)
    if self.currentToken.type ~= TokenType.SymRParen then
        repeat
            if self.currentToken.type == TokenType.Identifier then
                local param = Expr.IdentifierNode.new(self.currentToken.value)
                param:setLocation(self.currentToken, self.currentToken)
                -- 将参数定义为局部变量
                local variable = self.scopeManager:defineLocal(self.currentToken.value, param)
                param.variable = variable
                param.varType = "local"
                params[#params + 1] = param
                self:advance()
            elseif self.currentToken.type == TokenType.SymVararg then
                isVararg = true
                self:advance()
                break
            else
                self:error("Expected parameter name or '...' in function definition", "InvalidParameter")
            end
            if self.currentToken.type == TokenType.SymComma then
                self:advance()
            elseif self.currentToken.type ~= TokenType.SymRParen then
                self:error("Expected ',' or ')' after parameter", "InvalidParameter")
            end
        until self.currentToken.type == TokenType.SymRParen
    end
    self:eat(TokenType.SymRParen)
    local body = self:parseBlock()
    local endToken = self:eat(TokenType.KwEnd)
    
    -- 退出函数作用域
    local functionContext = self.scopeManager:exitFunctionScope()
    
    local node = Expr.FunctionExpressionNode.new(params, isVararg, body)
    node:setLocation(startToken, endToken)
    node.localScope = functionScope
    node.upvalues = functionContext.upvalues or {}
    return node
end

-- ============================================================
--  Statement Parsing
-- ============================================================

--- 解析整个程序
--- @return BlockNode 程序根节点
function Parser:parseProgram()
    local statements = {}
    local startToken = self.currentToken
    while self.currentToken.type ~= TokenType.EOF do
        local stmt = self:parseStatement()
        if stmt then
            stmt:setScope(self.scopeManager.currentScope)
            statements[#statements + 1] = stmt
        end
    end
    local programNode = Stmt.BlockNode.new(statements)

    local endToken = self.previousToken or startToken
    programNode:setLocation(startToken, endToken)
    programNode:setScope(self.scopeManager.globalScope)
    return programNode
end

--- 解析代码块
--- @return BlockNode 代码块 AST 节点
function Parser:parseBlock()
    local statements = {}
    local startToken = self.currentToken

    while not self:isBlockEnd() do
        local stmt = self:parseStatement()
        if stmt then
            stmt:setScope(self.scopeManager.currentScope)
            statements[#statements + 1] = stmt
            if stmt.type == "ReturnStatement" and not self:isBlockEnd() then
                self:error("Unreachable code after 'return' statement", "UnreachableCode")
            end
        end
    end

    local node = Stmt.BlockNode.new(statements)
    local endToken = self.previousToken or startToken
    node:setLocation(startToken, endToken)
    node:setScope(self.scopeManager.currentScope)

    return node
end

--- 检查是否为代码块结束
--- @return boolean
function Parser:isBlockEnd()
    local t = self.currentToken.type
    return t == TokenType.KwEnd or t == TokenType.KwElse or t == TokenType.KwElseif or
        t == TokenType.KwUntil or t == TokenType.EOF
end

--- 解析单条语句
--- @return Statement|nil 语句 AST 节点，空语句返回 nil
function Parser:parseStatement()
    local t = self.currentToken.type
    if t == TokenType.SymSemi then
        self:advance(); return nil
    end
    if t == TokenType.KwIf then
        return self:parseIfStatement()
    elseif t == TokenType.KwWhile then
        return self:parseWhileStatement()
    elseif t == TokenType.KwDo then
        return self:parseDoStatement()
    elseif t == TokenType.KwRepeat then
        return self:parseRepeatStatement()
    elseif t == TokenType.KwFor then
        return self:parseForStatement()
    elseif t == TokenType.KwBreak then
        return self:parseBreakStatement()
    elseif t == TokenType.KwReturn then
        return self:parseReturnStatement()
    elseif t == TokenType.KwGoto then
        return self:parseGotoStatement()
    end
    if t == TokenType.SymDoubleColon then return self:parseLabelStatement() end
    if t == TokenType.KwLocal then
        if self.peekToken.type == TokenType.KwFunction then
            return self:parseLocalFunctionDeclaration()
        else
            return self:parseLocalVariableDeclaration()
        end
    end
    if t == TokenType.KwFunction then return self:parseFunctionDeclaration() end
    return self:parseAssignmentOrCall()
end

--- 解析 if 条件语句
--- @return IfStatementNode if 语句 AST 节点
function Parser:parseIfStatement()
    local startToken = self:eat(TokenType.KwIf)
    local clauses = {}
    local condition = self:parseExpression()
    self:eat(TokenType.KwThen)
    -- 进入 if 块作用域
    self.scopeManager:enterScope()
    local body = self:parseBlock()
    -- 退出 if 块作用域
    self.scopeManager:exitScope()
    clauses[#clauses + 1] = { condition = condition, body = body }
    while self.currentToken.type == TokenType.KwElseif do
        self:advance()
        local elifCond = self:parseExpression()
        self:eat(TokenType.KwThen)
        -- 进入 elseif 块作用域
        self.scopeManager:enterScope()
        local elifBody = self:parseBlock()
        -- 退出 elseif 块作用域
        self.scopeManager:exitScope()
        clauses[#clauses + 1] = { condition = elifCond, body = elifBody }
    end
    local elseBody = nil
    if self.currentToken.type == TokenType.KwElse then
        self:advance()
        -- 进入 else 块作用域
        self.scopeManager:enterScope()
        elseBody = self:parseBlock()
        -- 退出 else 块作用域
        self.scopeManager:exitScope()
    end
    local endToken = self:eat(TokenType.KwEnd)
    local node = Stmt.IfStatementNode.new(clauses, elseBody)
    node:setLocation(startToken, endToken)
    return node
end

--- 解析 while 循环语句
--- @return WhileStatementNode while 语句 AST 节点
function Parser:parseWhileStatement()
    local startToken = self:eat(TokenType.KwWhile)
    local condition = self:parseExpression()
    self:eat(TokenType.KwDo)
    self.loopDepth = self.loopDepth + 1
    -- 进入 while 循环作用域
    self.scopeManager:enterScope()
    local body = self:parseBlock()
    -- 退出 while 循环作用域
    self.scopeManager:exitScope()
    self.loopDepth = self.loopDepth - 1
    local endToken = self:eat(TokenType.KwEnd)
    local node = Stmt.WhileStatementNode.new(condition, body)
    node:setLocation(startToken, endToken)
    return node
end

--- 解析 do 语句块
--- @return DoStatementNode do 语句 AST 节点
function Parser:parseDoStatement()
    local startToken = self:eat(TokenType.KwDo)
    -- 进入 do 块作用域
    self.scopeManager:enterScope()
    local body = self:parseBlock()
    -- 退出 do 块作用域
    self.scopeManager:exitScope()
    local endToken = self:eat(TokenType.KwEnd)
    local node = Stmt.DoStatementNode.new(body)
    node:setLocation(startToken, endToken)
    return node
end

--- 解析 repeat-until 循环语句
--- @return RepeatStatementNode repeat 语句 AST 节点
function Parser:parseRepeatStatement()
    local startToken = self:eat(TokenType.KwRepeat)
    self.loopDepth = self.loopDepth + 1
    -- 进入 repeat 块作用域
    self.scopeManager:enterScope()
    local body = self:parseBlock()
    self.loopDepth = self.loopDepth - 1
    self:eat(TokenType.KwUntil)
    local condition = self:parseExpression()
    -- 退出 repeat 块作用域（注意：until 条件可以访问 repeat 块内的局部变量）
    self.scopeManager:exitScope()
    local node = Stmt.RepeatStatementNode.new(body, condition)
    node:setLocation(startToken, condition.endToken)
    return node
end

--- 解析 for 循环语句（数值型或泛型）
--- @return ForNumericStatementNode|ForGenericStatementNode for 语句 AST 节点
function Parser:parseForStatement()
    local startToken = self:eat(TokenType.KwFor)
    local nameToken = self:eat(TokenType.Identifier)
    local varNode = Expr.IdentifierNode.new(nameToken.value)
    varNode:setLocation(nameToken, nameToken)

    if self.currentToken.type == TokenType.SymAssign then
        self:advance()
        local startExpr = self:parseExpression()
        self:eat(TokenType.SymComma)
        local limitExpr = self:parseExpression()
        local stepExpr = nil
        if self.currentToken.type == TokenType.SymComma then
            self:advance()
            stepExpr = self:parseExpression()
        end
        self:eat(TokenType.KwDo)
        self.loopDepth = self.loopDepth + 1
        -- 进入 for 循环作用域
        self.scopeManager:enterScope()
        -- 定义循环变量为局部变量
        local variable = self.scopeManager:defineLocal(nameToken.value, varNode)
        varNode.variable = variable
        varNode.varType = "local"
        local body = self:parseBlock()
        -- 退出 for 循环作用域
        self.scopeManager:exitScope()
        self.loopDepth = self.loopDepth - 1
        local endToken = self:eat(TokenType.KwEnd)
        local node = Stmt.ForNumericStatementNode.new(varNode, startExpr, limitExpr, stepExpr, body)
        node:setLocation(startToken, endToken)
        return node
    else
        local vars = { varNode }
        while self.currentToken.type == TokenType.SymComma do
            self:advance()
            local nextName = self:eat(TokenType.Identifier)
            local nextVar = Expr.IdentifierNode.new(nextName.value)
            nextVar:setLocation(nextName, nextName)
            vars[#vars + 1] = nextVar
        end
        self:eat(TokenType.KwIn)
        local exprs = {}
        exprs[#exprs + 1] = self:parseExpression()
        while self.currentToken.type == TokenType.SymComma do
            self:advance()
            exprs[#exprs + 1] = self:parseExpression()
        end
        self:eat(TokenType.KwDo)
        self.loopDepth = self.loopDepth + 1
        -- 进入 for-in 循环作用域
        self.scopeManager:enterScope()
        -- 定义所有循环变量为局部变量
        for _, v in ipairs(vars) do
            local variable = self.scopeManager:defineLocal(v.name, v)
            v.variable = variable
            v.varType = "local"
        end
        local body = self:parseBlock()
        -- 退出 for-in 循环作用域
        self.scopeManager:exitScope()
        self.loopDepth = self.loopDepth - 1
        local endToken = self:eat(TokenType.KwEnd)
        local node = Stmt.ForGenericStatementNode.new(vars, exprs, body)
        node:setLocation(startToken, endToken)
        return node
    end
end

--- 解析 break 语句
--- @return BreakStatementNode break 语句 AST 节点
function Parser:parseBreakStatement()
    local token = self:eat(TokenType.KwBreak)
    if self.loopDepth == 0 then
        self:error("'break' statement not inside a loop (for, while, or repeat)", "InvalidBreak")
    end
    local node = Stmt.BreakStatementNode.new()
    node:setLocation(token, token)
    return node
end

--- 解析 goto 语句
--- @return GotoStatementNode goto 语句 AST 节点
function Parser:parseGotoStatement()
    local startToken = self:eat(TokenType.KwGoto)
    local labelToken = self:eat(TokenType.Identifier)
    local node = Stmt.GotoStatementNode.new(labelToken.value)
    node:setLocation(startToken, labelToken)
    return node
end

--- 解析标签语句 (::label::)
--- @return LabelStatementNode 标签语句 AST 节点
function Parser:parseLabelStatement()
    local startToken = self:eat(TokenType.SymDoubleColon)
    local labelToken = self:eat(TokenType.Identifier)
    local endToken = self:eat(TokenType.SymDoubleColon)
    local node = Stmt.LabelStatementNode.new(labelToken.value)
    node:setLocation(startToken, endToken)
    return node
end

--- 解析 return 语句
--- @return ReturnStatementNode return 语句 AST 节点
function Parser:parseReturnStatement()
    local startToken = self:eat(TokenType.KwReturn)
    local args = {}
    local t = self.currentToken.type
    if t ~= TokenType.KwEnd and t ~= TokenType.KwElse and t ~= TokenType.KwElseif and
        t ~= TokenType.KwUntil and t ~= TokenType.EOF and t ~= TokenType.SymSemi then
        args[#args + 1] = self:parseExpression()
        while self.currentToken.type == TokenType.SymComma do
            self:advance()
            args[#args + 1] = self:parseExpression()
        end
    end
    if self.currentToken.type == TokenType.SymSemi then self:advance() end
    local node = Stmt.ReturnStatementNode.new(args)
    local endLoc = (#args > 0) and args[#args].endToken or startToken
    node:setLocation(startToken, endLoc)
    return node
end

--- 解析局部变量声明
--- @return LocalStatementNode 局部变量声明 AST 节点
function Parser:parseLocalVariableDeclaration()
    local startToken = self:eat(TokenType.KwLocal)
    local vars = {}
    local init = {}
    local nameToken = self:eat(TokenType.Identifier)
    local varNode = Expr.IdentifierNode.new(nameToken.value)
    varNode:setLocation(nameToken, nameToken)
    vars[#vars + 1] = varNode
    while self.currentToken.type == TokenType.SymComma do
        self:advance()
        local nextName = self:eat(TokenType.Identifier)
        local nextVar = Expr.IdentifierNode.new(nextName.value)
        nextVar:setLocation(nextName, nextName)
        vars[#vars + 1] = nextVar
    end
    if self.currentToken.type == TokenType.SymAssign then
        self:advance()
        init[#init + 1] = self:parseExpression()
        while self.currentToken.type == TokenType.SymComma do
            self:advance()
            init[#init + 1] = self:parseExpression()
        end
    end
    -- 定义所有局部变量（在解析初始化表达式之后，这样初始化表达式中的同名变量引用外层）
    for _, v in ipairs(vars) do
        local variable = self.scopeManager:defineLocal(v.name, v)
        v.variable = variable
        v.varType = "local"
    end
    local endLoc = (#init > 0) and init[#init].endToken or vars[#vars].endToken
    local node = Stmt.LocalStatementNode.new(vars, init)
    node:setLocation(startToken, endLoc)
    for i, v in ipairs(vars) do
        if v.variable and init[i] then
            v.variable:addValue({
                kind = "local",
                node = init[i],
                statementNode = node,
                mutated = true
            })
        end
    end
    return node
end

--- 解析局部函数声明
--- @return FunctionDeclarationNode 函数声明 AST 节点
function Parser:parseLocalFunctionDeclaration()
    local startToken = self:eat(TokenType.KwLocal)
    self:eat(TokenType.KwFunction)
    local nameToken = self:eat(TokenType.Identifier)
    local nameNode = Expr.IdentifierNode.new(nameToken.value)
    nameNode:setLocation(nameToken, nameToken)
    
    -- 先定义函数名为局部变量（允许递归调用）
    local funcVariable = self.scopeManager:defineLocal(nameToken.value, nameNode)
    nameNode.variable = funcVariable
    nameNode.varType = "local"
    
    local params = {}
    local isVararg = false
    
    -- 进入函数作用域
    local functionScope = self.scopeManager:enterFunctionScope()
    
    self:eat(TokenType.SymLParen)
    if self.currentToken.type ~= TokenType.SymRParen then
        repeat
            if self.currentToken.type == TokenType.Identifier then
                local param = Expr.IdentifierNode.new(self.currentToken.value)
                -- 修复：添加位置信息
                param:setLocation(self.currentToken, self.currentToken)
                -- 将参数定义为局部变量
                local variable = self.scopeManager:defineLocal(self.currentToken.value, param)
                param.variable = variable
                param.varType = "local"
                params[#params + 1] = param
                self:advance()
            elseif self.currentToken.type == TokenType.SymVararg then
                isVararg = true
                self:advance()
                break
            else
                self:error("Expected parameter name or '...' in local function definition", "InvalidParameter")
            end
            if self.currentToken.type == TokenType.SymComma then self:advance() end
        until self.currentToken.type == TokenType.SymRParen
    end
    self:eat(TokenType.SymRParen)
    local body = self:parseBlock()
    local endToken = self:eat(TokenType.KwEnd)
    
    -- 退出函数作用域
    local functionContext = self.scopeManager:exitFunctionScope()
    
    local node = Stmt.FunctionDeclarationNode.new(nameNode, params, isVararg, body, true)
    node:setLocation(startToken, endToken)
    node.localScope = functionScope
    node.upvalues = functionContext.upvalues or {}
    if nameNode.variable then
        nameNode.variable:addValue({
            kind = "function",
            node = node,
            statementNode = node,
            mutated = true
        })
    end
    return node
end

--- 解析全局函数声明
--- @return FunctionDeclarationNode 函数声明 AST 节点
function Parser:parseFunctionDeclaration()
    local startToken = self:eat(TokenType.KwFunction)
    local nameToken = self:eat(TokenType.Identifier)
    local nameNode = Expr.IdentifierNode.new(nameToken.value)
    nameNode:setLocation(nameToken, nameToken)
    -- 解析函数名（可能是全局变量或成员访问）
    local variable, varType = self.scopeManager:resolveVariable(nameToken.value, nameNode)
    nameNode.variable = variable
    nameNode.varType = varType
    
    while self.currentToken.type == TokenType.SymDot do
        self:advance()
        local memberToken = self:eat(TokenType.Identifier)
        local memberId = Expr.IdentifierNode.new(memberToken.value)
        memberId:setLocation(memberToken, memberToken)
        local baseNode = nameNode
        nameNode = Expr.MemberExpressionNode.new(baseNode, ".", memberId)
        nameNode:setLocation(baseNode.startToken, memberId.endToken)
    end
    local hasColon = false
    if self.currentToken.type == TokenType.SymColon then
        self:advance()
        hasColon = true
        local memberToken = self:eat(TokenType.Identifier)
        local memberId = Expr.IdentifierNode.new(memberToken.value)
        memberId:setLocation(memberToken, memberToken)
        local baseNode = nameNode
        nameNode = Expr.MemberExpressionNode.new(baseNode, ":", memberId)
        nameNode:setLocation(baseNode.startToken, memberId.endToken)
    end
    local params = {}
    local isVararg = false
    
    -- 进入函数作用域
    local functionScope = self.scopeManager:enterFunctionScope()
    
    if hasColon then
        local selfNode = Expr.IdentifierNode.new("self")
        selfNode:setLocation(startToken, startToken)
        -- 定义 self 为局部变量
        local selfVariable = self.scopeManager:defineLocal("self", selfNode)
        selfNode.variable = selfVariable
        selfNode.varType = "local"
        params[#params + 1] = selfNode
    end
    self:eat(TokenType.SymLParen)
    if self.currentToken.type ~= TokenType.SymRParen then
        repeat
            if self.currentToken.type == TokenType.Identifier then
                local param = Expr.IdentifierNode.new(self.currentToken.value)
                -- 修复：添加位置信息
                param:setLocation(self.currentToken, self.currentToken)
                -- 将参数定义为局部变量
                local paramVariable = self.scopeManager:defineLocal(self.currentToken.value, param)
                param.variable = paramVariable
                param.varType = "local"
                params[#params + 1] = param
                self:advance()
            elseif self.currentToken.type == TokenType.SymVararg then
                isVararg = true
                self:advance()
                break
            end
            if self.currentToken.type == TokenType.SymComma then self:advance() end
        until self.currentToken.type == TokenType.SymRParen
    end
    self:eat(TokenType.SymRParen)
    local body = self:parseBlock()
    local endToken = self:eat(TokenType.KwEnd)
    
    -- 退出函数作用域
    local functionContext = self.scopeManager:exitFunctionScope()
    
    local node = Stmt.FunctionDeclarationNode.new(nameNode, params, isVararg, body, false)
    node:setLocation(startToken, endToken)
    node.localScope = functionScope
    node.upvalues = functionContext.upvalues or {}
    if nameNode.type == "Identifier" and nameNode.variable then
        nameNode.variable:addValue({
            kind = "function",
            node = node,
            statementNode = node,
            mutated = true
        })
    end
    return node
end

--- 解析赋值语句或函数调用语句
--- @return AssignmentStatementNode|CallStatementNode 语句 AST 节点
function Parser:parseAssignmentOrCall()
    local startToken = self.currentToken
    local expr = self:parseSuffixedExpression()
    local isLValue = (expr.type == "Identifier" or expr.type == "MemberExpression")

    if isLValue and (self.currentToken.type == TokenType.SymAssign or self.currentToken.type == TokenType.SymComma) then
        local vars = { expr }
        while self.currentToken.type == TokenType.SymComma do
            self:advance()
            local nextExpr = self:parseSuffixedExpression()
            if nextExpr.type ~= "Identifier" and nextExpr.type ~= "MemberExpression" then
                self:error("Invalid assignment target: expected variable or table field, got expression", "InvalidAssignment")
            end
            vars[#vars + 1] = nextExpr
        end
        self:eat(TokenType.SymAssign)
        local exprs = {}
        exprs[#exprs + 1] = self:parseExpression()
        while self.currentToken.type == TokenType.SymComma do
            self:advance()
            exprs[#exprs + 1] = self:parseExpression()
        end
        local endLoc = exprs[#exprs].endToken
        local node = Stmt.AssignmentStatementNode.new(vars, exprs)
        node:setLocation(startToken, endLoc)
        for i, var in ipairs(vars) do
            if var.type == "Identifier" and var.variable then
                var.variable:addValue({
                    kind = "assignment",
                    node = exprs[i],
                    statementNode = node,
                    mutated = true
                })
            end
        end
        return node
    else
        if expr.type ~= "CallExpression" then
            self:error("Syntax error: only function calls and assignments are valid statements", "InvalidStatement")
        end
        local node = Stmt.CallStatementNode.new(expr)
        node:setLocation(startToken, expr.endToken)
        return node
    end
end

return Parser
