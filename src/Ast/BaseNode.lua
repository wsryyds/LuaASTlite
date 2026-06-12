-- src/Ast/BaseNode.lua
-- AST 基础节点类
-- 所有 AST 节点的基类，提供通用属性和方法

local Class = require("src.Core.Class")

-----------------------------------------------------------
-- 基础节点类 (BaseNode)
-----------------------------------------------------------

--- @class BaseNode
--- @field startToken Token|nil 起始词法单元
--- @field endToken Token|nil 结束词法单元
--- @field scope Scope|nil 所属作用域
--- @field leadingComments Token[] 前置注释列表
--- @field trailingComments Token[] 后置注释列表
local BaseNode = Class("BaseNode")

-----------------------------------------------------------
-- 构造函数
-----------------------------------------------------------

--- 构造基础节点
function BaseNode:constructor()
    -- 位置信息：记录节点对应的词法单元范围
    self.startToken = nil       -- 起始词法单元
    self.endToken = nil         -- 结束词法单元
    
    -- 作用域信息
    self.scope = nil            -- 所属作用域
    
    -- 注释信息
    self.leadingComments = {}   -- 前置注释列表
    self.trailingComments = {}  -- 后置注释列表
end

-----------------------------------------------------------
-- 位置信息方法
-----------------------------------------------------------

--- 设置节点的位置信息
--- @param startToken Token 起始词法单元
--- @param endToken Token 结束词法单元
function BaseNode:setLocation(startToken, endToken)
    self.startToken = startToken
    self.endToken = endToken
end

-----------------------------------------------------------
-- 访问者模式方法
-----------------------------------------------------------

--- 接受访问者 (Visitor Pattern)
--- @param visitor table 访问者对象
--- @return any 访问结果
function BaseNode:accept(visitor)
    local methodName = "visit" .. (self.type or self.__name)
    
    if visitor[methodName] then
        return visitor[methodName](visitor, self)
    end
    
    -- 尝试使用通用的 visitNode 方法
    if visitor.visitNode then
        return visitor.visitNode(visitor, self)
    end
    
    error("访问者未实现方法: " .. methodName)
end

-----------------------------------------------------------
-- 注释管理方法
-----------------------------------------------------------

--- 添加前置注释
--- @param comment Token 注释词法单元
function BaseNode:addLeadingComment(comment)
    self.leadingComments[#self.leadingComments + 1] = comment
end

--- 添加后置注释
--- @param comment Token 注释词法单元
function BaseNode:addTrailingComment(comment)
    self.trailingComments[#self.trailingComments + 1] = comment
end

-----------------------------------------------------------
-- 作用域管理方法
-----------------------------------------------------------

--- 设置所属作用域
--- @param scope Scope 作用域对象
function BaseNode:setScope(scope)
    self.scope = scope
end

--- 获取所属作用域
--- @return Scope|nil 作用域对象
function BaseNode:getScope()
    return self.scope
end

return BaseNode
