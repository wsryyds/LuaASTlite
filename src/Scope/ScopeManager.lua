-- src/Scope/ScopeManager.lua

local Class = require("src.Core.Class")
local Scope = require("src.Scope.Scope")
local Variable = require("src.Scope.Variable")

--- @class ScopeManager
--- @field globalScope Scope 全局作用域
--- @field currentScope Scope 当前作用域
--- @field allVariables Variable[] 所有变量列表
--- @field functionStack table[] 当前函数解析上下文栈
local ScopeManager = Class("ScopeManager")

--- ScopeManager 构造函数
function ScopeManager:constructor()
    self.globalScope = Scope.new(nil)
    self.currentScope = self.globalScope
    self.allVariables = {}
    self.functionStack = {}
    -- 预定义全局变量
    self:defineGlobal("_G")
    self:defineGlobal("_ENV")
end

--- 进入新作用域
--- @param options table|nil 作用域选项
--- @return Scope 新创建的作用域
function ScopeManager:enterScope(options)
    local newScope = Scope.new(self.currentScope, options)
    self.currentScope = newScope
    return newScope
end

--- 进入函数作用域，并记录该函数捕获的 upvalue
--- @return Scope 新创建的函数作用域
function ScopeManager:enterFunctionScope()
    local newScope = self:enterScope({ isFunctionScope = true })
    self.functionStack[#self.functionStack + 1] = {
        scope = newScope,
        upvalues = {},
        upvalueSet = {}
    }
    return newScope
end

--- 退出当前作用域
--- @return Scope 退出后的当前作用域（父作用域）
function ScopeManager:exitScope()
    if self.currentScope.parent then
        self.currentScope = self.currentScope.parent
    end
    return self.currentScope
end

--- 退出函数作用域
--- @return table 函数上下文，包含 upvalues
function ScopeManager:exitFunctionScope()
    local context = table.remove(self.functionStack)
    self:exitScope()
    return context or { upvalues = {} }
end

--- 记录当前函数捕获的 upvalue
--- @param variable Variable 被捕获的变量
function ScopeManager:recordUpvalue(variable)
    local context = self.functionStack[#self.functionStack]
    if not context then return end
    if not context.upvalueSet[variable] then
        context.upvalueSet[variable] = true
        context.upvalues[#context.upvalues + 1] = variable
    end
end

--- 记录变量引用
--- @param variable Variable 变量实体
--- @param referenceNode BaseNode|nil 引用节点
function ScopeManager:recordReference(variable, referenceNode)
    if variable and referenceNode and variable.addReference then
        variable:addReference(referenceNode)
    end
end

--- 定义局部变量
--- @param name string 变量名
--- @param definitionNode BaseNode|nil 定义节点
--- @return Variable
function ScopeManager:defineLocal(name, definitionNode)
    local variable = Variable.new(name, self.currentScope, false)
    variable.definitionNode = definitionNode
    self.currentScope:define(name, variable)
    self.allVariables[#self.allVariables + 1] = variable
    return variable
end

--- 定义全局变量
--- @param name string 变量名
--- @return Variable
function ScopeManager:defineGlobal(name)
    local variable = Variable.new(name, self.globalScope, true)
    variable.canRename = false
    self.globalScope:define(name, variable)
    self.allVariables[#self.allVariables + 1] = variable
    return variable
end

--- 解析变量引用
--- @param name string 变量名
--- @param referenceNode BaseNode|nil 引用节点
--- @return Variable, string 变量实体和类型("local"|"global"|"upvalue")
function ScopeManager:resolveVariable(name, referenceNode)
    local scope = self.currentScope
    local crossedFunctionBoundary = false

    while scope do
        local variable = scope.variables[name]
        if variable then
            if variable.isGlobal then
                self:recordReference(variable, referenceNode)
                return variable, "global"
            end

            if scope == self.currentScope or not crossedFunctionBoundary then
                self:recordReference(variable, referenceNode)
                return variable, "local"
            end

            variable.isUpvalue = true
            self:recordUpvalue(variable)
            self:recordReference(variable, referenceNode)
            return variable, "upvalue"
        end

        if scope.isFunctionScope then
            crossedFunctionBoundary = true
        end
        scope = scope.parent
    end

    -- 未找到，创建全局变量
    local variable = self:defineGlobal(name)
    self:recordReference(variable, referenceNode)
    return variable, "global"
end

return ScopeManager
