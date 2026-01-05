-- PropertyArea.lua
-- 浮动属性窗口：样式参考属性窗口，但不包含工具列表内容
local lv = require("lvgl")
local gen = require("general")
-- 移除 ColorDialog 引用，改用文本输入
-- local ColorDialog = require("ColorDialog")
-- 获取屏幕
local scr = lv.scr_act()

local PropertyArea = {}
PropertyArea.__index = PropertyArea

PropertyArea.__widget_meta = {
    id = "property_area",
    name = "属性窗口",
    description = "浮动属性窗口",
    schema_version = "1.0",
    version = "1.0",
}
local selectedItems ={}
-- 构造函数
function PropertyArea.new(parent, props)
    
    props = props or {}
    local self = setmetatable({}, PropertyArea)
    
    -- 属性
    self.props = {
        x = props.x or 800,
        y = props.y or 50,
        width = props.width or 260,
        title_height = props.title_height or 28,
        item_height = props.item_height or 32,
        bg_color = props.bg_color or 0x2D2D2D,
        title_bg_color = props.title_bg_color or 0x3D3D3D,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
        visible = props.visible or false,
        collapsed = props.collapsed or false,  -- 折叠状态
    }
    
    -- 保存父元素引用（屏幕）
    self._parent = parent
    
    -- 工具列表
    self._tools = props.tools or PropertyArea.DEFAULT_TOOLS
    
    -- 模块缓存
    self._loaded_modules = {}
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 标题栏拖拽状态
    self._drag_state = {
        is_dragging = false,
        start_x = 0,
        start_y = 0,
        start_mouse_x = 0,
        start_mouse_y = 0,
    }
    
    -- 工具拖拽状态（拖拽工具到画布）
    self._tool_drag_state = {
        is_dragging = false,
        tool = nil,
        module = nil,
        ghost = nil,  -- 拖拽时显示的幽灵预览
        start_mouse_x = 0,
        start_mouse_y = 0,
    }
    self._content_height = 600  -- 内容区域高度（可根据需要调整）
    -- 创建主容器（浮动窗口样式）
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self._content_height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_bg_opa(240, 0)  -- 略微透明
    self.container:set_style_radius(6, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(self.props.border_color, 0)
    self.container:set_style_shadow_width(8, 0)
    self.container:set_style_shadow_color(0x000000, 0)
    self.container:set_style_shadow_opa(100, 0)
    self.container:set_style_text_color(self.props.text_color, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.container:clear_layout()
    
    -- 创建标题栏
    self:_create_title_bar()
    
    -- 创建内容区域
    self:_create_content_area()
    
    -- 如果初始状态是折叠的，则折叠
    if self.props.collapsed then
        self:_apply_collapsed_state()
    end
    
    return self
end

-- 创建标题栏
function PropertyArea:_create_title_bar()
    local this = self
    
    self.title_bar = lv.obj_create(self.container)
    self.title_bar:set_pos(0, 0)
    self.title_bar:set_size(self.props.width, self.props.title_height)
    self.title_bar:set_style_bg_color(self.props.title_bg_color, 0)
    self.title_bar:set_style_radius(6, 0)
    self.title_bar:set_style_border_width(0, 0)
    self.title_bar:set_style_text_color(self.props.text_color, 0)
    self.title_bar:set_style_pad_all(0, 0)
    self.title_bar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.title_bar:clear_layout()
    
    -- 折叠按钮 (▼/▶)
    self.collapse_btn = lv.obj_create(self.title_bar)
    self.collapse_btn:set_size(20, 20)
    self.collapse_btn:set_pos(4, 4)
    self.collapse_btn:set_style_bg_color(0x505050, 0)
    self.collapse_btn:set_style_radius(3, 0)
    self.collapse_btn:set_style_border_width(0, 0)
    self.collapse_btn:set_style_pad_all(0, 0)
    self.collapse_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    self.collapse_label = lv.label_create(self.collapse_btn)
    self.collapse_label:set_text(self.props.collapsed and "+" or "-")
    self.collapse_label:set_style_text_color(self.props.text_color, 0)
    self.collapse_label:center()
    
    -- 折叠按钮事件
    self.collapse_btn:add_event_cb(function(e)
        this:toggle_collapse()
    end, lv.EVENT_CLICKED, nil)
    
    -- 标题文本
    self.title_label = lv.label_create(self.title_bar)
    self.title_label:set_text("属性窗口")
    self.title_label:set_style_text_color(self.props.text_color, 0)
    self.title_label:align(lv.ALIGN_LEFT_MID, 28, 0)
    
    -- 隐藏按钮 (X)
    self.hide_btn = lv.obj_create(self.title_bar)
    self.hide_btn:set_size(20, 20)
    self.hide_btn:align(lv.ALIGN_RIGHT_MID, -4, 0)
    self.hide_btn:set_style_bg_color(0x555555, 0)
    self.hide_btn:set_style_radius(3, 0)
    self.hide_btn:set_style_border_width(0, 0)
    self.hide_btn:set_style_pad_all(0, 0)
    self.hide_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local hide_label = lv.label_create(self.hide_btn)
    hide_label:set_text("X")
    hide_label:set_style_text_color(self.props.text_color, 0)
    hide_label:center()
    
    -- 隐藏按钮事件
    self.hide_btn:add_event_cb(function(e)
        this:hide()
    end, lv.EVENT_CLICKED, nil)
    
    -- 标题栏拖拽事件
    self.title_bar:add_event_cb(function(e)
        this:_on_title_pressed()
    end, lv.EVENT_PRESSED, nil)
    
    self.title_bar:add_event_cb(function(e)
        this:_on_title_pressing()
    end, lv.EVENT_PRESSING, nil)
    
    self.title_bar:add_event_cb(function(e)
        this:_on_title_released()
    end, lv.EVENT_RELEASED, nil)
end

-- 创建内容区域
function PropertyArea:_create_content_area()
    self.content = lv.obj_create(self.container)
    self.content:set_pos(0, self.props.title_height)
    self.content:set_size(self.props.width, self._content_height - self.props.title_height)
    self.content:set_style_bg_opa(0, 0)
    self.content:set_style_border_width(0, 0)
    self.content:set_style_text_color(self.props.text_color, 0)
    self.content:set_style_pad_all(5, 0)
    self.content:remove_flag(lv.OBJ_FLAG_SCROLLABLE)  -- 启用滚动以支持更多内容
    self.content:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)  -- 禁用手势冒泡
    self.content:clear_layout()
end

-- 标题栏按下事件
function PropertyArea:_on_title_pressed()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    self._drag_state.is_dragging = false
    self._drag_state.start_x = self.props.x
    self._drag_state.start_y = self.props.y
    self._drag_state.start_mouse_x = mouse_x
    self._drag_state.start_mouse_y = mouse_y
end

-- 标题栏拖动事件
function PropertyArea:_on_title_pressing()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    local delta_x = mouse_x - self._drag_state.start_mouse_x
    local delta_y = mouse_y - self._drag_state.start_mouse_y
    
    -- 检查是否开始拖拽
    if not self._drag_state.is_dragging then
        if math.abs(delta_x) > 3 or math.abs(delta_y) > 3 then
            self._drag_state.is_dragging = true
        else
            return
        end
    end
    
    -- 计算新位置
    local new_x = self._drag_state.start_x + delta_x
    local new_y = self._drag_state.start_y + delta_y
    
    -- 限制在屏幕范围内
    new_x = math.max(0, new_x)
    new_y = math.max(0, new_y)
    
    -- 更新位置
    self.props.x = new_x
    self.props.y = new_y
    self.container:set_pos(math.floor(new_x), math.floor(new_y))
end

-- 标题栏释放事件
function PropertyArea:_on_title_released()
    if self._drag_state.is_dragging then
        self:_emit("position_changed", self.props.x, self.props.y)
    end
    self._drag_state.is_dragging = false
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


-- 折叠/展开
function PropertyArea:toggle_collapse()
    self.props.collapsed = not self.props.collapsed
    self:_apply_collapsed_state()
    self:_emit("collapse_changed", self.props.collapsed)
end

-- 应用折叠状态
function PropertyArea:_apply_collapsed_state()
    if self.props.collapsed then
        -- 折叠：只显示标题栏
        self.content:add_flag(lv.OBJ_FLAG_HIDDEN)
        print(self.props.title_height)
        self.container:set_height(self.props.title_height)
        self.collapse_label:set_text("+")
    else
        -- 展开：显示全部
        self.content:remove_flag(lv.OBJ_FLAG_HIDDEN)
        print(self._content_height)
        self.container:set_height(self._content_height)
        self.collapse_label:set_text("-")
    end
end

-- 折叠
function PropertyArea:collapse()
    if not self.props.collapsed then
        self:toggle_collapse()
    end
end

-- 展开
function PropertyArea:expand()
    if self.props.collapsed then
        self:toggle_collapse()
    end
end

-- 是否折叠
function PropertyArea:is_collapsed()
    return self.props.collapsed
end

-- 显示属性窗口
function PropertyArea:show()
    self.props.visible = true
    self.container:remove_flag(lv.OBJ_FLAG_HIDDEN)
    self:_emit("visibility_changed", true)
    print("[属性窗口] 显示")
end

-- 隐藏属性窗口
function PropertyArea:hide()
    self.props.visible = false
    self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
    self:_emit("visibility_changed", false)
    print("[属性窗口] 隐藏")
end

-- 切换显示/隐藏
function PropertyArea:toggle()
    if self.props.visible then
        self:hide()
    else
        self:show()
    end
end

-- 是否可见
function PropertyArea:is_visible()
    return self.props.visible
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

-- 添加自定义工具
function PropertyArea:add_tool(tool_def)
    table.insert(self._tools, tool_def)
end

-- 获取所有工具
function PropertyArea:get_tools()
    return self._tools
end

-- 检查是否正在拖拽工具
function PropertyArea:is_dragging_tool()
    return self._tool_drag_state.is_dragging
end

-- 获取当前拖拽的工具
function PropertyArea:get_dragging_tool()
    if self._tool_drag_state.is_dragging then
        return self._tool_drag_state.tool, self._tool_drag_state.module
    end
    return nil, nil
end
function PropertyArea:onSelectedItem(item)
    if item == nil then
        print("[属性窗口] 取消选中控件")
        selectedItems = {}
        self:_clear_content_area()
        return
    end
    
    -- item 可能是单个 widget_entry 或多个 widget_entries 列表
    if type(item) == "table" and item.instance then
        -- 单个选中
        selectedItems = {}
        selectedItems = { item }
        self:_display_widget_properties(item)
        
    elseif type(item) == "table" then
        -- 多个选中，显示第一个
        selectedItems = item
        if #item > 0 then
            print("[属性窗口] 多个控件已选中，共 " .. #item .. " 个，显示第一个")
            self:_display_widget_properties(item[1])
        end
    end
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

-- 显示控件属性
function PropertyArea:_display_widget_properties(widget_entry)
    self:_clear_content_area()
    
    local instance = widget_entry.instance
    local module = widget_entry.module
    
    if not instance or not module then
        print("[属性窗口] 错误：instance 或 module 为空")
        return
    end
    
    -- 获取元数据
    local meta = module.__widget_meta
    if not meta then
        print("[属性窗口] 错误：模块没有 __widget_meta")
        return
    end
    
    -- 显示第一个表：元数据信息（不可修改）
    local y_pos = self:_create_metadata_table(meta)
    
    -- 显示第二个表：属性编辑表（可修改）
    self:_create_properties_table(y_pos,widget_entry, meta)
end

-- 创建元数据表（不可修改）
function PropertyArea:_create_metadata_table(meta)
    local y_pos = 0
    local table_title_height = 20
    
    -- 表标题
    local title = lv.label_create(self.content)
    title:set_text("基本信息")
    title:set_style_text_color(0x007ACC, 0)
    title:set_pos(5, y_pos)
    y_pos = y_pos + table_title_height
    
    -- 元数据字段列表
    local meta_fields = {
        { key = "id", label = "ID: " },
        { key = "name", label = "名称: " },
        { key = "description", label = "描述: " },
        { key = "schema_version", label = "Schema: " },
        { key = "version", label = "版本: " },
    }
    
    local item_height = 20
    for _, field in ipairs(meta_fields) do
        local value = meta[field.key] or ""
        local field_height = 18
        
        -- 创建标签
        local label = lv.label_create(self.content)
        label:set_text(field.label .. tostring(value))
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(10, y_pos)
        y_pos = y_pos + field_height
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
        return
    end
    
    -- 获取当前实例的属性值
    local current_props = {}
    if instance.get_properties then
        current_props = instance:get_properties()
    end
    
    local table_title_height = 20
    local item_height = 24
    
    -- 表标题
    local title = lv.label_create(self.content)
    title:set_text("属性编辑")
    title:set_style_text_color(0x00CC00, 0)
    title:set_pos(0, y_pos)
    y_pos = y_pos + table_title_height + 5
    
    -- 遍历属性定义
    for _, prop_def in ipairs(meta.properties) do
        
        local prop_name = prop_def.name
        if prop_name == "design_mode" then
            -- 跳过 design_mode 属性
            goto continue
        end
        local prop_label = prop_def.label or prop_name
        local prop_type = prop_def.type
        local prop_value = current_props[prop_name] or prop_def.default or ""
        local is_read_only = prop_def.read_only or false
        
        -- 创建标签（属性名）
        local label = lv.label_create(self.content)
        label:set_text(prop_label .. ": ")
        label:set_style_text_color(0xCCCCCC, 0)
        label:set_pos(5, y_pos)
        label:set_width(80)
        
        -- 根据类型创建编辑控件
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
            -- 默认为只读文本显示
            local value_label = lv.label_create(self.content)
            value_label:set_text(tostring(prop_value))
            value_label:set_style_text_color(0xFFFFFF, 0)
            value_label:set_pos(95, y_pos)
        end
        y_pos = y_pos + item_height
        ::continue::
    end
end

-- 创建文本输入框
function PropertyArea:_create_text_input(prop_name, value, is_read_only, widget_entry, y_pos)
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(self.props.width - 110, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)  -- 矩形，无圆角
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)  -- 单行模式
    textarea:set_text(value)
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)  -- 单行模式不需要滚动
    
    -- 启用键盘输入
    --textarea:enable_keyboard_input()
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        -- 添加值变更事件回调
        local this = self
        textarea:add_event_cb(function(e)
            local new_value = textarea:get_text()
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, new_value)
            end
            this:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_VALUE_CHANGED, nil)
    end
