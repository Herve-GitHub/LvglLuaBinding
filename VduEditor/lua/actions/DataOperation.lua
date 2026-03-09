-- data_operation.lua
-- 数据读写操作动作函数模块（基于 DataAction 的封装）
-- 此模块定义了可用于按钮等控件的数据读写函数
-- 用于编译后的运行时环境

local DataAction = require("editor.DataAction")

local DataOperation = {}

-- 模块元数据
DataOperation.__action_meta = {
    id = "data_operation",
    name = "数据读写操作",
    description = "提供数据读写相关的动作函数，基于 DataAction 实现",
    version = "1.0",
}

-- 可用的动作列表（供属性编辑器读取）
DataOperation.available_actions = {
    {
        id = "write_bind_point",
        name = "写入绑定数据点",
        description = "向当前控件绑定的数据点写入值",
        params = {
            { name = "value", type = "string", label = "写入值", default = "1" },
        },
    },
    {
        id = "read_bind_point",
        name = "读取绑定数据点",
        description = "读取当前控件绑定的数据点",
        params = {},
    },
    {
        id = "toggle_bind_point",
        name = "切换绑定数据点",
        description = "切换当前控件绑定的数据点值（0/1）",
        params = {},
    },
    {
        id = "write_custom",
        name = "写入自定义地址",
        description = "向指定地址写入值",
        params = {
            { name = "address", type = "string", label = "地址", default = "Device1.E" },
            { name = "value", type = "string", label = "写入值", default = "42" },
        },
    },
    {
        id = "read_custom",
        name = "读取自定义地址",
        description = "读取指定地址的值",
        params = {
            { name = "address", type = "string", label = "地址", default = "Device1.E" },
        },
    },
    {
        id = "websocket_connect",
        name = "连接WebSocket",
        description = "连接控件配置的WebSocket服务器",
        params = {},
    },
    {
        id = "http_request",
        name = "发送HTTP请求",
        description = "发送HTTP请求到配置的URL",
        params = {},
    },
}

-- 存储标签引用（可选，用于按名称查找）
local _label_registry = {}

-- 存储控件ID与变量名的映射
local _widget_var_map = {}

-- 注册标签以便通过名称查找
function DataOperation.register_label(label_name, label_obj)
    _label_registry[label_name] = label_obj
    print("[DataOperation] 注册标签: " .. label_name)
end

-- 获取标签对象
function DataOperation.get_label(label_name)
    return _label_registry[label_name]
end

-- 注册控件变量名（由编译器生成的代码调用）
function DataOperation.register_widget_var(widget_id, var_name)
    _widget_var_map[widget_id] = var_name
end

-- 获取控件变量名
function DataOperation.get_widget_var(widget_id)
    return _widget_var_map[widget_id]
end

-- 写入绑定数据点（基于 DataAction）
-- @param widget_id: 控件ID
-- @param value: 要写入的值
function DataOperation.write_bind_point(widget_id, value)
    return DataAction.write_bind_point(widget_id, value)
end

-- 读取绑定数据点（基于 DataAction）
-- @param widget_id: 控件ID
function DataOperation.read_bind_point(widget_id)
    return DataAction.read_bind_point(widget_id)
end

-- 切换绑定数据点（基于 DataAction）
-- @param widget_id: 控件ID
function DataOperation.toggle_bind_point(widget_id)
    return DataAction.toggle_bind_point(widget_id)
end

-- 写入自定义地址
-- @param address: 完整地址
-- @param value: 要写入的值
function DataOperation.write_custom(address, value)
    return DataAction.write_custom(address, value)
end

-- 读取自定义地址
-- @param address: 完整地址
function DataOperation.read_custom(address)
    return DataAction.read_custom(address)
end

-- 连接WebSocket
-- @param widget_id: 控件ID
function DataOperation.websocket_connect(widget_id)
    return DataAction.websocket_connect(widget_id)
end

-- 发送HTTP请求
-- @param widget_id: 控件ID
function DataOperation.http_request(widget_id)
    return DataAction.http_request(widget_id)
end

-- 读取并显示到标签（兼容旧接口）
-- @param address: 完整地址
-- @param label_name: 标签名称（需预先注册）
function DataOperation.read_to_label(address, label_name)
    print("[DataOperation] 读取 " .. address .. " 并显示到 " .. label_name)
    
    -- 这里只触发读取，实际更新由 set_callbacks 中的回调处理
    return lvgl.read(address)
