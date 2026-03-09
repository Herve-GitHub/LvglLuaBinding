-- editor/PropertyEvent.lua
-- 事件配置面板 - 超级简化版

local lv = require("lvgl")
local DataAction = require("editor.DataAction")

local PropertyEvent = {}

-- 事件类型选项（只用3个最常用的）
local EVENT_TYPES = {
    "写入绑定数据点",
    "读取绑定数据点", 
    "连接WebSocket"
}

function PropertyEvent.display(property_area)
    if not property_area or not property_area.content then
        return
    end
    
    -- 清空内容区域
    property_area:_clear_content_area()
    
    -- 获取选中的控件
    local selected_items = property_area:get_selected_items()
    local widget = (selected_items and #selected_items > 0) and selected_items[1] or nil
    
    if not widget then
        local tip = lv.label_create(property_area.content)
        tip:set_text("请先选择一个控件")
        tip:set_style_text_color(0xFFA500, 0)
        tip:align(lv.ALIGN_TOP_MID, 0, 50)
        return
    end
    
    local instance = widget.instance
    if not instance then
        return
    end
    
    local content = property_area.content
    local props = property_area.props
    local y = 10
    
    -- 标题
    local title = lv.label_create(content)
    title:set_text("事件配置")
    title:set_style_text_color(0xFF6600, 0)
    title:set_pos(10, y)
    y = y + 30
    
    -- 显示当前绑定点
    local bind_point = instance:get_property("bind_point") or "未配置"
    local point_label = lv.label_create(content)
    point_label:set_text("数据点: " .. bind_point)
    point_label:set_style_text_color(0x4A90E2, 0)
    point_label:set_pos(10, y)
    y = y + 30
    
    -- 获取当前事件类型
    local current_event = instance:get_property("event_action") or "写入绑定数据点"
    
    -- 创建三个按钮（简单可靠）
    for i, event_name in ipairs(EVENT_TYPES) do
        local btn = lv.btn_create(content)
        btn:set_pos(10, y)
        btn:set_size(props.width - 35, 40)
        
        -- 高亮当前选中的
        if event_name == current_event then
            btn:set_style_bg_color(0x4A90E2, 0)  -- 蓝色
        else
            btn:set_style_bg_color(0x3D3D3D, 0)  -- 灰色
        end
        btn:set_style_radius(3, 0)
        
        local btn_label = lv.label_create(btn)
        btn_label:set_text(event_name)
        btn_label:set_style_text_color(0xFFFFFF, 0)
        btn_label:center()
        
        -- 点击按钮直接保存
        btn:add_event_cb(function()
            -- 保存到控件属性
            instance:set_property("event_action", event_name)
            
            -- 如果是写入操作，还可以设置动作类型
            local action_type = "write_bind_point"
            if event_name == "读取绑定数据点" then
                action_type = "read_bind_point"
            elseif event_name == "连接WebSocket" then
                action_type = "websocket_connect"
            end
            
            -- 保存完整的事件配置
            local event_config = {
                event_type = event_name,
                action_type = action_type
            }
            instance:set_property("event_config", event_config)
            
            print("[事件] 已选择: " .. event_name)
            
            -- 刷新显示（更新高亮）
            PropertyEvent.display(property_area)
        end, lv.EVENT_CLICKED, nil)
        
        y = y + 45
    end
    
    -- 获取写入值（如果有）
    local write_value = instance:get_property("custom_value") or "1"
    
    -- 如果是写入操作，显示写入值
    if current_event == "写入绑定数据点" then
        y = y + 10
        
        local value_label = lv.label_create(content)
        value_label:set_text("写入值:")
        value_label:set_style_text_color(0xCCCCCC, 0)
        value_label:set_pos(10, y)
        y = y + 25
        
        local value_input = lv.textarea_create(content)
        value_input:set_pos(10, y)
        value_input:set_size(props.width - 35, 35)
        value_input:set_style_bg_color(0x2D2D2D, 0)
        value_input:set_style_text_color(0xFFFFFF, 0)
        value_input:set_style_border_width(1, 0)
        value_input:set_style_border_color(0x555555, 0)
        value_input:set_style_radius(3, 0)
        value_input:set_style_pad_all(8, 0)
        value_input:set_one_line(true)
        value_input:set_text(write_value)
        value_input:set_placeholder_text("输入要写入的值")
        
        -- 值改变时保存
        value_input:add_event_cb(function()
            local new_value = value_input:get_text()
            instance:set_property("custom_value", new_value)
            print("[事件] 写入值已更新: " .. new_value)
        end, lv.EVENT_VALUE_CHANGED, nil)
        
        y = y + 45
    end
    
    -- 状态提示
    y = y + 10
    local status = lv.label_create(content)
    status:set_text("当前: " .. current_event)
    status:set_style_text_color(0xAAAAAA, 0)
    status:set_pos(10, y)
end

return PropertyEvent