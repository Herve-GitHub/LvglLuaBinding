-- editor/DataAction.lua
-- 动作执行器
--local lvgl = require("lvgl")
local DataAction = {}

-- 执行写入操作
local function write_bind_point(params)
    local bind_point = params.bind_point
    local value = params.value or "1"
    local websocket = params.websocket_url  -- 注意：这里是 websocket_url 不是 websocket.url
    
    print("\n========== WebSocket 写入 ==========")
    print("📤 数据点: " .. tostring(bind_point))
    print("📤 写入值: " .. tostring(value))
    print("📤 WebSocket: " .. tostring(websocket))
    print("📤 时间: " .. os.date("%H:%M:%S"))
    print("====================================\n")
    
    -- 启动网络服务并连接
    if lvgl then
        lvgl.start_network_service(100)
        lvgl.connect(websocket, 3000)
        lvgl.write(bind_point, value)
    end
    
    return true
end

-- 执行读取操作（新增）
local function read_bind_point(params)
    local bind_point = params.bind_point
    local websocket = params.websocket_url
    
    print("\n========== WebSocket 读取 ==========")
    print("📥 数据点: " .. tostring(bind_point))
    print("📥 WebSocket: " .. tostring(websocket))
    print("📥 时间: " .. os.date("%H:%M:%S"))
    print("====================================\n")
    
    -- 启动网络服务并连接
    if lvgl then
        lvgl.start_network_service(100)
        lvgl.connect(websocket, 3000)
        lvgl.read(bind_point)
    end
    
    return true
end

-- 执行WebSocket连接
local function websocket_connect(params)
    local websocket = params.websocket_url
    
    print("\n========== WebSocket 连接 ==========")
    print("🔌 连接: " .. tostring(websocket))
    print("📤 时间: " .. os.date("%H:%M:%S"))
    print("====================================\n")
    
    if lvgl then
        lvgl.start_network_service(100)
        lvgl.connect(websocket, 3000)
    end
    
    return true
end

-- 创建动作回调
function DataAction.create_callback(action_type, params)
    return function()
        print("[动作] 触发: " .. action_type)
        
        if action_type == "写入绑定数据点" then
            return write_bind_point(params)
        elseif action_type == "读取绑定数据点" then
            return read_bind_point(params)
        elseif action_type == "连接WebSocket" then
            return websocket_connect(params)
        end
    end
end

return DataAction