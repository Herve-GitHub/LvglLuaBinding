-- 多图页选择窗口组件
local lv = require("lvgl")

local CanvasList = {}
CanvasList.__index = CanvasList

CanvasList.__widget_meta = {
    id = "canvas_list",
    name = "Canvas List",
    description = "多图页窗口",
    schema_version = "1.0",
    version = "1.0",
}

-- 图页属性元数据（用于属性窗口显示）
CanvasList.__page_meta = {
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

-- 构造函数
function CanvasList.new(parent, props)
    props = props or {}
    local self = setmetatable({}, CanvasList)
    
    -- 属性
    self.props = {
        x = props.x or 10,
        y = props.y or 50,
        width = props.width or 200,
        title_height = props.title_height or 28,
        item_height = props.item_height or 32,
        bg_color = props.bg_color or 0x2D2D2D,
        title_bg_color = props.title_bg_color or 0x3D3D3D,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
        selected_color = props.selected_color or 0x007ACC,
        hover_color = props.hover_color or 0x404040,
        visible = props.visible ~= false,  -- 默认显示
        collapsed = props.collapsed or false,
    }
    
    -- 保存父元素引用（屏幕）
    self._parent = parent
    
    -- 图页数据列表
    self._pages = {}
    
    -- 当前选中的图页索引
    self._selected_index = 0
    
    -- 图页计数器（用于生成唯一ID）
    self._page_counter = 0
    
    -- 图页项UI元素（使用page_id作为key）
    self._page_items = {}
    
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
    
    -- 工具栏高度
    self._toolbar_height = 30
    
    -- 内容区域高度
    self._content_height = 300
    
    -- 创建主容器（浮动窗口样式）
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.title_height + self._content_height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_bg_opa(240, 0)
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
    
    -- 创建工具栏（新增/删除按钮）
    self:_create_toolbar()
    
    -- 创建内容区域（图页列表）
    self:_create_content_area()
    
    -- 如果初始不可见则隐藏
    if not self.props.visible then
        self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
    end
    
    -- 如果初始状态是折叠的，则折叠
    if self.props.collapsed then
        self:_apply_collapsed_state()
    end
    
    return self
end

-- 创建标题栏
function CanvasList:_create_title_bar()
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
    
    -- 折叠按钮 (+/-)
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
    self.title_label:set_text("图页列表")
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

-- 创建工具栏
function CanvasList:_create_toolbar()
    local this = self
    
    self.toolbar = lv.obj_create(self.container)
    self.toolbar:set_pos(0, self.props.title_height)
    self.toolbar:set_size(self.props.width, self._toolbar_height)
    self.toolbar:set_style_bg_color(0x353535, 0)
    self.toolbar:set_style_radius(0, 0)
    self.toolbar:set_style_border_width(0, 0)
    self.toolbar:set_style_border_color(self.props.border_color, 0)
    self.toolbar:set_style_pad_all(0, 0)
    self.toolbar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.toolbar:clear_layout()
    
    -- 新增图页按钮
    self.add_btn = lv.obj_create(self.toolbar)
    self.add_btn:set_size(60, 24)
    self.add_btn:set_pos(5, 3)
    self.add_btn:set_style_bg_color(0x4CAF50, 0)
    self.add_btn:set_style_radius(4, 0)
    self.add_btn:set_style_border_width(0, 0)
    self.add_btn:set_style_pad_all(0, 0)
    self.add_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local add_label = lv.label_create(self.add_btn)
    add_label:set_text("+ 新增")
    add_label:set_style_text_color(0xFFFFFF, 0)
    add_label:center()
    
    self.add_btn:add_event_cb(function(e)
        this:add_page()
    end, lv.EVENT_CLICKED, nil)
    
    -- 删除图页按钮
    self.del_btn = lv.obj_create(self.toolbar)
    self.del_btn:set_size(60, 24)
    self.del_btn:set_pos(70, 3)
    self.del_btn:set_style_bg_color(0xF44336, 0)
    self.del_btn:set_style_radius(4, 0)
    self.del_btn:set_style_border_width(0, 0)
    self.del_btn:set_style_pad_all(0, 0)
    self.del_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local del_label = lv.label_create(self.del_btn)
    del_label:set_text("- 删除")
    del_label:set_style_text_color(0xFFFFFF, 0)
    del_label:center()
    
    self.del_btn:add_event_cb(function(e)
        this:delete_selected_page()
    end, lv.EVENT_CLICKED, nil)
end

-- 创建内容区域
function CanvasList:_create_content_area()
    local content_y = self.props.title_height + self._toolbar_height
    
    self.content = lv.obj_create(self.container)
    self.content:set_pos(0, content_y)
    self.content:set_size(self.props.width, self._content_height - self._toolbar_height)
    self.content:set_style_bg_opa(0, 0)
    self.content:set_style_border_width(0, 0)
    self.content:set_style_text_color(self.props.text_color, 0)
    self.content:set_style_pad_all(5, 0)
    self.content:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.content:clear_layout()
end

-- 添加新图页
function CanvasList:add_page(name, page_props)
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
        widgets = {},  -- 存储该图页的控件数据
    }
    
    table.insert(self._pages, page_data)
    
    -- 创建UI项
    self:_create_page_item(page_data)
    
    -- 如果是第一个图页，自动选中
    if #self._pages == 1 then
        self:select_page(1)
    end
    
    print("[图页列表] 新增图页: " .. page_name .. " (ID: " .. page_id .. ")")
    self:_emit("page_added", page_data)
    
    return page_data
