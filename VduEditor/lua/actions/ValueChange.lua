-- actions/ValueChange.lua
-- 动作执行器
local ValueChange = {}

-- 全局连接状态
local connected_websockets = {}

-- 存储等待数据更新的标签
local pending_reads = {}  -- key: bind_point, value: label

-- 存储所有已绑定的标签
local bound_labels = {}  -- key: bind_point, value: label

-- 存储读写模式的标签配置
local read_write_labels = {}  -- key: bind_point, value: {label=label, write_value="1"}



-- 设置全局数据接收回调
local function setup_global_callback()
    -- 检查是否已经设置过
    if _G._data_callback_set then
        return
    end
    
    lvgl.set_callbacks(
        -- 连接状态回调
        function(connected)
            print("[WebSocket] 连接状态: " .. tostring(connected))
        end,
        
        -- 数据接收回调
        function(device_id, value, status)
            print("[数据回调] 收到: " .. device_id .. " = " .. value)
            
            -- 1. 更新等待读取的标签
            local pending_label = pending_reads[device_id]
            if pending_label and pending_label.set_text then
                pending_label:set_text(value)
                pending_reads[device_id] = nil
            end
            
            -- 2. 更新所有已绑定的标签
            local bound_label = bound_labels[device_id]
            if bound_label and bound_label.set_text then
                print("[自动更新] 更新标签: " .. device_id .. " = " .. value)
                bound_label:set_text(value)
            end
            
            -- 3. 更新读写模式的标签
            local rw_config = read_write_labels[device_id]
            if rw_config and rw_config.button and rw_config.label.set_text then
                print("[读写模式] 更新标签: " .. device_id .. " = " .. value)
                rw_config.label:set_text(value)
            end
        end
    )
    
    _G._data_callback_set = true
end



-- 执行读取操作
local function label_bind_point(params)
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local label = params.label
    
 
    
    setup_global_callback()
    
    if lvgl then
        if label and label.set_text then
           label:set_text("...")
        end
        
       if label and bind_point then
            pending_reads[bind_point] = label
            bound_labels[bind_point] = label
            print("[绑定] 标签绑定到数据点: " .. bind_point)
        end
        
       -- print("[读取] 发起读取请求: " .. bind_point)]]--
        lvgl.read(bind_point)
    end
    
    --return true
end


-- 创建动作回调
function ValueChange.create_callback(action_type, params)
    return function()
        print("[LabelAction] 执行回调: " .. action_type)
        
        if action_type == "值变化" then
            return label_bind_point(params)
        end
    end
end







return ValueChange