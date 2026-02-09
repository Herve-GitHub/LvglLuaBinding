-- PropertyEventEditor.lua
-- 事件绑定编辑模块 - 新版：事件下拉选择 + 多行代码编辑 + 保存按钮
local lv = require("lvgl")
local PropertyInputs = require("editor.PropertyInputs")

local PropertyEventEditor = {}

-- 当前编辑状态
local _current_state = {
    widget_entry = nil,
    selected_event = nil,
    events_list = {},
    event_handlers = {},  -- 存储各事件的处理代码
    textarea = nil,
    dropdown_list = nil,
    is_dropdown_open = false,
}

-- 获取控件支持的事件列表
local function get_widget_events(meta)
    local events = {}
    
    -- 从 events 列表获取
    if meta.events then
        for _, event_name in ipairs(meta.events) do
            table.insert(events, {
                name = event_name,
                label = event_name,
            })
        end
    end
    
    -- 如果没有 events，从 properties 中查找 action 类型
    if #events == 0 and meta.properties then
        local event_set = {}
        for _, prop_def in ipairs(meta.properties) do
            if prop_def.type == "action" and prop_def.event then
                if not event_set[prop_def.event] then
                    event_set[prop_def.event] = true
                    table.insert(events, {
                        name = prop_def.event,
                        label = prop_def.event,
                    })
                end
            end
        end
    end
    
    return events
end

-- 获取事件处理代码的属性名
local function get_event_handler_prop_name(event_name)
    return "on_" .. event_name .. "_handler"
end

-- 获取事件参数的属性名
local function get_event_params_prop_name(event_name)
    return "on_" .. event_name .. "_params"
end

-- 获取事件动作的属性名
local function get_event_action_prop_name(event_name)
    return "on_" .. event_name .. "_action"
end

-- 加载事件处理代码
local function load_event_handlers(widget_entry, events)
    local handlers = {}
    local instance = widget_entry.instance
    
    if instance and instance.get_properties then
        local props = instance:get_properties()
        for _, event in ipairs(events) do
            local handler_prop = get_event_handler_prop_name(event.name)
            local params_prop = get_event_params_prop_name(event.name)
            local action_prop = get_event_action_prop_name(event.name)
            
            -- 优先使用 handler 属性，如果没有则使用 params 属性
            local code = props[handler_prop] or props[params_prop] or ""
            if code == "{}" then code = "" end
            handlers[event.name] = code
        end
    end
    
    return handlers
end

-- 保存事件处理代码
local function save_event_handler(ctx, widget_entry, event_name, code)
    local instance = widget_entry.instance
    
    if instance and instance.set_property then
        -- 保存到 handler 属性
        local handler_prop = get_event_handler_prop_name(event_name)
        instance:set_property(handler_prop, code)
        
        -- 同时更新 params 属性（兼容旧格式）
        local params_prop = get_event_params_prop_name(event_name)
        if code ~= "" then
            instance:set_property(params_prop, code)
        end
        
        -- 触发属性变更事件
        ctx:_emit("property_changed", handler_prop, code, widget_entry)
        
        print("[事件编辑器] 保存事件 " .. event_name .. " 的处理代码")
    end
end

-- 关闭下拉列表
local function close_dropdown()
    if _current_state.dropdown_list then
        pcall(function() _current_state.dropdown_list:delete() end)
        _current_state.dropdown_list = nil
        _current_state.is_dropdown_open = false
    end
end

-- 更新文本框内容
local function update_textarea_content(event_name)
    if _current_state.textarea and event_name then
        local code = _current_state.event_handlers[event_name] or ""
        _current_state.textarea:set_text(code)
        _current_state.selected_event = event_name
    end
end

