-- CanvasArea.lua
-- 画布区域：组态软件的设计画布，支持拖拽移动控件、框选多选
local lv = require("lvgl")

local CanvasArea = {}
CanvasArea.__index = CanvasArea

CanvasArea.__widget_meta = {
    id = "canvas_area",
    name = "Canvas Area",
    description = "组态编辑器画布，支持拖拽放置和移动控件、框选多选",
    schema_version = "1.0",
    version = "1.0",
}

-- 构造函数
function CanvasArea.new(parent, props)
    props = props or {}
    local self = setmetatable({}, CanvasArea)
    
    -- 属性
    self.props = {
        x = props.x or 0,
        y = props.y or 40,
        width = props.width or 800,
        height = props.height or 600,
        bg_color = props.bg_color or 0x1E1E1E,
        grid_color = props.grid_color or 0x2A2A2A,
        grid_size = props.grid_size or 20,
        show_grid = props.show_grid ~= false,
        snap_to_grid = props.snap_to_grid ~= false,
    }
    
    -- 放置的控件列表
    self._widgets = {}
    
    -- 选中的控件（支持多选）
    self._selected_widgets = {}
    self._selection_boxes = {}
    
    -- 选择框ID映射（使用独立的表来存储映射关系）
    self._box_widget_map = {}
    
    -- 单个控件拖拽状态
    self._drag_state = {
        is_dragging = false,
        widget_entry = nil,
        start_widget_x = 0,
        start_widget_y = 0,
        start_mouse_x = 0,
        start_mouse_y = 0,
        last_x = 0,
        last_y = 0,
    }
    
    -- 多选拖拽状态
    self._multi_drag_state = {
        is_dragging = false,
        start_positions = {},
        start_mouse_x = 0,
        start_mouse_y = 0,
    }
    
    -- 框选状态
    self._marquee_state = {
        is_selecting = false,
        was_selecting = false,  -- 新增：记录是否刚刚完成框选
        start_x = 0,
        start_y = 0,
        current_x = 0,
        current_y = 0,
        marquee_box = nil,
    }
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 创建画布容器
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_radius(0, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(0x3C3C3C, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.container:clear_layout()
    
    -- 绘制网格
    if self.props.show_grid then
        self:_draw_grid()
    end
    
    -- 画布事件
    local this = self
    
    -- 按下事件 - 开始框选
    self.container:add_event_cb(function(e)
        this:_on_canvas_pressed()
    end, lv.EVENT_PRESSED, nil)
    
    -- 拖动事件 - 更新框选区域
    self.container:add_event_cb(function(e)
        this:_on_canvas_pressing()
    end, lv.EVENT_PRESSING, nil)
    
    -- 释放事件 - 完成框选
    self.container:add_event_cb(function(e)
        this:_on_canvas_released()
    end, lv.EVENT_RELEASED, nil)
    
    -- 点击事件 - 取消选中（非框选时）
    self.container:add_event_cb(function(e)
        -- 如果刚刚完成框选，不要取消选中
        if this._marquee_state.was_selecting then
            this._marquee_state.was_selecting = false
            return
        end
        -- 只有当不是拖拽操作时才取消选中
        if not this._drag_state.is_dragging then
            this:deselect_all()
        end
    end, lv.EVENT_CLICKED, nil)
    
    return self
end

-- 事件订阅方法
function CanvasArea:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function CanvasArea:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[CanvasArea] event callback error:", err)
            end
        end
    end
end

-- ========== 画布框选事件 ==========

function CanvasArea:_on_canvas_pressed()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    local canvas_x = mouse_x - self.props.x
    local canvas_y = mouse_y - self.props.y
    
    self._marquee_state.is_selecting = false
    self._marquee_state.start_x = canvas_x
    self._marquee_state.start_y = canvas_y
    self._marquee_state.current_x = canvas_x
    self._marquee_state.current_y = canvas_y
end

function CanvasArea:_on_canvas_pressing()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    local canvas_x = mouse_x - self.props.x
    local canvas_y = mouse_y - self.props.y
    
    local delta_x = canvas_x - self._marquee_state.start_x
    local delta_y = canvas_y - self._marquee_state.start_y
    
    if not self._marquee_state.is_selecting then
        if math.abs(delta_x) > 5 or math.abs(delta_y) > 5 then
            self._marquee_state.is_selecting = true
            self:deselect_all()
            self:_create_marquee_box()
        else
            return
        end
    end
    
    self._marquee_state.current_x = canvas_x
    self._marquee_state.current_y = canvas_y
    self:_update_marquee_box()
end

function CanvasArea:_on_canvas_released()
    if self._marquee_state.is_selecting then
        -- 标记刚刚完成框选
        self._marquee_state.was_selecting = true
        
        -- 获取框选区域
        local x1 = math.min(self._marquee_state.start_x, self._marquee_state.current_x)
        local y1 = math.min(self._marquee_state.start_y, self._marquee_state.current_y)
        local x2 = math.max(self._marquee_state.start_x, self._marquee_state.current_x)
        local y2 = math.max(self._marquee_state.start_y, self._marquee_state.current_y)
        
        print("[画布] 框选区域: (" .. x1 .. "," .. y1 .. ") - (" .. x2 .. "," .. y2 .. ")")
        print("[画布] 控件数量: " .. #self._widgets)
        
        -- 查找框选区域内的控件
        local selected = {}
        for _, widget_entry in ipairs(self._widgets) do
            local instance = widget_entry.instance
            local main_obj = instance.btn or instance.container or instance.obj or instance.chart
            if main_obj then
                local wx = main_obj:get_x()
                local wy = main_obj:get_y()
                local ww = main_obj:get_width()
                local wh = main_obj:get_height()
                
                print("[画布] 检查控件: " .. widget_entry.id .. " 位置: (" .. wx .. "," .. wy .. ") 尺寸: (" .. ww .. "x" .. wh .. ")")
                
                -- 检查是否相交
                if wx < x2 and wx + ww > x1 and wy < y2 and wy + wh > y1 then
                    print("[画布] 控件在框选区域内: " .. widget_entry.id)
                    table.insert(selected, widget_entry)
                end
            end
        end
        
        -- 删除框选矩形
        self:_delete_marquee_box()
        
        -- 选中找到的控件
        if #selected > 0 then
            print("[画布] 框选完成，选中 " .. #selected .. " 个控件")
            -- 清除旧的选择状态
            self._selected_widgets = {}
            for i = #self._selection_boxes, 1, -1 do
                local box = self._selection_boxes[i]
                if box then
                    pcall(function() box:delete() end)
                end
            end
            self._selection_boxes = {}
            self._box_widget_map = {}
            
            -- 设置新的选中状态
            self._selected_widgets = selected
            
            for _, w in ipairs(selected) do
                self:_create_selection_box(w)
            end
            
            if #selected == 1 then
                self:_emit("widget_selected", selected[1])
            else
                self:_emit("widgets_selected", selected)
            end
        else
            print("[画布] 框选完成，未选中任何控件")
        end
    else
        -- 不是框选，清除标志
        self._marquee_state.was_selecting = false
    end
    self._marquee_state.is_selecting = false
end

function CanvasArea:_create_marquee_box()
    if self._marquee_state.marquee_box then
        self._marquee_state.marquee_box:delete()
    end
    
    local box = lv.obj_create(self.container)
    box:set_style_bg_color(0x007ACC, 0)
    box:set_style_bg_opa(50, 0)
    box:set_style_border_width(1, 0)
    box:set_style_border_color(0x007ACC, 0)
    box:set_style_radius(0, 0)
    box:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    self._marquee_state.marquee_box = box
end

function CanvasArea:_update_marquee_box()
    if not self._marquee_state.marquee_box then return end
    
    local x1 = math.min(self._marquee_state.start_x, self._marquee_state.current_x)
    local y1 = math.min(self._marquee_state.start_y, self._marquee_state.current_y)
    local x2 = math.max(self._marquee_state.start_x, self._marquee_state.current_x)
    local y2 = math.max(self._marquee_state.start_y, self._marquee_state.current_y)
    
    x1 = math.max(0, x1)
    y1 = math.max(0, y1)
    x2 = math.min(self.props.width, x2)
    y2 = math.min(self.props.height, y2)
    
    self._marquee_state.marquee_box:set_pos(math.floor(x1), math.floor(y1))
    self._marquee_state.marquee_box:set_size(math.floor(x2 - x1), math.floor(y2 - y1))
end

function CanvasArea:_delete_marquee_box()
    if self._marquee_state.marquee_box then
        self._marquee_state.marquee_box:delete()
        self._marquee_state.marquee_box = nil
    end
end

-- ========== 网格绘制 ==========

function CanvasArea:_draw_grid()
    local grid_size = self.props.grid_size
    local width = self.props.width
    local height = self.props.height
    
    for x = grid_size, width - 1, grid_size do
        local line = lv.obj_create(self.container)
        line:set_pos(x, 0)
        line:set_size(1, height)
        line:set_style_bg_color(self.props.grid_color, 0)
        line:set_style_bg_opa(128, 0)
        line:set_style_radius(0, 0)
        line:set_style_border_width(0, 0)
        line:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    end
    
    for y = grid_size, height - 1, grid_size do
        local line = lv.obj_create(self.container)
        line:set_pos(0, y)
        line:set_size(width, 1)
        line:set_style_bg_color(self.props.grid_color, 0)
        line:set_style_bg_opa(128, 0)
        line:set_style_radius(0, 0)
        line:set_style_border_width(0, 0)
        line:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    end
end

function CanvasArea:snap_position(x, y)
    if not self.props.snap_to_grid then
        return math.floor(x), math.floor(y)
    end
    local grid = self.props.grid_size
    x = x or 0
    y = y or 0
    local snapped_x = math.floor((x + grid / 2) / grid) * grid
    local snapped_y = math.floor((y + grid / 2) / grid) * grid
    snapped_x = math.max(0, snapped_x)
    snapped_y = math.max(0, snapped_y)
    return snapped_x, snapped_y
end

function CanvasArea:_disable_widget_events(obj)
    obj:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    obj:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    obj:remove_flag(lv.OBJ_FLAG_CHECKABLE)
    obj:remove_flag(lv.OBJ_FLAG_SCROLL_ON_FOCUS)
    
    local child_count = obj:get_child_count()
    for i = 0, child_count - 1 do
        local child = obj:get_child(i)
        if child then
            self:_disable_widget_events(child)
        end
    end
end

-- ========== 控件管理 ==========

function CanvasArea:add_widget(widget_module, props)
    props = props or {}
    
    local x, y = self:snap_position(props.x or 100, props.y or 100)
    props.x = x
    props.y = y
    props.design_mode = true
    -- 不再强制设置 auto_update 为 false，保留用户配置的值或使用默认值
    -- 设计模式下 trend_chart 和其他控件的 start() 函数会自行检查 design_mode
    if props.auto_update == nil then
        -- 如果没有明确指定，使用控件的默认值（大多数控件默认为 true）
        -- 获取默认值
        if widget_module.__widget_meta and widget_module.__widget_meta.properties then
            for _, p in ipairs(widget_module.__widget_meta.properties) do
                if p.name == "auto_update" then
                    props.auto_update = p.default
                    break
                end
            end
        end
        -- 如果仍然没有，默认为 true
        if props.auto_update == nil then
            props.auto_update = true
        end
    end
    
    local widget_instance = widget_module.new(self.container, props)
    local main_obj = widget_instance.btn or widget_instance.container or widget_instance.obj or widget_instance.chart
    
    if widget_instance.stop then
        widget_instance:stop()
    end
    
    if main_obj then
        self:_disable_widget_events(main_obj)
    end
    
    local widget_entry = {
        id = self:_generate_id(),
        module = widget_module,
        instance = widget_instance,
        props = props,
    }
    
    table.insert(self._widgets, widget_entry)
    self:_setup_widget_drag_events(widget_entry)
    self:_emit("widget_added", widget_entry)
    
    return widget_entry
end

function CanvasArea:_setup_widget_drag_events(widget_entry)
    local instance = widget_entry.instance
    local main_obj = instance.btn or instance.container or instance.obj or instance.chart
    if not main_obj then return end
    
    local this = self
    main_obj:add_flag(lv.OBJ_FLAG_CLICKABLE)
    
    main_obj:add_event_cb(function(e)
        this:_on_widget_pressed(widget_entry)
    end, lv.EVENT_PRESSED, nil)
    
    main_obj:add_event_cb(function(e)
        this:_on_widget_pressing(widget_entry)
    end, lv.EVENT_PRESSING, nil)
    
    main_obj:add_event_cb(function(e)
        this:_on_widget_released(widget_entry)
    end, lv.EVENT_RELEASED, nil)
    
    main_obj:add_event_cb(function(e)
        if not this._drag_state.is_dragging and not this._multi_drag_state.is_dragging then
            this:_on_widget_clicked(widget_entry)
        end
    end, lv.EVENT_CLICKED, nil)
end

function CanvasArea:_on_widget_clicked(widget_entry)
    if self:_is_widget_selected(widget_entry) then
        return
    end
    self:select_widget(widget_entry)
end

function CanvasArea:_on_widget_pressed(widget_entry)
    local instance = widget_entry.instance
    local main_obj = instance.btn or instance.container or instance.obj or instance.chart
    if not main_obj then return end
    
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    local widget_x = main_obj:get_x()
    local widget_y = main_obj:get_y()
    
    if self:_is_widget_selected(widget_entry) and #self._selected_widgets > 1 then
        self._multi_drag_state.is_dragging = false
        self._multi_drag_state.start_mouse_x = mouse_x
        self._multi_drag_state.start_mouse_y = mouse_y
        self._multi_drag_state.start_positions = {}
        
        for _, w in ipairs(self._selected_widgets) do
            local inst = w.instance
            local obj = inst.btn or inst.container or inst.obj or inst.chart
            if obj then
                self._multi_drag_state.start_positions[w.id] = {
                    x = obj:get_x(),
                    y = obj:get_y()
                }
            end
        end
    else
        self._drag_state.is_dragging = false
        self._drag_state.widget_entry = widget_entry
        self._drag_state.start_widget_x = widget_x
        self._drag_state.start_widget_y = widget_y
        self._drag_state.start_mouse_x = mouse_x
        self._drag_state.start_mouse_y = mouse_y
        self._drag_state.last_x = widget_x
        self._drag_state.last_y = widget_y
    end
end

function CanvasArea:_on_widget_pressing(widget_entry)
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    -- 多选拖拽
    if self:_is_widget_selected(widget_entry) and #self._selected_widgets > 1 then
        local delta_x = mouse_x - self._multi_drag_state.start_mouse_x
        local delta_y = mouse_y - self._multi_drag_state.start_mouse_y
        
        if not self._multi_drag_state.is_dragging then
            if math.abs(delta_x) > 3 or math.abs(delta_y) > 3 then
                self._multi_drag_state.is_dragging = true
            else
                return
            end
        end
        
        for _, w in ipairs(self._selected_widgets) do
            local inst = w.instance
            local obj = inst.btn or inst.container or inst.obj or inst.chart
            local start_pos = self._multi_drag_state.start_positions[w.id]
            if obj and start_pos then
                local new_x = start_pos.x + delta_x
                local new_y = start_pos.y + delta_y
                local ow = obj:get_width()
                local oh = obj:get_height()
                new_x = math.max(0, math.min(new_x, self.props.width - ow))
                new_y = math.max(0, math.min(new_y, self.props.height - oh))
                obj:set_pos(math.floor(new_x), math.floor(new_y))
            end
        end
        
        self:_update_all_selection_boxes()
        return
    end
    
    -- 单个拖拽
    if self._drag_state.widget_entry ~= widget_entry then return end
    
    local instance = widget_entry.instance
    local main_obj = instance.btn or instance.container or instance.obj or instance.chart
    if not main_obj then return end
    
    local delta_x = mouse_x - self._drag_state.start_mouse_x
    local delta_y = mouse_y - self._drag_state.start_mouse_y
    
    if not self._drag_state.is_dragging then
        if math.abs(delta_x) > 3 or math.abs(delta_y) > 3 then
            self._drag_state.is_dragging = true
            self:select_widget(widget_entry)
        else
            return
        end
    end
    
    local new_x = self._drag_state.start_widget_x + delta_x
    local new_y = self._drag_state.start_widget_y + delta_y
    local w = main_obj:get_width()
    local h = main_obj:get_height()
    new_x = math.max(0, math.min(new_x, self.props.width - w))
    new_y = math.max(0, math.min(new_y, self.props.height - h))
    new_x = math.floor(new_x)
    new_y = math.floor(new_y)
    
    self._drag_state.last_x = new_x
    self._drag_state.last_y = new_y
    main_obj:set_pos(new_x, new_y)
    self:_update_all_selection_boxes()
end

function CanvasArea:_on_widget_released(widget_entry)
    -- 多选拖拽结束
    if self._multi_drag_state.is_dragging then
        for _, w in ipairs(self._selected_widgets) do
            local inst = w.instance
            local obj = inst.btn or inst.container or inst.obj or inst.chart
            if obj then
                local final_x, final_y = self:snap_position(obj:get_x(), obj:get_y())
                local ow = obj:get_width()
                local oh = obj:get_height()
                final_x = math.max(0, math.min(final_x, self.props.width - ow))
                final_y = math.max(0, math.min(final_y, self.props.height - oh))
                obj:set_pos(final_x, final_y)
                if inst.props then
                    inst.props.x = final_x
                    inst.props.y = final_y
                end
                w.props.x = final_x
                w.props.y = final_y
            end
        end
        
        self:_update_all_selection_boxes()
        self:_emit("widgets_moved", self._selected_widgets)
        self._multi_drag_state.is_dragging = false
        self._multi_drag_state.start_positions = {}
        return
    end
    
    -- 单个拖拽结束
    if self._drag_state.widget_entry ~= widget_entry then return end
    
    local was_dragging = self._drag_state.is_dragging
    local instance = widget_entry.instance
    local main_obj = instance.btn or instance.container or instance.obj or instance.chart
    
    if was_dragging and main_obj then
        local snapped_x, snapped_y = self:snap_position(self._drag_state.last_x, self._drag_state.last_y)
        local w = main_obj:get_width()
        local h = main_obj:get_height()
        snapped_x = math.max(0, math.min(snapped_x, self.props.width - w))
        snapped_y = math.max(0, math.min(snapped_y, self.props.height - h))
        main_obj:set_pos(snapped_x, snapped_y)
        
        if instance.props then
            instance.props.x = snapped_x
            instance.props.y = snapped_y
        end
        widget_entry.props.x = snapped_x
        widget_entry.props.y = snapped_y
        
        self:_update_all_selection_boxes()
        self:_emit("widget_moved", widget_entry)
    end
    
    self._drag_state.is_dragging = false
    self._drag_state.widget_entry = nil
end

-- ========== 选中管理（多选） ==========

function CanvasArea:_is_widget_selected(widget_entry)
    for _, w in ipairs(self._selected_widgets) do
        if w.id == widget_entry.id then
            return true
        end
    end
    return false
end

function CanvasArea:select_widget(widget_entry)
    self:deselect_all()
    self._selected_widgets = { widget_entry }
    self:_create_selection_box(widget_entry)
    self:_emit("widget_selected", widget_entry)
end

function CanvasArea:select_widgets(widget_entries
)
    self:deselect_all()
    self._selected_widgets = widget_entries
    
    for _, w in ipairs(widget_entries) do
        self:_create_selection_box(w)
    end
    
    if #widget_entries == 1 then
        self:_emit("widget_selected", widget_entries[1])
    else
        self:_emit("widgets_selected", widget_entries)
    end
end

function CanvasArea:deselect_all()
    -- 先清空映射表
    self._box_widget_map = {}
    
    -- 删除所有选择框
    for i = #self._selection_boxes, 1, -1 do
        local box = self._selection_boxes[i]
        if box then
            pcall(function() box:delete() end)
        end
    end
    self._selection_boxes = {}
    
    local prev_count = #self._selected_widgets
    self._selected_widgets = {}
    
    if prev_count > 0 then
        self:_emit("widget_deselected", {})
    end
end

function CanvasArea:deselect()
    self:deselect_all()
end

function CanvasArea:_create_selection_box(widget_entry)
    local instance = widget_entry.instance
    local main_obj = instance.btn or instance.container or instance.obj or instance.chart
    if not main_obj then return end
    
    -- 始终优先使用 props 中的值（在控件创建时已正确设置）
    -- 这样可以避免 LVGL 位置更新延迟导致获取到错误的值
    local x, y, w, h
    
    -- 首先尝试从 widget_entry.props 获取位置
    if widget_entry.props and widget_entry.props.x ~= nil then
        x = widget_entry.props.x
    elseif instance.props and instance.props.x ~= nil then
        x = instance.props.x
    else
        x = main_obj:get_x()
    end
    
    if widget_entry.props and widget_entry.props.y ~= nil then
        y = widget_entry.props.y
    elseif instance.props and instance.props.y ~= nil then
        y = instance.props.y
    else
        y = main_obj:get_y()
    end
    
    -- 获取尺寸（优先从 props，因为 main_obj 可能还未更新）
    if widget_entry.props and widget_entry.props.width ~= nil then
        w = widget_entry.props.width
    elseif instance.props and instance.props.width ~= nil then
        w = instance.props.width
    else
        w = main_obj:get_width()
    end
    
    if widget_entry.props and widget_entry.props.height ~= nil then
        h = widget_entry.props.height
    elseif instance.props and instance.props.height ~= nil then
        h = instance.props.height
    else
        h = main_obj:get_height()
    end
    
    print("[选中框] 创建选中框: x=" .. tostring(x) .. ", y=" .. tostring(y) .. ", w=" .. tostring(w) .. ", h=" .. tostring(h))
    
    local box = lv.obj_create(self.container)
    box:set_pos(x - 2, y - 2)
    box:set_size(w + 4, h + 4)
    box:set_style_bg_opa(0, 0)
    box:set_style_border_width(2, 0)
    box:set_style_border_color(0x007ACC, 0)
    box:set_style_radius(2, 0)
    box:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local handle_size = 8
    local handle_positions = {
        { x = -handle_size/2, y = -handle_size/2 },
        { x = w - handle_size/2, y = -handle_size/2 },
        { x = -handle_size/2, y = h - handle_size/2 },
        { x = w - handle_size/2, y = h - handle_size/2 },
    }
    
    for _, pos in ipairs(handle_positions) do
        local handle = lv.obj_create(box)
        handle:set_pos(pos.x, pos.y)
        handle:set_size(handle_size, handle_size)
        handle:set_style_bg_color(0x007ACC, 0)
        handle:set_style_radius(1, 0)
        handle:set_style_border_width(0, 0)
        handle:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    end
    
    -- 使用独立的映射表来存储关联关系
    local box_index = #self._selection_boxes + 1
    table.insert(self._selection_boxes, box)
    self._box_widget_map[box_index] = widget_entry.id
end

function CanvasArea:_update_all_selection_boxes()
    for idx, box in ipairs(self._selection_boxes) do
        local widget_id = self._box_widget_map[idx]
        local widget_entry = nil
        
        for _, w in ipairs(self._selected_widgets) do
            if w.id == widget_id then
                widget_entry = w
                break
            end
        end
        
        if widget_entry and box then
            local instance = widget_entry.instance
            local main_obj = instance.btn or instance.container or instance.obj or instance.chart
            if main_obj then
                -- 拖动时使用 main_obj 的实时位置
                local x = main_obj:get_x()
                local y = main_obj:get_y()
                local w = main_obj:get_width()
                local h = main_obj:get_height()
                
                box:set_pos(x - 2, y - 2)
                box:set_size(w + 4, h + 4)
                
                local handle_size = 8
                local handle_positions = {
                    { x = -handle_size/2, y = -handle_size/2 },
                    { x = w - handle_size/2, y = -handle_size/2 },
                    { x = -handle_size/2, y = h - handle_size/2 },
                    { x = w - handle_size/2, y = h - handle_size/2 },
                }
                
                local child_count = box:get_child_count()
                for i = 0, child_count - 1 do
                    local handle = box:get_child(i)
                    if handle and handle_positions[i + 1] then
                        handle:set_pos(handle_positions[i + 1].x, handle_positions[i + 1].y)
                    end
                end
            end
        end
    end
end

function CanvasArea:_generate_id()
    return "widget_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- ========== 删除操作 ==========

function CanvasArea:delete_selected()
    if #self._selected_widgets == 0 then return end
    
    local deleted = {}
    
    for _, widget_entry in ipairs(self._selected_widgets) do
        local instance = widget_entry.instance
        local main_obj = instance.btn or instance.container or instance.obj or instance.chart
        if main_obj then
            main_obj:delete()
        end
        
        for i, w in ipairs(self._widgets) do
            if w.id == widget_entry.id then
                table.remove(self._widgets, i)
                break
            end
        end
        
        table.insert(deleted, widget_entry)
    end
    
    self:deselect_all()
    
    for _, w in ipairs(deleted) do
        self:_emit("widget_deleted", w)
    end
end

-- ========== 获取方法 ==========

function CanvasArea:get_widgets()
    return self._widgets
end

function CanvasArea:get_selected()
    if #self._selected_widgets == 1 then
        return self._selected_widgets[1]
    end
    return nil
end

function CanvasArea:get_selected_widgets()
    return self._selected_widgets
end

function CanvasArea:get_container()
    return self.container
end

-- ========== 导出/清空 ==========

function CanvasArea:export_state()
    local state = { widgets = {} }
    for _, w in ipairs(self._widgets) do
        local widget_state = {
            id = w.id,
            type = w.module.__widget_meta and w.module.__widget_meta.id or "unknown",
            props = w.instance:to_state()
        }
        table.insert(state.widgets, widget_state)
    end
    return state
end

function CanvasArea:clear()
    for _, w in ipairs(self._widgets) do
        local instance = w.instance
        local main_obj = instance.btn or instance.container or instance.obj or instance.chart
        if main_obj then main_obj:delete() end
    end
    self._widgets = {}
    self:deselect_all()
    self:_emit("canvas_cleared")
end

-- ========== 网格控制 ==========

function CanvasArea:toggle_grid()
    self.props.show_grid = not self.props.show_grid
    self:_refresh_grid()
    return self.props.show_grid
end

function CanvasArea:set_show_grid(show)
    if self.props.show_grid ~= show then
        self.props.show_grid = show
        self:_refresh_grid()
    end
end

function CanvasArea:is_grid_visible()
    return self.props.show_grid
end

function CanvasArea:toggle_snap_to_grid()
    self.props.snap_to_grid = not self.props.snap_to_grid
    return self.props.snap_to_grid
end

function CanvasArea:set_snap_to_grid(snap)
    self.props.snap_to_grid = snap
end

function CanvasArea:is_snap_to_grid()
    return self.props.snap_to_grid
end

function CanvasArea:_refresh_grid()
    local children_to_delete = {}
    local child_count = self.container:get_child_count()
    
    for i = 0, child_count - 1 do
        local child = self.container:get_child(i)
        if child then
            local w = child:get_width()
            local h = child:get_height()
            if (w == 1 or h == 1) and not child:has_flag(lv.OBJ_FLAG_CLICKABLE) then
                table.insert(children_to_delete, child)
            end
        end
    end
    
    for _, child in ipairs(children_to_delete) do
        child:delete()
    end
    
    if self.props.show_grid then
        self:_draw_grid()
    end
end

-- ========== 工具箱放置 ==========

function CanvasArea:handle_drop(widget_module, drop_x, drop_y)
    local canvas_x = math.max(0, math.min(drop_x, self.props.width - 50))
    local canvas_y = math.max(0, math.min(drop_y, self.props.height - 50))
    return self:add_widget(widget_module, { x = canvas_x, y = canvas_y })
end

-- ========== 对齐操作 ==========

function CanvasArea:align_selected(align_type)
    if #self._selected_widgets == 0 then return end
    
    for _, widget_entry in ipairs(self._selected_widgets) do
        local instance = widget_entry.instance
        local main_obj = instance.btn or instance.container or instance.obj or instance.chart
        if main_obj then
            local w = main_obj:get_width()
            local h = main_obj:get_height()
            local new_x, new_y = main_obj:get_x(), main_obj:get_y()
            
            if align_type == "center_h" then
                new_x = math.floor((self.props.width - w) / 2)
            elseif align_type == "center_v" then
                new_y = math.floor((self.props.height - h) / 2)
            elseif align_type == "left" then
                new_x = 0
            elseif align_type == "right" then
                new_x = self.props.width - w
            elseif align_type == "top" then
                new_y = 0
            elseif align_type == "bottom" then
                new_y = self.props.height - h
            end
            
            new_x, new_y = self:snap_position(new_x, new_y)
            main_obj:set_pos(new_x, new_y)
            
            if instance.props then
                instance.props.x = new_x
                instance.props.y = new_y
            end
            widget_entry.props.x = new_x
            widget_entry.props.y = new_y
        end
    end
    
    self:_update_all_selection_boxes()
    self:_emit("widgets_moved", self._selected_widgets)
end

return CanvasArea
