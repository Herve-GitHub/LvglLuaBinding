-- LeftPanel.lua
-- 左侧面板：包含工具箱和图页列表的Tab页
local lv = require("lvgl")

local LeftPanel = {}
LeftPanel.__index = LeftPanel

LeftPanel.__widget_meta = {
    id = "left_panel",
    name = "Left Panel",
    description = "左侧面板，包含工具箱和图页列表Tab",
    schema_version = "1.0",
    version = "1.0",
}

-- 图页属性元数据（用于属性窗口显示）
LeftPanel.__page_meta = {
    id = "canvas_page",
    name = "图页",
    description = "图页属性设置",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        { name = "name", label = "名称", type = "string", default = "图页" },
        { name = "width", label = "宽度", type = "number", default = 800, min = 100, max = 4096 },
        { name = "height", label = "高度", type = "number", default = 600, min = 100, max = 4096 },
        { name = "bg_color", label = "背景颜色", type = "color", default = 0x1E1E1E },
    },
}

-- 默认工具列表
LeftPanel.DEFAULT_TOOLS = {
    { id = "button", name = "按钮", icon = "BTN", module_path = "widgets.button" },
    { id = "valve", name = "阀门", icon = "VLV", module_path = "widgets.valve" },
    { id = "trend_chart", name = "趋势图", icon = "CHT", module_path = "widgets.trend_chart" },
    { id = "status_bar", name = "状态栏", icon = "STA", module_path = "widgets.status_bar" },
}

