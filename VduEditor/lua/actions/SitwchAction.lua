-- actions/SitwchAction.lua
-- 开关动作执行器 - 适配开关控件

local SitwchAction = {}

-- 全局连接状态
local connected_websockets = {}  -- key: websocket_url, value: true
local active_connections = {}     -- key: websocket_url, value: connection_id (如果可用)

-- 存储等待数据更新的开关
local pending_reads = {}  -- key: bind_point, value: switch

-- 存储所有已绑定的开关
local bound_switches = {}  -- key: bind_point, value: switch

-- 存储读写模式的开关配置
local read_write_switches = {}  -- key: bind_point, value: {switch=switch, on_value="1", off_value="0"}

-- 回调已设置标志
local data_callback_set = false

-- 新增：判断是否在设计模式
local function is_design_mode()
    -- 可以通过全局变量或环境变量判断是否在设计模式
    return _G.design_mode == true
end

-- 确保WebSocket连接
local function ensure_websocket_connected(websocket)
    -- 重要：设计模式不执行实际连接
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过WebSocket连接")
        return false
    end
    
    if not websocket or websocket == "" then
        print("[SitwchAction] WebSocket地址为空")
        return false
    end
    
    if connected_websockets[websocket] then
        return true
    end
    
    local success, err = pcall(function()
        lvgl.start_network_service(100)
        local conn_id = lvgl.connect(websocket, 3000)
        connected_websockets[websocket] = true
        active_connections[websocket] = conn_id  -- 保存连接ID
        print("[SitwchAction] WebSocket连接成功: " .. websocket)
    end)
    
    if not success then
        print("[SitwchAction] WebSocket连接失败: " .. tostring(err))
        return false
    end
    
    -- 等待连接建立
    local start_time = os.clock()
    while os.clock() - start_time < 0.5 do end
    
    return true
end

-- 断开指定WebSocket连接
function SitwchAction.disconnect(websocket_url)
    if not websocket_url or websocket_url == "" then
        return
    end
    
    pcall(function()
        if connected_websockets[websocket_url] then
            print("[SitwchAction] 断开WebSocket连接: " .. websocket_url)
            -- 如果有断开连接的方法，调用它
            if lvgl and lvgl.disconnect then
                lvgl.disconnect(websocket_url)
            elseif lvgl and lvgl.close then
                lvgl.close(websocket_url)
            end
            connected_websockets[websocket_url] = nil
            active_connections[websocket_url] = nil
        end
    end)
end

-- 断开所有WebSocket连接
function SitwchAction.disconnect_all()
    print("[SitwchAction] 断开所有WebSocket连接")
    for url, _ in pairs(connected_websockets) do
        pcall(function()
            if lvgl and lvgl.disconnect then
                lvgl.disconnect(url)
            elseif lvgl and lvgl.close then
                lvgl.close(url)
            end
            print("[SitwchAction] 已断开: " .. url)
        end)
    end
    connected_websockets = {}
    active_connections = {}
end

-- 设置全局数据接收回调
local function setup_global_callback()
    -- 重要：设计模式不设置回调
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过设置回调")
        return false
    end
    
    -- 检查是否已经设置过
    if _G._sitwch_action_callback_set then
        return true
    end
    
    if not lvgl then
        print("[SitwchAction] lvgl不存在")
        return false
    end
    
    local success, err = pcall(function()
        lvgl.set_callbacks(
            -- 连接状态回调
            function(connected)
                print("[SitwchAction WebSocket] 连接状态: " .. tostring(connected))
                -- 如果连接断开，清理状态
                if not connected then
                    print("[SitwchAction] WebSocket连接已断开，清理状态")
                    connected_websockets = {}
                    active_connections = {}
                end
            end,
            
            -- 数据接收回调
            function(device_id, value, status)
                -- 使用pcall保护整个回调
                pcall(function()
                    print("[SitwchAction 数据回调] 收到: " .. tostring(device_id) .. " = " .. tostring(value))
                    
                    if not device_id then return end
                    
                    -- 将接收到的值转换为布尔值
                    local bool_value = false
                    if value then
                        local num_value = tonumber(value)
                        if num_value ~= nil then
                            bool_value = num_value ~= 0
                        else
                            bool_value = value == "1" or value == "true" or value == "on"
                        end
                    end
                    
                    -- 1. 更新等待读取的开关
                    if pending_reads[device_id] then
                        pcall(function()
                            local pending_switch = pending_reads[device_id]
                            if pending_switch and pending_switch.set_property then
                                print("[SitwchAction] 更新等待开关: " .. device_id .. " = " .. tostring(bool_value))
                                pending_switch:set_property("switch_state", bool_value)
                                pending_reads[device_id] = nil
                            end
                        end)
                    end
                    
                    -- 2. 更新所有已绑定的开关
                    if bound_switches[device_id] then
                        pcall(function()
                            local bound_switch = bound_switches[device_id]
                            if bound_switch and bound_switch.set_property then
                                print("[SitwchAction] 更新绑定开关: " .. device_id .. " = " .. tostring(bool_value))
                                bound_switch:set_property("switch_state", bool_value)
                            end
                        end)
                    end
                    
                    -- 3. 更新读写模式的开关
                    if read_write_switches[device_id] then
                        pcall(function()
                            local rw_config = read_write_switches[device_id]
                            if rw_config and rw_config.switch and rw_config.switch.set_property then
                                print("[SitwchAction] 更新读写开关: " .. device_id .. " = " .. tostring(bool_value))
                                rw_config.switch:set_property("switch_state", bool_value)
                            end
                        end)
                    end
                end)
            end
        )
    end)
    
    if not success then
        print("[SitwchAction] 设置回调失败: " .. tostring(err))
        return false
    end
    
    _G._sitwch_action_callback_set = true
    return true
