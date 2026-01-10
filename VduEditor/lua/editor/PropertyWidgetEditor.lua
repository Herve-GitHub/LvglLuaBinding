-- PropertyWidgetEditor.lua
-- 控件属性编辑模块
local lv = require("lvgl")
local PropertyInputs = require("editor.PropertyInputs")

local PropertyWidgetEditor = {}

-- 创建元数据表（不可修改）
function PropertyWidgetEditor.create_metadata_table(ctx, meta)
    local y_pos = 0
    local table_title_height = 20
    
    local title = lv.label_create(ctx.content)
    title:set_text("基本信息")
    title:set_style_text_color(0x007ACC, 0)
    title:set_pos(5, y_pos)
    y_pos = y_pos + table_title_height
    
    local meta_fields = {
        { key = "id", label = "ID: " },
        { key = "name", label = "名称: " },
        { key = "description", label = "描述: " },
        { key = "schema_version", label = "Schema: " },
        { key = "version", label = "版本: " },
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
        if prop_name == "design_mode" then
            goto continue
        end
        
        if prop_def.type == "action" or prop_def.type == "action_params" then
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
        
        if prop_type == "string" then
            PropertyInputs.create_text_input(ctx, prop_name, tostring(prop_value), is_read_only, widget_entry, y_pos)
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
        y_pos = y_pos + item_height
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
    
    local y_pos = PropertyWidgetEditor.create_metadata_table(ctx, meta)
    y_pos = PropertyWidgetEditor.create_properties_table(ctx, y_pos, widget_entry, meta)
    
    -- 事件编辑器需要单独引入以避免循环依赖
    local PropertyEventEditor = require("editor.PropertyEventEditor")
    PropertyEventEditor.create_events_table(ctx, y_pos, widget_entry, meta)
end

return PropertyWidgetEditor
