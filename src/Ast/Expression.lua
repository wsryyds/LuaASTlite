-- src/Ast/Expression.lua
-- AST 表达式节点类
-- 定义所有表达式类型的 AST 节点

local BaseNode = require("src.Ast.BaseNode")
local Class = require("src.Core.Class")

-----------------------------------------------------------
-- 表达式节点模块
-----------------------------------------------------------

local Expression = {}

-----------------------------------------------------------
-- 字面量节点 (Literal)
-----------------------------------------------------------

--- @class LiteralNode : BaseNode
--- @field value any 字面量的实际值
--- @field rawValue string 字面量的原始文本
Expression.LiteralNode = Class("LiteralNode", BaseNode)

--- 构造字面量节点
--- @param value any 字面量值（数字、字符串、布尔值、nil）
--- @param rawValue string 原始文本表示
function Expression.LiteralNode:constructor(value, rawValue)
    BaseNode.constructor(self)
    self.type = "Literal"
    self.value = value
    self.rawValue = rawValue
end

-----------------------------------------------------------
-- 可变参数节点 (Vararg)
-----------------------------------------------------------

--- @class VarargNode : BaseNode
Expression.VarargNode = Class("VarargNode", BaseNode)

--- 构造可变参数节点 (...)
function Expression.VarargNode:constructor()
    BaseNode.constructor(self)
    self.type = "VarargLiteral"
end

-----------------------------------------------------------
-- 标识符节点 (Identifier)
-----------------------------------------------------------

--- @class IdentifierNode : BaseNode
--- @field name string 标识符名称
--- @field variable Variable|nil 关联的变量实体
--- @field varType string|nil 变量类型 "local" | "global" | "upvalue"
Expression.IdentifierNode = Class("IdentifierNode", BaseNode)

--- 构造标识符节点
--- @param name string 标识符名称
function Expression.IdentifierNode:constructor(name)
    BaseNode.constructor(self)
    self.type = "Identifier"
    self.name = name
    self.variable = nil
    self.varType = nil
end


-----------------------------------------------------------
-- 二元表达式节点 (BinaryExpression)
-----------------------------------------------------------

--- @class BinaryExpressionNode : BaseNode
--- @field operator Token 运算符词法单元
--- @field left Expression 左侧表达式
--- @field right Expression 右侧表达式
Expression.BinaryExpressionNode = Class("BinaryExpressionNode", BaseNode)

--- 构造二元表达式节点
--- @param operator Token 运算符
--- @param left Expression 左侧表达式
--- @param right Expression 右侧表达式
function Expression.BinaryExpressionNode:constructor(operator, left, right)
    BaseNode.constructor(self)
    self.type = "BinaryExpression"
    self.operator = operator
    self.left = left
    self.right = right
end

-----------------------------------------------------------
-- 一元表达式节点 (UnaryExpression)
-----------------------------------------------------------

--- @class UnaryExpressionNode : BaseNode
--- @field operator Token 运算符词法单元
--- @field argument Expression 操作数表达式
Expression.UnaryExpressionNode = Class("UnaryExpressionNode", BaseNode)

--- 构造一元表达式节点
--- @param operator Token 运算符
--- @param argument Expression 操作数
function Expression.UnaryExpressionNode:constructor(operator, argument)
    BaseNode.constructor(self)
    self.type = "UnaryExpression"
    self.operator = operator
    self.argument = argument
    self.operand = argument  -- 兼容别名
end

-----------------------------------------------------------
-- 表构造节点 (TableConstructor)
-----------------------------------------------------------

--- @class TableConstructorNode : BaseNode
--- @field fields TableField[] 表字段列表
Expression.TableConstructorNode = Class("TableConstructorNode", BaseNode)

--- 构造表构造节点
--- @param fields TableField[] 字段列表
function Expression.TableConstructorNode:constructor(fields)
    BaseNode.constructor(self)
    self.type = "TableConstructorExpression"
    self.fields = fields or {}
end

-----------------------------------------------------------
-- 表字段节点 (TableField)
-----------------------------------------------------------

--- @class TableFieldNode : BaseNode
--- @field key Expression|nil 字段键（可为 nil 表示数组元素）
--- @field value Expression 字段值
--- @field kind string 字段类型 "Map" | "Rec" | "List"
Expression.TableFieldNode = Class("TableFieldNode", BaseNode)

--- 构造表字段节点
--- @param key Expression|nil 字段键
--- @param value Expression 字段值
--- @param kind string 字段类型
function Expression.TableFieldNode:constructor(key, value, kind)
    BaseNode.constructor(self)
    self.type = "TableField"
    self.key = key
    self.value = value
    self.kind = kind
end

-----------------------------------------------------------
-- 成员访问节点 (MemberExpression)
-----------------------------------------------------------

--- @class MemberExpressionNode : BaseNode
--- @field base Expression 被访问的对象
--- @field indexer string 索引方式 "." 或 "["
--- @field identifier Expression 成员标识符或索引表达式
Expression.MemberExpressionNode = Class("MemberExpressionNode", BaseNode)

--- 构造成员访问节点
--- @param base Expression 被访问的对象
--- @param indexer string 索引方式
--- @param identifier Expression 成员标识
function Expression.MemberExpressionNode:constructor(base, indexer, identifier)
    BaseNode.constructor(self)
    self.type = "MemberExpression"
    self.base = base
    self.indexer = indexer
    self.identifier = identifier
end

-----------------------------------------------------------
-- 函数调用节点 (CallExpression)
-----------------------------------------------------------

--- @class CallExpressionNode : BaseNode
--- @field base Expression 被调用的函数表达式
--- @field arguments Expression[] 参数列表
--- @field methodIdentifier IdentifierNode|nil 方法名（用于冒号调用）
Expression.CallExpressionNode = Class("CallExpressionNode", BaseNode)

--- 构造函数调用节点
--- @param base Expression 被调用的函数
--- @param arguments Expression[] 参数列表
--- @param methodIdentifier IdentifierNode|nil 方法名
function Expression.CallExpressionNode:constructor(base, arguments, methodIdentifier)
    BaseNode.constructor(self)
    self.type = "CallExpression"
    self.base = base
    self.arguments = arguments or {}
    self.methodIdentifier = methodIdentifier
end

-----------------------------------------------------------
-- 函数表达式节点 (FunctionExpression)
-----------------------------------------------------------

--- @class FunctionExpressionNode : BaseNode
--- @field params IdentifierNode[] 参数列表
--- @field isVararg boolean 是否有可变参数
--- @field body BlockNode 函数体
--- @field upvalues Variable[] 捕获的上值列表
--- @field localScope Scope|nil 函数内部作用域
Expression.FunctionExpressionNode = Class("FunctionExpressionNode", BaseNode)

--- 构造函数表达式节点
--- @param params IdentifierNode[] 参数列表
--- @param isVararg boolean 是否可变参数
--- @param body BlockNode 函数体
function Expression.FunctionExpressionNode:constructor(params, isVararg, body)
    BaseNode.constructor(self)
    self.type = "FunctionExpression"
    self.params = params or {}
    self.isVararg = isVararg or false
    self.body = body
    self.upvalues = {}
    self.localScope = nil
end

return Expression
