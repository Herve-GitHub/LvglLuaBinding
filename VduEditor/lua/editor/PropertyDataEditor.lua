-- editor/PropertyDataEditor.lua
-- 数据配置面板 - 简化版

local lv = require("lvgl")
local DataAction = require("editor.DataAction")

local PropertyDataEditor = {}

-- 显示数据配置页面
function PropertyDataEditor.display(property_area)
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
    if not instance or not instance.get_property then
        return
    end
    
    local content = property_area.content
    local props = property_area.props
    local y = 10
    
    -- 标题
    local title = lv.label_create(content)
    title:set_text("WebSocket 数据配置")
    title:set_style_text_color(0x4A90E2, 0)
    title:set_pos(10, y)
    y = y + 30
    
    -- 获取当前配置
    local bind_point = instance:get_property("bind_point") or ""
    local websocket_url = instance:get_property("websocket_url") or ""
    local custom_value = instance:get_property("custom_value") or ""
    
    -- ===== WebSocket URL =====
    local url_label = lv.label_create(content)
    url_label:set_text("WebSocket URL:")
    url_label:set_style_text_color(0xCCCCCC, 0)
    url_label:set_pos(10, y)
    y = y + 25
    
    local url_input = lv.textarea_create(content)
    url_input:set_pos(10, y)
    url_input:set_size(props.width - 35, 35)
    url_input:set_style_bg_color(0x2D2D2D, 0)
    url_input:set_style_text_color(0xFFFFFF, 0)
    url_input:set_style_border_width(1, 0)
    url_input:set_style_border_color(0x555555, 0)
    url_input:set_style_radius(3, 0)
    url_input:set_style_pad_all(8, 0)
    url_input:set_one_line(true)
    url_input:set_text(websocket_url)
    url_input:set_placeholder_text("ws://192.168.1.100:8080/ws")
    y = y + 45
    
    -- ===== 数据点名称 =====
    local point_label = lv.label_create(content)
    point_label:set_text("数据点名称:")
    point_label:set_style_text_color(0xCCCCCC, 0)
    point_label:set_pos(10, y)
    y = y + 25
    
    local point_input = lv.textarea_create(content)
    point_input:set_pos(10, y)
    point_input:set_size(props.width - 35, 35)
    point_input:set_style_bg_color(0x2D2D2D, 0)
    point_input:set_style_text_color(0xFFFFFF, 0)
    point_input:set_style_border_width(1, 0)
    point_input:set_style_border_color(0x555555, 0)
    point_input:set_style_radius(3, 0)
    point_input:set_style_pad_all(8, 0)
    point_input:set_one_line(true)
    point_input:set_text(bind_point)
    point_input:set_placeholder_text("Device1.tag0001")
    y = y + 45
    
    -- ===== 写入值 =====
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
    value_input:set_text(custom_value)
    value_input:set_placeholder_text("42")
    y = y + 50
    
    -- ===== 保存按钮 =====
    local save_btn = lv.btn_create(content)
    save_btn:set_size(120, 35)
    save_btn:set_pos((props.width - 120) / 2, y)
    save_btn:set_style_bg_color(0x4A90E2, 0)
    save_btn:set_style_radius(5, 0)
    
    local save_label = lv.label_create(save_btn)
    save_label:set_text("保存配置")
    save_label:center()
    
    save_btn:add_event_cb(function()
        -- 获取输入值
        local new_url = url_input:get_text()
        local new_point = point_input:get_text()
        local new_value = value_input:get_text()
        
        -- 保存到控件
        if instance.set_property then
            instance:set_property("websocket_url", new_url)
            instance:set_property("bind_point", new_point)
            instance:set_property("custom_value", new_value)
            
            -- 显示成功提示
            local tip = lv.label_create(content)
            tip:set_text("保存成功")
            tip:set_style_text_color(0x00FF00, 0)
            tip:set_pos((props.width - 80) / 2, y + 45)
            
            lv.timer_create(function()
                pcall(function() tip:delete() end)
            end, 1500, nil)
            
            print("[数据] 已保存: " .. new_point .. " = " .. new_value .. " @ " .. new_url)
        end
    end, lv.EVENT_CLICKED, nil)
end

return PropertyDataEditor