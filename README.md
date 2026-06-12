# LuaAstlite

LuaAstlite 是一个轻量 Lua AST 解析器，包含 Lexer、Parser、AST 节点和基础作用域分析。

## 要求

- Lua 5.3 或更高版本
- 运行目录为项目根目录，或通过 `main.lua` 启动

## 命令行使用

```powershell
lua main.lua test.lua
```

不传文件时默认解析 `test.lua`：

```powershell
lua main.lua
```

查看帮助：

```powershell
lua main.lua --help
```

格式化文件：

```powershell
lua main.lua --format test.lua
```

Windows 下也可以把 `.lua` 文件拖到 `格式化.bat` 上。脚本不会覆盖源文件，会在同目录生成 `格式化` + 原文件名的新文件。

## 作为库使用

```lua
package.path = package.path .. ";./?.lua"

local LuaAstlite = require("LuaAstlite")

local ast, parser = LuaAstlite.parse("local x = 1")
print(ast.type) -- Block

local tokens = LuaAstlite.lex("print('ok')")
print(tokens[1].type)

local formatted = LuaAstlite.format("if x then print'x' end")
print(formatted)
```

`LuaAstlite.parse(source, options)` 返回根 `Block` 节点和 `Parser` 实例。

`LuaAstlite.lex(source, options)` 返回 token 列表和 `Lexer` 实例。`options.preserveComments = true` 时会保留注释 token。

`LuaAstlite.format(source, options)` 会解析源码并按 AST 重新输出格式化后的 Lua 代码。`options.indent` 可以是数字或字符串，默认是 4 个空格。

## 测试

```powershell
lua run_tests.lua
```

也可以先做 Lua 语法检查：

```powershell
luac -p main.lua LuaAstlite.lua run_tests.lua src\Lexer\*.lua src\Parser\*.lua src\Ast\*.lua src\Scope\*.lua src\Core\*.lua src\Formatter\*.lua
```

## 当前支持范围

已覆盖的核心语法包括：

- 字面量、标识符、表构造、函数调用
- 一元和二元表达式，包含 Lua 5.3 位运算符
- `local`、赋值、函数声明、匿名函数
- `if`、`while`、`repeat`、数值 `for`、泛型 `for`
- `break`、`return`、`goto`、标签
- 方法调用和方法声明

当前不支持或未完整支持：

- Lua 5.4 的 local attribute，例如 `local <const> x`
- Lexer 中存在部分扩展 token，例如 `+=`、`..=`、`->`，Parser 还未支持这些扩展语法
- 注释可被 Lexer 保留，但尚未自动挂载到 AST 节点的 `leadingComments` / `trailingComments`
- Formatter 基于 AST 重新打印代码，因此不会保留原始空白、原始括号风格或注释位置