-- 构造函数
function LeftPanel.new(parent, props)
    props = props or {}
    local self = setmetatable({}, LeftPanel)
    
    -- 保存父元素引用
    self._parent = parent
    
    -- 属性
    self.props = {
        x = props.x or 0,
        y = props.y or 0,
        width = props.width or 250,
        height = props.height or 600,
        bg_color = props.bg_color or 0x2D2D2D,
        tab_bg_color = props.tab_bg_color or 0x3D3D3D,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
        selected_color = props.selected_color or 0x007ACC,
        item_height = props.item_height or 32,
    }
    
    -- 工具列表
    self._tools = props.tools or LeftPanel.DEFAULT_TOOLS
    
    -- 模块缓存
    self._loaded_modules = {}
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- Tab 状态
    self._current_tab = "toolbox"  -- "toolbox" 或 "pages"
    
    -- 图页数据
    self._pages = {}
    self._selected_page_index = 0
    self._page_counter = 0
    self._page_items = {}
    
    -- 工具拖拽状态
    self._tool_drag_state = {
        is_dragging = false,
        tool = nil,
        module = nil,
        ghost = nil,
        start_mouse_x = 0,
        start_mouse_y = 0,
    }
    
    -- Tab 高度
    self._tab_height = 36
    
    -- 创建主容器
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_radius(0, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(self.props.border_color, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:set_style_text_color(self.props.text_color, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.container:clear_layout()
    
    -- 创建 Tab 按钮区域
    self:_create_tab_buttons()
    
    -- 创建工具箱内容区域
    self:_create_toolbox_content()
    
    -- 创建图页列表内容区域
    self:_create_pages_content()
    
    -- 默认显示工具箱
    self:_switch_tab("toolbox")
    
    return self
end

-- 创建 Tab 按钮
function LeftPanel:_create_tab_buttons()
    local this = self
    local tab_width = (self.props.width - 4) / 2
    
    -- Tab 按钮容器
    self.tab_container = lv.obj_create(self.container)
    self.tab_container:set_pos(0, 0)
    self.tab_container:set_size(self.props.width, self._tab_height)
    self.tab_container:set_style_bg_color(self.props.tab_bg_color, 0)
    self.tab_container:set_style_radius(0, 0)
    self.tab_container:set_style_border_width(0, 0)
    self.tab_container:set_style_border_color(self.props.border_color, 0)
    self.tab_container:set_style_pad_all(0, 0)
    self.tab_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.tab_container:clear_layout()
    
    -- 工具箱 Tab 按钮
    self.toolbox_tab = lv.obj_create(self.tab_container)
    self.toolbox_tab:set_pos(2, 4)
    self.toolbox_tab:set_size(tab_width, self._tab_height - 8)
    self.toolbox_tab:set_style_bg_color(self.props.selected_color, 0)
    self.toolbox_tab:set_style_radius(4, 0)
    self.toolbox_tab:set_style_border_width(0, 0)
    self.toolbox_tab:set_style_pad_all(0, 0)
    self.toolbox_tab:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.toolbox_tab:clear_layout()
    
    local toolbox_label = lv.label_create(self.toolbox_tab)
    toolbox_label:set_text("工具箱")
    toolbox_label:set_style_text_color(self.props.text_color, 0)
    toolbox_label:center()
    self._toolbox_tab_label = toolbox_label
    
    self.toolbox_tab:add_event_cb(function(e)
        this:_switch_tab("toolbox")
    end, lv.EVENT_CLICKED, nil)
    
    -- 图页列表 Tab 按钮
    self.pages_tab = lv.obj_create(self.tab_container)
    self.pages_tab:set_pos(tab_width + 2, 4)
    self.pages_tab:set_size(tab_width, self._tab_height - 8)
    self.pages_tab:set_style_bg_color(0x404040, 0)
    self.pages_tab:set_style_radius(4, 0)
    self.pages_tab:set_style_border_width(0, 0)
    self.pages_tab:set_style_pad_all(0, 0)
    self.pages_tab:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.pages_tab:clear_layout()
    
    local pages_label = lv.label_create(self.pages_tab)
    pages_label:set_text("图页列表")
    pages_label:set_style_text_color(self.props.text_color, 0)
    pages_label:center()
    self._pages_tab_label = pages_label
    
    self.pages_tab:add_event_cb(function(e)
        this:_switch_tab("pages")
    end, lv.EVENT_CLICKED, nil)
end

-- 切换 Tab
function LeftPanel:_switch_tab(tab_name)
    self._current_tab = tab_name
    
    if tab_name == "toolbox" then
        self.toolbox_tab:set_style_bg_color(self.props.selected_color, 0)
        self.pages_tab:set_style_bg_color(0x404040, 0)
        self.toolbox_content:remove_flag(lv.OBJ_FLAG_HIDDEN)
        self.pages_content:add_flag(lv.OBJ_FLAG_HIDDEN)
    else
        self.toolbox_tab:set_style_bg_color(0x404040, 0)
        self.pages_tab:set_style_bg_color(self.props.selected_color, 0)
        self.toolbox_content:add_flag(lv.OBJ_FLAG_HIDDEN)
        self.pages_content:remove_flag(lv.OBJ_FLAG_HIDDEN)
    end
    
    self:_emit("tab_changed", tab_name)
end

-- 创建工具箱内容区域
function LeftPanel:_create_toolbox_content()
    local content_y = self._tab_height
    local content_height = self.props.height - self._tab_height
    
    self.toolbox_content = lv.obj_create(self.container)
    self.toolbox_content:set_pos(0, content_y)
    self.toolbox_content:set_size(self.props.width, content_height)
    self.toolbox_content:set_style_bg_opa(0, 0)
    self.toolbox_content:set_style_border_width(0, 0)
    self.toolbox_content:set_style_pad_all(5, 0)
    self.toolbox_content:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.toolbox_content:clear_layout()
    
    -- 创建工具项
    local y_offset = 0
    for _, tool in ipairs(self._tools) do
        self:_create_tool_item(tool, y_offset)
        y_offset = y_offset + self.props.item_height + 4
    end
end

-- 创建单个工具项
function LeftPanel:_create_tool_item(tool, y_offset)
    local item_width = self.props.width - 14
    local item_height = self.props.item_height
    
    local item_container = lv.obj_create(self.toolbox_content)
    item_container:set_pos(0, y_offset)
    item_container:set_size(item_width, item_height)
    item_container:set_style_bg_color(0x404040, 0)
    item_container:set_style_radius(4, 0)
    item_container:set_style_border_width(0, 0)
    item_container:set_style_pad_all(0, 0)
    item_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    item_container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    item_container:clear_layout()
    
    -- 图标区域
    local icon_box = lv.obj_create(item_container)
    icon_box:set_pos(4, 3)
    icon_box:set_size(36, 26)
    icon_box:set_style_bg_color(0x505050, 0)
    icon_box:set_style_radius(4, 0)
    icon_box:set_style_border_width(0, 0)
    icon_box:set_style_pad_all(0, 0)
    icon_box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    icon_box:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    
    local icon_label = lv.label_create(icon_box)
    icon_label:set_text(tool.icon or "?")
    icon_label:set_style_text_color(self.props.text_color, 0)
    icon_label:center()
    
    -- 名称
    local name_label = lv.label_create(item_container)
    name_label:set_text(tool.name)
    name_label:set_style_text_color(self.props.text_color, 0)
    name_label:align(lv.ALIGN_LEFT_MID, 46, 0)
    
    -- 工具项拖拽事件
    local this = self
    local tool_ref = tool
    
    item_container:add_event_cb(function(e)
        this:_on_tool_pressed(tool_ref)
    end, lv.EVENT_PRESSED, nil)
    
    item_container:add_event_cb(function(e)
        this:_on_tool_pressing(tool_ref)
    end, lv.EVENT_PRESSING, nil)
    
    item_container:add_event_cb(function(e)
        this:_on_tool_released(tool_ref)
    end, lv.EVENT_RELEASED, nil)
    
    return item_container
end

-- 工具项按下
function LeftPanel:_on_tool_pressed(tool)
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    local module = self:_load_module(tool.module_path)
    if not module then return end
    
    self._tool_drag_state.is_dragging = false
    self._tool_drag_state.tool = tool
    self._tool_drag_state.module = module
    self._tool_drag_state.start_mouse_x = mouse_x
    self._tool_drag_state.start_mouse_y = mouse_y
    self._tool_drag_state.ghost = nil
end

-- 工具项拖动
function LeftPanel:_on_tool_pressing(tool)
    if self._tool_drag_state.tool ~= tool then return end
    
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    local delta_x = mouse_x - self._tool_drag_state.start_mouse_x
    local delta_y = mouse_y - self._tool_drag_state.start_mouse_y
    
    if not self._tool_drag_state.is_dragging then
        if math.abs(delta_x) > 5 or math.abs(delta_y) > 5 then
            self._tool_drag_state.is_dragging = true
            self:_create_drag_ghost(tool, mouse_x, mouse_y)
        else
            return
        end
    end
    
    if self._tool_drag_state.ghost then
        self._tool_drag_state.ghost:set_pos(mouse_x - 30, mouse_y - 15)
    end
end

-- 工具项释放
function LeftPanel:_on_tool_released(tool)
    if self._tool_drag_state.tool ~= tool then return end
    
    local was_dragging = self._tool_drag_state.is_dragging
    local module = self._tool_drag_state.module
    
    if self._tool_drag_state.ghost then
        self._tool_drag_state.ghost:delete()
        self._tool_drag_state.ghost = nil
    end
    
    if was_dragging and module then
        local mouse_x = lv.get_mouse_x()
        local mouse_y = lv.get_mouse_y()
        self:_emit("tool_drag_drop", tool, module, mouse_x, mouse_y)
    end
    
    self._tool_drag_state.is_dragging = false
    self._tool_drag_state.tool = nil
    self._tool_drag_state.module = nil
end

-- 创建拖拽幽灵预览
function LeftPanel:_create_drag_ghost(tool, x, y)
    local ghost = lv.obj_create(self._parent)
    ghost:set_pos(x - 30, y - 15)
    ghost:set_size(60, 30)
    ghost:set_style_bg_color(0x007ACC, 0)
    ghost:set_style_bg_opa(180, 0)
    ghost:set_style_radius(4, 0)
    ghost:set_style_border_width(2, 0)
    ghost:set_style_border_color(0x00AAFF, 0)
    ghost:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    ghost:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    ghost:clear_layout()
    
    local label = lv.label_create(ghost)
    label:set_text(tool.icon or "?")
    label:set_style_text_color(0xFFFFFF, 0)
    label:center()
    
    self._tool_drag_state.ghost = ghost
end

-- 加载工具模块
function LeftPanel:_load_module(module_path)
    if self._loaded_modules[module_path] then
        return self._loaded_modules[module_path]
    end
    
    local ok, module = pcall(require, module_path)
    if ok then
        self._loaded_modules[module_path] = module
        return module
    else
        print("[左侧面板] 加载模块失败: " .. module_path)
        return nil
    end
end

-- 创建图页列表内容区域
function LeftPanel:_create_pages_content()
    local this = self
    local content_y = self._tab_height
    local content_height = self.props.height - self._tab_height
    
    self.pages_content = lv.obj_create(self.container)
    self.pages_content:set_pos(0, content_y)
    self.pages_content:set_size(self.props.width, content_height)
    self.pages_content:set_style_bg_opa(0, 0)
    self.pages_content:set_style_border_width(0, 0)
    self.pages_content:set_style_pad_all(0, 0)
    self.pages_content:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.pages_content:clear_layout()
    self.pages_content:add_flag(lv.OBJ_FLAG_HIDDEN)
    
    -- 工具栏（新增/删除按钮）
    local toolbar_height = 36
    self.pages_toolbar = lv.obj_create(self.pages_content)
    self.pages_toolbar:set_pos(0, 0)
    self.pages_toolbar:set_size(self.props.width, toolbar_height)
    self.pages_toolbar:set_style_bg_color(0x353535, 0)
    self.pages_toolbar:set_style_radius(0, 0)
    self.pages_toolbar:set_style_border_width(0, 0)
    self.pages_toolbar:set_style_pad_all(0, 0)
    self.pages_toolbar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.pages_toolbar:clear_layout()
    
    -- 新增按钮
    local add_btn = lv.obj_create(self.pages_toolbar)
    add_btn:set_size(70, 26)
    add_btn:set_pos(8, 5)
    add_btn:set_style_bg_color(0x4CAF50, 0)
    add_btn:set_style_radius(4, 0)
    add_btn:set_style_border_width(0, 0)
    add_btn:set_style_pad_all(0, 0)
    add_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local add_label = lv.label_create(add_btn)
    add_label:set_text("+ 新增")
    add_label:set_style_text_color(0xFFFFFF, 0)
    add_label:center()
    
    add_btn:add_event_cb(function(e)
        this:add_page()
    end, lv.EVENT_CLICKED, nil)
    
    -- 删除按钮
    local del_btn = lv.obj_create(self.pages_toolbar)
    del_btn:set_size(70, 26)
    del_btn:set_pos(86, 5)
    del_btn:set_style_bg_color(0xF44336, 0)
    del_btn:set_style_radius(4, 0)
    del_btn:set_style_border_width(0, 0)
    del_btn:set_style_pad_all(0, 0)
    del_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local del_label = lv.label_create(del_btn)
    del_label:set_text("- 删除")
    del_label:set_style_text_color(0xFFFFFF, 0)
    del_label:center()
    
    del_btn:add_event_cb(function(e)
        this:delete_selected_page()
    end, lv.EVENT_CLICKED, nil)
    
    -- 图页列表区域
    self.pages_list = lv.obj_create(self.pages_content)
    self.pages_list:set_pos(0, toolbar_height)
    self.pages_list:set_size(self.props.width, content_height - toolbar_height)
    self.pages_list:set_style_bg_opa(0, 0)
    self.pages_list:set_style_border_width(0, 0)
    self.pages_list:set_style_pad_all(5, 0)
    self.pages_list:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.pages_list:clear_layout()
end

-- 添加新图页
function LeftPanel:add_page(name, page_props)
    self._page_counter = self._page_counter + 1
    local page_id = "page_" .. self._page_counter
    local page_name = name or ("图页 " .. self._page_counter)
    
    -- 合并默认属性和传入的属性
    page_props = page_props or {}
    
    local page_data = {
        id = page_id,
        name = page_name,
        width = page_props.width or 800,
        height = page_props.height or 600,
        bg_color = page_props.bg_color or 0x1E1E1E,
        widgets = {},
    }
    
    table.insert(self._pages, page_data)
    self:_create_page_item(page_data)
    
    if #self._pages == 1 then
        self:select_page(1)
    end
    
    self:_emit("page_added", page_data)
    return page_data
end

-- 创建图页列表项UI
function LeftPanel:_create_page_item(page_data)
    local this = self
    local page_id = page_data.id
    local item_index = #self._pages
    local y_offset = (item_index - 1) * (self.props.item_height + 4)
    
    local item = lv.obj_create(self.pages_list)
    item:set_pos(0, y_offset)
    item:set_size(self.props.width - 14, self.props.item_height)
    item:set_style_bg_color(0x404040, 0)
    item:set_style_radius(4, 0)
    item:set_style_border_width(1, 0)
    item:set_style_border_color(0x555555, 0)
    item:set_style_pad_all(0, 0)
    item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    item:clear_layout()
    
    local name_label = lv.label_create(item)
    name_label:set_text(page_data.name)
    name_label:set_style_text_color(self.props.text_color, 0)
    name_label:align(lv.ALIGN_LEFT_MID, 10, 0)
    
    self._page_items[page_id] = {
        container = item,
        label = name_label,
        page_data = page_data,
    }
    
    item:add_event_cb(function(e)
        local current_index = this:_find_page_index(page_id)
        if current_index then
            this:select_page(current_index)
        end
    end, lv.EVENT_CLICKED, nil)
end

-- 查找图页索引
function LeftPanel:_find_page_index(page_id)
    for i, page in ipairs(self._pages) do
        if page.id == page_id then
            return i
        end
    end
    return nil
end

-- 选中图页
function LeftPanel:select_page(index)
    if index < 1 or index > #self._pages then return end
    
    -- 更新之前选中项的样式
    if self._selected_page_index > 0 and self._selected_page_index <= #self._pages then
        local prev_page = self._pages[self._selected_page_index]
        if prev_page then
            local prev_item = self._page_items[prev_page.id]
            if prev_item and prev_item.container then
                prev_item.container:set_style_bg_color(0x404040, 0)
                prev_item.container:set_style_border_color(0x555555, 0)
            end
        end
    end
    
    self._selected_page_index = index
    local page_data = self._pages[index]
    local item = self._page_items[page_data.id]
    if item and item.container then
        item.container:set_style_bg_color(self.props.selected_color, 0)
        item.container:set_style_border_color(0x005A9E, 0)
    end
    
    self:_emit("page_selected", page_data, index)
end

-- 删除选中的图页
function LeftPanel:delete_selected_page()
    if self._selected_page_index < 1 or self._selected_page_index > #self._pages then
        return
    end
    
    if #self._pages <= 1 then
        print("[左侧面板] 至少需要保留一个图页")
        return
    end
    
    local index = self._selected_page_index
    local page_data = self._pages[index]
    local page_id = page_data.id
    
    local item = self._page_items[page_id]
    if item and item.container then
        item.container:delete()
    end
    
    self._page_items[page_id] = nil
    table.remove(self._pages, index)
    self:_relayout_page_items()
    
    self:_emit("page_deleted", page_data, index)
    
    local new_index = math.min(index, #self._pages)
    if new_index >= 1 then
        self._selected_page_index = 0
        self:select_page(new_index)
    end
end

-- 重新排列图页项位置
function LeftPanel:_relayout_page_items()
    for i, page in ipairs(self._pages) do
        local item = self._page_items[page.id]
        if item and item.container then
            local y_offset = (i - 1) * (self.props.item_height + 4)
            item.container:set_pos(0, y_offset)
        end
    end
end

-- 获取所有图页
function LeftPanel:get_pages()
    return self._pages
end

-- 获取图页数量
function LeftPanel:get_page_count()
    return #self._pages
end

-- 更新图页数据
function LeftPanel:update_page_data(index, widgets_data)
    if index >= 1 and index <= #self._pages then
        self._pages[index].widgets = widgets_data
    end
end

-- 获取图页数据
function LeftPanel:get_page_data(index)
    if index >= 1 and index <= #self._pages then
        return self._pages[index]
    end
    return nil
end

-- 获取当前选中的图页
function LeftPanel:get_selected_page()
    if self._selected_page_index >= 1 and self._selected_page_index <= #self._pages then
        return self._pages[self._selected_page_index], self._selected_page_index
    end
    return nil, 0
end

-- 更新图页属性
function LeftPanel:update_page_property(index, prop_name, prop_value)
    if index >= 1 and index <= #self._pages then
        local page = self._pages[index]
        page[prop_name] = prop_value
        
        -- 如果是名称变更，更新UI显示
        if prop_name == "name" then
            local item = self._page_items[page.id]
            if item and item.label then
                item.label:set_text(prop_value)
            end
        end
        
        print("[左侧面板] 更新图页属性: " .. prop_name .. " = " .. tostring(prop_value))
        self:_emit("page_property_changed", page, index, prop_name, prop_value)
    end
end

-- 获取图页属性元数据
function LeftPanel:get_page_meta()
    return LeftPanel.__page_meta
end

-- 事件订阅
function LeftPanel:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function LeftPanel:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[左侧面板] 事件回调错误:", err)
            end
        end
    end
end

-- 设置高度
function LeftPanel:set_height(height)
    if height and height > 0 then
        self.props.height = height
        self.container:set_height(height)
        
        local content_height = height - self._tab_height
        self.toolbox_content:set_height(content_height)
        self.pages_content:set_height(content_height)
        self.pages_list:set_height(content_height - 36)
    end
end

-- 获取容器
function LeftPanel:get_container()
    return self.container
end

-- 获取宽度
function LeftPanel:get_width()
    return self.props.width
end

-- 检查是否正在拖拽工具
function LeftPanel:is_dragging_tool()
    return self._tool_drag_state.is_dragging
end

-- 兼容性方法：获取 canvas_list（返回自身，因为 LeftPanel 已包含图页管理功能）
function LeftPanel:get_canvas_list()
    return self
end

return LeftPanel
