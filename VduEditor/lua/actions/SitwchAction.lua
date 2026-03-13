-- actions/SitwchAction.lua
-- 开关动作执行器 - 适配开关控件

local SitwchAction = {}

-- 全局连接状态
local connected_websockets = {}

-- 存储等待数据更新的开关
local pending_reads = {}  -- key: bind_point, value: switch

-- 存储所有已绑定的开关
local bound_switches = {}  -- key: bind_point, value: switch

-- 存储读写模式的开关配置
local read_write_switches = {}  -- key: bind_point, value: {switch=switch, on_value="1", off_value="0"}

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
        
        -- 数据接收回调
        function(device_id, value, status)
            print("[数据回调] 收到: " .. device_id .. " = " .. value)
            
            -- 1. 更新等待读取的开关
            local pending_switch = pending_reads[device_id]
            if pending_switch and pending_switch.set_property then
                -- 将接收到的值转换为布尔值（用于开关状态）
                local num_value = tonumber(value)
                local bool_value = false
                if num_value ~= nil then
                    bool_value = num_value ~= 0
                else
                    bool_value = value == "1" or value == "true" or value == "on"
                end
                
                print("[数据回调] 更新开关状态: " .. device_id .. " = " .. tostring(bool_value))
                pending_switch:set_property("switch_state", bool_value)
                pending_reads[device_id] = nil
            end
            
            -- 2. 更新所有已绑定的开关
            local bound_switch = bound_switches[device_id]
            if bound_switch and bound_switch.set_property then
                -- 将接收到的值转换为布尔值
                local num_value = tonumber(value)
                local bool_value = false
                if num_value ~= nil then
                    bool_value = num_value ~= 0
                else
                    bool_value = value == "1" or value == "true" or value == "on"
                end
                
                print("[自动更新] 更新开关: " .. device_id .. " = " .. tostring(bool_value))
                bound_switch:set_property("switch_state", bool_value)
            end
            
            -- 3. 更新读写模式的开关
            local rw_config = read_write_switches[device_id]
            if rw_config and rw_config.switch and rw_config.switch.set_property then
                -- 将接收到的值转换为布尔值
                local num_value = tonumber(value)
                local bool_value = false
                if num_value ~= nil then
                    bool_value = num_value ~= 0
                else
                    bool_value = value == "1" or value == "true" or value == "on"
                end
                
                print("[读写模式] 更新开关: " .. device_id .. " = " .. tostring(bool_value))
                rw_config.switch:set_property("switch_state", bool_value)
            end
        end
    )
    
    _G._data_callback_set = true
end

-- 执行写入操作
local function write_bind_point(params)
    local bind_point = params.bind_point
    local value = params.value or "1"
   -- local websocket = params.websocket_url or params.url or params.websocket
    
    --if not bind_point or bind_point == "" then
     --   print("[错误] 写入操作失败：未配置数据点")
     --   return false
    --end
    
   -- if not ensure_websocket_connected(websocket) then
   --     return false
  --  end
    
 --   setup_global_callback()
    
  --  if lvgl then
   --     print("[写入] 写入数据点 " .. bind_point .. " = " .. value)
        lvgl.write(bind_point, value)
 --   end
    
  --  return true
end

-- 执行读取操作（用于开关）
local function read_bind_point(params)
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local switch = params.switch
    
 
    
    --if not ensure_websocket_connected(websocket) then
     --   return false
    --end
    
    setup_global_callback()
    
    if lvgl then
        -- 注册开关到等待读取列表
        if switch and bind_point then
            pending_reads[bind_point] = switch
            bound_switches[bind_point] = switch
            print("[绑定] 开关绑定到数据点: " .. bind_point)
        end
        
        print("[读取] 发起读取请求: " .. bind_point)
        lvgl.read(bind_point)
    end
    
    return true
end

-- 执行读写数据点操作（用于开关）
local function read_write_bind_point(params)
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local switch = params.switch
    local write_value = params.write_value or {}  -- {on = on_value, off = off_value}
    
    print("[读写模式] 初始化: bind_point=" .. tostring(bind_point))
    
    if not bind_point or bind_point == "" then
        print("[错误] 读写操作失败：未配置数据点")
        return false
    end
    
    if not ensure_websocket_connected(websocket) then
        return false
    end
    
    setup_global_callback()
    
    -- 注册开关
    if switch and bind_point then
        -- 保存到读写模式表
        read_write_switches[bind_point] = {
            switch = switch,
            on_value = write_value.on or "1",
            off_value = write_value.off or "0"
        }
        
        -- 同时也注册到bound_switches，确保能接收数据更新
        bound_switches[bind_point] = switch
        
        print("[读写模式] 开关已注册到数据点: " .. bind_point)
        
        -- 立即发起第一次读取
        if lvgl then
            print("[读写模式] 首次读取数据点: " .. bind_point)
            lvgl.read(bind_point)
        end
        
        return true
    end
    
    return false
end

-- 创建动作回调
function SitwchAction.create_callback(action_type, params)
    return function()
        print("[SitwchAction] 执行回调: " .. action_type)
        
        if action_type == "写入绑定数据点" then
            return write_bind_point(params)
        elseif action_type == "读取绑定数据点" then
            return read_bind_point(params)
        elseif action_type == "读写数据点" then
            return read_write_bind_point(params)
        end
    end
end

-- 解绑开关的方法
function SitwchAction.unbind_switch(bind_point)
    if bind_point then
        bound_switches[bind_point] = nil
        pending_reads[bind_point] = nil
        read_write_switches[bind_point] = nil
        print("[解绑] 已解除数据点绑定: " .. bind_point)
    end
end

return SitwchAction