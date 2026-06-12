-- src/Scope/Scope.lua

local Class = require("src.Core.Class")

--- @class Scope
--- @field parent Scope|nil 父作用域
--- @field variables table<string, Variable> 当前作用域的变量映射
--- @field children Scope[] 子作用域列表
--- @field isFunctionScope boolean 是否为函数作用域边界
local Scope = Class("Scope")

--- Scope 构造函数
--- @param parent Scope|nil 父作用域
--- @param options table|nil 作用域选项
function Scope:constructor(parent, options)
    options = options or {}
    self.parent = parent
    self.variables = {}
    self.children = {}
    self.isFunctionScope = options.isFunctionScope or false
    if parent then
        parent.children[#parent.children + 1] = self
    end
end

--- 在当前作用域定义变量
--- @param name string 变量名
--- @param variable Variable 变量实体
function Scope:define(name, variable)
    self.variables[name] = variable
end

--- 在作用域链中查找变量
--- @param name string 变量名
--- @return Variable|nil, Scope|nil 变量实体和所在作用域
function Scope:lookup(name)
    if self.variables[name] then
        return self.variables[name], self
    end
    if self.parent then
        return self.parent:lookup(name)
    end
    return nil, nil
end

--- 获取作用域深度
--- @return number
function Scope:getDepth()
    local depth = 0
    local current = self
    while current.parent do
        depth = depth + 1
        current = current.parent
    end
    return depth
end

return Scope
