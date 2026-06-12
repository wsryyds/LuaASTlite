-- src/Ast/Statement.lua
-- AST 语句节点类
-- 定义所有语句类型的 AST 节点

local BaseNode = require("src.Ast.BaseNode")
local Class = require("src.Core.Class")

-----------------------------------------------------------
-- 语句节点模块
-----------------------------------------------------------

local Statement = {}

-----------------------------------------------------------
-- 代码块节点 (Block)
-----------------------------------------------------------

--- @class BlockNode : BaseNode
--- @field body Statement[] 语句列表
Statement.BlockNode = Class("BlockNode", BaseNode)

--- 构造代码块节点
--- @param statements Statement[] 语句列表
function Statement.BlockNode:constructor(statements)
    BaseNode.constructor(self)
    self.type = "Block"
    self.body = statements or {}
    self.statements = self.body  -- 兼容别名
end

-----------------------------------------------------------
-- 赋值语句节点 (Assignment)
-----------------------------------------------------------

--- @class AssignmentStatementNode : BaseNode
--- @field variables Expression[] 左值列表
--- @field init Expression[] 右值列表
Statement.AssignmentStatementNode = Class("AssignmentStatementNode", BaseNode)

--- 构造赋值语句节点
--- @param variables Expression[] 左值列表
--- @param init Expression[] 右值列表
function Statement.AssignmentStatementNode:constructor(variables, init)
    BaseNode.constructor(self)
    self.type = "AssignmentStatement"
    self.variables = variables or {}
    self.init = init or {}
end


-----------------------------------------------------------
-- 局部变量声明节点 (LocalStatement)
-----------------------------------------------------------

--- @class LocalStatementNode : BaseNode
--- @field variables IdentifierNode[] 变量名列表
--- @field init Expression[] 初始值列表
Statement.LocalStatementNode = Class("LocalStatementNode", BaseNode)

--- 构造局部变量声明节点
--- @param variables IdentifierNode[] 变量名列表
--- @param init Expression[] 初始值列表
function Statement.LocalStatementNode:constructor(variables, init)
    BaseNode.constructor(self)
    self.type = "LocalStatement"
    self.variables = variables or {}
    self.init = init or {}
end

-----------------------------------------------------------
-- 调用语句节点 (CallStatement)
-----------------------------------------------------------

--- @class CallStatementNode : BaseNode
--- @field expression CallExpression 函数调用表达式
Statement.CallStatementNode = Class("CallStatementNode", BaseNode)

--- 构造调用语句节点
--- @param expression CallExpression 函数调用表达式
function Statement.CallStatementNode:constructor(expression)
    BaseNode.constructor(self)
    self.type = "CallStatement"
    self.expression = expression
end

-----------------------------------------------------------
-- Do 语句节点
-----------------------------------------------------------

--- @class DoStatementNode : BaseNode
--- @field body BlockNode 代码块
Statement.DoStatementNode = Class("DoStatementNode", BaseNode)

--- 构造 Do 语句节点
--- @param body BlockNode 代码块
function Statement.DoStatementNode:constructor(body)
    BaseNode.constructor(self)
    self.type = "DoStatement"
    self.body = body
end

-----------------------------------------------------------
-- While 循环语句节点
-----------------------------------------------------------

--- @class WhileStatementNode : BaseNode
--- @field condition Expression 循环条件
--- @field body BlockNode 循环体
Statement.WhileStatementNode = Class("WhileStatementNode", BaseNode)

--- 构造 While 循环节点
--- @param condition Expression 循环条件
--- @param body BlockNode 循环体
function Statement.WhileStatementNode:constructor(condition, body)
    BaseNode.constructor(self)
    self.type = "WhileStatement"
    self.condition = condition
    self.body = body
end

-----------------------------------------------------------
-- Repeat 循环语句节点
-----------------------------------------------------------

--- @class RepeatStatementNode : BaseNode
--- @field body BlockNode 循环体
--- @field condition Expression 终止条件
Statement.RepeatStatementNode = Class("RepeatStatementNode", BaseNode)

--- 构造 Repeat 循环节点
--- @param body BlockNode 循环体
--- @param condition Expression 终止条件
function Statement.RepeatStatementNode:constructor(body, condition)
    BaseNode.constructor(self)
    self.type = "RepeatStatement"
    self.body = body
    self.condition = condition
end

-----------------------------------------------------------
-- If 条件语句节点
-----------------------------------------------------------

--- @class IfStatementNode : BaseNode
--- @field clauses table[] 条件分支列表 {condition, body}
--- @field elseBody BlockNode|nil else 分支
Statement.IfStatementNode = Class("IfStatementNode", BaseNode)

--- 构造 If 条件节点
--- @param clauses table[] 分支列表
--- @param elseBody BlockNode|nil else 分支
function Statement.IfStatementNode:constructor(clauses, elseBody)
    BaseNode.constructor(self)
    self.type = "IfStatement"
    self.clauses = clauses or {}
    self.elseBody = elseBody
