-- editor/DataAction.lua
-- 动作执行器
local DataManager = require("editor.DataManager")
local DataAction = {}

-- 全局连接状态
local connected_websockets = {}

-- 存储等待数据更新的按钮
local pending_reads = {}  -- key: bind_point, value: button

-- 存储所有已绑定的按钮
local bound_buttons = {}  -- key: bind_point, value: button

-- 存储读写模式的按钮配置
local read_write_buttons = {}  -- key: bind_point, value: {button=button, write_value="1"}

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
    if _G._data_action_callback_set then
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
            
            -- 1. 更新等待读取的按钮
            local pending_button = pending_reads[device_id]
            if pending_button and pending_button.set_label then
                pending_button:set_label(value)
                pending_reads[device_id] = nil
            end
            
            -- 2. 更新所有已绑定的按钮
            local bound_button = bound_buttons[device_id]
            if bound_button and bound_button.set_label then
                print("[自动更新] 更新按钮: " .. device_id .. " = " .. value)
                bound_button:set_label(value)
            end
            
            -- 3. 更新读写模式的按钮
            local rw_config = read_write_buttons[device_id]
            if rw_config and rw_config.button and rw_config.button.set_label then
                print("[读写模式] 更新按钮: " .. device_id .. " = " .. value)
                rw_config.button:set_label(value)
            end
        end
    )
    
    _G._data_action_callback_set = true
end

-- 执行写入操作
local function write_bind_point(params)
    local bind_point = params.bind_point
    local value = params.value or "1"
    local websocket = params.websocket_url or params.url or params.websocket
    
   -- if not bind_point or bind_point == "" then
    --    print("[错误] 写入操作失败：未配置数据点")
    --    return false
   -- end
    
    --if not ensure_websocket_connected(websocket) then
    --    return false
    --end
    
    --setup_global_callback()
    
   -- if lvgl then
    --    print("[写入] 写入数据点 " .. bind_point .. " = " .. value)
        lvgl.write(bind_point, value)
   -- end
    
    --return true
end

-- 执行读取操作
local function read_bind_point(params)
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local button = params.button
    
   --[[ if not bind_point or bind_point == "" then
        print("[错误] 读取操作失败：未配置数据点")
       return false
    end]]--
    
   -- if not ensure_websocket_connected(websocket) then
   --   return true
  --  end
    
    setup_global_callback()
    
    if lvgl then
       -- if button and button.set_label then
        --   button:set_label("...")
       -- end
        
       if button and bind_point then
            pending_reads[bind_point] = button
            bound_buttons[bind_point] = button
            print("[绑定] 按钮绑定到数据点: " .. bind_point)
        end
        
       -- print("[读取] 发起读取请求: " .. bind_point)]]--
        lvgl.read(bind_point)
    end
    
    --return true
end

-- 执行读写数据点操作（替代原来的websocket_connect）
local function read_write_bind_point(params)
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local button = params.button
    local write_value = params.write_value or params.value or "1"
    
    print("[读写模式] 初始化: bind_point=" .. tostring(bind_point) .. 
          ", write_value=" .. tostring(write_value))
    
    if not bind_point or bind_point == "" then
        print("[错误] 读写操作失败：未配置数据点")
        return false
    end
    
    if not ensure_websocket_connected(websocket) then
        return false
    end
    
    setup_global_callback()
    
    -- 注册按钮
    if button and bind_point then
        -- 保存到读写模式表
        read_write_buttons[bind_point] = {
            button = button,
            write_value = write_value
        }
        
        -- 同时也注册到bound_buttons，确保能接收数据更新
        bound_buttons[bind_point] = button
        
        print("[读写模式] 按钮已注册到数据点: " .. bind_point .. "，写入值: " .. write_value)
        
        -- 立即发起第一次读取
        if lvgl then
            print("[读写模式] 首次读取数据点: " .. bind_point)
            lvgl.read(bind_point)
        end
        
        -- 返回true表示成功
        return true
    end
    
    return false
end

-- 创建动作回调
function DataAction.create_callback(action_type, params)
    return function()
        print("[DataAction] 执行回调: " .. action_type)
        
        if action_type == "写入绑定数据点" then
            if params.bind_point then
                DataManager.write(params.bind_point, params.value or "1")
            end
            
        elseif action_type == "读取绑定数据点" then
            if params.button and params.bind_point then
                DataManager.register_button(params.bind_point, params.button)
                DataManager.read(params.bind_point)
            end
            
        elseif action_type == "读写数据点" then
            if params.button and params.bind_point then
                DataManager.register_button(params.bind_point, params.button)
                DataManager.read(params.bind_point)
                -- 写入逻辑在按钮点击时单独处理
            end
        end
    end
end

-- 解绑按钮的方法
function DataAction.unbind_button(bind_point)
    if bind_point then
        bound_buttons[bind_point] = nil
        pending_reads[bind_point] = nil
        read_write_buttons[bind_point] = nil
        print("[解绑] 已解除数据点绑定: " .. bind_point)
    end
end





return DataAction