end

-- 创建数字输入框
function PropertyArea:_create_number_input(prop_name, value, min_val, max_val, is_read_only, widget_entry, y_pos)
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(95, y_pos + 2)
    textarea:set_size(self.props.width - 110, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)  -- 矩形，无圆角
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)  -- 单行模式
    textarea:set_text(tostring(math.floor(value)))
    textarea:set_accepted_chars("0123456789-")  -- 只接受数字和负号
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)  -- 单行模式不需要滚动
    
    -- 启用键盘输入
    --textarea:enable_keyboard_input()
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        -- 添加值变更事件回调
        local this = self
        textarea:add_event_cb(function(e)
            local new_value = tonumber(textarea:get_text()) or 0
            -- 限制范围
            if min_val and new_value < min_val then new_value = min_val end
            if max_val and new_value > max_val then new_value = max_val end
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, new_value)
            end
            this:_emit("property_changed", prop_name, new_value, widget_entry)
        end, lv.EVENT_VALUE_CHANGED, nil)
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
    checkbox:set_style_radius(0, 0)  -- 矩形，无圆角
    checkbox:set_style_pad_all(0, 0)  -- 移除内边距
    checkbox:remove_flag(lv.OBJ_FLAG_SCROLLABLE)  -- 移除滚动条
    
    if not is_read_only then
        checkbox:add_flag(lv.OBJ_FLAG_CLICKABLE)
        
        -- 添加点击事件回调
        checkbox:add_event_cb(function(e)
            -- 切换状态
            is_checked = not is_checked
            
            -- 更新复选框颜色
            checkbox:set_style_bg_color(is_checked and 0x007ACC or 0x1E1E1E, 0)
            
            -- 更新控件属性
            if widget_entry.instance and widget_entry.instance.set_property then
                widget_entry.instance:set_property(prop_name, is_checked)
            end
            this:_emit("property_changed", prop_name, is_checked, widget_entry)
            
            print("[属性窗口] 布尔属性已更新: " .. prop_name .. " = " .. tostring(is_checked))
        end, lv.EVENT_CLICKED, nil)
    end
