-- src/Core/Class.lua
-- 面向对象类系统实现
-- 提供类定义、继承、实例化等功能

--- 创建类的函数，支持继承
--- @param className string 类名
--- @param super table|nil 父类（可选）
--- @return table 新创建的类
local function Class(className, super)
    local cls = {}
    cls.__name = className
    cls.__super = super
    cls.__index = cls

    -- 继承父类的方法
    setmetatable(cls, {
        __index = super,
        __call = function(c, ...)
            return c.new(...)
        end
    })

    -- 定义 .new() 构造器
    function cls.new(...)
        local instance = setmetatable({}, cls)
        if instance.constructor then
            instance:constructor(...)
        end
        return instance
    end

    -- 检查实例是否属于该类
    function cls.isInstance(instance)
        if type(instance) ~= "table" then return false end
        local mt = getmetatable(instance)
        while mt do
            if mt == cls then return true end
            mt = getmetatable(mt)
            if mt then mt = mt.__index end
        end
        return false
    end

    return cls
end

return Class
