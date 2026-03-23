-- actions/SitwchAction.lua (移除网络连接版)
local lvgl = require("lvgl")  -- 确保全局/局部对象一致
local SitwchAction = {}
local DataManager = require("editor.DataManager")  -- 引入中央管理器

-- 移除：全局连接状态（不再管理连接）
-- 移除：connected_websockets = {}
-- 移除：active_connections = {}

-- 新增：判断是否在设计模式
local function is_design_mode()
    return _G.design_mode == true
end

-- 移除：ensure_websocket_connected 函数（不再检查/创建连接）

-- 移除：disconnect 函数（不再管理连接）
-- 移除：disconnect_all 函数（不再管理连接）

-- 执行写入操作（移除连接检查）
local function write_bind_point(params)
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过写入操作")
        return true
    end
    
    local bind_point = params.bind_point
    local value = params.value or "1"
    
    if not bind_point or bind_point == "" then
        print("[SitwchAction] 写入操作失败：未配置数据点")
        return false
    end
    
    -- 移除：WebSocket 连接检查
    -- 直接使用 DataManager 写入（依赖外部已建立的连接）
    DataManager.write(bind_point, value)
    
    return true
end

-- 执行读取操作（用于开关，移除连接检查）
local function read_bind_point(params)
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过读取操作")
        if params and params.switch and params.bind_point then
            print("[SitwchAction] 设计模式记录绑定: " .. params.bind_point)
        end
        return true
    end
    
    if not params then
        print("[SitwchAction] 读取操作失败：参数为空")
        return false
    end
    
    local bind_point = params.bind_point
    local switch = params.switch  -- 移除：websocket 参数
    
    if not bind_point or bind_point == "" then
        print("[SitwchAction] 读取操作失败：未配置数据点")
        return false
    end
    
    -- 移除：WebSocket 连接检查
    
    -- 注册开关到DataManager（核心保留）
    if switch and bind_point then
        DataManager.register_switch(bind_point, switch)
    end
    
    -- 使用DataManager读取（依赖外部已建立的连接）
    local success, err = pcall(function()
        print("[SitwchAction] 发起读取请求: " .. bind_point)
        DataManager.read(bind_point)
    end)
    
    if not success then
        print("[SitwchAction] 读取失败: " .. tostring(err))
        return false
    end
    
    return true
end

-- 执行读写数据点操作（移除连接检查）
local function read_write_bind_point(params)
    if is_design_mode() then
        print("[SitwchAction] 设计模式，跳过读写操作")
        if params and params.switch and params.bind_point then
            print("[SitwchAction] 设计模式记录读写绑定: " .. params.bind_point)
        end
        return true
    end
    
    if not params then
        print("[SitwchAction] 读写操作失败：参数为空")
        return false
    end
    
    local bind_point = params.bind_point
    local switch = params.switch  -- 移除：websocket 参数
    local write_value = params.write_value or {}
    
    if not bind_point or bind_point == "" then
        print("[SitwchAction] 读写操作失败：未配置数据点")
        return false
    end
    
    if not switch then
        print("[SitwchAction] 读写操作失败：未提供开关实例")
        return false
    end
    
    -- 移除：WebSocket 连接检查
    
    -- 注册开关到DataManager（核心保留）
    DataManager.register_switch(bind_point, switch)
    
    -- 注册写入回调到开关对象（核心保留）
    switch._write_callback = function(new_state)
        pcall(function()
            local value = new_state and write_value.on or write_value.off
            print("[SitwchAction] 读写模式状态改变，写入: " .. bind_point .. " = " .. value)
            
            local write_cb = SitwchAction.create_callback("写入绑定数据点", {
                bind_point = bind_point,
                value = value
                -- 移除：websocket_url 参数
            })
            if write_cb then
                write_cb()
            end
        end)
    end
    
    -- 延迟读取（核心保留）
    local function do_read()
        pcall(function()
            print("[SitwchAction] 执行读取数据点: " .. bind_point)
            DataManager.read(bind_point)
        end)
    end
    
    if lvgl and lvgl.timer_create then
        print("[SitwchAction] 设置定时读取: " .. bind_point)
        
        local read_executed = false
        
        lvgl.timer_create(function()
            if read_executed then
                return
            end
            
            read_executed = true
            print("[SitwchAction] 延迟读取数据点: " .. bind_point)
            do_read()
        end, 500, nil)
    else
        print("[SitwchAction] 立即读取数据点: " .. bind_point)
        do_read()
    end
    
    return true
end

-- 创建动作回调（移除 websocket 参数依赖）
function SitwchAction.create_callback(action_type, params, is_design_mode_override)
    return function()
        print("[SitwchAction] 执行回调: " .. action_type)
        
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

-- 解绑开关的方法（核心保留）
function SitwchAction.unbind_switch(bind_point, switch_obj)
    if bind_point and switch_obj then
        pcall(function()
            DataManager.unregister_switch(bind_point, switch_obj)
            print("[SitwchAction] 已解除数据点绑定: " .. bind_point)
        end)
    end
end

-- 清理所有绑定（移除连接清理）
function SitwchAction.clear_all()
    pcall(function()
        print("[SitwchAction] 已清除所有绑定（网络连接由外部管理）")
    end)
end

-- 初始化函数（简化，不再处理连接）
function SitwchAction.init(is_design_mode)
    if is_design_mode ~= nil then
        _G.design_mode = is_design_mode
    end
    print("[SitwchAction] 初始化，设计模式: " .. tostring(_G.design_mode))
    
    if not _G.design_mode then
        SitwchAction.clear_all()
    end
end

-- 移除：get_connection_status 函数（不再管理连接）

return SitwchAction