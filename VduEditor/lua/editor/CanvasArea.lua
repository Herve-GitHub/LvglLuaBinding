-- CanvasArea.lua
-- 画布区域：组态软件的设计画布，支持拖拽移动控件、框选多选、剪切复制粘贴撤销重做
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
        width = props.width or 1024,
        height = props.height or 600,
        bg_color = props.bg_color or 0x1E1E1E,
        grid_color = props.grid_color or 0x2A2A2A,
        grid_size = props.grid_size or 20,
        show_grid = props.show_grid ~= false,
        snap_to_grid = props.snap_to_grid ~= false,
        page_width = props.page_width or 1024,
        page_height = props.page_height or 600,
        show_page_border = props.show_page_border ~= false,
        page_border_color = props.page_border_color or 0xF00000,--0xFF6600
        page_border_width = props.page_border_width or 2,
    }
    
    -- 放置的控件列表
    self._widgets = {}
    
    -- 选中的控件（支持多选）
    self._selected_widgets = {}
    self._selection_boxes = {}
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
        was_selecting = false,
        start_x = 0,
        start_y = 0,
        current_x = 0,
        current_y = 0,
        marquee_box = nil,
    }
    
    -- 剪贴板
    self._clipboard = nil

    -- 撤销/重做栈
    self._undo_stack = {}
    self._redo_stack = {}
    self._is_in_undo_redo = false
    
    -- 图页边界线对象
    self._page_border = nil
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 创建画布容器
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x+10, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_radius(0, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(0x3C3C3C, 0)
    self.container:set_style_pad_all(0, 0)
    --self.container:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.container:clear_layout()
    
    -- 绘制网格
    if self.props.show_grid then
        self:_draw_grid()
    end
    
    -- 绘制图页边界线
    if self.props.show_page_border then
        self:_create_page_border()
    end
    
    -- 画布事件
    local this = self
    
    self.container:add_event_cb(function(e)
        this:_on_canvas_pressed()
    end, lv.EVENT_PRESSED, nil)
    
    self.container:add_event_cb(function(e)
        this:_on_canvas_pressing()
    end, lv.EVENT_PRESSING, nil)
    
    self.container:add_event_cb(function(e)
        this:_on_canvas_released()
    end, lv.EVENT_RELEASED, nil)
    
    self.container:add_event_cb(function(e)
        if this._marquee_state.was_selecting then
            this._marquee_state.was_selecting = false
            return
        end
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

-- 保存快照（用于撤销）
function CanvasArea:_save_state()
    if self._is_in_undo_redo then return end
    local snapshot = self:export_state()
    table.insert(self._undo_stack, snapshot)
    self._redo_stack = {}
end

-- 撤销
function CanvasArea:undo()
    if #self._undo_stack == 0 then return end
    local current = self:export_state()
    table.insert(self._redo_stack, current)
    
    self._is_in_undo_redo = true
    local prev = table.remove(self._undo_stack)
    self:import_state(prev)
    self._is_in_undo_redo = false
    print("[画布] 撤销")
end

-- 重做
function CanvasArea:redo()
    if #self._redo_stack == 0 then return end
    local current = self:export_state()
    table.insert(self._undo_stack, current)
    
    self._is_in_undo_redo = true
    local next_state = table.remove(self._redo_stack)
    self:import_state(next_state)
    self._is_in_undo_redo = false
    print("[画布] 重做")
end

-- 复制
function CanvasArea:copy_selected()
    local selected = self:get_selected_widgets()
    if #selected == 0 then return end
    
    local data = {}
    for _, w in ipairs(selected) do
        table.insert(data, {
            module = w.module,
            module_path = w.module_path,
            props = w.instance:to_state()
        })
    end
    self._clipboard = data
    print("[画布] 复制 " .. #data .. " 个控件")
end

-- 剪切
function CanvasArea:cut_selected()
    local selected = self:get_selected_widgets()
    if #selected == 0 then return end

    self:_save_state()
    self:copy_selected()
    self:delete_selected()
    print("[画布] 剪切")
end

-- 粘贴
function CanvasArea:paste()
    if not self._clipboard or #self._clipboard == 0 then return end

    self:_save_state()
    local offset = 20
    local new_widgets = {}

    for _, item in ipairs(self._clipboard) do
        local mod = item.module
        local path = item.module_path
        local props = item.props

        if not mod then goto continue end

        local p = {}
        for k, v in pairs(props) do
            p[k] = v
        end

        p.x = (p.x or 100) + offset
        p.y = (p.y or 100) + offset
        p.x = math.max(0, math.min(p.x, self.props.width - 50))
        p.y = math.max(0, math.min(p.y, self.props.height - 50))

        local entry = self:add_widget(mod, p)
        if entry then
            entry.module_path = path
            table.insert(new_widgets, entry)
        end

        ::continue::
    end

    self:deselect_all()
    for _, w in ipairs(new_widgets) do
        table.insert(self._selected_widgets, w)
        self:_create_selection_box(w)
    end

    if #new_widgets == 1 then
        self:_emit("widget_selected", new_widgets[1])
    else
        self:_emit("widgets_selected", new_widgets)
    end

    print("[画布] 粘贴 " .. #new_widgets .. " 个控件")
end

-- 导入状态（撤销/重做用）
function CanvasArea:import_state(state)
    if not state or not state.widgets then return end
    self:clear()

    for _, wdata in ipairs(state.widgets) do
        local mod = nil
        local path = nil

        for _, v in pairs(package.loaded) do
            if type(v) == "table" and v.__widget_meta and v.__widget_meta.id == wdata.type then
                mod = v
                break
            end
        end

        if not mod then goto continue end

        local entry = self:add_widget(mod, wdata.props)
        if entry then
            entry.module_path = path
            entry.id = wdata.id
        end

        ::continue::
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
        self._marquee_state.was_selecting = true
        
        local x1 = math.min(self._marquee_state.start_x, self._marquee_state.current_x)
        local y1 = math.min(self._marquee_state.start_y, self._marquee_state.current_y)
        local x2 = math.max(self._marquee_state.start_x, self._marquee_state.current_x)
        local y2 = math.max(self._marquee_state.start_y, self._marquee_state.current_y)
        
        local selected = {}
        for _, widget_entry in ipairs(self._widgets) do
            local instance = widget_entry.instance
            local main_obj = instance.btn or instance.container or instance.obj or instance.chart
            if main_obj then
                local wx = main_obj:get_x()
                local wy = main_obj:get_y()
                local ww = main_obj:get_width()
                local wh = main_obj:get_height()
                
                if wx < x2 and wx + ww > x1 and wy < y2 and wy + wh > y1 then
                    table.insert(selected, widget_entry)
                end
            end
        end
        
        self:_delete_marquee_box()
        
        if #selected > 0 then
            self._selected_widgets = {}
            for i = #self._selection_boxes, 1, -1 do
                local box = self._selection_boxes[i]
                if box then
                    pcall(function() box:delete() end)
                end
            end
            self._selection_boxes = {}
            self._box_widget_map = {}
            
            self._selected_widgets = selected
            
            for _, w in ipairs(selected) do
                self:_create_selection_box(w)
            end
            
            if #selected == 1 then
                self:_emit("widget_selected", selected[1])
            else
                self:_emit("widgets_selected", selected)
            end
        end
    else
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
    if props.auto_update == nil then
        if widget_module.__widget_meta and widget_module.__widget_meta.properties then
            for _, p in ipairs(widget_module.__widget_meta.properties) do
                if p.name == "auto_update" then
                    props.auto_update = p.default
                    break
                end
            end
        end
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
    self:_save_state()
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
        self:_save_state()
        self:_emit("widgets_moved", self._selected_widgets)
        self._multi_drag_state.is_dragging = false
        self._multi_drag_state.start_positions = {}
        return
    end
    
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
        self:_save_state()
        self:_emit("widget_moved", widget_entry)
    end
    
    self._drag_state.is_dragging = false
    self._drag_state.widget_entry = nil
end

-- ========== 图页边界线管理 ==========
function CanvasArea:_create_page_border()
    if self._page_border then
        self:_delete_page_border()
    end
    
    local border_width = self.props.page_border_width
    local page_w = self.props.page_width
    local page_h = self.props.page_height
    
    self._page_border = { lines = {} }
    
    local top_line = lv.obj_create(self.container)
    top_line:set_pos(0, 0)
    top_line:set_size(page_w, border_width)
    top_line:set_style_bg_color(self.props.page_border_color, 0)
    top_line:set_style_bg_opa(180, 0)
    top_line:set_style_radius(0, 0)
    top_line:set_style_border_width(0, 0)
    top_line:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    top_line:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    table.insert(self._page_border.lines, top_line)
    
    local bottom_line = lv.obj_create(self.container)
    bottom_line:set_pos(0, page_h - border_width)
    bottom_line:set_size(page_w, border_width)
    bottom_line:set_style_bg_color(self.props.page_border_color, 0)
    bottom_line:set_style_bg_opa(180, 0)
    bottom_line:set_style_radius(0, 0)
    bottom_line:set_style_border_width(0, 0)
    bottom_line:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    bottom_line:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    table.insert(self._page_border.lines, bottom_line)
    
    local left_line = lv.obj_create(self.container)
    left_line:set_pos(0, border_width)
    left_line:set_size(border_width, page_h - 2 * border_width)
    left_line:set_style_bg_color(self.props.page_border_color, 0)
    left_line:set_style_bg_opa(180, 0)
    left_line:set_style_radius(0, 0)
    left_line:set_style_border_width(0, 0)
    left_line:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    left_line:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    table.insert(self._page_border.lines, left_line)
    
    local right_line = lv.obj_create(self.container)
    right_line:set_pos(page_w - border_width, border_width)
    right_line:set_size(border_width, page_h - 2 * border_width)
    right_line:set_style_bg_color(self.props.page_border_color, 0)
    right_line:set_style_bg_opa(180, 0)
    right_line:set_style_radius(0, 0)
    right_line:set_style_border_width(0, 0)
    right_line:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    right_line:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    table.insert(self._page_border.lines, right_line)
end

function CanvasArea:_delete_page_border()
    if self._page_border and self._page_border.lines then
        for _, line in ipairs(self._page_border.lines) do
            if line then
                pcall(function() line:delete() end)
            end
        end
    end
    self._page_border = nil
end

function CanvasArea:update_page_border(page_width, page_height)
    self.props.page_width = page_width or self.props.page_width
    self.props.page_height = page_height or self.props.page_height
    
    if self.props.show_page_border then
        self:_create_page_border()
    end
end

function CanvasArea:set_show_page_border(show)
    self.props.show_page_border = show
    if show then
        self:_create_page_border()
    else
        self:_delete_page_border()
    end
end

function CanvasArea:is_page_border_visible()
    return self.props.show_page_border
end

function CanvasArea:toggle_page_border()
    self:set_show_page_border(not self.props.show_page_border)
    return self.props.show_page_border
end

function CanvasArea:set_page_border_color(color)
    self.props.page_border_color = color
    if self._page_border and self._page_border.lines then
        for _, line in ipairs(self._page_border.lines) do
            if line then
                line:set_style_bg_color(color, 0)
            end
        end
    end
end

function CanvasArea:get_page_size()
    return self.props.page_width, self.props.page_height
end

function CanvasArea:set_page_size(width, height)
    self:update_page_border(width, height)
end

-- ========== 选择管理（多选） ==========
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

function CanvasArea:select_widgets(widget_entries)
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
    self._box_widget_map = {}
    
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
    
    local x, y, w, h
    
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
    { x = -handle_size/2, y = -handle_size/2, dir = "tl" },
    { x = w - handle_size/2, y = -handle_size/2, dir = "tr" },
    { x = -handle_size/2, y = h - handle_size/2, dir = "bl" },
    { x = w - handle_size/2, y = h - handle_size/2, dir = "br" },
}

for _, pos in ipairs(handle_positions) do
    local handle = lv.obj_create(box)
    handle:set_pos(pos.x, pos.y)
    handle:set_size(handle_size, handle_size)
    handle:set_style_bg_color(0x007ACC, 0)
    handle:set_style_radius(1, 0)
    handle:set_style_border_width(0, 0)
    handle:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    handle:add_flag(lv.OBJ_FLAG_CLICKABLE)

    local dir = pos.dir
    local widget = widget_entry
    local this = self

    handle:add_event_cb(function(e)
        this:_on_resize_handle_pressed(dir, widget)
    end, lv.EVENT_PRESSED, nil)

    handle:add_event_cb(function(e)
        this:_on_resize_handle_pressing()
    end, lv.EVENT_PRESSING, nil)

    handle:add_event_cb(function(e)
        this:_on_resize_handle_released()
    end, lv.EVENT_RELEASED, nil)
end
    
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
function CanvasArea:_get_selection_bounds()
    if #self._selected_widgets == 0 then
        return nil
    end
    
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge
    
    for _, widget_entry in ipairs(self._selected_widgets) do
        local instance = widget_entry.instance
        local main_obj = instance.btn or instance.container or instance.obj or instance.chart
        if main_obj then
            local x = main_obj:get_x()
            local y = main_obj:get_y()
            local w = main_obj:get_width()
            local h = main_obj:get_height()
            
            min_x = math.min(min_x, x)
            min_y = math.min(min_y, y)
            max_x = math.max(max_x, x + w)
            max_y = math.max(max_y, y + h)
        end
    end
    
    return {
        x = min_x,
        y = min_y,
        width = max_x - min_x,
        height = max_y - min_y,
        right = max_x,
        bottom = max_y
    }
end

function CanvasArea:align_selected(align_type)
    if #self._selected_widgets == 0 then return end
    
    if #self._selected_widgets == 1 then
        local widget_entry = self._selected_widgets[1]
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
    else
        local bounds = self:_get_selection_bounds()
        if not bounds then return end
        
        for _, widget_entry in ipairs(self._selected_widgets) do
            local instance = widget_entry.instance
            local main_obj = instance.btn or instance.container or instance.obj or instance.chart
            if main_obj then
                local w = main_obj:get_width()
                local h = main_obj:get_height()
                local cur_x = main_obj:get_x()
                local cur_y = main_obj:get_y()
                local new_x, new_y = cur_x, cur_y
                
                if align_type == "center_h" then
                    local group_center_x = bounds.x + bounds.width / 2
                    new_x = math.floor(group_center_x - w / 2)
                elseif align_type == "center_v" then
                    local group_center_y = bounds.y + bounds.height / 2
                    new_y = math.floor(group_center_y - h / 2)
                elseif align_type == "left" then
                    new_x = bounds.x
                elseif align_type == "right" then
                    new_x = bounds.right - w
                elseif align_type == "top" then
                    new_y = bounds.y
                elseif align_type == "bottom" then
                    new_y = bounds.bottom - h
                end
                
                new_x = math.max(0, math.min(new_x, self.props.width - w))
                new_y = math.max(0, math.min(new_y, self.props.height - h))
                
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
    end
    
    self:_update_all_selection_boxes()
    self:_emit("widgets_moved", self._selected_widgets)
end







-- ==============================
-- 控件缩放功能 —— 最终无错版
-- ==============================
function CanvasArea:_on_resize_handle_pressed(dir, widget)
    if not widget then return end

    local obj = widget.instance.btn or widget.instance.container or widget.instance.obj or widget.instance.chart
    if not obj then return end

    self._resize_state = {
        is_resizing = true,
        dir = dir,
        widget = widget,
        obj = obj,
        start_x = obj:get_x(),
        start_y = obj:get_y(),
        start_w = obj:get_width(),
        start_h = obj:get_height(),
        start_mx = lv.get_mouse_x(),
        start_my = lv.get_mouse_y(),
    }
end

function CanvasArea:_on_resize_handle_pressing()
    if not self._resize_state or not self._resize_state.is_resizing then return end
    local s = self._resize_state

    local dx = lv.get_mouse_x() - s.start_mx
    local dy = lv.get_mouse_y() - s.start_my

    local new_w, new_h = s.start_w, s.start_h
    local new_x, new_y = s.start_x, s.start_y

    if s.dir == "br" then
        new_w = s.start_w + dx
        new_h = s.start_h + dy
    elseif s.dir == "bl" then
        new_w = s.start_w - dx
        new_h = s.start_h + dy
        new_x = s.start_x + dx
    elseif s.dir == "tr" then
        new_w = s.start_w + dx
        new_h = s.start_h - dy
        new_y = s.start_y + dy
    elseif s.dir == "tl" then
        new_w = s.start_w - dx
        new_h = s.start_h - dy
        new_x = s.start_x + dx
        new_y = s.start_y + dy
    end

    new_w = math.max(30, new_w)
    new_h = math.max(30, new_h)
    new_x = math.max(0, new_x)
    new_y = math.max(0, new_y)
    if new_x + new_w > self.props.width then new_w = self.props.width - new_x end
    if new_y + new_h > self.props.height then new_h = self.props.height - new_y end

    s.obj:set_pos(math.floor(new_x), math.floor(new_y))
    s.obj:set_size(math.floor(new_w), math.floor(new_h))

    local widget = s.widget
    if widget.instance.props then
        widget.instance.props.x = new_x
        widget.instance.props.y = new_y
        widget.instance.props.width = new_w
        widget.instance.props.height = new_h
    end
    widget.props.x = new_x
    widget.props.y = new_y
    widget.props.width = new_w
    widget.props.height = new_h

    self:_update_all_selection_boxes()
end

function CanvasArea:_on_resize_handle_released()
    if not self._resize_state or not self._resize_state.is_resizing then
        self._resize_state = nil
        return
    end

    local s = self._resize_state
    local widget = s.widget
    local obj = s.obj

    local fx, fy = self:snap_position(obj:get_x(), obj:get_y())
    local fw, fh = self:snap_position(obj:get_width(), obj:get_height())
    fw = math.max(30, fw)
    fh = math.max(30, fh)

    obj:set_pos(fx, fy)
    obj:set_size(fw, fh)

    if widget.instance.props then
        widget.instance.props.x = fx
        widget.instance.props.y = fy
        widget.instance.props.width = fw
        widget.instance.props.height = fh
    end
    widget.props.x = fx
    widget.props.y = fy
    widget.props.width = fw
    widget.props.height = fh

    self:_update_all_selection_boxes()
    self:_save_state()
    self:_emit("widget_resized", widget)
    self._resize_state = nil
end








return CanvasArea