end

-- 切换值（0/1切换）- 兼容旧接口
-- @param address: 完整地址
function DataOperation.toggle_value(address)
    print("[DataOperation] 切换值: " .. address)
    
    -- 使用 DataAction 的缓存机制
    local current = DataAction._get_cache(address)
    local new_value = current == "1" and "0" or "1"
    return DataAction.write_custom(address, new_value)
end

-- 写入标签（兼容旧接口）
-- @param device_id: 设备ID
-- @param tag_name: 标签名
-- @param value: 要写入的值
function DataOperation.write_tag(device_id, tag_name, value)
    local full_address = device_id .. "." .. tag_name
    return DataAction.write_custom(full_address, value)
end

-- 读取标签（兼容旧接口）
-- @param device_id: 设备ID
-- @param tag_name: 标签名
function DataOperation.read_tag(device_id, tag_name)
    local full_address = device_id .. "." .. tag_name
    return DataAction.read_custom(full_address)
end

-- 写入固定地址（兼容旧接口）
-- @param address: 完整地址
-- @param value: 要写入的值
function DataOperation.write_constant(address, value)
    return DataAction.write_custom(address, value)
end

-- 创建动作回调函数（用于绑定到控件事件）
-- @param action_id: 动作ID
-- @param params: 动作参数表
-- @param widget_id: 控件ID（可选，某些动作需要）
-- @return: 可直接调用的回调函数
function DataOperation.create_action_callback(action_id, params, widget_id)
    params = params or {}
    
    if action_id == "write_bind_point" or action_id == "write_tag" then
        if widget_id then
            local value = params.value or "1"
            return function()
                DataAction.write_bind_point(widget_id, value)
            end
        else
            -- 兼容旧接口：使用 address 参数
            local address = params.address or params.device_id .. "." .. (params.tag_name or "tag0001")
            local value = params.value or "42"
            return function()
                DataAction.write_custom(address, value)
            end
        end
        
    elseif action_id == "read_bind_point" or action_id == "read_tag" then
        if widget_id then
            return function()
                DataAction.read_bind_point(widget_id)
            end
        else
            local address = params.address or params.device_id .. "." .. (params.tag_name or "tag0001")
            return function()
                DataAction.read_custom(address)
            end
        end
        
    elseif action_id == "write_custom" or action_id == "write_constant" then
        local address = params.address or "Device1.E"
        local value = params.value or "42"
        return function()
            DataAction.write_custom(address, value)
        end
        
    elseif action_id == "read_custom" then
        local address = params.address or "Device1.E"
        return function()
            DataAction.read_custom(address)
        end
        
    elseif action_id == "toggle_bind_point" or action_id == "toggle_value" then
        if widget_id then
            return function()
                DataAction.toggle_bind_point(widget_id)
            end
        else
            local address = params.address or "Device1.E"
            return function()
                local current = DataAction._get_cache(address)
                local new_value = current == "1" and "0" or "1"
                DataAction.write_custom(address, new_value)
            end
        end
        
    elseif action_id == "read_to_label" then
        local address = params.address or "Device1.E"
        local label_name = params.label_name or "display_label"
        return function()
            print("[DataOperation] 读取 " .. address .. " 并显示到 " .. label_name)
            lvgl.read(address)
        end
        
    elseif action_id == "websocket_connect" then
        if widget_id then
            return function()
                DataAction.websocket_connect(widget_id)
            end
        end
    elseif action_id == "http_request" then
        if widget_id then
            return function()
                DataAction.http_request(widget_id)
            end
        end
    end
    
    -- 未知动作，返回空函数
    print("[DataOperation] 警告: 未知动作 " .. tostring(action_id))
    return function() end
end

-- 设置全局回调处理（需要在主程序中调用）
function DataOperation.setup_global_callbacks(label_update_func)
    -- 使用 DataAction 的全局回调设置
    return DataAction.setup_global_callbacks(function(device_id, value, status)
        -- 更新缓存（DataAction 已经做了）
        
        -- 如果有提供标签更新函数，调用它
        if label_update_func then
            label_update_func(device_id, value, status)
        end
        
        -- 尝试更新注册的标签
        for label_name, label_obj in pairs(_label_registry) do
            -- 这里可以根据需要更新特定标签
            -- 例如，如果标签名与设备ID匹配
        end
    end)
end

return DataOperation