-- 脚本：解析并打印指定控件脚本的 __widget_meta 信息
-- 用法: lua lua/print_widget_meta.lua <path_to_widget_file>

local target_file = arg[1]
if not target_file then
    print("用法: lua lua/print_widget_meta.lua <lua_file_path>")
    return
end

-- 1. Dummy lvgl 模块 (如果在纯 Lua 环境运行)
-- 控件脚本会 require("lvgl")，需要模拟它以避免加载失败
if not package.loaded["lvgl"] then
    -- 创建一个能够响应任意调用的 Mock 对象
    local dummy_obj = {}
    local dummy_mt = {
        __index = function(_, key)
            -- 返回一个空函数，支持 obj:method() 调用
            return function() return dummy_obj end
        end,
        __newindex = function() end, -- 忽略赋值
        __call = function() return dummy_obj end -- 支持作为函数调用
    }
    setmetatable(dummy_obj, dummy_mt)

    -- 将 lvgl 模块设置为这个 Mock 对象
    package.loaded["lvgl"] = dummy_obj
end

-- 2. 配置包路径，确保能找到项目中的其他模块
-- 添加当前目录和 lua 子目录到搜索路径
package.path = package.path .. ";./?.lua;./lua/?.lua"

-- 3. 加载目标文件
-- 使用 dofile 直接执行文件并获取返回值
local ok, Widget = pcall(dofile, target_file)

if not ok then
    print("无法加载文件: " .. target_file)
    print("错误信息: " .. tostring(Widget))
    return
end

if type(Widget) ~= "table" then
    print("错误: 脚本没有返回 Widget 表 (got " .. type(Widget) .. ")")
    return
end

-- 4. 获取元数据
local meta = Widget.__widget_meta

if not meta then
    print("模块中未找到 __widget_meta 表")
    return
end

-- 5. 打印辅助函数
local function print_kv(key, value, indent)
    indent = indent or ""
    print(string.format("%s%s: %s", indent, key, tostring(value)))
end

-- 6. 遍历并打印
print("================================================================")
print("Widget Metadata Report: " .. target_file)
print("================================================================")

-- 打印基础信息
print("Basic Info:")
print_kv("ID", meta.id, "  ")
print_kv("Name", meta.name, "  ")
print_kv("Description", meta.description, "  ")
print_kv("Schema Version", meta.schema_version, "  ")
print_kv("Version", meta.version, "  ")

-- 打印属性 (Properties)
print("Properties:")
if meta.properties and #meta.properties > 0 then
    for i, prop in ipairs(meta.properties) do
        print(string.format("  [%d] %s", i, prop.name))
        for k, v in pairs(prop) do
            if k ~= "name" then
                print(string.format("      %s: %s", k, v))
            end
        end
    end
else
    print("  (None)")
end

-- 打印事件 (Events)
print("Events:")
if meta.events and #meta.events > 0 then
    for i, evt in ipairs(meta.events) do
        print(string.format("  - %s", evt))
    end
else
    print("  (None)")
end

print("================================================================")
