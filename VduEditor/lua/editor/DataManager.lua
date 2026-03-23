-- DataManager.lua (最终修复版)
local DataManager = {
    button_callbacks = {},  -- key: bind_point, value: {buttons = {}}
    label_callbacks = {},   -- key: bind_point, value: {labels = {}}
    switch_callbacks = {},  -- 新增：管理开关回调
    write_timer_flags = {},
    initialized = false
}

-- 新增：注册开关
function DataManager.register_switch(bind_point, switch_obj)
    DataManager.init()
    
    if not bind_point or not switch_obj then
        return
    end
    
    if not DataManager.switch_callbacks[bind_point] then
        DataManager.switch_callbacks[bind_point] = {switches = {}}
    end
    
    local switch_list = DataManager.switch_callbacks[bind_point].switches
    
    -- 避免重复注册
    for _, existing_switch in ipairs(switch_list) do
        if existing_switch == switch_obj then
            print("[开关已注册] " .. bind_point)
            return
        end
    end
    
    table.insert(switch_list, switch_obj)
    print("[注册开关] " .. bind_point .. "，当前开关数: " .. #switch_list)
    
    -- 立即读取一次数据
    DataManager.read(bind_point)
end

-- 新增：解绑开关
function DataManager.unregister_switch(bind_point, switch_obj)
    if not bind_point or not switch_obj then
        return
    end
    
    local switch_info = DataManager.switch_callbacks[bind_point]
    if switch_info and switch_info.switches then
        for i, existing_switch in ipairs(switch_info.switches) do
            if existing_switch == switch_obj then
                table.remove(switch_info.switches, i)
                print("[解绑开关] " .. bind_point)
                break
            end
        end
        
        if #switch_info.switches == 0 then
            DataManager.switch_callbacks[bind_point] = nil
        end
    end
end

function DataManager.init()
    if DataManager.initialized then return end
    
    -- 启动网络服务
    lvgl.start_network_service(100)
    
    -- 统一的全局回调（唯一入口）
    -- DataManager.lua 中修改中央回调部分
lvgl.set_callbacks(
    function(connected)
        print("[WebSocket] 连接状态: " .. tostring(connected))
        
        -- 通知所有模块连接状态变化
        if _G.on_ws_connection_changed then
            pcall(_G.on_ws_connection_changed, connected)
        end
    end,
    function(device_id, value, status)
        -- 核心过滤：忽略空数据、PONG帧、控制帧
        if not device_id or device_id == "" or value == nil or value == "" then
            -- 可选：只打印一次心跳提示，避免刷屏
            -- static local pong_count = 0
            -- pong_count = pong_count + 1
            -- if pong_count % 100 == 0 then
            --     print("[WebSocket] 心跳保活中 (已收到" .. pong_count .. "次PONG)")
            -- end
            return
        end
        
        print("[中央回调] 设备: " .. device_id .. " = " .. value)
        
        -- 以下保持原有逻辑（更新按钮、标签、开关）
        -- 1. 更新按钮
        local button_info = DataManager.button_callbacks[device_id]
        if button_info and button_info.buttons then
            for i, button in ipairs(button_info.buttons) do
                if button then
                    local success = pcall(function()
                        if button.set_label then
                            button:set_label(value)
                            print("[更新按钮" .. i .. "] " .. device_id .. " = " .. value)
                        elseif button.set_text then
                            button:set_text(value)
                            print("[更新按钮文本" .. i .. "] " .. device_id .. " = " .. value)
                        end
                    end)
                    
                    if not success then
                        print("[移除无效按钮] " .. device_id)
                        button_info.buttons[i] = nil
                    end
                end
            end
        end
        
        -- 2. 更新标签
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
        
        -- 3. 更新开关
        local switch_info = DataManager.switch_callbacks[device_id]
        if switch_info and switch_info.switches then
            for i, switch_obj in ipairs(switch_info.switches) do
                if switch_obj then
                    local success = pcall(function()
                        -- 将数值转换为开关状态
                        local bool_value = false
                        if value then
                            local num_value = tonumber(value)
                            if num_value ~= nil then
                                bool_value = num_value ~= 0
                            else
                                bool_value = value == "1" or value == "true" or value == "on"
                            end
                        end
                        
                        if switch_obj.set_property then
                            switch_obj:set_property("switch_state", bool_value)
                            print("[更新开关" .. i .. "] " .. device_id .. " = " .. tostring(bool_value))
                        end
                    end)
                    
                    if not success then
                        print("[移除无效开关] " .. device_id)
                        switch_info.switches[i] = nil
                    end
                end
            end
        end
    end
)
    
    DataManager.initialized = true
    print("[中央管理器] 初始化完成")
end

-- 原有功能保持不变
function DataManager.register_button(bind_point, button)
    DataManager.init()
    
    if not bind_point or not button then
        return
    end
    
    if not DataManager.button_callbacks[bind_point] then
        DataManager.button_callbacks[bind_point] = {buttons = {}}
    end
    
    local button_list = DataManager.button_callbacks[bind_point].buttons
    
    for _, existing_button in ipairs(button_list) do
        if existing_button == button then
            print("[按钮已注册] " .. bind_point)
            return
        end
    end
    
    table.insert(button_list, button)
    print("[注册按钮] " .. bind_point .. "，当前按钮数: " .. #button_list)
    
    DataManager.read(bind_point)
end

function DataManager.register_label(bind_point, label)
    DataManager.init()
    
    if not bind_point or not label then
        return
    end
    
    if not DataManager.label_callbacks[bind_point] then
        DataManager.label_callbacks[bind_point] = {labels = {}}
    end
    
    local label_list = DataManager.label_callbacks[bind_point].labels
    
    for _, existing_label in ipairs(label_list) do
        if existing_label == label then
            print("[标签已注册] " .. bind_point)
            return
        end
    end
    
    table.insert(label_list, label)
    print("[注册标签] " .. bind_point .. "，当前标签数: " .. #label_list)
    
    DataManager.read(bind_point)
end

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
        
        if #button_info.buttons == 0 then
            DataManager.button_callbacks[bind_point] = nil
        end
    end
end

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

function DataManager.unregister(bind_point)
    DataManager.button_callbacks[bind_point] = nil
    DataManager.label_callbacks[bind_point] = nil
    DataManager.switch_callbacks[bind_point] = nil  -- 新增
    print("[解绑所有] " .. bind_point)
end

function DataManager.read(bind_point)
    if bind_point and bind_point ~= "" then
        pcall(function()
            lvgl.read(bind_point)
        end)
    end
end

function DataManager.write(bind_point, value)
    if bind_point and bind_point ~= "" then
        print("[写入] " .. bind_point .. " = " .. value)
        local write_success = pcall(function()
            lvgl.write(bind_point, value)
        end)
        
        if write_success then
            if not DataManager.write_timer_flags then
                DataManager.write_timer_flags = {}
            end
            local flag = DataManager.write_timer_flags[bind_point] or {executed = false, timer = nil}
            
            if flag.timer then
                lvgl.timer_del(flag.timer)
                flag.timer = nil
            end
            
            flag.executed = false
            
            flag.timer = lvgl.timer_create(function()
                if flag.executed then
                    return
                end
                
                flag.executed = true
                print("[DataManager] 写入后兜底读取: " .. bind_point .. " = " .. value)
                DataManager.read(bind_point)
                flag.timer = nil
            end, 1000, nil)
            
            DataManager.write_timer_flags[bind_point] = flag
        end
    end
end

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
    for bp, info in pairs(DataManager.switch_callbacks) do  -- 新增
        stats[bp] = stats[bp] or {}
        stats[bp].switches = info.switches and #info.switches or 0
    end
    return stats
end





return DataManager