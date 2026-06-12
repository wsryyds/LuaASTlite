-- main.lua
-- LuaAstlite 最小解析入口

local scriptPath = arg and arg[0] or "main.lua"
local scriptDir = scriptPath:match("^(.*[\\/])") or "./"
package.path = table.concat({
    scriptDir .. "?.lua",
    scriptDir .. "?/init.lua",
    package.path
}, ";")

local LuaAstlite = require("LuaAstlite")

local function printUsage()
    print("用法: lua main.lua [--format] [file.lua]")
    print("不传文件时默认解析 test.lua")
end

local inputFile = nil
local formatMode = false

if arg then
    for i = 1, #arg do
        local value = arg[i]
        if value == "-h" or value == "--help" then
            printUsage()
            return
        elseif value == "--format" then
            formatMode = true
        elseif not inputFile then
            inputFile = value
        else
            io.stderr:write("错误: 未知参数 '" .. value .. "'\n")
            printUsage()
            os.exit(1)
        end
    end
end

inputFile = inputFile or (scriptDir .. "test.lua")

local file = io.open(inputFile, "r")
if not file then
    io.stderr:write("错误: 无法打开文件 '" .. inputFile .. "'\n")
    os.exit(1)
end

local source = file:read("*a")
file:close()

local ok, result = pcall(function()
    if formatMode then
        return LuaAstlite.format(source)
    end
    return LuaAstlite.parse(source)
end)

if not ok then
    local message = tostring(result):gsub("^.-:%d+: ", "", 1)
    io.stderr:write("解析失败: " .. message .. "\n")
    os.exit(1)
end

if formatMode then
    print(result)
    return
end

local ast = result

if ast and ast.type then
    print("解析成功: " .. ast.type)
end
