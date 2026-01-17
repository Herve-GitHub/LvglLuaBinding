-- PropertyWidgetEditor.lua
-- 控件属性编辑模块
local lv = require("lvgl")
local PropertyInputs = require("editor.PropertyInputs")

local PropertyWidgetEditor = {}

-- 创建元数据表（控件类型信息，只读）
function PropertyWidgetEditor.create_metadata_table(ctx, meta)
    local y_pos = 0
    local table_title_height = 20
    
    local title = lv.label_create(ctx.content)
    title:set_text("控件类型")
    title:set_style_text_color(0x007ACC, 0)
    title:set_pos(5, y_pos)
    y_pos = y_pos + table_title_height
    
    -- 只显示控件类型的基本信息（只读）
    local meta_fields = {
        { key = "id", label = "类型ID: " },
        { key = "name", label = "类型名称: " },
    }
    
    for _, field in ipairs(meta_fields) do
        local value = meta[field.key] or ""
        local label = lv.label_create(ctx.content)
        label:set_text(field.label .. tostring(value))
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(10, y_pos)
        y_pos = y_pos + 18
    end
    
    y_pos = y_pos + 10
    return y_pos
end

-- 创建实例名称编辑区域
function PropertyWidgetEditor.create_instance_name_editor(ctx, y_pos, widget_entry)
    local instance = widget_entry.instance
    local item_height = 24
    
    local title = lv.label_create(ctx.content)
    title:set_text("实例标识")
    title:set_style_text_color(0xFF6600, 0)
    title:set_pos(0, y_pos)
    y_pos = y_pos + 20 + 5
    
    -- 实例名称输入
    local label = lv.label_create(ctx.content)
    label:set_text("实例名称:")
    label:set_style_text_color(0xCCCCCC, 0)
    label:set_pos(5, y_pos)
    label:set_width(80)
    
    local current_name = ""
    if instance and instance.get_property then
        current_name = instance:get_property("instance_name") or ""
    end
    
    PropertyInputs.create_text_input(ctx, "instance_name", current_name, false, widget_entry, y_pos)
    y_pos = y_pos + item_height
    
    -- 提示文字
    local hint = lv.label_create(ctx.content)
    hint:set_text("(用于编译时的变量名)")
    hint:set_style_text_color(0x888888, 0)
    hint:set_pos(95, y_pos)
    y_pos = y_pos + 18
    
    return y_pos + 10
end

-- 创建属性编辑表（可修改）
function PropertyWidgetEditor.create_properties_table(ctx, y_pos, widget_entry, meta)
    local instance = widget_entry.instance
    
    if not meta.properties then
        print("[属性窗口] 模块没有 properties 定义")
        return y_pos
    end
    
    local current_props = {}
    if instance.get_properties then
        current_props = instance:get_properties()
    end
    
    local table_title_height = 20
    local item_height = 24
    
    local title = lv.label_create(ctx.content)
    title:set_text("属性编辑")
    title:set_style_text_color(0x00CC00, 0)
    title:set_pos(0, y_pos)
    y_pos = y_pos + table_title_height + 5
    
    for _, prop_def in ipairs(meta.properties) do
        local prop_name = prop_def.name
        
        -- 跳过设计模式和实例名称（已在上方单独显示）
        if prop_name == "design_mode" or prop_name == "instance_name" then
            goto continue
        end
        
        -- 跳过事件相关属性（在事件编辑器中显示）
        if prop_def.type == "action" or prop_def.type == "action_params" or prop_def.type == "code" then
            goto continue
        end
        
        local prop_label = prop_def.label or prop_name
        local prop_type = prop_def.type
        local prop_value = current_props[prop_name] or prop_def.default or ""
        local is_read_only = prop_def.read_only or false
        
        local label = lv.label_create(ctx.content)
        label:set_text(prop_label .. ": ")
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(5, y_pos)
        label:set_width(80)
        
        -- 计算此属性占用的高度
        local current_item_height = item_height
        
        if prop_type == "string" then
            -- 检查是否是多行文本
            if prop_def.multiline then
                local lines = prop_def.lines or 3
                local _, actual_height = PropertyInputs.create_multiline_text_input(ctx, prop_name, tostring(prop_value), is_read_only, widget_entry, y_pos, lines)
                current_item_height = actual_height + 4
            else
                PropertyInputs.create_text_input(ctx, prop_name, tostring(prop_value), is_read_only, widget_entry, y_pos)
            end
        elseif prop_type == "number" then
            PropertyInputs.create_number_input(ctx, prop_name, tonumber(prop_value) or 0, prop_def.min, prop_def.max, is_read_only, widget_entry, y_pos)
        elseif prop_type == "boolean" then
            PropertyInputs.create_checkbox_input(ctx, prop_name, prop_value, is_read_only, widget_entry, y_pos)
        elseif prop_type == "color" then
            PropertyInputs.create_color_input(ctx, prop_name, prop_value, is_read_only, widget_entry, y_pos)
        elseif prop_type == "enum" then
            PropertyInputs.create_enum_dropdown(ctx, prop_name, prop_value, prop_def.options, is_read_only, widget_entry, y_pos)
        else
            local value_label = lv.label_create(ctx.content)
            value_label:set_text(tostring(prop_value))
            value_label:set_style_text_color(0xFFFFFF, 0)
            value_label:set_pos(95, y_pos)
        end
        y_pos = y_pos + current_item_height
        ::continue::
    end
    
    return y_pos + 10
end

-- 显示控件属性
function PropertyWidgetEditor.display_properties(ctx, widget_entry)
    ctx:_clear_content_area()
    
    local instance = widget_entry.instance
    local module = widget_entry.module
    
    if not instance or not module then
        print("[属性窗口] 错误：instance 或 module 为空")
        return
    end
    
    local meta = module.__widget_meta
    if not meta then
        print("[属性窗口] 错误：模块没有 __widget_meta")
        return
    end
    
    -- 1. 显示控件类型信息（只读）
    local y_pos = PropertyWidgetEditor.create_metadata_table(ctx, meta)
    
    -- 2. 显示实例名称编辑器
    y_pos = PropertyWidgetEditor.create_instance_name_editor(ctx, y_pos, widget_entry)
    
    -- 3. 显示属性编辑
    y_pos = PropertyWidgetEditor.create_properties_table(ctx, y_pos, widget_entry, meta)
    
    -- 4. 显示事件编辑器
    local PropertyEventEditor = require("editor.PropertyEventEditor")
    PropertyEventEditor.create_events_table(ctx, y_pos, widget_entry, meta)
end

return PropertyWidgetEditor
