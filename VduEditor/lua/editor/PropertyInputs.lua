-- PropertyInputs.lua
-- 属性面板输入控件创建模块
local lv = require("lvgl")
local ColorDialog = require("editor.ColorDialog")

local PropertyInputs = {}

-- ========== 剪贴板功能实现 ==========

-- 使用 Windows 命令行实现剪贴板操作
local function clipboard_get_text()
    -- 尝试使用 lv 模块的剪贴板函数（如果已编译）
    if lv.clipboard_get_text then
        return lv.clipboard_get_text()
    end
    
    -- 回退方案：使用 PowerShell 获取剪贴板内容
    local handle = io.popen('powershell -command "Get-Clipboard"', 'r')
    if handle then
        local result = handle:read('*a')
        handle:close()
        -- 去除末尾的换行符
        if result then
            result = result:gsub("[\r\n]+$", "")
        end
        return result
    end
    return nil
end

local function clipboard_set_text(text)
    -- 尝试使用 lv 模块的剪贴板函数（如果已编译）
    if lv.clipboard_set_text then
        return lv.clipboard_set_text(text)
    end
    
    -- 回退方案：使用 PowerShell 设置剪贴板内容
    if text and text ~= "" then
        -- 转义特殊字符
        local escaped = text:gsub('"', '`"'):gsub("'", "`'")
        local cmd = 'powershell -command "Set-Clipboard -Value \'' .. escaped .. '\'"'
        local result = os.execute(cmd)
        return result == 0 or result == true
    end
    return false
end

-- ========== 输入控件创建函数 ==========

-- 创建文本输入框
function PropertyInputs.create_text_input(ctx, prop_name, value, is_read_only, widget_entry, y_pos)
    local textarea = lv.textarea_create(ctx.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(ctx.props.width - 105, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)
    textarea:set_text(value)
    
    -- 设置基本属性
    textarea:add_flag(lv.OBJ_FLAG_CLICKABLE)
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        -- 按回车键时触发设置
        local ta = textarea
        textarea:add_event_cb(function(e)
            local new_value = lv.textarea_get_text(ta)
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, new_value)
            end
            ctx:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_READY, nil)
    end
end

-- 创建数字输入框
function PropertyInputs.create_number_input(ctx, prop_name, value, min_val, max_val, is_read_only, widget_entry, y_pos)
    local textarea = lv.textarea_create(ctx.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(ctx.props.width - 105, 22)
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
    
    -- 设置基本属性
    textarea:add_flag(lv.OBJ_FLAG_CLICKABLE)
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        -- 按回车键时触发设置
        local ta = textarea
        textarea:add_event_cb(function(e)
            local new_value = tonumber(lv.textarea_get_text(ta)) or 0
            if min_val and new_value < min_val then new_value = min_val end
            if max_val and new_value > max_val then new_value = max_val end
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, new_value)
            end
            ctx:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_READY, nil)
    end
end

-- 创建复选框
function PropertyInputs.create_checkbox_input(ctx, prop_name, value, is_read_only, widget_entry, y_pos)
    local is_checked = value and true or false
    
    local checkbox = lv.obj_create(ctx.content)
    checkbox:set_pos(95, y_pos + 2)
    checkbox:set_size(20, 20)
    checkbox:set_style_bg_color(is_checked and 0x007ACC or 0x1E1E1E, 0)
    checkbox:set_style_border_width(1, 0)
    checkbox:set_style_border_color(0x555555, 0)
    checkbox:set_style_radius(0, 0)
    checkbox:set_style_pad_all(0, 0)
    checkbox:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    if not is_read_only then
        checkbox:add_flag(lv.OBJ_FLAG_CLICKABLE)
        
        checkbox:add_event_cb(function(e)
            is_checked = not is_checked
            checkbox:set_style_bg_color(is_checked and 0x007ACC or 0x1E1E1E, 0)
            
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, is_checked)
            end
            ctx:_emit("property_changed", prop_name, is_checked, widget_entry)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建颜色选择框
function PropertyInputs.create_color_input(ctx, prop_name, value, is_read_only, widget_entry, y_pos)
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
    textarea:set_size(ctx.props.width - 130, 22)
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
    
    -- 设置基本属性
    textarea:add_flag(lv.OBJ_FLAG_CLICKABLE)
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
                
                if widget_entry.instance and widget_entry.instance.set_property then
                    widget_entry.instance:set_property(prop_name, new_color_num)
                end
                ctx:_emit("property_changed", prop_name, new_color_num, widget_entry)
            end)
        end, lv.EVENT_CLICKED, nil)
        
        -- 按回车键时触发设置
        textarea:add_event_cb(function(e)
            local new_value = lv.textarea_get_text(ta)
            if new_value then
                new_value = new_value:upper()
                if new_value:match("^#%x%x%x%x%x%x$") then
                    local new_color_num = tonumber(new_value:sub(2), 16)
                    cb:set_style_bg_color(new_color_num, 0)
                    color_num = new_color_num
                    color_hex = new_value
                    
                    if widget_entry.instance and widget_entry.instance.set_property then
                        widget_entry.instance:set_property(prop_name, new_color_num)
                    end
                    ctx:_emit("property_changed", prop_name, new_color_num, widget_entry)
                end
            end
        end, lv.EVENT_READY, nil)
        
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

-- 创建枚举下拉框
function PropertyInputs.create_enum_dropdown(ctx, prop_name, value, options, is_read_only, widget_entry, y_pos)
    local dropdown = lv.obj_create(ctx.content)
    dropdown:set_pos(95, y_pos + 2)
    dropdown:set_size(ctx.props.width - 105, 20)
    dropdown:set_style_bg_color(0x1E1E1E, 0)
    dropdown:set_style_border_width(1, 0)
    dropdown:set_style_border_color(0x555555, 0)
    dropdown:set_style_text_color(0xFFFFFF, 0)
    dropdown:set_style_radius(0, 0)
    dropdown:set_style_pad_all(3, 0)
    dropdown:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local label = lv.label_create(dropdown)
    label:set_text(tostring(value))
    label:set_style_text_color(0xFFFFFF, 0)
    
    if not is_read_only then
        dropdown:add_flag(lv.OBJ_FLAG_CLICKABLE)
    end
end

-- 导出剪贴板函数供其他模块使用
PropertyInputs.clipboard_get_text = clipboard_get_text
PropertyInputs.clipboard_set_text = clipboard_set_text

return PropertyInputs
