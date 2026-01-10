-- PropertyPageEditor.lua
-- 图页属性编辑模块
local lv = require("lvgl")
local ColorDialog = require("editor.ColorDialog")

local PropertyPageEditor = {}

-- 创建图页文本输入框
function PropertyPageEditor.create_text_input(ctx, prop_name, value, is_read_only, page_index, y_pos)
    local textarea = lv.textarea_create(ctx.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(ctx.props.width - 150, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)
    textarea:set_text(value)
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        local set_btn = lv.obj_create(ctx.content)
        set_btn:set_pos(ctx.props.width - 50, y_pos + 2)
        set_btn:set_size(36, 22)
        set_btn:set_style_bg_color(0x007ACC, 0)
        set_btn:set_style_radius(2, 0)
        set_btn:set_style_border_width(0, 0)
        set_btn:set_style_pad_all(0, 0)
        set_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        set_btn:add_flag(lv.OBJ_FLAG_CLICKABLE)
        
        local btn_label = lv.label_create(set_btn)
        btn_label:set_text("设置")
        btn_label:set_style_text_color(0xFFFFFF, 0)
        btn_label:center()
        
        local ta = textarea
        set_btn:add_event_cb(function(e)
            local new_value = lv.textarea_get_text(ta)
            ctx:_emit("page_property_changed", prop_name, new_value, page_index)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建图页数字输入框
function PropertyPageEditor.create_number_input(ctx, prop_name, value, min_val, max_val, is_read_only, page_index, y_pos)
    local textarea = lv.textarea_create(ctx.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(ctx.props.width - 150, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)
    textarea:set_text(tostring(math.floor(value)))
    textarea:set_accepted_chars("0123456789-")
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        local set_btn = lv.obj_create(ctx.content)
        set_btn:set_pos(ctx.props.width - 50, y_pos + 2)
        set_btn:set_size(36, 22)
        set_btn:set_style_bg_color(0x007ACC, 0)
        set_btn:set_style_radius(2, 0)
        set_btn:set_style_border_width(0, 0)
        set_btn:set_style_pad_all(0, 0)
        set_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        set_btn:add_flag(lv.OBJ_FLAG_CLICKABLE)
        
        local btn_label = lv.label_create(set_btn)
        btn_label:set_text("设置")
        btn_label:set_style_text_color(0xFFFFFF, 0)
        btn_label:center()
        
        local ta = textarea
        set_btn:add_event_cb(function(e)
            local new_value = tonumber(lv.textarea_get_text(ta)) or 0
            if min_val and new_value < min_val then new_value = min_val end
            if max_val and new_value > max_val then new_value = max_val end
            ctx:_emit("page_property_changed", prop_name, new_value, page_index)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建图页颜色选择框
function PropertyPageEditor.create_color_input(ctx, prop_name, value, is_read_only, page_index, y_pos)
    local color_hex = "#007ACC"
    local color_num = 0x007ACC
    if type(value) == "number" then
        color_num = value
        color_hex = string.format("#%06X", value)
    elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
        color_hex = value:upper()
        color_num = tonumber(value:sub(2), 16)
    end
    
    local color_box = lv.obj_create(ctx.content)
    color_box:set_pos(95, y_pos + 2)
    color_box:set_size(20, 20)
    color_box:set_style_bg_color(color_num, 0)
    color_box:set_style_border_width(1, 0)
    color_box:set_style_border_color(0x555555, 0)
    color_box:set_style_radius(0, 0)
    color_box:set_style_pad_all(0, 0)
    color_box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local textarea = lv.textarea_create(ctx.content)
    textarea:set_pos(120, y_pos + 2)
    textarea:set_size(ctx.props.width - 175, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)
    textarea:set_text(color_hex)
    textarea:set_accepted_chars("#0123456789ABCDEFabcdef")
    textarea:set_max_length(7)
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        -- 让 color_box 可点击，点击后弹出颜色选择对话框
        color_box:add_flag(lv.OBJ_FLAG_CLICKABLE)
        
        local cb = color_box
        local ta = textarea
        color_box:add_event_cb(function(e)
            -- 获取当前颜色值
            local current_color = color_num
            local current_text = lv.textarea_get_text(ta)
            if current_text and current_text:match("^#%x%x%x%x%x%x$") then
                current_color = tonumber(current_text:sub(2), 16)
            end
            
            -- 弹出颜色选择对话框
            ColorDialog.show(ctx._parent, current_color, function(new_color_num, new_color_hex)
                cb:set_style_bg_color(new_color_num, 0)
                ta:set_text(new_color_hex)
                color_num = new_color_num
                color_hex = new_color_hex
                
                ctx:_emit("page_property_changed", prop_name, new_color_num, page_index)
            end)
        end, lv.EVENT_CLICKED, nil)
        
        -- 创建设置按钮
        local set_btn = lv.obj_create(ctx.content)
        set_btn:set_pos(ctx.props.width - 50, y_pos + 2)
        set_btn:set_size(36, 22)
        set_btn:set_style_bg_color(0x007ACC, 0)
        set_btn:set_style_radius(2, 0)
        set_btn:set_style_border_width(0, 0)
        set_btn:set_style_pad_all(0, 0)
        set_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        set_btn:add_flag(lv.OBJ_FLAG_CLICKABLE)
        
        local btn_label = lv.label_create(set_btn)
        btn_label:set_text("设置")
        btn_label:set_style_text_color(0xFFFFFF, 0)
        btn_label:center()
        
        set_btn:add_event_cb(function(e)
            local new_value = lv.textarea_get_text(ta)
            if new_value then
                new_value = new_value:upper()
                if new_value:match("^#%x%x%x%x%x%x$") then
                    local new_color_num = tonumber(new_value:sub(2), 16)
                    cb:set_style_bg_color(new_color_num, 0)
                    color_num = new_color_num
                    color_hex = new_value
                    ctx:_emit("page_property_changed", prop_name, new_color_num, page_index)
                end
            end
        end, lv.EVENT_CLICKED, nil)
        
        -- 输入时实时更新颜色预览
        textarea:add_event_cb(function(e)
            local preview_value = lv.textarea_get_text(ta)
            if preview_value and preview_value:match("^#%x%x%x%x%x%x$") then
                local preview_color = tonumber(preview_value:sub(2), 16)
                cb:set_style_bg_color(preview_color, 0)
            end
        end, lv.EVENT_VALUE_CHANGED, nil)
    end
end

-- 显示图页属性
function PropertyPageEditor.display_properties(ctx, page_data, page_index, page_meta)
    ctx:_clear_content_area()
    
    if not page_meta then
        print("[属性窗口] 错误：page_meta 为空")
        return
    end
    
    local y_pos = 0
    local table_title_height = 20
    
    -- 基本信息
    local title = lv.label_create(ctx.content)
    title:set_text("图页信息")
    title:set_style_text_color(0x007ACC, 0)
    title:set_pos(5, y_pos)
    y_pos = y_pos + table_title_height
    
    local meta_fields = {
        { key = "id", label = "ID: " },
        { key = "name", label = "类型: " },
    }
    
    for _, field in ipairs(meta_fields) do
        local value = page_meta[field.key] or ""
        local label = lv.label_create(ctx.content)
        label:set_text(field.label .. tostring(value))
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(10, y_pos)
        y_pos = y_pos + 18
    end
    
    y_pos = y_pos + 10
    
    -- 属性编辑
    y_pos = PropertyPageEditor.create_properties_table(ctx, y_pos, page_data, page_index, page_meta)
end

-- 创建图页属性编辑表
function PropertyPageEditor.create_properties_table(ctx, y_pos, page_data, page_index, page_meta)
    if not page_meta.properties then
        print("[属性窗口] 图页没有 properties 定义")
        return y_pos
    end
    
    local table_title_height = 20
    local item_height = 24
    
    local title = lv.label_create(ctx.content)
    title:set_text("属性编辑")
    title:set_style_text_color(0x00CC00, 0)
    title:set_pos(0, y_pos)
    y_pos = y_pos + table_title_height + 5
    
    for _, prop_def in ipairs(page_meta.properties) do
        local prop_name = prop_def.name
        local prop_label = prop_def.label or prop_name
        local prop_type = prop_def.type
        local prop_value = page_data[prop_name]
        if prop_value == nil then
            prop_value = prop_def.default or ""
        end
        local is_read_only = prop_def.read_only or false
        
        local label = lv.label_create(ctx.content)
        label:set_text(prop_label .. ": ")
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(5, y_pos)
        label:set_width(80)
        
        if prop_type == "string" then
            PropertyPageEditor.create_text_input(ctx, prop_name, tostring(prop_value), is_read_only, page_index, y_pos)
        elseif prop_type == "number" then
            PropertyPageEditor.create_number_input(ctx, prop_name, tonumber(prop_value) or 0, prop_def.min, prop_def.max, is_read_only, page_index, y_pos)
        elseif prop_type == "color" then
            PropertyPageEditor.create_color_input(ctx, prop_name, prop_value, is_read_only, page_index, y_pos)
        else
            local value_label = lv.label_create(ctx.content)
            value_label:set_text(tostring(prop_value))
            value_label:set_style_text_color(0xFFFFFF, 0)
            value_label:set_pos(95, y_pos)
        end
        y_pos = y_pos + item_height
    end
    
    return y_pos + 10
end

return PropertyPageEditor
