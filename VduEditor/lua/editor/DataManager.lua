-- DataManager.lua
local DataManager = {
    button_callbacks = {},  -- key: bind_point, value: {buttons = {}} 改为表结构
    label_callbacks = {},   -- key: bind_point, value: {labels = {}}
    initialized = false
}

function DataManager.init()
    if DataManager.initialized then return end
    
    -- 启动网络服务
    lvgl.start_network_service(100)
    
    lvgl.set_callbacks(
        function(connected)
            print("[WebSocket] 连接状态: " .. tostring(connected))
        end,
        function(device_id, value, status)
            print("[中央回调] 设备: " .. device_id .. " = " .. value)
            
            -- 更新所有按钮
            local button_info = DataManager.button_callbacks[device_id]
            if button_info and button_info.buttons then
                for i, button in ipairs(button_info.buttons) do
                    if button then
                        -- 检查按钮是否有效
                        local success = pcall(function()
                            if button.set_label then
                                button:set_label(value)
                                print("[更新按钮" .. i .. "] " .. device_id .. " = " .. value)
                            elseif button.set_text then
                                button:set_text(value)
                                print("[更新按钮文本" .. i .. "] " .. device_id .. " = " .. value)
                            end
                        end)
                        
                        -- 如果按钮无效（已被销毁），从列表中移除
                        if not success then
                            print("[移除无效按钮] " .. device_id)
                            button_info.buttons[i] = nil
                        end
                    end
                end
            end
            
            -- 更新所有标签
            local label_info = DataManager.label_callbacks[device_id]
            if label_info and label_info.labels then
                for i, label in ipairs(label_info.labels) do
                    if label and label.set_text then
                        local success = pcall(function()
                            label:set_text(value)
                            print("[更新标签" .. i .. "] " .. device_id .. " = " .. value)
                        end)
                        
                        if not success then
                            print("[移除无效标签] " .. device_id)
                            label_info.labels[i] = nil
                        end
                    end
                end
            end
        end
    )
    
    DataManager.initialized = true
    print("[中央管理器] 初始化完成")
end

-- 注册按钮（支持多个按钮绑定同一数据点）
function DataManager.register_button(bind_point, button)
    DataManager.init()
    
    if not bind_point or not button then
        return
    end
    
    -- 如果该数据点还没有按钮表，创建新表
    if not DataManager.button_callbacks[bind_point] then
        DataManager.button_callbacks[bind_point] = {buttons = {}}
    end
    
    local button_list = DataManager.button_callbacks[bind_point].buttons
    
    -- 检查是否已经注册过，避免重复
    for _, existing_button in ipairs(button_list) do
        if existing_button == button then
            print("[按钮已注册] " .. bind_point)
            return
        end
    end
    
    -- 添加到列表
    table.insert(button_list, button)
    print("[注册按钮] " .. bind_point .. "，当前按钮数: " .. #button_list)
    
    -- 立即读取一次数据，获取最新值
    DataManager.read(bind_point)
end

-- 注册标签（支持多个标签绑定同一数据点）
function DataManager.register_label(bind_point, label)
    DataManager.init()
    
    if not bind_point or not label then
        return
    end
    
    -- 如果该数据点还没有标签表，创建新表
    if not DataManager.label_callbacks[bind_point] then
        DataManager.label_callbacks[bind_point] = {labels = {}}
    end
    
    local label_list = DataManager.label_callbacks[bind_point].labels
    
    -- 检查是否已经注册过
    for _, existing_label in ipairs(label_list) do
        if existing_label == label then
            print("[标签已注册] " .. bind_point)
            return
        end
    end
    
    -- 添加到列表
    table.insert(label_list, label)
    print("[注册标签] " .. bind_point .. "，当前标签数: " .. #label_list)
    
    -- 立即读取一次数据
    DataManager.read(bind_point)
end

-- 解绑特定按钮
function DataManager.unregister_button(bind_point, button)
    if not bind_point or not button then
        return
    end
    
    local button_info = DataManager.button_callbacks[bind_point]
    if button_info and button_info.buttons then
        for i, existing_button in ipairs(button_info.buttons) do
            if existing_button == button then
                table.remove(button_info.buttons, i)
                print("[解绑按钮] " .. bind_point)
                break
            end
        end
        
        -- 如果列表为空，删除整个条目
        if #button_info.buttons == 0 then
            DataManager.button_callbacks[bind_point] = nil
        end
    end
end

-- 解绑特定标签
function DataManager.unregister_label(bind_point, label)
    if not bind_point or not label then
        return
    end
    
    local label_info = DataManager.label_callbacks[bind_point]
    if label_info and label_info.labels then
        for i, existing_label in ipairs(label_info.labels) do
            if existing_label == label then
                table.remove(label_info.labels, i)
                print("[解绑标签] " .. bind_point)
                break
            end
        end
        
        if #label_info.labels == 0 then
            DataManager.label_callbacks[bind_point] = nil
        end
    end
end

-- 兼容旧的解绑函数
function DataManager.unregister(bind_point)
    DataManager.button_callbacks[bind_point] = nil
    DataManager.label_callbacks[bind_point] = nil
    print("[解绑所有] " .. bind_point)
end

-- 读取数据
function DataManager.read(bind_point)
    if bind_point and bind_point ~= "" then
        pcall(function()
            lvgl.read(bind_point)
        end)
    end
end

-- 写入数据
function DataManager.write(bind_point, value)
    if bind_point and bind_point ~= "" then
        print("[写入] " .. bind_point .. " = " .. value)
        pcall(function()
            lvgl.write(bind_point, value)
        end)
    end
end

-- 获取绑定统计信息（调试用）
function DataManager.get_stats()
    local stats = {}
    for bp, info in pairs(DataManager.button_callbacks) do
        stats[bp] = stats[bp] or {}
        stats[bp].buttons = info.buttons and #info.buttons or 0
    end
    for bp, info in pairs(DataManager.label_callbacks) do
        stats[bp] = stats[bp] or {}
        stats[bp].labels = info.labels and #info.labels or 0
    end
    return stats
end

return DataManager