end

-----------------------------------------------------------
-- Break 语句节点
-----------------------------------------------------------

--- @class BreakStatementNode : BaseNode
Statement.BreakStatementNode = Class("BreakStatementNode", BaseNode)

--- 构造 Break 语句节点
function Statement.BreakStatementNode:constructor()
    BaseNode.constructor(self)
    self.type = "BreakStatement"
end

-----------------------------------------------------------
-- Return 语句节点
-----------------------------------------------------------

--- @class ReturnStatementNode : BaseNode
--- @field arguments Expression[] 返回值列表
Statement.ReturnStatementNode = Class("ReturnStatementNode", BaseNode)

--- 构造 Return 语句节点
--- @param arguments Expression[] 返回值列表
function Statement.ReturnStatementNode:constructor(arguments)
    BaseNode.constructor(self)
    self.type = "ReturnStatement"
    self.arguments = arguments or {}
end


-----------------------------------------------------------
-- 数值 For 循环节点
-----------------------------------------------------------

--- @class ForNumericStatementNode : BaseNode
--- @field variable IdentifierNode 循环变量
--- @field start Expression 起始值
--- @field endVal Expression 结束值
--- @field step Expression|nil 步长
--- @field body BlockNode 循环体
Statement.ForNumericStatementNode = Class("ForNumericStatementNode", BaseNode)

--- 构造数值 For 循环节点
--- @param variable IdentifierNode 循环变量
--- @param startVal Expression 起始值
--- @param endVal Expression 结束值
--- @param step Expression|nil 步长
--- @param body BlockNode 循环体
function Statement.ForNumericStatementNode:constructor(variable, startVal, endVal, step, body)
    BaseNode.constructor(self)
    self.type = "ForNumericStatement"
    self.variable = variable
    self.start = startVal
    self.endVal = endVal
    self.step = step
    self.body = body
end

-----------------------------------------------------------
-- 泛型 For 循环节点
-----------------------------------------------------------

--- @class ForGenericStatementNode : BaseNode
--- @field variables IdentifierNode[] 循环变量列表
--- @field iterators Expression[] 迭代器表达式列表
--- @field body BlockNode 循环体
Statement.ForGenericStatementNode = Class("ForGenericStatementNode", BaseNode)

--- 构造泛型 For 循环节点
--- @param variables IdentifierNode[] 循环变量列表
--- @param iterators Expression[] 迭代器列表
--- @param body BlockNode 循环体
function Statement.ForGenericStatementNode:constructor(variables, iterators, body)
    BaseNode.constructor(self)
    self.type = "ForGenericStatement"
    self.variables = variables or {}
    self.iterators = iterators or {}
    self.body = body
end

-----------------------------------------------------------
-- 函数声明节点
-----------------------------------------------------------

--- @class FunctionDeclarationNode : BaseNode
--- @field identifier Expression 函数名（标识符或成员表达式）
--- @field params IdentifierNode[] 参数列表
--- @field isVararg boolean 是否有可变参数
--- @field body BlockNode 函数体
--- @field isLocal boolean 是否为局部函数
--- @field localScope Scope|nil 函数内部作用域
--- @field upvalues Variable[] 捕获的上值列表
Statement.FunctionDeclarationNode = Class("FunctionDeclarationNode", BaseNode)

--- 构造函数声明节点
--- @param identifier Expression 函数名
--- @param params IdentifierNode[] 参数列表
--- @param isVararg boolean 是否可变参数
--- @param body BlockNode 函数体
--- @param isLocal boolean 是否局部函数
function Statement.FunctionDeclarationNode:constructor(identifier, params, isVararg, body, isLocal)
    BaseNode.constructor(self)
    self.type = "FunctionDeclaration"
    self.identifier = identifier
    self.params = params or {}
    self.isVararg = isVararg or false
    self.body = body
    self.isLocal = isLocal or false
    self.localScope = nil
    self.upvalues = {}
end

-----------------------------------------------------------
-- Goto 语句节点
-----------------------------------------------------------

--- @class GotoStatementNode : BaseNode
--- @field label string 跳转目标标签
Statement.GotoStatementNode = Class("GotoStatementNode", BaseNode)

--- 构造 Goto 语句节点
--- @param label string 标签名
function Statement.GotoStatementNode:constructor(label)
    BaseNode.constructor(self)
    self.type = "GotoStatement"
    self.label = label
end

-----------------------------------------------------------
-- 标签语句节点
-----------------------------------------------------------

--- @class LabelStatementNode : BaseNode
--- @field label string 标签名称
Statement.LabelStatementNode = Class("LabelStatementNode", BaseNode)

--- 构造标签语句节点
--- @param label string 标签名
function Statement.LabelStatementNode:constructor(label)
    BaseNode.constructor(self)
    self.type = "LabelStatement"
    self.label = label
end

return Statement
