-- editor/DataAction.lua
-- 动作执行器
local DataAction = {}

-- 全局连接状态
local connected_websockets = {}

-- 存储等待数据更新的按钮
local pending_reads = {}  -- key: bind_point, value: button

-- 存储所有已绑定的按钮（新增！）
local bound_buttons = {}  -- key: bind_point, value: button

-- 确保WebSocket连接
local function ensure_websocket_connected(websocket)
    if not websocket then
        return false
    end
    
    if connected_websockets[websocket] then
        return true
    end
    
    lvgl.start_network_service(100)
    lvgl.connect(websocket, 3000)
    connected_websockets[websocket] = true
    
    -- 等待连接建立
    local start_time = os.clock()
    while os.clock() - start_time < 0.5 do end
    
    return true
end

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
        
        -- 数据接收回调（关键修改！）
        function(device_id, value, status)
            print("[数据回调] 收到: " .. device_id .. " = " .. value)
            
            -- 1. 首先更新等待读取的按钮（用于读取操作的响应）
            local pending_button = pending_reads[device_id]
            if pending_button and pending_button.set_label then
                pending_button:set_label(value)
                pending_reads[device_id] = nil  -- 清理
            end
            
            -- 2. 然后更新所有已绑定的按钮（用于云端主动推送！）
            local bound_button = bound_buttons[device_id]
            if bound_button and bound_button.set_label then
                print("[自动更新] 更新按钮: " .. device_id .. " = " .. value)
                bound_button:set_label(value)
            end
            
            -- 如果没有找到任何按钮，记录一下
            if not pending_button and not bound_button then
                print("[警告] 没有找到绑定点 " .. device_id .. " 对应的按钮")
            end
        end
    )
    
    _G._data_callback_set = true
end

-- 执行写入操作
local function write_bind_point(params)
    local bind_point = params.bind_point
    local value = params.value or "1"
    local websocket = params.websocket_url or params.url or params.websocket
    local button = params.button
    
    if not ensure_websocket_connected(websocket) then
        return false
    end
    
    -- 设置全局回调（如果还没设置）
    setup_global_callback()
    
    if lvgl then
        lvgl.write(bind_point, value)
    end
    
    return true
end

-- 执行读取操作
local function read_bind_point(params)
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local button = params.button
    
    if not ensure_websocket_connected(websocket) then
        return false
    end
    
    -- 设置全局回调（如果还没设置）
    setup_global_callback()
    
    if lvgl then
        -- 先设置按钮标签为"读取中..."
        if button and button.set_label then
            button:set_label("...")
        end
        
        -- 注册等待回调
        if button and bind_point then
            pending_reads[bind_point] = button
            -- 同时也注册到bound_buttons，实现长期绑定
            bound_buttons[bind_point] = button
            print("[绑定] 按钮绑定到数据点: " .. bind_point)
        end
        
        -- 发起读取请求
        lvgl.read(bind_point)
    end
    
    return true
end

-- 执行WebSocket连接
local function websocket_connect(params)
    local websocket = params.websocket_url or params.url or params.websocket
    
    if not websocket then
        return false
    end
    
    if lvgl then
        ensure_websocket_connected(websocket)
        setup_global_callback()
    end
    
    return true
end

-- 创建动作回调
function DataAction.create_callback(action_type, params)
    return function()
        if action_type == "写入绑定数据点" then
            return write_bind_point(params)
        elseif action_type == "读取绑定数据点" then
            return read_bind_point(params)
        elseif action_type == "连接WebSocket" then
            return websocket_connect(params)
        end
    end
end

-- 新增：解绑按钮的方法（可选，用于清理）
function DataAction.unbind_button(bind_point)
    if bind_point then
        bound_buttons[bind_point] = nil
        pending_reads[bind_point] = nil
    end
end

return DataAction