end

-- 创建图页列表项UI
function CanvasList:_create_page_item(page_data)
    local this = self
    local page_id = page_data.id
    
    -- 计算Y偏移（基于当前图页数量）
    local item_index = #self._pages
    local y_offset = (item_index - 1) * (self.props.item_height + 4)
    
    local item = lv.obj_create(self.content)
    item:set_pos(0, y_offset)
    item:set_size(self.props.width - 12, self.props.item_height)
    item:set_style_bg_color(0x404040, 0)
    item:set_style_radius(4, 0)
    item:set_style_border_width(1, 0)
    item:set_style_border_color(0x555555, 0)
    item:set_style_pad_all(0, 0)
    item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    item:clear_layout()
    
    -- 图页名称标签
    local name_label = lv.label_create(item)
    name_label:set_text(page_data.name)
    name_label:set_style_text_color(self.props.text_color, 0)
    name_label:align(lv.ALIGN_LEFT_MID, 10, 0)
    
    -- 使用page_id作为key存储UI引用
    self._page_items[page_id] = {
        container = item,
        label = name_label,
        page_data = page_data,
    }
    
    -- 点击选中事件
    item:add_event_cb(function(e)
        -- 查找当前索引
        local current_index = this:_find_page_index(page_id)
        if current_index then
            this:select_page(current_index)
        end
    end, lv.EVENT_CLICKED, nil)
end

-- 查找图页索引
function CanvasList:_find_page_index(page_id)
    for i, page in ipairs(self._pages) do
        if page.id == page_id then
            return i
        end
    end
    return nil
end

-- 选中图页
function CanvasList:select_page(index)
    if index < 1 or index > #self._pages then
        print("[图页列表] 无效的图页索引: " .. index)
        return
    end
    
    -- 更新之前选中项的样式
    if self._selected_index > 0 and self._selected_index <= #self._pages then
        local prev_page = self._pages[self._selected_index]
        if prev_page then
            local prev_item = self._page_items[prev_page.id]
            if prev_item and prev_item.container then
                prev_item.container:set_style_bg_color(0x404040, 0)
                prev_item.container:set_style_border_color(0x555555, 0)
            end
        end
    end
    
    -- 更新当前选中项的样式
    self._selected_index = index
    local page_data = self._pages[index]
    local item = self._page_items[page_data.id]
    if item and item.container then
        item.container:set_style_bg_color(self.props.selected_color, 0)
        item.container:set_style_border_color(0x005A9E, 0)
    end
    
    print("[图页列表] 选中图页: " .. page_data.name)
    self:_emit("page_selected", page_data, index)
end

