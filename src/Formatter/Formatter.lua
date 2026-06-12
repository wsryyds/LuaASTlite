local TokenType = require("src.Lexer.TokenType")

local Formatter = {}
Formatter.__index = Formatter

local BINARY_PRECEDENCE = {
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

local RIGHT_ASSOCIATIVE = {
    [TokenType.OpConcat] = true,
    [TokenType.OpPow] = true
}

local UNARY_PRECEDENCE = 11

local function makeIndent(options)
    local indent = options and options.indent or 4
    if type(indent) == "number" then
        return string.rep(" ", indent)
    end
    return tostring(indent)
end

local function join(items, separator)
    return table.concat(items, separator or ", ")
end

local function quoteString(value)
    local parts = { "\"" }
    local binaryLike = false

    for i = 1, #value do
        local byte = string.byte(value, i)
        if byte < 32 or byte > 126 then
            binaryLike = true
            break
        end
    end

    if binaryLike then
        for i = 1, #value do
            parts[#parts + 1] = string.format("\\%03d", string.byte(value, i))
        end
        parts[#parts + 1] = "\""
        return table.concat(parts)
    end

    for i = 1, #value do
        local byte = string.byte(value, i)
        if byte == 34 then
            parts[#parts + 1] = "\\\""
        elseif byte == 92 then
            parts[#parts + 1] = "\\\\"
        elseif byte == 7 then
            parts[#parts + 1] = "\\a"
        elseif byte == 8 then
            parts[#parts + 1] = "\\b"
        elseif byte == 9 then
            parts[#parts + 1] = "\\t"
        elseif byte == 10 then
            parts[#parts + 1] = "\\n"
        elseif byte == 11 then
            parts[#parts + 1] = "\\v"
        elseif byte == 12 then
            parts[#parts + 1] = "\\f"
        elseif byte == 13 then
            parts[#parts + 1] = "\\r"
        elseif byte >= 32 and byte <= 126 then
            parts[#parts + 1] = string.char(byte)
        else
            parts[#parts + 1] = string.format("\\%03d", byte)
        end
    end

    parts[#parts + 1] = "\""
    return table.concat(parts)
end

function Formatter.new(options)
    return setmetatable({
        indentText = makeIndent(options or {})
    }, Formatter)
end

function Formatter:indent(level)
    return string.rep(self.indentText, level or 0)
end

function Formatter:format(ast)
    return self:formatBlock(ast, 0)
end

function Formatter:formatBlock(block, level)
    local lines = {}
    for _, statement in ipairs(block.body or block.statements or {}) do
        lines[#lines + 1] = self:formatStatement(statement, level)
    end
    return table.concat(lines, "\n")
end

function Formatter:formatStatement(statement, level)
    local t = statement.type
    if t == "LocalStatement" then
        return self:formatLocalStatement(statement, level)
    elseif t == "AssignmentStatement" then
        return self:formatAssignmentStatement(statement, level)
    elseif t == "CallStatement" then
        return self:indent(level) .. self:formatExpression(statement.expression, level)
    elseif t == "DoStatement" then
        return self:formatBodyStatement("do", nil, statement.body, "end", level)
    elseif t == "WhileStatement" then
        return self:formatBodyStatement(
            "while " .. self:formatExpression(statement.condition, level) .. " do",
            nil,
            statement.body,
            "end",
            level
        )
    elseif t == "RepeatStatement" then
        return self:formatRepeatStatement(statement, level)
    elseif t == "IfStatement" then
        return self:formatIfStatement(statement, level)
    elseif t == "BreakStatement" then
        return self:indent(level) .. "break"
    elseif t == "ReturnStatement" then
        return self:formatReturnStatement(statement, level)
    elseif t == "ForNumericStatement" then
        return self:formatForNumericStatement(statement, level)
    elseif t == "ForGenericStatement" then
        return self:formatForGenericStatement(statement, level)
    elseif t == "FunctionDeclaration" then
        return self:formatFunctionDeclaration(statement, level)
    elseif t == "GotoStatement" then
        return self:indent(level) .. "goto " .. statement.label
    elseif t == "LabelStatement" then
        return self:indent(level) .. "::" .. statement.label .. "::"
    end

    error("Unsupported statement type for formatting: " .. tostring(t))
end

function Formatter:formatBodyStatement(header, separator, body, footer, level)
    local indent = self:indent(level)
    local lines = { indent .. header }
    local bodyText = self:formatBlock(body, level + 1)

    if bodyText ~= "" then
        lines[#lines + 1] = bodyText
    end
    if separator then
        lines[#lines + 1] = indent .. separator
    end
    lines[#lines + 1] = indent .. footer
    return table.concat(lines, "\n")
end

function Formatter:formatLocalStatement(statement, level)
    local names = {}
    for _, variable in ipairs(statement.variables or {}) do
        names[#names + 1] = self:formatExpression(variable, level)
    end

    local text = self:indent(level) .. "local " .. join(names)
    if statement.init and #statement.init > 0 then
        text = text .. " = " .. self:formatExpressionList(statement.init, level)
    end
    return text
end

function Formatter:formatAssignmentStatement(statement, level)
    return self:indent(level)
        .. self:formatExpressionList(statement.variables, level)
        .. " = "
        .. self:formatExpressionList(statement.init, level)
end

function Formatter:formatReturnStatement(statement, level)
    if not statement.arguments or #statement.arguments == 0 then
        return self:indent(level) .. "return"
    end
    return self:indent(level) .. "return " .. self:formatExpressionList(statement.arguments, level)
end

function Formatter:formatRepeatStatement(statement, level)
    local indent = self:indent(level)
    local lines = { indent .. "repeat" }
    local bodyText = self:formatBlock(statement.body, level + 1)
    if bodyText ~= "" then
        lines[#lines + 1] = bodyText
    end
    lines[#lines + 1] = indent .. "until " .. self:formatExpression(statement.condition, level)
    return table.concat(lines, "\n")
end

function Formatter:formatIfStatement(statement, level)
    local indent = self:indent(level)
    local lines = {}

    for index, clause in ipairs(statement.clauses or {}) do
        local keyword = (index == 1) and "if" or "elseif"
        lines[#lines + 1] = indent .. keyword .. " " .. self:formatExpression(clause.condition, level) .. " then"
        local bodyText = self:formatBlock(clause.body, level + 1)
        if bodyText ~= "" then
            lines[#lines + 1] = bodyText
        end
    end

    if statement.elseBody then
        lines[#lines + 1] = indent .. "else"
        local elseText = self:formatBlock(statement.elseBody, level + 1)
        if elseText ~= "" then
            lines[#lines + 1] = elseText
        end
    end

    lines[#lines + 1] = indent .. "end"
    return table.concat(lines, "\n")
end

function Formatter:formatForNumericStatement(statement, level)
    local values = {
        self:formatExpression(statement.start, level),
        self:formatExpression(statement.endVal, level)
    }
    if statement.step then
        values[#values + 1] = self:formatExpression(statement.step, level)
    end

    local header = "for "
        .. self:formatExpression(statement.variable, level)
        .. " = "
        .. join(values)
        .. " do"

    return self:formatBodyStatement(header, nil, statement.body, "end", level)
end

function Formatter:formatForGenericStatement(statement, level)
    local header = "for "
        .. self:formatExpressionList(statement.variables, level)
        .. " in "
        .. self:formatExpressionList(statement.iterators, level)
        .. " do"

    return self:formatBodyStatement(header, nil, statement.body, "end", level)
end

function Formatter:formatFunctionDeclaration(statement, level)
    local params = self:formatParams(statement.params, statement.isVararg, self:isMethodName(statement.identifier))
    local prefix = statement.isLocal and "local function " or "function "
    local header = prefix .. self:formatExpression(statement.identifier, level) .. "(" .. params .. ")"
    return self:formatBodyStatement(header, nil, statement.body, "end", level)
end

function Formatter:isMethodName(identifier)
    return identifier and identifier.type == "MemberExpression" and identifier.indexer == ":"
end

function Formatter:formatParams(params, isVararg, skipSyntheticSelf)
    local result = {}
    local startIndex = skipSyntheticSelf and 2 or 1
    for i = startIndex, #(params or {}) do
        result[#result + 1] = self:formatExpression(params[i], 0)
    end
    if isVararg then
        result[#result + 1] = "..."
    end
    return join(result)
end

function Formatter:formatExpressionList(expressions, level)
    local result = {}
    for _, expression in ipairs(expressions or {}) do
        result[#result + 1] = self:formatExpression(expression, level)
    end
    return join(result)
end

function Formatter:formatExpression(expression, level)
    local t = expression.type
    if t == "Literal" then
        return self:formatLiteral(expression)
    elseif t == "VarargLiteral" then
        return "..."
    elseif t == "Identifier" then
        return expression.name
    elseif t == "BinaryExpression" then
        return self:formatBinaryExpression(expression, level)
    elseif t == "UnaryExpression" then
        return self:formatUnaryExpression(expression, level)
    elseif t == "TableConstructorExpression" then
        return self:formatTableConstructor(expression, level)
    elseif t == "TableField" then
        return self:formatTableField(expression, level)
    elseif t == "MemberExpression" then
        return self:formatMemberExpression(expression, level)
    elseif t == "CallExpression" then
        return self:formatCallExpression(expression, level)
    elseif t == "FunctionExpression" then
        return self:formatFunctionExpression(expression, level)
    end

    error("Unsupported expression type for formatting: " .. tostring(t))
end

function Formatter:formatLiteral(literal)
    local value = literal.value
    if type(value) == "string" then
        return quoteString(value)
    elseif type(value) == "nil" then
        return "nil"
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    end
    return tostring(value)
end

function Formatter:formatBinaryExpression(expression, level)
    local opType = expression.operator.type
    local precedence = BINARY_PRECEDENCE[opType] or 0
    local operator = expression.operator.value or opType
    local left = self:formatSubExpression(expression.left, level, precedence, opType, "left")
    local right = self:formatSubExpression(expression.right, level, precedence, opType, "right")
    return left .. " " .. operator .. " " .. right
end

function Formatter:formatUnaryExpression(expression, level)
    local operator = expression.operator.value or expression.operator.type
    local argument = self:formatSubExpression(expression.argument, level, UNARY_PRECEDENCE, expression.operator.type, "right")
    if operator == "not" then
        return "not " .. argument
    end
    return operator .. argument
end

function Formatter:formatSubExpression(expression, level, parentPrecedence, parentOperatorType, side)
    local text = self:formatExpression(expression, level)
    local childPrecedence = self:getExpressionPrecedence(expression)
    if childPrecedence == nil then
        return text
    end

    local needsParens = childPrecedence < parentPrecedence
    if childPrecedence == parentPrecedence then
        if side == "right" and not RIGHT_ASSOCIATIVE[parentOperatorType] then
            needsParens = true
        elseif side == "left" and RIGHT_ASSOCIATIVE[parentOperatorType] then
            needsParens = true
        end
    end

    if needsParens then
        return "(" .. text .. ")"
    end
    return text
end

function Formatter:getExpressionPrecedence(expression)
    if expression.type == "BinaryExpression" then
        return BINARY_PRECEDENCE[expression.operator.type] or 0
    elseif expression.type == "UnaryExpression" then
        return UNARY_PRECEDENCE
    end
    return nil
end

function Formatter:formatTableConstructor(expression, level)
    if not expression.fields or #expression.fields == 0 then
        return "{}"
    end

    local folded = self:formatFoldedTableConstructor(expression, level)
    if folded then
        return folded
    end

    local lines = { "{" }
    for _, field in ipairs(expression.fields) do
        lines[#lines + 1] = self:indent(level + 1) .. self:formatTableField(field, level + 1) .. ","
    end
    lines[#lines + 1] = self:indent(level) .. "}"
    return table.concat(lines, "\n")
end

function Formatter:formatFoldedTableConstructor(expression, level)
    local fields = expression.fields or {}
    local formattedFields = {}
    local shortCount = 0

    for _, field in ipairs(fields) do
        local formatted = self:formatTableField(field, level)
        if formatted:find("\n", 1, true) then
            return nil
        end
        if #formatted < 5 then
            shortCount = shortCount + 1
        end
        formattedFields[#formattedFields + 1] = formatted
    end

    if shortCount * 2 < #fields then
        return nil
    end

    return "{ " .. table.concat(formattedFields, ", ") .. " }"
end

function Formatter:formatTableField(field, level)
    if field.kind == "Map" then
        return "[" .. self:formatExpression(field.key, level) .. "] = " .. self:formatExpression(field.value, level)
    elseif field.kind == "Rec" then
        return self:formatExpression(field.key, level) .. " = " .. self:formatExpression(field.value, level)
    end
    return self:formatExpression(field.value, level)
end

function Formatter:formatMemberExpression(expression, level)
    local base = self:formatPrefixBase(expression.base, level)
    if expression.indexer == "[" then
        return base .. "[" .. self:formatExpression(expression.identifier, level) .. "]"
    end
    return base .. expression.indexer .. self:formatExpression(expression.identifier, level)
end

function Formatter:formatCallExpression(expression, level)
    local base = self:formatPrefixBase(expression.base, level)
    if expression.methodIdentifier then
        base = base .. ":" .. self:formatExpression(expression.methodIdentifier, level)
    end
    return base .. "(" .. self:formatExpressionList(expression.arguments, level) .. ")"
end

function Formatter:formatPrefixBase(expression, level)
    local text = self:formatExpression(expression, level)
    if self:isSafePrefixBase(expression) then
        return text
    end
    return "(" .. text .. ")"
end

function Formatter:isSafePrefixBase(expression)
    return expression.type == "Identifier"
        or expression.type == "MemberExpression"
        or expression.type == "CallExpression"
end

function Formatter:formatFunctionExpression(expression, level)
    local params = self:formatParams(expression.params, expression.isVararg, false)
    local lines = { "function(" .. params .. ")" }
    local bodyText = self:formatBlock(expression.body, level + 1)
    if bodyText ~= "" then
        lines[#lines + 1] = bodyText
    end
    lines[#lines + 1] = self:indent(level) .. "end"
    return table.concat(lines, "\n")
end

return Formatter