-- 创建事件下拉选择框
local function create_event_dropdown(ctx, y_pos, events, display_label_obj)
    local dropdown_container = lv.obj_create(ctx.content)
    dropdown_container:set_pos(70, y_pos)
    dropdown_container:set_size(ctx.props.width - 90, 26)
    dropdown_container:set_style_bg_color(0x1E1E1E, 0)
    dropdown_container:set_style_border_width(1, 0)
    dropdown_container:set_style_border_color(0x555555, 0)
    dropdown_container:set_style_radius(3, 0)
    dropdown_container:set_style_pad_all(2, 0)
    dropdown_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    dropdown_container:add_flag(lv.OBJ_FLAG_CLICKABLE)
    
    -- 当前选中的事件名
    local current_event = events[1] and events[1].name or ""
    _current_state.selected_event = current_event
    
    -- 显示标签
    local display_label = lv.label_create(dropdown_container)
    display_label:set_text(current_event ~= "" and current_event or "(选择事件)")
    display_label:set_style_text_color(0xFFFFFF, 0)
    display_label:align(lv.ALIGN_LEFT_MID, 6, 0)
    
    -- 下拉箭头
    local arrow_label = lv.label_create(dropdown_container)
    arrow_label:set_text("▼")
    arrow_label:set_style_text_color(0xAAAAAA, 0)
    arrow_label:align(lv.ALIGN_RIGHT_MID, -6, 0)
    
    -- 打开下拉列表
    local function open_dropdown()
        if _current_state.is_dropdown_open then
            close_dropdown()
            return
        end
        
        local list = lv.obj_create(ctx._parent)
        local list_height = math.min(#events * 28 + 6, 180)
        list:set_size(ctx.props.width - 90, list_height)
        
        -- 计算绝对位置
        local abs_x = ctx.props.x + 70
        local abs_y = ctx.props.y + ctx.props.title_height + y_pos + 30
        list:set_pos(abs_x, abs_y)
        
        list:set_style_bg_color(0x2D2D2D, 0)
        list:set_style_border_width(1, 0)
        list:set_style_border_color(0x555555, 0)
        list:set_style_radius(4, 0)
        list:set_style_pad_all(3, 0)
        list:add_flag(lv.OBJ_FLAG_SCROLLABLE)
        list:clear_layout()
        
        for i, event in ipairs(events) do
            local item = lv.obj_create(list)
            item:set_pos(0, (i - 1) * 26)
            item:set_size(ctx.props.width - 100, 24)
            item:set_style_bg_color(event.name == _current_state.selected_event and 0x007ACC or 0x3D3D3D, 0)
            item:set_style_radius(3, 0)
            item:set_style_border_width(0, 0)
            item:set_style_pad_all(0, 0)
            item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            item:add_flag(lv.OBJ_FLAG_CLICKABLE)
            
            local item_label = lv.label_create(item)
            item_label:set_text(event.label)
            item_label:set_style_text_color(0xFFFFFF, 0)
            item_label:align(lv.ALIGN_LEFT_MID, 8, 0)
            
            local event_name = event.name
            item:add_event_cb(function(e)
                display_label:set_text(event_name)
                _current_state.selected_event = event_name
                update_textarea_content(event_name)
                close_dropdown()
            end, lv.EVENT_CLICKED, nil)
        end
        
        _current_state.dropdown_list = list
        _current_state.is_dropdown_open = true
    end
    
    dropdown_container:add_event_cb(function(e)
        open_dropdown()
    end, lv.EVENT_CLICKED, nil)
    
    return dropdown_container
end

-- 创建多行代码编辑文本框（带复制粘贴按钮）
local function create_code_textarea(ctx, y_pos, initial_code)
    local textarea = lv.textarea_create(ctx.content)
    textarea:set_pos(5, y_pos)
    textarea:set_size(ctx.props.width - 25, 150)  -- 较大的多行文本框
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xE0E0E0, 0)
    textarea:set_style_radius(3, 0)
    textarea:set_style_pad_all(8, 0)
    textarea:set_one_line(false)  -- 多行模式
    textarea:set_text(initial_code or "")
    textarea:set_placeholder_text("-- 在此编写事件处理代码\n-- 例如: print('clicked')")
    -- 确保文本框可点击和可编辑
    textarea:add_flag(lv.OBJ_FLAG_CLICKABLE)
    -- 多行文本框需要滚动支持
    textarea:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 启用文本选择功能（鼠标拖动选择）
    PropertyInputs.setup_text_selection(textarea)
    
    _current_state.textarea = textarea
    
    -- 创建复制粘贴按钮
    local ta = textarea
    local btn_size = 24
    local btn_spacing = 4
    local btn_y = y_pos - 28
    
    -- 复制按钮
    local copy_btn = lv.obj_create(ctx.content)
    copy_btn:set_pos(ctx.props.width - 80, btn_y)
    copy_btn:set_size(btn_size, btn_size)
    copy_btn:set_style_bg_color(0x3D3D3D, 0)
    copy_btn:set_style_border_width(1, 0)
    copy_btn:set_style_border_color(0x555555, 0)
    copy_btn:set_style_radius(3, 0)
    copy_btn:set_style_pad_all(0, 0)
    copy_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    copy_btn:add_flag(lv.OBJ_FLAG_CLICKABLE)
    
    local copy_label = lv.label_create(copy_btn)
    copy_label:set_text("C")
    copy_label:set_style_text_color(0xAAAAAA, 0)
    copy_label:center()
    
    copy_btn:add_event_cb(function(e)
        -- 如果有选中文本，只复制选中部分
        if ta.text_is_selected and ta:text_is_selected() then
            if ta.copy_selection then
                ta:copy_selection()
                print("[剪贴板] 已复制选中的代码")
            end
        else
            -- 否则复制全部文本
            local text = lv.textarea_get_text(ta)
            if text and text ~= "" then
                PropertyInputs.clipboard_set_text(text)
                print("[剪贴板] 已复制全部代码")
            end
        end
    end, lv.EVENT_CLICKED, nil)
    
    -- 粘贴按钮
    local paste_btn = lv.obj_create(ctx.content)
    paste_btn:set_pos(ctx.props.width - 80 + btn_size + btn_spacing, btn_y)
    paste_btn:set_size(btn_size, btn_size)
    paste_btn:set_style_bg_color(0x3D3D3D, 0)
    paste_btn:set_style_border_width(1, 0)
    paste_btn:set_style_border_color(0x555555, 0)
    paste_btn:set_style_radius(3, 0)
    paste_btn:set_style_pad_all(0, 0)
    paste_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    paste_btn:add_flag(lv.OBJ_FLAG_CLICKABLE)
    
    local paste_label = lv.label_create(paste_btn)
    paste_label:set_text("V")
    paste_label:set_style_text_color(0xAAAAAA, 0)
    paste_label:center()
    
    paste_btn:add_event_cb(function(e)
        -- 如果有选中文本，先删除选中部分再粘贴
        if ta.text_is_selected and ta:text_is_selected() then
            if ta.delete_selection then
                ta:delete_selection()
            end
        end
        
        local text = PropertyInputs.clipboard_get_text()
        if text and text ~= "" then
            ta:add_text(text)
            print("[剪贴板] 已粘贴代码")
        end
    end, lv.EVENT_CLICKED, nil)
    
    return textarea