-- 删除选中的图页
function CanvasList:delete_selected_page()
    if self._selected_index < 1 or self._selected_index > #self._pages then
        print("[图页列表] 没有选中的图页")
        return
    end
    
    -- 至少保留一个图页
    if #self._pages <= 1 then
        print("[图页列表] 至少需要保留一个图页")
        return
    end
    
    local index = self._selected_index
    local page_data = self._pages[index]
    local page_id = page_data.id
    
    -- 删除UI元素
    local item = self._page_items[page_id]
    if item and item.container then
        item.container:delete()
    end
    
    -- 从映射中移除
    self._page_items[page_id] = nil
    
    -- 从数据中移除
    table.remove(self._pages, index)
    
    -- 重新排列剩余项的位置
    self:_relayout_items()
    
    print("[图页列表] 删除图页: " .. page_data.name)
    self:_emit("page_deleted", page_data, index)
    
    -- 选中相邻的图页
    local new_index = math.min(index, #self._pages)
    if new_index >= 1 then
        self._selected_index = 0  -- 重置以便重新应用样式
        self:select_page(new_index)
    end
end

-- 重新排列图页项位置
function CanvasList:_relayout_items()
    for i, page in ipairs(self._pages) do
        local item = self._page_items[page.id]
        if item and item.container then
            local y_offset = (i - 1) * (self.props.item_height + 4)
            item.container:set_pos(0, y_offset)
        end
    end
end

-- 删除指定图页
function CanvasList:delete_page(index)
    if index < 1 or index > #self._pages then
        return
    end
    
    -- 先选中该图页，然后删除
    self:select_page(index)
    self:delete_selected_page()
end

-- 获取当前选中的图页
function CanvasList:get_selected_page()
    if self._selected_index >= 1 and self._selected_index <= #self._pages then
        return self._pages[self._selected_index], self._selected_index
    end
    return nil, 0
end

-- 获取所有图页
function CanvasList:get_pages()
    return self._pages
end

-- 获取图页数量
function CanvasList:get_page_count()
    return #self._pages
end

-- 更新图页数据（保存画布状态到当前图页）
function CanvasList:update_page_data(index, widgets_data)
    if index >= 1 and index <= #self._pages then
        self._pages[index].widgets = widgets_data
        print("[图页列表] 更新图页数据: " .. self._pages[index].name)
    end
end

-- 获取图页数据
function CanvasList:get_page_data(index)
    if index >= 1 and index <= #self._pages then
        return self._pages[index]
    end
    return nil
end

-- 重命名图页
function CanvasList:rename_page(index, new_name)
    if index >= 1 and index <= #self._pages then
        local page = self._pages[index]
        page.name = new_name
        local item = self._page_items[page.id]
        if item and item.label then
            item.label:set_text(new_name)
        end
        print("[图页列表] 重命名图页: " .. new_name)
        self:_emit("page_renamed", page, index)
    end
end

-- 更新图页属性
function CanvasList:update_page_property(index, prop_name, prop_value)
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
        
        print("[图页列表] 更新图页属性: " .. prop_name .. " = " .. tostring(prop_value))
        self:_emit("page_property_changed", page, index, prop_name, prop_value)
    end
end

-- 获取图页属性元数据
function CanvasList:get_page_meta()
    return CanvasList.__page_meta
end

-- 标题栏按下事件
function CanvasList:_on_title_pressed()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    self._drag_state.is_dragging = false
    self._drag_state.start_x = self.props.x
    self._drag_state.start_y = self.props.y
    self._drag_state.start_mouse_x = mouse_x
    self._drag_state.start_mouse_y = mouse_y
end

-- 标题栏拖动事件
function CanvasList:_on_title_pressing()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    local delta_x = mouse_x - self._drag_state.start_mouse_x
    local delta_y = mouse_y - self._drag_state.start_mouse_y
    
    if not self._drag_state.is_dragging then
        if math.abs(delta_x) > 3 or math.abs(delta_y) > 3 then
            self._drag_state.is_dragging = true
        else
            return
        end
    end
    
    local new_x = self._drag_state.start_x + delta_x
    local new_y = self._drag_state.start_y + delta_y
    
    new_x = math.max(0, new_x)
    new_y = math.max(0, new_y)
    
    self.props.x = new_x
    self.props.y = new_y
    self.container:set_pos(math.floor(new_x), math.floor(new_y))
end

-- 标题栏释放事件
function CanvasList:_on_title_released()
    if self._drag_state.is_dragging then
        self:_emit("position_changed", self.props.x, self.props.y)
    end
    self._drag_state.is_dragging = false
end

-- 事件订阅
function CanvasList:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function CanvasList:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[图页列表] 事件回调错误:", err)
            end
        end
    end
end

-- 折叠/展开
function CanvasList:toggle_collapse()
    self.props.collapsed = not self.props.collapsed
    self:_apply_collapsed_state()
    self:_emit("collapse_changed", self.props.collapsed)
end

-- 应用折叠状态
function CanvasList:_apply_collapsed_state()
    if self.props.collapsed then
        self.toolbar:add_flag(lv.OBJ_FLAG_HIDDEN)
        self.content:add_flag(lv.OBJ_FLAG_HIDDEN)
        self.container:set_height(self.props.title_height)
        self.collapse_label:set_text("+")
    else
        self.toolbar:remove_flag(lv.OBJ_FLAG_HIDDEN)
        self.content:remove_flag(lv.OBJ_FLAG_HIDDEN)
        self.container:set_height(self.props.title_height + self._content_height)
        self.collapse_label:set_text("-")
    end
end

-- 折叠
function CanvasList:collapse()
    if not self.props.collapsed then
        self:toggle_collapse()
    end
end

-- 展开
function CanvasList:expand()
    if self.props.collapsed then
        self:toggle_collapse()
    end
end

-- 是否折叠
function CanvasList:is_collapsed()
    return self.props.collapsed
end

-- 显示图页列表
function CanvasList:show()
    self.props.visible = true
    self.container:remove_flag(lv.OBJ_FLAG_HIDDEN)
    self:_emit("visibility_changed", true)
    print("[图页列表] 显示")
end

-- 隐藏图页列表
function CanvasList:hide()
    self.props.visible = false
    self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
    self:_emit("visibility_changed", false)
    print("[图页列表] 隐藏")
end

-- 切换显示/隐藏
function CanvasList:toggle()
    if self.props.visible then
        self:hide()
    else
        self:show()
    end
end

-- 是否可见
function CanvasList:is_visible()
    return self.props.visible
end

-- 设置位置
function CanvasList:set_pos(x, y)
    self.props.x = x
    self.props.y = y
    self.container:set_pos(x, y)
end

-- 获取位置
function CanvasList:get_pos()
    return self.props.x, self.props.y
end

-- 获取容器
function CanvasList:get_container()
    return self.container
end

return CanvasList