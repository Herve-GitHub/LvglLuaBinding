-- PropertyArea.lua
-- 右侧属性面板：固定在右侧，不可拖拽和关闭
local lv = require("lvgl")
local gen = require("general")

local scr = lv.scr_act()

local PropertyArea = {}
PropertyArea.__index = PropertyArea

PropertyArea.__widget_meta = {
    id = "property_area",
    name = "属性窗口",
    description = "右侧固定属性面板",
    schema_version = "1.0",
    version = "1.0",
}
local selectedItems = {}

-- 当前选中的图页信息
local selectedPage = nil
local selectedPageIndex = 0

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

-- 构造函数
function PropertyArea.new(parent, props)
    props = props or {}
    local self = setmetatable({}, PropertyArea)
    
    -- 属性
    self.props = {
        x = props.x or 800,
        y = props.y or 0,
        width = props.width or 280,
        height = props.height or 600,
        title_height = props.title_height or 32,
        item_height = props.item_height or 32,
        bg_color = props.bg_color or 0x2D2D2D,
        title_bg_color = props.title_bg_color or 0x3D3D3D,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
    }
    
    -- 保存父元素引用
    self._parent = parent
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 创建主容器（固定面板样式）
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_radius(0, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(self.props.border_color, 0)
    self.container:set_style_text_color(self.props.text_color, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.container:clear_layout()
    
    -- 创建标题栏（只显示标题，无关闭按钮）
    self:_create_title_bar()
    
    -- 创建内容区域
    self:_create_content_area()
    
    return self
end

-- 创建标题栏（无关闭按钮）
function PropertyArea:_create_title_bar()
    self.title_bar = lv.obj_create(self.container)
    self.title_bar:set_pos(0, 0)
    self.title_bar:set_size(self.props.width, self.props.title_height)
    self.title_bar:set_style_bg_color(self.props.title_bg_color, 0)
    self.title_bar:set_style_radius(0, 0)
    self.title_bar:set_style_border_width(0, 0)
    self.title_bar:set_style_text_color(self.props.text_color, 0)
    self.title_bar:set_style_pad_all(0, 0)
    self.title_bar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.title_bar:clear_layout()
    
    -- 标题文本
    self.title_label = lv.label_create(self.title_bar)
    self.title_label:set_text("属性")
    self.title_label:set_style_text_color(self.props.text_color, 0)
    self.title_label:align(lv.ALIGN_LEFT_MID, 10, 0)
end

-- 创建内容区域
function PropertyArea:_create_content_area()
    local content_height = self.props.height - self.props.title_height
    
    self.content = lv.obj_create(self.container)
    self.content:set_pos(0, self.props.title_height)
    self.content:set_size(self.props.width, content_height)
    self.content:set_style_bg_opa(0, 0)
    self.content:set_style_border_width(0, 0)
    self.content:set_style_text_color(self.props.text_color, 0)
    self.content:set_style_pad_all(5, 0)
    self.content:set_style_pad_right(10, 0)
    self.content:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.content:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.content:clear_layout()
end

-- 事件订阅
function PropertyArea:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function PropertyArea:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[属性窗口] 事件回调错误:", err)
            end
        end
    end
end

-- 设置高度
function PropertyArea:set_height(height)
    if height and height > 0 then
        self.props.height = height
        self.container:set_height(height)
        self.content:set_height(height - self.props.title_height)
    end
end

-- 设置位置
function PropertyArea:set_pos(x, y)
    self.props.x = x
    self.props.y = y
    self.container:set_pos(x, y)
end

-- 获取位置
function PropertyArea:get_pos()
    return self.props.x, self.props.y
end

-- 获取容器
function PropertyArea:get_container()
    return self.container
end

-- 获取宽度
function PropertyArea:get_width()
    return self.props.width
end

-- 是否可见（始终可见）
function PropertyArea:is_visible()
    return true
end

function PropertyArea:onSelectedItem(item)
    -- 清除图页选中状态
    selectedPage = nil
    selectedPageIndex = 0
    
    if item == nil then
        print("[属性窗口] 取消选中控件")
        selectedItems = {}
        self:_clear_content_area()
        return
    end
    
    if type(item) == "table" and item.instance then
        selectedItems = { item }
        self:_display_widget_properties(item)
    elseif type(item) == "table" then
        selectedItems = item
        if #item > 0 then
            print("[属性窗口] 多个控件已选中，共 " .. #item .. " 个，显示第一个")
            self:_display_widget_properties(item[1])
        end
    end
end

-- 选中图页时调用
function PropertyArea:onSelectedPage(page_data, page_index, page_meta)
    -- 清除控件选中状态
    selectedItems = {}
    
    if page_data == nil then
        print("[属性窗口] 取消选中图页")
        selectedPage = nil
        selectedPageIndex = 0
        self:_clear_content_area()
        return
    end
    
    selectedPage = page_data
    selectedPageIndex = page_index
    
    print("[属性窗口] 选中图页: " .. page_data.name)
    self:_display_page_properties(page_data, page_index, page_meta)
end

-- 清空内容区域
function PropertyArea:_clear_content_area()
    local child_count = self.content:get_child_count()
    for i = child_count - 1, 0, -1 do
        local child = self.content:get_child(i)
        if child then
            child:delete()
        end
    end
end

-- 显示图页属性
function PropertyArea:_display_page_properties(page_data, page_index, page_meta)
    self:_clear_content_area()
    
    if not page_meta then
        print("[属性窗口] 错误：page_meta 为空")
        return
    end
    
    local y_pos = 0
    local table_title_height = 20
    
    -- 基本信息
    local title = lv.label_create(self.content)
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
        local label = lv.label_create(self.content)
        label:set_text(field.label .. tostring(value))
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(10, y_pos)
        y_pos = y_pos + 18
    end
    
    y_pos = y_pos + 10
    
    -- 属性编辑
    y_pos = self:_create_page_properties_table(y_pos, page_data, page_index, page_meta)
end

-- 创建图页属性编辑表
function PropertyArea:_create_page_properties_table(y_pos, page_data, page_index, page_meta)
    local this = self
    
    if not page_meta.properties then
        print("[属性窗口] 图页没有 properties 定义")
        return y_pos
    end
    
    local table_title_height = 20
    local item_height = 24
    
    local title = lv.label_create(self.content)
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
        
        local label = lv.label_create(self.content)
        label:set_text(prop_label .. ": ")
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(5, y_pos)
        label:set_width(80)
        
        if prop_type == "string" then
            self:_create_page_text_input(prop_name, tostring(prop_value), is_read_only, page_index, y_pos)
        elseif prop_type == "number" then
            self:_create_page_number_input(prop_name, tonumber(prop_value) or 0, prop_def.min, prop_def.max, is_read_only, page_index, y_pos)
        elseif prop_type == "color" then
            self:_create_page_color_input(prop_name, prop_value, is_read_only, page_index, y_pos)
        else
            local value_label = lv.label_create(self.content)
            value_label:set_text(tostring(prop_value))
            value_label:set_style_text_color(0xFFFFFF, 0)
            value_label:set_pos(95, y_pos)
        end
        y_pos = y_pos + item_height
    end
    
    return y_pos + 10
end

-- 创建图页文本输入框
function PropertyArea:_create_page_text_input(prop_name, value, is_read_only, page_index, y_pos)
    local this = self
    
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(self.props.width - 150, 22)  -- 缩短宽度，留出按钮空间
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
        -- 创建设置按钮
        local set_btn = lv.obj_create(self.content)
        set_btn:set_pos(self.props.width - 50, y_pos + 2)
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
            this:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建图页数字输入框
function PropertyArea:_create_page_number_input(prop_name, value, min_val, max_val, is_read_only, page_index, y_pos)
    local this = self
    
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(self.props.width - 150, 22)  -- 缩短宽度，留出按钮空间
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
        -- 创建设置按钮
        local set_btn = lv.obj_create(self.content)
        set_btn:set_pos(self.props.width - 50, y_pos + 2)
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
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, new_value)
            end
            this:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建图页颜色选择框
function PropertyArea:_create_page_color_input(prop_name, value, is_read_only, page_index, y_pos)
    local this = self
    
    local color_hex = "#007ACC"
    local color_num = 0x007ACC
    if type(value) == "number" then
        color_num = value
        color_hex = string.format("#%06X", value)
    elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
        color_hex = value:upper()
        color_num = tonumber(value:sub(2), 16)
    end
    
    local color_box = lv.obj_create(self.content)
    color_box:set_pos(95, y_pos + 2)
    color_box:set_size(20, 20)
    color_box:set_style_bg_color(color_num, 0)
    color_box:set_style_border_width(1, 0)
    color_box:set_style_border_color(0x555555, 0)
    color_box:set_style_radius(0, 0)
    color_box:set_style_pad_all(0, 0)
    color_box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(120, y_pos + 2)
    textarea:set_size(self.props.width - 175, 22)  -- 缩短宽度，留出按钮空间
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
        -- 创建设置按钮
        local set_btn = lv.obj_create(self.content)
        set_btn:set_pos(self.props.width - 50, y_pos + 2)
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
        local cb = color_box
        set_btn:add_event_cb(function(e)
            local new_value = lv.textarea_get_text(ta)
            if new_value then
                new_value = new_value:upper()
                if new_value:match("^#%x%x%x%x%x%x$") then
                    local new_color_num = tonumber(new_value:sub(2), 16)
                    cb:set_style_bg_color(new_color_num, 0)
                    
                    if widget_entry.instance and widget_entry.instance.set_property then
                        widget_entry.instance:set_property(prop_name, new_color_num)
                    end
                    this:_emit("property_changed", prop_name, new_color_num, widget_entry)
                end
            end
        end, lv.EVENT_CLICKED, nil)
        
        -- 输入时实时更新颜色预览（但不触发属性变更）
        textarea:add_event_cb(function(e)
            local target = e:get_target()
            local preview_value = lv.textarea_get_text(target)
            if preview_value and preview_value:match("^#%x%x%x%x%x%x$") then
                local preview_color = tonumber(preview_value:sub(2), 16)
                cb:set_style_bg_color(preview_color, 0)
            end
        end, lv.EVENT_VALUE_CHANGED, nil)
    end
end

-- 显示控件属性
function PropertyArea:_display_widget_properties(widget_entry)
    self:_clear_content_area()
    
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
    
    local y_pos = self:_create_metadata_table(meta)
    y_pos = self:_create_properties_table(y_pos, widget_entry, meta)
    self:_create_events_table(y_pos, widget_entry, meta)
end

-- 创建元数据表（不可修改）
function PropertyArea:_create_metadata_table(meta)
    local y_pos = 0
    local table_title_height = 20
    
    local title = lv.label_create(self.content)
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
        local label = lv.label_create(self.content)
        label:set_text(field.label .. tostring(value))
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(10, y_pos)
        y_pos = y_pos + 18
    end
    
    y_pos = y_pos + 10
    return y_pos
end

-- 创建属性编辑表（可修改）
function PropertyArea:_create_properties_table(y_pos, widget_entry, meta)
    local instance = widget_entry.instance
    local module = widget_entry.module
    
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
    
    local title = lv.label_create(self.content)
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
        
        local label = lv.label_create(self.content)
        label:set_text(prop_label .. ": ")
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(5, y_pos)
        label:set_width(80)
        
        if prop_type == "string" then
            self:_create_text_input(prop_name, tostring(prop_value), is_read_only, widget_entry, y_pos)
        elseif prop_type == "number" then
            self:_create_number_input(prop_name, tonumber(prop_value) or 0, prop_def.min, prop_def.max, is_read_only, widget_entry, y_pos)
        elseif prop_type == "boolean" then
            self:_create_checkbox_input(prop_name, prop_value, is_read_only, widget_entry, y_pos)
        elseif prop_type == "color" then
            self:_create_color_input(prop_name, prop_value, is_read_only, widget_entry, y_pos)
        elseif prop_type == "enum" then
            self:_create_enum_dropdown(prop_name, prop_value, prop_def.options, is_read_only, widget_entry, y_pos)
        else
            local value_label = lv.label_create(self.content)
            value_label:set_text(tostring(prop_value))
            value_label:set_style_text_color(0xFFFFFF, 0)
            value_label:set_pos(95, y_pos)
        end
        y_pos = y_pos + item_height
        ::continue::
    end
    
    return y_pos + 10
end

-- 创建事件绑定表
function PropertyArea:_create_events_table(y_pos, widget_entry, meta)
    local this = self
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
    
    local title = lv.label_create(self.content)
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
            local event_title = lv.label_create(self.content)
            event_title:set_text("[" .. event_name .. "]")
            event_title:set_style_text_color(0x888888, 0)
            event_title:set_pos(5, y_pos)
            y_pos = y_pos + 18
        end
        
        local label = lv.label_create(self.content)
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
            params_container = lv.obj_create(self.content)
            params_container:set_pos(0, params_y_pos)
            params_container:set_size(self.props.width - 10, item_height)
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
            
            this:_create_action_params_input_in_container(
                params_container, params_prop_name, params_value, 
                selected_action_id, action_module_path, widget_entry
            )
        end
        
        self:_create_action_dropdown_with_callback(
            prop_name, prop_value, action_module_path, widget_entry, y_pos,
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

-- 创建动作选择下拉框（带回调）
function PropertyArea:_create_action_dropdown_with_callback(prop_name, current_value, action_module_path, widget_entry, y_pos, on_action_changed)
    local this = self
    
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
    
    local dropdown_container = lv.obj_create(self.content)
    dropdown_container:set_pos(95, y_pos + 2)
    dropdown_container:set_size(self.props.width - 115, 24)
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
        
        dropdown_list = lv.obj_create(self._parent)
        local list_height = math.min(#action_names * 24 + 4, 200)
        dropdown_list:set_size(self.props.width - 115, list_height)
        
        local abs_x = self.props.x + 95
        local abs_y = self.props.y + self.props.title_height + y_pos + 28
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
            item:set_size(self.props.width - 121, 22)
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
                this:_emit("property_changed", prop_name, action_id, widget_entry)
                
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
function PropertyArea:_create_action_params_input_in_container(container, prop_name, current_value, action_id, action_module_path, widget_entry)
    local this = self
    
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
        textarea:set_size(self.props.width - 115, 22)
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
    textarea:set_size(self.props.width - 155, 22)  -- 缩短宽度，留出按钮空间
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
    
    -- 创建设置按钮
    local set_btn = lv.obj_create(container)
    set_btn:set_pos(self.props.width - 55, 2)
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
        this:_emit("property_changed", prop_name, new_value, widget_entry)
    end, lv.EVENT_CLICKED, nil)
end

-- 创建文本输入框
function PropertyArea:_create_text_input(prop_name, value, is_read_only, widget_entry, y_pos)
    local this = self
    
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(self.props.width - 150, 22)  -- 缩短宽度，留出按钮空间
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
        -- 创建设置按钮
        local set_btn = lv.obj_create(self.content)
        set_btn:set_pos(self.props.width - 50, y_pos + 2)
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
            this:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建数字输入框
function PropertyArea:_create_number_input(prop_name, value, min_val, max_val, is_read_only, widget_entry, y_pos)
    local this = self
    
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(self.props.width - 150, 22)  -- 缩短宽度，留出按钮空间
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
        -- 创建设置按钮
        local set_btn = lv.obj_create(self.content)
        set_btn:set_pos(self.props.width - 50, y_pos + 2)
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
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, new_value)
            end
            this:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建复选框
function PropertyArea:_create_checkbox_input(prop_name, value, is_read_only, widget_entry, y_pos)
    local this = self
    local is_checked = value and true or false
    
    local checkbox = lv.obj_create(self.content)
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
            this:_emit("property_changed", prop_name, is_checked, widget_entry)
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建颜色选择框
function PropertyArea:_create_color_input(prop_name, value, is_read_only, widget_entry, y_pos)
    local this = self
    
    local color_hex = "#007ACC"
    local color_num = 0x007ACC
    if type(value) == "number" then
        color_num = value
        color_hex = string.format("#%06X", value)
    elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
        color_hex = value:upper()
        color_num = tonumber(value:sub(2), 16)
    end
    
    local color_box = lv.obj_create(self.content)
    color_box:set_pos(95, y_pos + 2)
    color_box:set_size(20, 20)
    color_box:set_style_bg_color(color_num, 0)
    color_box:set_style_border_width(1, 0)
    color_box:set_style_border_color(0x555555, 0)
    color_box:set_style_radius(0, 0)
    color_box:set_style_pad_all(0, 0)
    color_box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(120, y_pos + 2)
    textarea:set_size(self.props.width - 175, 22)  -- 缩短宽度，留出按钮空间
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
        -- 创建设置按钮
        local set_btn = lv.obj_create(self.content)
        set_btn:set_pos(self.props.width - 50, y_pos + 2)
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
        local cb = color_box
        set_btn:add_event_cb(function(e)
            local new_value = lv.textarea_get_text(ta)
            if new_value then
                new_value = new_value:upper()
                if new_value:match("^#%x%x%x%x%x%x$") then
                    local new_color_num = tonumber(new_value:sub(2), 16)
                    cb:set_style_bg_color(new_color_num, 0)
                    
                    if widget_entry.instance and widget_entry.instance.set_property then
                        widget_entry.instance:set_property(prop_name, new_color_num)
                    end
                    this:_emit("property_changed", prop_name, new_color_num, widget_entry)
                end
            end
        end, lv.EVENT_CLICKED, nil)
        
        -- 输入时实时更新颜色预览（但不触发属性变更）
        textarea:add_event_cb(function(e)
            local target = e:get_target()
            local preview_value = lv.textarea_get_text(target)
            if preview_value and preview_value:match("^#%x%x%x%x%x%x$") then
                local preview_color = tonumber(preview_value:sub(2), 16)
                cb:set_style_bg_color(preview_color, 0)
            end
        end, lv.EVENT_VALUE_CHANGED, nil)
    end
end

-- 创建枚举下拉框
function PropertyArea:_create_enum_dropdown(prop_name, value, options, is_read_only, widget_entry, y_pos)
    local dropdown = lv.obj_create(self.content)
    dropdown:set_pos(95, y_pos + 2)
    dropdown:set_size(self.props.width - 105, 20)
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

return PropertyArea