end

-- 创建颜色选择框（改为文本输入方式）
function PropertyArea:_create_color_input(prop_name, value, is_read_only, widget_entry, y_pos)
    local this = self
    
    -- 解析颜色值，转换为 #RRGGBB 格式
    local color_hex = "#007ACC"
    local color_num = 0x007ACC
    if type(value) == "number" then
        color_num = value
        color_hex = string.format("#%06X", value)
    elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
        color_hex = value:upper()
        color_num = tonumber(value:sub(2), 16)
    end
    
    -- 颜色预览框
    local color_box = lv.obj_create(self.content)
    color_box:set_pos(95, y_pos + 2)
    color_box:set_size(20, 20)
    color_box:set_style_bg_color(color_num, 0)
    color_box:set_style_border_width(1, 0)
    color_box:set_style_border_color(0x555555, 0)
    color_box:set_style_radius(0, 0)
    color_box:set_style_pad_all(0, 0)
    color_box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 颜色文本输入框
    local textarea = lv.textarea_create(self.content)
    textarea:set_pos(120, y_pos + 2)
    textarea:set_size(self.props.width - 135, 22)
    textarea:set_style_bg_color(0x1E1E1E, 0)
    textarea:set_style_border_width(1, 0)
    textarea:set_style_border_color(0x555555, 0)
    textarea:set_style_text_color(0xFFFFFF, 0)
    textarea:set_style_radius(0, 0)
    textarea:set_style_pad_all(2, 0)
    textarea:set_style_pad_left(4, 0)
    textarea:set_one_line(true)
    textarea:set_text(color_hex)
    textarea:set_accepted_chars("#0123456789ABCDEFabcdef")  -- 只接受十六进制字符
    textarea:set_max_length(7)  -- #RRGGBB 共7个字符
    textarea:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 启用键盘输入
    --textarea:enable_keyboard_input()
    
    if is_read_only then
        textarea:add_state(lv.STATE_DISABLED)
    else
        -- 添加值变更事件回调
        textarea:add_event_cb(function(e)
            local new_value = textarea:get_text():upper()
            
            -- 验证格式是否正确
            if new_value:match("^#%x%x%x%x%x%x$") then
                local new_color_num = tonumber(new_value:sub(2), 16)
                
                -- 更新颜色预览框
                color_box:set_style_bg_color(new_color_num, 0)
                
                -- 更新控件属性
                if widget_entry.instance and widget_entry.instance.set_property then
                    widget_entry.instance:set_property(prop_name, new_color_num)
                end
                this:_emit("property_changed", prop_name, new_color_num, widget_entry)
                
                print("[属性窗口] 颜色属性已更新: " .. prop_name .. " = " .. new_value)
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
    dropdown:set_style_radius(0, 0)  -- 矩形，无圆角
    dropdown:set_style_pad_all(3, 0)
    dropdown:remove_flag(lv.OBJ_FLAG_SCROLLABLE)  -- 移除滚动条
    
    local label = lv.label_create(dropdown)
    label:set_text(tostring(value))
    label:set_style_text_color(0xFFFFFF, 0)
    
    if not is_read_only then
        dropdown:add_flag(lv.OBJ_FLAG_CLICKABLE)
    end
end

return PropertyArea