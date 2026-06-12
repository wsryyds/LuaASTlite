package.path = package.path .. ";./?.lua"

local LuaAstlite = require("LuaAstlite")
local TokenType = LuaAstlite.TokenType

local tests = {}

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s",
            message or "assertEqual failed", tostring(expected), tostring(actual)), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "assertTruthy failed", 2)
    end
end

local function assertFails(fn, expectedText, message)
    local ok, err = pcall(fn)
    if ok then
        error(message or "expected function to fail", 2)
    end
    if expectedText and not tostring(err):find(expectedText, 1, true) then
        error(string.format("%s: expected error containing %q, got %q",
            message or "unexpected error", expectedText, tostring(err)), 2)
    end
end

tests[#tests + 1] = {
    name = "parser smoke cases",
    run = function()
        local cases = {
            "local x = 1",
            "x = 1",
            "print(1)",
            "print\"x\"",
            "function f(a) return a end",
            "function t:m(a) return self.x end",
            "local t = { a = 1, [2] = 3, 4; 5 }",
            "if a then b() elseif c then d() else e() end",
            "while a do break end",
            "repeat local x = 1 until x > 0",
            "for i = 1, 10, 2 do print(i) end",
            "for k, v in pairs(t) do print(k, v) end",
            "local function f(...) return ... end",
            "goto a ::a::",
            "a = 1 + 2 * 3 ^ 4 .. 5",
            "a = not b and c or d",
            "(f)()"
        }

        for _, source in ipairs(cases) do
            local ast = LuaAstlite.parse(source)
            assertEqual(ast.type, "Block", source)
        end
    end
}

tests[#tests + 1] = {
    name = "lexer preserves comments when requested",
    run = function()
        local tokens = LuaAstlite.lex("-- c\nlocal x = 1", { preserveComments = true })
        assertEqual(tokens[1].type, TokenType.Comment, "first token")
        assertEqual(tokens[1].commentType, "line", "comment type")
        assertEqual(tokens[2].type, TokenType.KwLocal, "second token")
    end
}

tests[#tests + 1] = {
    name = "lexer rejects bare line break in short string",
    run = function()
        assertFails(function()
            LuaAstlite.lex("\"a\nb\"")
        end, "UnfinishedString")
    end
}

tests[#tests + 1] = {
    name = "block scope outer local is not an upvalue",
    run = function()
        local ast = LuaAstlite.parse("local x; do print(x) end")
        local doStatement = ast.body[2]
        local argument = doStatement.body.body[1].expression.arguments[1]

        assertEqual(argument.name, "x", "argument name")
        assertEqual(argument.varType, "local", "block reference varType")
        assertEqual(argument.variable.isUpvalue, false, "block reference variable.isUpvalue")
    end
}