end

-- 创建保存按钮
local function create_save_button(ctx, y_pos, widget_entry)
    local btn = lv.button_create(ctx.content)
    btn:set_pos(ctx.props.width - 80, y_pos)
    btn:set_size(60, 28)
    btn:set_style_bg_color(0x007ACC, 0)
    btn:set_style_radius(3, 0)
    
    local btn_label = lv.label_create(btn)
    btn_label:set_text("保存")
    btn_label:set_style_text_color(0xFFFFFF, 0)
    btn_label:center()
    
    btn:add_event_cb(function(e)
        local event_name = _current_state.selected_event
        if event_name and _current_state.textarea then
            local code = lv.textarea_get_text(_current_state.textarea)
            _current_state.event_handlers[event_name] = code
            save_event_handler(ctx, widget_entry, event_name, code)
            
            -- 显示保存成功提示
            print("[事件编辑器] 已保存事件 [" .. event_name .. "] 的处理代码")
        end
    end, lv.EVENT_CLICKED, nil)
    
    return btn
end

-- 创建事件绑定编辑器
function PropertyEventEditor.create_events_table(ctx, y_pos, widget_entry, meta)
    -- 关闭之前的下拉列表
    close_dropdown()
    
    -- 重置状态
    _current_state.widget_entry = widget_entry
    _current_state.textarea = nil
    
    -- 获取事件列表
    local events = get_widget_events(meta)
    _current_state.events_list = events
    
    if #events == 0 then
        return y_pos
    end
    
    -- 加载现有的事件处理代码
    _current_state.event_handlers = load_event_handlers(widget_entry, events)
    
    -- 标题
    local table_title_height = 22
    local title = lv.label_create(ctx.content)
    title:set_text("事件绑定")
    title:set_style_text_color(0xFF6600, 0)
    title:set_pos(0, y_pos)
    y_pos = y_pos + table_title_height + 5
    
    -- 事件选择标签
    local event_label = lv.label_create(ctx.content)
    event_label:set_text("事件:")
    event_label:set_style_text_color(0xCCCCCC, 0)
    event_label:set_pos(5, y_pos + 3)
    
    -- 事件下拉选择框
    create_event_dropdown(ctx, y_pos, events, nil)
    y_pos = y_pos + 35
    
    -- 代码标签和复制粘贴按钮（在同一行）
    local code_label = lv.label_create(ctx.content)
    code_label:set_text("处理代码:")
    code_label:set_style_text_color(0xCCCCCC, 0)
    code_label:set_pos(5, y_pos)
    y_pos = y_pos + 28  -- 留出复制粘贴按钮的空间
    
    -- 多行代码编辑文本框（带复制粘贴按钮）
    local initial_event = events[1] and events[1].name or ""
    local initial_code = _current_state.event_handlers[initial_event] or ""
    create_code_textarea(ctx, y_pos, initial_code)
    y_pos = y_pos + 160
    
    -- 保存按钮
    create_save_button(ctx, y_pos, widget_entry)
    y_pos = y_pos + 40
    
    return y_pos
end

-- 旧版兼容函数
function PropertyEventEditor.create_action_dropdown(ctx, prop_name, current_value, action_module_path, widget_entry, y_pos, on_action_changed)
    -- 保留旧接口，但内部不做任何事
end

function PropertyEventEditor.create_params_input(ctx, container, prop_name, current_value, action_id, action_module_path, widget_entry)
    -- 保留旧接口，但内部不做任何事
end

return PropertyEventEditor
