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

-- ========== 文本选择辅助函数 ==========

-- 为 textarea 设置文本选择功能
local function setup_text_selection(textarea)
    -- 启用点击定位光标
    if textarea.set_cursor_click_pos then
        textarea:set_cursor_click_pos(true)
    end
    
    -- 启用文本选择（鼠标拖动选择）
    if textarea.set_text_selection then
        textarea:set_text_selection(true)
    end
    
    -- 设置选中文本的样式（背景色）
    --textarea:set_style_bg_color(0x264F78, lv.PART_SELECTED)  -- 选中背景色（深蓝色）
    textarea:set_style_text_color(0xFFFFFF, lv.PART_SELECTED) -- 选中文字颜色（白色）
    
    -- 注意：LVGL 的 textarea 已经内置支持文本选择功能
    -- 复制粘贴等快捷键需要在 C 层实现，Lua 绑定中没有 lv.event_get_key 函数
    -- 用户可以使用以下方法：
    -- - 鼠标拖动选择文本
    -- - 通过复制粘贴按钮进行操作
    -- - textarea:copy_selection(), textarea:paste() 等方法
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
    
    -- 启用文本选择功能
    setup_text_selection(textarea)
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        local ta = textarea
        local last_value = value  -- 记录上次的值，避免重复触发
        
        -- 提交属性变更的函数
        local function commit_change()
            local new_value = lv.textarea_get_text(ta)
            if new_value ~= last_value then
                last_value = new_value
                if widget_entry.instance and widget_entry.instance.set_property then
                    widget_entry.instance:set_property(prop_name, new_value)
                end
                ctx:_emit("property_changed", prop_name, new_value, widget_entry)
            end
        end
        
        -- 按回车键时触发设置
        textarea:add_event_cb(function(e)
            commit_change()
        end, lv.EVENT_READY, nil)
        
        -- 失去焦点时也触发设置
        textarea:add_event_cb(function(e)
            commit_change()
        end, lv.EVENT_DEFOCUSED, nil)
    end
    
    return textarea
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
    
    -- 启用文本选择功能
    setup_text_selection(textarea)
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        local ta = textarea
        local last_value = value  -- 记录上次的值，避免重复触发
        
        -- 提交属性变更的函数
        local function commit_change()
            local new_value = tonumber(lv.textarea_get_text(ta)) or 0
            if min_val and new_value < min_val then new_value = min_val end
            if max_val and new_value > max_val then new_value = max_val end
            if new_value ~= last_value then
                last_value = new_value
                if widget_entry.instance and widget_entry.instance.set_property then
                    widget_entry.instance:set_property(prop_name, new_value)
                end
                ctx:_emit("property_changed", prop_name, new_value, widget_entry)
            end
        end
        
        -- 按回车键时触发设置
        textarea:add_event_cb(function(e)
            commit_change()
        end, lv.EVENT_READY, nil)
        
        -- 失去焦点时也触发设置
        textarea:add_event_cb(function(e)
            commit_change()
        end, lv.EVENT_DEFOCUSED, nil)
    end
    
    return textarea
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
    
    return checkbox
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
    
    -- 启用文本选择功能
    setup_text_selection(textarea)
    
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
    
    return textarea, color_box
end