end

-- 执行写入操作
local function write_bind_point(params)
    -- 重要：设计模式不执行实际写入
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过写入操作")
        return true
    end
    
    local bind_point = params.bind_point
    local value = params.value or "1"
    local websocket = params.websocket_url or params.url or params.websocket
    
    -- 检查必要参数
    if not bind_point or bind_point == "" then
        print("[SitwchAction] 写入操作失败：未配置数据点")
        return false
    end
    
    if not ensure_websocket_connected(websocket) then
        return false
    end
    
    setup_global_callback()
    
    if lvgl then
        print("[SitwchAction] 写入数据点 " .. bind_point .. " = " .. value)
        lvgl.write(bind_point, value)
    end
    
    return true
end

-- 执行读取操作（用于开关）
local function read_bind_point(params)
    -- 重要：设计模式不执行实际读取
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过读取操作")
        -- 在设计模式，只记录绑定，不实际读取
        if params and params.switch and params.bind_point then
            print("[SitwchAction] 设计模式记录绑定: " .. params.bind_point)
        end
        return true
    end
    
    -- 参数检查
    if not params then
        print("[SitwchAction] 读取操作失败：参数为空")
        return false
    end
    
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local switch = params.switch
    
    if not bind_point or bind_point == "" then
        print("[SitwchAction] 读取操作失败：未配置数据点")
        return false
    end
    
    if not ensure_websocket_connected(websocket) then
        print("[SitwchAction] 读取操作失败：WebSocket连接失败")
        return false
    end
    
    if not setup_global_callback() then
        print("[SitwchAction] 读取操作失败：无法设置回调")
        return false
    end
    
    if not lvgl or not lvgl.read then
        print("[SitwchAction] lvgl.read不存在")
        return false
    end
    
    -- 注册开关到等待读取列表
    if switch and bind_point then
        pending_reads[bind_point] = switch
        bound_switches[bind_point] = switch
        print("[SitwchAction] 开关绑定到数据点: " .. bind_point)
    end
    
    local success, err = pcall(function()
        print("[SitwchAction] 发起读取请求: " .. bind_point)
        lvgl.read(bind_point)
    end)
    
    if not success then
        print("[SitwchAction] 读取失败: " .. tostring(err))
        return false
    end
    
    return true
end

