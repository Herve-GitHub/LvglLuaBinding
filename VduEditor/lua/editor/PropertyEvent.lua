-- editor/PropertyEvent.lua
-- 事件配置面板 - 修正版

local lv = require("lvgl")
local DataAction = require("editor.DataAction")

local PropertyEvent = {}

-- 事件类型选项
local EVENT_TYPES = {
    "写入绑定数据点",
    "读取绑定数据点", 
    "读写数据点"
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
    
    -- 创建事件类型按钮
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
        
        -- 点击按钮：立即保存选择的事件类型
        btn:add_event_cb(function()
            -- 直接保存到实例属性
            instance:set_property("event_action", event_name)
            
            -- 刷新界面（保留已输入的值）
            PropertyEvent.display(property_area)
        end, lv.EVENT_CLICKED, nil)
        
        y = y + 45
    end
    
    -- 获取写入值
    local write_value = instance:get_property("custom_value") or ""
    local value_input = nil
    
    -- 显示写入值输入框
    if current_event == "写入绑定数据点" or current_event == "读写数据点" then
        y = y + 10
        
        local value_label = lv.label_create(content)
        value_label:set_text("写入值:")
        value_label:set_style_text_color(0xCCCCCC, 0)
        value_label:set_pos(10, y)
        y = y + 25
        
        value_input = lv.textarea_create(content)
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
        
        -- 输入框内容改变时自动保存
        value_input:add_event_cb(function()
            local new_value = value_input:get_text()
            instance:set_property("custom_value", new_value)
        end, lv.EVENT_VALUE_CHANGED, nil)
        
        y = y + 45
    end
    
    -- 状态提示
    y = y + 10
    local status = lv.label_create(content)
    status:set_text("当前事件: " .. current_event)
    status:set_style_text_color(0xAAAAAA, 0)
    status:set_pos(10, y)
end

return PropertyEvent