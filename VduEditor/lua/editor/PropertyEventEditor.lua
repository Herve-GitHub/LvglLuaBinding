-- PropertyEventEditor.lua
-- 事件绑定编辑模块
local lv = require("lvgl")

local PropertyEventEditor = {}

-- 动作模块缓存
local _action_modules_cache = {}

-- 加载动作模块
local function load_action_module(module_path)
    if _action_modules_cache[module_path] then
        return _action_modules_cache[module_path]
    end
    local ok, module = pcall(require, module_path)
    if ok then
        _action_modules_cache[module_path] = module
        return module
    else
        print("[属性窗口] 加载动作模块失败: " .. module_path .. " - " .. tostring(module))
        return nil
    end
end

-- 创建动作选择下拉框（带回调）
function PropertyEventEditor.create_action_dropdown(ctx, prop_name, current_value, action_module_path, widget_entry, y_pos, on_action_changed)
    local actions = {}
    local action_names = { "(无)" }
    local action_ids = { "" }
    
    if action_module_path then
        local action_module = load_action_module(action_module_path)
        if action_module and action_module.available_actions then
            for _, action_def in ipairs(action_module.available_actions) do
                table.insert(actions, action_def)
                table.insert(action_names, action_def.name)
                table.insert(action_ids, action_def.id)
            end
        end
    end
    
    local dropdown_container = lv.obj_create(ctx.content)
    dropdown_container:set_pos(95, y_pos + 2)
    dropdown_container:set_size(ctx.props.width - 115, 24)
    dropdown_container:set_style_bg_color(0x1E1E1E, 0)
    dropdown_container:set_style_border_width(1, 0)
    dropdown_container:set_style_border_color(0x555555, 0)
    dropdown_container:set_style_radius(0, 0)
    dropdown_container:set_style_pad_all(2, 0)
    dropdown_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    dropdown_container:add_flag(lv.OBJ_FLAG_CLICKABLE)
    
    local current_name = "(无)"
    for i, id in ipairs(action_ids) do
        if id == current_value then
            current_name = action_names[i]
            break
        end
    end
    
    local display_label = lv.label_create(dropdown_container)
    display_label:set_text(current_name)
    display_label:set_style_text_color(0xFFFFFF, 0)
    display_label:align(lv.ALIGN_LEFT_MID, 4, 0)
    
    local arrow_label = lv.label_create(dropdown_container)
    arrow_label:set_text("v")
    arrow_label:set_style_text_color(0xAAAAAA, 0)
    arrow_label:align(lv.ALIGN_RIGHT_MID, -4, 0)
    
    local dropdown_list = nil
    local is_open = false
    
    local function close_dropdown()
        if dropdown_list then
            dropdown_list:delete()
            dropdown_list = nil
            is_open = false
        end
    end
    
    local function open_dropdown()
        if is_open then
            close_dropdown()
            return
        end
        
        dropdown_list = lv.obj_create(ctx._parent)
        local list_height = math.min(#action_names * 24 + 4, 200)
        dropdown_list:set_size(ctx.props.width - 115, list_height)
        
        local abs_x = ctx.props.x + 95
        local abs_y = ctx.props.y + ctx.props.title_height + y_pos + 28
        dropdown_list:set_pos(abs_x, abs_y)
        
        dropdown_list:set_style_bg_color(0x2D2D2D, 0)
        dropdown_list:set_style_border_width(1, 0)
        dropdown_list:set_style_border_color(0x555555, 0)
        dropdown_list:set_style_radius(4, 0)
        dropdown_list:set_style_pad_all(2, 0)
        dropdown_list:add_flag(lv.OBJ_FLAG_SCROLLABLE)
        dropdown_list:clear_layout()
        
        for i, name in ipairs(action_names) do
            local item = lv.obj_create(dropdown_list)
            item:set_pos(0, (i - 1) * 24)
            item:set_size(ctx.props.width - 121, 22)
            item:set_style_bg_color(action_ids[i] == current_value and 0x007ACC or 0x3D3D3D, 0)
            item:set_style_radius(2, 0)
            item:set_style_border_width(0, 0)
            item:set_style_pad_all(0, 0)
            item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            item:add_flag(lv.OBJ_FLAG_CLICKABLE)
            
            local item_label = lv.label_create(item)
            item_label:set_text(name)
            item_label:set_style_text_color(0xFFFFFF, 0)
            item_label:align(lv.ALIGN_LEFT_MID, 6, 0)
            
            local action_id = action_ids[i]
            item:add_event_cb(function(e)
                display_label:set_text(name)
                current_value = action_id
                
                if widget_entry.instance and widget_entry.instance.set_property then
                    widget_entry.instance:set_property(prop_name, action_id)
                end
                ctx:_emit("property_changed", prop_name, action_id, widget_entry)
                
                if on_action_changed then
                    on_action_changed(action_id)
                end
                
                close_dropdown()
            end, lv.EVENT_CLICKED, nil)
        end
        
        is_open = true
    end
    
    dropdown_container:add_event_cb(function(e)
        open_dropdown()
    end, lv.EVENT_CLICKED, nil)
end

-- 在容器中创建动作参数输入框
function PropertyEventEditor.create_params_input(ctx, container, prop_name, current_value, action_id, action_module_path, widget_entry)
    local param_defs = {}
    if action_module_path and action_id and action_id ~= "" then
        local action_module = load_action_module(action_module_path)
        if action_module and action_module.available_actions then
            for _, action_def in ipairs(action_module.available_actions) do
                if action_def.id == action_id then
                    param_defs = action_def.params or {}
                    break
                end
            end
        end
    end
    
    if #param_defs == 0 then
        local textarea = lv.textarea_create(container)
        textarea:set_pos(95, 2)
        textarea:set_size(ctx.props.width - 115, 22)
        textarea:set_style_bg_color(0x1E1E1E, 0)
        textarea:set_style_border_width(1, 0)
        textarea:set_style_border_color(0x555555, 0)
        textarea:set_style_text_color(0x888888, 0)
        textarea:set_style_radius(0, 0)
        textarea:set_style_pad_all(2, 0)
        textarea:set_style_pad_left(4, 0)
        textarea:set_one_line(true)
        textarea:set_text("(无参数)")
        textarea:add_state(lv.STATE_DISABLED)
        textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        return
    end
    
    local current_params = {}
    if current_value and current_value ~= "" and current_value ~= "{}" then
        local ok, parsed = pcall(function()
            local content = current_value:match("^%s*{(.*)%s*}%s*$") or current_value
            local result = {}
            for key, value in content:gmatch('([%w_]+)%s*=%s*([^,}]+)') do
                value = value:gsub('^%s*"(.*)"%s*$', '%1')
                value = value:gsub("^%s*'(.*)'%s*$", '%1')
                value = value:gsub("^%s*(.-)%s*$", '%1')
                local num = tonumber(value)
                if num then
                    result[key] = num
                else
                    result[key] = value
                end
            end
            return result
        end)
        if ok then
            current_params = parsed
        end
    end
    
    local param_hint = "{"
    for i, p in ipairs(param_defs) do
        local default_val = current_params[p.name] or p.default or ""
        if i > 1 then param_hint = param_hint .. ", " end
        if p.type == "string" then
            param_hint = param_hint .. p.name .. '="' .. tostring(default_val) .. '"'
        else
            param_hint = param_hint .. p.name .. "=" .. tostring(default_val)
        end
    end
    param_hint = param_hint .. "}"
    
    local textarea = lv.textarea_create(container)
    textarea:set_pos(95, 2)
    textarea:set_size(ctx.props.width - 155, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)
    textarea:set_text(current_value ~= "" and current_value ~= "{}" and current_value or param_hint)
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local set_btn = lv.obj_create(container)
    set_btn:set_pos(ctx.props.width - 55, 2)
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
        if widget_entry.instance and widget_entry.instance.set_property then
            widget_entry.instance:set_property(prop_name, new_value)
        end
        ctx:_emit("property_changed", prop_name, new_value, widget_entry)
    end, lv.EVENT_CLICKED, nil)