-- 执行读写数据点操作
local function read_write_bind_point(params)
    -- 重要：设计模式不执行实际读写
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过读写操作")
        -- 在设计模式，只记录绑定，不实际连接
        if params and params.switch and params.bind_point then
            print("[SitwchAction] 设计模式记录读写绑定: " .. params.bind_point)
        end
        return true
    end
    
    -- 参数检查
    if not params then
        print("[SitwchAction] 读写操作失败：参数为空")
        return false
    end
    
    local bind_point = params.bind_point
    local websocket = params.websocket_url or params.url or params.websocket
    local switch = params.switch
    local write_value = params.write_value or {}  -- {on = on_value, off = off_value}
    
    if not bind_point or bind_point == "" then
        print("[SitwchAction] 读写操作失败：未配置数据点")
        return false
    end
    
    if not switch then
        print("[SitwchAction] 读写操作失败：未提供开关实例")
        return false
    end
    
    if not ensure_websocket_connected(websocket) then
        print("[SitwchAction] 读写操作失败：WebSocket连接失败")
        return false
    end
    
    if not setup_global_callback() then
        print("[SitwchAction] 读写操作失败：无法设置回调")
        return false
    end
    
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
        
        print("[SitwchAction] 读写模式开关已注册到数据点: " .. bind_point)
        
        -- 注册写入回调到开关对象
        switch._write_callback = function(new_state)
            pcall(function()
                local value = new_state and write_value.on or write_value.off
                print("[SitwchAction] 读写模式状态改变，写入: " .. bind_point .. " = " .. value)
                
                -- 调用写入函数
                local write_cb = SitwchAction.create_callback("写入绑定数据点", {
                    bind_point = bind_point,
                    value = value,
                    websocket_url = websocket
                })
                if write_cb then
                    write_cb()
                end
            end)
        end
        
        -- 延迟读取
        local function do_read()
            pcall(function()
                if ensure_websocket_connected(websocket) and lvgl and lvgl.read then
                    print("[SitwchAction] 执行读取数据点: " .. bind_point)
                    lvgl.read(bind_point)
                end
            end)
        end
        
        -- 使用带执行标志的定时器
        if lvgl and lvgl.timer_create then
            print("[SitwchAction] 设置定时读取: " .. bind_point)
            
            -- 添加执行标志，确保只执行一次
            local read_executed = false
            
            lvgl.timer_create(function()
                -- 如果已经执行过，直接返回
                if read_executed then
                    -- print("[SitwchAction] 定时器已经执行过，忽略")
                    return
                end
                
                read_executed = true
                print("[SitwchAction] 延迟读取数据点: " .. bind_point)
                do_read()  -- 执行读取
            end, 500, nil)  -- 500ms后自动读取
        else
            -- 如果没有 timer_create，立即执行
            print("[SitwchAction] 立即读取数据点: " .. bind_point)
            do_read()
        end
        
        return true
    end
    
    return false
end

-- 创建动作回调
function SitwchAction.create_callback(action_type, params, is_design_mode_override)
    return function()
        print("[SitwchAction] 执行回调: " .. action_type)
        
        -- 如果传入了设计模式覆盖标志，使用它
        if is_design_mode_override == true then
            print("[SitwchAction] 设计模式(覆盖)，跳过实际执行")
            return true
        end
        
        local success, result = pcall(function()
            if action_type == "写入绑定数据点" then
                return write_bind_point(params)
            elseif action_type == "读取绑定数据点" then
                return read_bind_point(params)
            elseif action_type == "读写数据点" then
                return read_write_bind_point(params)
            else
                print("[SitwchAction] 未知的动作类型: " .. tostring(action_type))
                return false
            end
        end)
        
        if not success then
            print("[SitwchAction] 回调执行失败: " .. tostring(result))
            return false
        end
        
        return result
    end
end

-- 解绑开关的方法
function SitwchAction.unbind_switch(bind_point)
    if bind_point then
        pcall(function()
            bound_switches[bind_point] = nil
            pending_reads[bind_point] = nil
            read_write_switches[bind_point] = nil
            print("[SitwchAction] 已解除数据点绑定: " .. bind_point)
        end)
    end
end

-- 清理所有绑定和连接
function SitwchAction.clear_all()
    pcall(function()
        -- 先断开所有连接
        SitwchAction.disconnect_all()
        
        -- 再清除绑定
        bound_switches = {}
        pending_reads = {}
        read_write_switches = {}
        data_callback_set = false
        _G._sitwch_action_callback_set = nil
        print("[SitwchAction] 已清除所有绑定和连接")
    end)
end

-- 初始化函数（由编辑器调用）
function SitwchAction.init(is_design_mode)
    if is_design_mode ~= nil then
        _G.design_mode = is_design_mode
    end
    print("[SitwchAction] 初始化，设计模式: " .. tostring(_G.design_mode))
    
    -- 如果退出设计模式，清理连接
    if not _G.design_mode then
        SitwchAction.clear_all()
    end
end

-- 获取当前连接状态
function SitwchAction.get_connection_status()
    local status = {}
    for url, _ in pairs(connected_websockets) do
        status[url] = "connected"
    end
    return status
end

return SitwchAction