-- 创建枚举下拉框
function PropertyInputs.create_enum_dropdown(ctx, prop_name, value, options, is_read_only, widget_entry, y_pos)
    -- 解析选项：支持 {value, label} 格式或简单字符串数组
    local option_list = {}
    local value_to_label = {}
    local label_to_value = {}
    
    if options then
        for _, opt in ipairs(options) do
            if type(opt) == "table" then
                -- { value = "xxx", label = "显示文本" } 格式
                local opt_value = opt.value or opt[1]
                local opt_label = opt.label or opt[2] or opt_value
                table.insert(option_list, { value = opt_value, label = opt_label })
                value_to_label[opt_value] = opt_label
                label_to_value[opt_label] = opt_value
            else
                -- 简单字符串
                table.insert(option_list, { value = opt, label = opt })
                value_to_label[opt] = opt
                label_to_value[opt] = opt
            end
        end
    end
    
    -- 获取当前值的显示标签
    local current_label = value_to_label[value] or tostring(value)
    
    -- 创建下拉框容器
    local dropdown_container = lv.obj_create(ctx.content)
    dropdown_container:set_pos(95, y_pos + 2)
    dropdown_container:set_size(ctx.props.width - 105, 22)
    dropdown_container:set_style_bg_color(0x1E1E1E, 0)
    dropdown_container:set_style_border_width(1, 0)
    dropdown_container:set_style_border_color(0x555555, 0)
    dropdown_container:set_style_radius(3, 0)
    dropdown_container:set_style_pad_all(2, 0)
    dropdown_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 显示标签
    local display_label = lv.label_create(dropdown_container)
    display_label:set_text(current_label)
    display_label:set_style_text_color(0xFFFFFF, 0)
    display_label:align(lv.ALIGN_LEFT_MID, 4, 0)
    
    -- 下拉箭头
    local arrow_label = lv.label_create(dropdown_container)
    arrow_label:set_text("▼")
    arrow_label:set_style_text_color(0xAAAAAA, 0)
    arrow_label:align(lv.ALIGN_RIGHT_MID, -4, 0)
    
    if is_read_only then
        dropdown_container:set_style_bg_color(0x2D2D2D, 0)
        display_label:set_style_text_color(0x888888, 0)
        arrow_label:set_style_text_color(0x555555, 0)
        return dropdown_container
    end
    
    dropdown_container:add_flag(lv.OBJ_FLAG_CLICKABLE)
    
    -- 下拉列表状态
    local dropdown_list = nil
    local is_open = false
    
    -- 关闭下拉列表
    local function close_dropdown()
        if dropdown_list then
            pcall(function() dropdown_list:delete() end)
            dropdown_list = nil
            is_open = false
        end
    end
    
    -- 打开下拉列表
    local function open_dropdown()
        if is_open then
            close_dropdown()
            return
        end
        
        local list = lv.obj_create(ctx._parent)
        local list_height = math.min(#option_list * 24 + 6, 150)
        list:set_size(ctx.props.width - 105, list_height)
        
        -- 计算绝对位置
        local abs_x = ctx.props.x + 95
        local abs_y = ctx.props.y + ctx.props.title_height + y_pos + 26
        list:set_pos(abs_x, abs_y)
        
        list:set_style_bg_color(0x2D2D2D, 0)
        list:set_style_border_width(1, 0)
        list:set_style_border_color(0x555555, 0)
        list:set_style_radius(3, 0)
        list:set_style_pad_all(3, 0)
        list:add_flag(lv.OBJ_FLAG_SCROLLABLE)
        list:clear_layout()
        
        for i, opt in ipairs(option_list) do
            local item = lv.obj_create(list)
            item:set_pos(0, (i - 1) * 22)
            item:set_size(ctx.props.width - 115, 20)
            item:set_style_bg_color(opt.value == value and 0x007ACC or 0x3D3D3D, 0)
            item:set_style_radius(2, 0)
            item:set_style_border_width(0, 0)
            item:set_style_pad_all(0, 0)
            item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            item:add_flag(lv.OBJ_FLAG_CLICKABLE)
            
            local item_label = lv.label_create(item)
            item_label:set_text(opt.label)
            item_label:set_style_text_color(0xFFFFFF, 0)
            item_label:align(lv.ALIGN_LEFT_MID, 6, 0)
            
            local opt_value = opt.value
            local opt_label = opt.label
            item:add_event_cb(function(e)
                display_label:set_text(opt_label)
                value = opt_value
                close_dropdown()
                
                if widget_entry.instance and widget_entry.instance.set_property then
                    widget_entry.instance:set_property(prop_name, opt_value)
                end
                ctx:_emit("property_changed", prop_name, opt_value, widget_entry)
            end, lv.EVENT_CLICKED, nil)
        end
        
        dropdown_list = list
        is_open = true
    end
    
    dropdown_container:add_event_cb(function(e)
        open_dropdown()
    end, lv.EVENT_CLICKED, nil)
    
    return dropdown_container
end

-- 导出剪贴板函数供其他模块使用
PropertyInputs.clipboard_get_text = clipboard_get_text
PropertyInputs.clipboard_set_text = clipboard_set_text

-- 导出文本选择设置函数
PropertyInputs.setup_text_selection = setup_text_selection

return PropertyInputs