end

-- 创建事件绑定表
function PropertyEventEditor.create_events_table(ctx, y_pos, widget_entry, meta)
    local instance = widget_entry.instance
    
    local action_props = {}
    if meta.properties then
        for _, prop_def in ipairs(meta.properties) do
            if prop_def.type == "action" then
                table.insert(action_props, prop_def)
            end
        end
    end
    
    if #action_props == 0 then
        return y_pos
    end
    
    local table_title_height = 20
    local item_height = 28
    
    local title = lv.label_create(ctx.content)
    title:set_text("事件绑定")
    title:set_style_text_color(0xFF6600, 0)
    title:set_pos(0, y_pos)
    y_pos = y_pos + table_title_height + 5
    
    local current_props = {}
    if instance.get_properties then
        current_props = instance:get_properties()
    end
    
    for _, prop_def in ipairs(action_props) do
        local prop_name = prop_def.name
        local prop_label = prop_def.label or prop_name
        local prop_value = current_props[prop_name] or prop_def.default or ""
        local action_module_path = prop_def.action_module
        local event_name = prop_def.event or ""
        
        if event_name ~= "" then
            local event_title = lv.label_create(ctx.content)
            event_title:set_text("[" .. event_name .. "]")
            event_title:set_style_text_color(0x888888, 0)
            event_title:set_pos(5, y_pos)
            y_pos = y_pos + 18
        end
        
        local label = lv.label_create(ctx.content)
        label:set_text(prop_label .. ": ")
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(5, y_pos)
        label:set_width(80)
        
        local params_prop_name = nil
        local params_prop_def = nil
        for _, p in ipairs(meta.properties) do
            if p.type == "action_params" then
                if p.event and p.event == event_name then
                    params_prop_name = p.name
                    params_prop_def = p
                    break
                elseif not p.event and prop_name:match("_action$") then
                    local expected_params = prop_name:gsub("_action$", "_params")
                    if p.name == expected_params then
                        params_prop_name = p.name
                        params_prop_def = p
                        break
                    end
                end
            end
        end
        
        local params_container = nil
        local params_y_pos = y_pos + item_height
        
        if params_prop_name then
            params_container = lv.obj_create(ctx.content)
            params_container:set_pos(0, params_y_pos)
            params_container:set_size(ctx.props.width - 10, item_height)
            params_container:set_style_bg_opa(0, 0)
            params_container:set_style_border_width(0, 0)
            params_container:set_style_pad_all(0, 0)
            params_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            params_container:clear_layout()
        end
        
        local function update_params_input(selected_action_id)
            if not params_container or not params_prop_name then return end
            
            local child_count = params_container:get_child_count()
            for i = child_count - 1, 0, -1 do
                local child = params_container:get_child(i)
                if child then child:delete() end
            end
            
            local params_value = "{}"
            if instance.get_properties then
                local props = instance:get_properties()
                params_value = props[params_prop_name] or "{}"
            end
            
            local params_label_text = params_prop_def and params_prop_def.label or "参数"
            
            local params_label = lv.label_create(params_container)
            params_label:set_text(params_label_text .. ": ")
            params_label:set_style_text_color(0xCCCCCC, 0)
            params_label:set_pos(5, 2)
            params_label:set_width(80)
            
            PropertyEventEditor.create_params_input(
                ctx, params_container, params_prop_name, params_value, 
                selected_action_id, action_module_path, widget_entry
            )
        end
        
        PropertyEventEditor.create_action_dropdown(
            ctx, prop_name, prop_value, action_module_path, widget_entry, y_pos,
            update_params_input
        )
        y_pos = y_pos + item_height
        
        if params_prop_name then
            update_params_input(prop_value)
            y_pos = y_pos + item_height
        end
        
        y_pos = y_pos + 5
    end
    
    return y_pos
end

return PropertyEventEditor
