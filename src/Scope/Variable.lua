-- src/Scope/Variable.lua

local Class = require("src.Core.Class")

--- @class Variable
--- @field name string 变量名
--- @field scope Scope 定义所在的作用域
--- @field isGlobal boolean 是否为全局变量
--- @field isUpvalue boolean 是否为 Upvalue
--- @field canRename boolean 是否可以重命名
--- @field definitionNode BaseNode 定义节点
--- @field references BaseNode[] 变量的所有引用
--- @field values table[] 变量的所有值（赋值）
local Variable = Class("Variable")

--- Variable 构造函数
--- @param name string 变量名
--- @param scope Scope 定义所在的作用域
--- @param isGlobal boolean|nil 是否为全局变量
function Variable:constructor(name, scope, isGlobal)
    self.name = name
    self.scope = scope
    self.isGlobal = isGlobal or false
    self.isUpvalue = false
    self.canRename = not (isGlobal or false)
    self.definitionNode = nil
    self.references = {}
    self.values = {}  -- 变量的所有值（赋值）
end

--- 添加引用
--- @param referenceNode BaseNode 引用节点
function Variable:addReference(referenceNode)
    if referenceNode then
        self.references[#self.references + 1] = referenceNode
    end
end

--- 添加值（赋值）
--- @param value table 值对象
function Variable:addValue(value)
    self.values[#self.values + 1] = value
end

--- 获取值列表
--- @return table[]
function Variable:getValues()
    return self.values
end

--- 检查是否被使用
--- @return boolean
function Variable:isUsed()
    if #self.references > 0 then
        return true
    end
    for _, value in ipairs(self.values) do
        if value.used or value.mutated then
            return true
        end
    end
    return false
end

return Variable