tests[#tests + 1] = {
    name = "function capture is tracked as upvalue",
    run = function()
        local ast = LuaAstlite.parse("local x; function f() return x end")
        local functionStatement = ast.body[2]
        local argument = functionStatement.body.body[1].arguments[1]

        assertEqual(argument.name, "x", "argument name")
        assertEqual(argument.varType, "upvalue", "function reference varType")
        assertTruthy(functionStatement.localScope, "function declaration localScope")
        assertTruthy(functionStatement.localScope.isFunctionScope, "function scope boundary")
        assertEqual(#functionStatement.upvalues, 1, "upvalue count")
        assertEqual(functionStatement.upvalues[1].name, "x", "upvalue name")
    end
}

tests[#tests + 1] = {
    name = "anonymous function capture is tracked as upvalue",
    run = function()
        local ast = LuaAstlite.parse("local x; local f = function() return x end")
        local functionExpression = ast.body[2].init[1]
        local argument = functionExpression.body.body[1].arguments[1]

        assertEqual(functionExpression.type, "FunctionExpression", "expression type")
        assertEqual(argument.name, "x", "captured name")
        assertEqual(argument.varType, "upvalue", "captured varType")
        assertEqual(#functionExpression.upvalues, 1, "upvalue count")
        assertEqual(functionExpression.upvalues[1].name, "x", "upvalue name")
    end
}

tests[#tests + 1] = {
    name = "local function scope and recursive upvalue are tracked",
    run = function()
        local ast = LuaAstlite.parse("local function f() return f end")
        local functionStatement = ast.body[1]
        local argument = functionStatement.body.body[1].arguments[1]

        assertEqual(functionStatement.type, "FunctionDeclaration", "statement type")
        assertEqual(functionStatement.isLocal, true, "local function flag")
        assertTruthy(functionStatement.localScope, "local function localScope")
        assertEqual(argument.name, "f", "recursive reference name")
        assertEqual(argument.varType, "upvalue", "recursive reference varType")
        assertEqual(#functionStatement.upvalues, 1, "recursive upvalue count")
    end
}

tests[#tests + 1] = {
    name = "variable references and values are recorded",
    run = function()
        local ast = LuaAstlite.parse("local x; print(x); x = 2")
        local variable = ast.body[1].variables[1].variable

        assertEqual(#variable.references, 2, "reference count")
        assertEqual(#variable.values, 1, "value count")
        assertEqual(variable.values[1].kind, "assignment", "value kind")
        assertEqual(variable.values[1].mutated, true, "value mutation flag")
        assertEqual(variable:isUsed(), true, "isUsed")
    end
}

tests[#tests + 1] = {
    name = "formatter formats statements and blocks",
    run = function()
        local source = "local x=1 if x then print\"ok\" else x=x+1 end"
        local expected = table.concat({
            "local x = 1",
            "if x then",
            "    print(\"ok\")",
            "else",
            "    x = x + 1",
            "end"
        }, "\n")

        assertEqual(LuaAstlite.format(source), expected, "formatted block")
    end
}

tests[#tests + 1] = {
    name = "formatter formats tables and method declarations",
    run = function()
        local source = "local t={a=1,[2]=3,4}; function t:m(a)return self.x+a end"
        local expected = table.concat({
            "local t = {",
            "    a = 1,",
            "    [2] = 3,",
            "    4,",
            "}",
            "function t:m(a)",
            "    return self.x + a",
            "end"
        }, "\n")

        assertEqual(LuaAstlite.format(source), expected, "formatted table and method")
    end
}

tests[#tests + 1] = {
    name = "formatter preserves required prefix expression parentheses",
    run = function()
        local source = "(function(...) local x=1 return x end)(1,2); (\"abc\"):sub(1)"
        local expected = table.concat({
            "(function(...)",
            "    local x = 1",
            "    return x",
            "end)(1, 2)",
            "(\"abc\"):sub(1)"
        }, "\n")

        assertEqual(LuaAstlite.format(source), expected, "formatted prefix parentheses")
    end
}

tests[#tests + 1] = {
    name = "formatter escapes binary string bytes",
    run = function()
        local source = "local a=\"\\57\\11\\27\\3\\18\\12\"; local b=\"\\148\\157\\131\\130\""
        local expected = table.concat({
            "local a = \"\\057\\011\\027\\003\\018\\012\"",
            "local b = \"\\148\\157\\131\\130\""
        }, "\n")

        assertEqual(LuaAstlite.format(source), expected, "formatted binary strings")
    end
}

tests[#tests + 1] = {
    name = "formatter folds mostly short table fields",
    run = function()
        local source = "local k={95,49,231,54,194,185,4,135}; local long={veryLongName=123456,[2]=98765,4}"
        local expected = table.concat({
            "local k = { 95, 49, 231, 54, 194, 185, 4, 135 }",
            "local long = {",
            "    veryLongName = 123456,",
            "    [2] = 98765,",
            "    4,",
            "}"
        }, "\n")

        assertEqual(LuaAstlite.format(source), expected, "folded short table")
    end
}

local failed = 0

for _, test in ipairs(tests) do
    local ok, err = xpcall(test.run, debug.traceback)
    if ok then
        print("[PASS] " .. test.name)
    else
        failed = failed + 1
        io.stderr:write("[FAIL] " .. test.name .. "\n" .. tostring(err) .. "\n")
    end
end

if failed > 0 then
    io.stderr:write(string.format("%d test(s) failed\n", failed))
    os.exit(1)
end

print(string.format("%d test(s) passed", #tests))
