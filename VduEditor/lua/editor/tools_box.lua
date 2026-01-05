-- tools_box.lua
-- 浮动工具箱：悬浮在画布上方，支持拖拽移动和折叠
local lv = require("lvgl")

local ToolsBox = {}
ToolsBox.__index = ToolsBox

ToolsBox.__widget_meta = {
    id = "tools_box",
    name = "Tools Box",
    description = "浮动工具箱，悬浮在画布上方，支持拖拽和折叠",
    schema_version = "1.0",
    version = "1.0",
}

-- 默认工具列表
ToolsBox.DEFAULT_TOOLS = {
    { id = "button", name = "按钮", icon = "BTN", module_path = "widgets.button" },
    { id = "valve", name = "阀门", icon = "VLV", module_path = "widgets.valve" },
    { id = "trend_chart", name = "趋势图", icon = "CHT", module_path = "widgets.trend_chart" },
    { id = "status_bar", name = "状态栏", icon = "STA", module_path = "widgets.status_bar" },
}

-- 尝试获取中文字体
local function get_cjk_font()
    -- 优先使用 simsun 16 中文字体
    if lv.font_simsun_16_cjk then
        return lv.font_simsun_16_cjk
    elseif lv.FONT_SIMSUN_16_CJK then
        return lv.FONT_SIMSUN_16_CJK
    end
    -- 备选 simsun 14
    if lv.font_simsun_14_cjk then
        return lv.font_simsun_14_cjk
    elseif lv.FONT_SIMSUN_14_CJK then
        return lv.FONT_SIMSUN_14_CJK
    end
    return nil
end

-- 构造函数
function ToolsBox.new(parent, props)
    props = props or {}
    local self = setmetatable({}, ToolsBox)
    
    -- 属性
    self.props = {
        x = props.x or 10,
        y = props.y or 50,
        width = props.width or 130,
        title_height = props.title_height or 28,
        item_height = props.item_height or 32,
        bg_color = props.bg_color or 0x2D2D2D,
        title_bg_color = props.title_bg_color or 0x3D3D3D,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
        visible = props.visible ~= false,  -- 默认显示
        collapsed = props.collapsed or false,  -- 折叠状态
    }
    
    -- 保存父元素引用（屏幕）
    self._parent = parent
    
    -- 工具列表
    self._tools = props.tools or ToolsBox.DEFAULT_TOOLS
    
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
    
    -- 计算高度
    local content_height = #self._tools * self.props.item_height
    self._content_height = content_height + 8
    self._total_height = self.props.title_height + self._content_height
    
    -- 创建主容器（浮动窗口样式）
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self._total_height)
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
    
    -- 创建工具项
    self:_create_tool_items()
    
    -- 如果初始状态是折叠的，则折叠
    if self.props.collapsed then
        self:_apply_collapsed_state()
    end
    
    return self
end

-- 创建标题栏
function ToolsBox:_create_title_bar()
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
    self.title_label:set_text("工具箱")
    self.title_label:set_style_text_color(self.props.text_color, 0)
    -- 设置中文字体
    local cjk_font = get_cjk_font()
    if cjk_font then
        self.title_label:set_style_text_font(cjk_font, 0)
    end
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
function ToolsBox:_create_content_area()
    self.content = lv.obj_create(self.container)
    self.content:set_pos(0, self.props.title_height)
    self.content:set_size(self.props.width, self._content_height)
    self.content:set_style_bg_opa(0, 0)
    self.content:set_style_border_width(0, 0)
    self.content:set_style_text_color(self.props.text_color, 0)
    self.content:set_style_pad_all(0, 0)
    self.content:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.content:clear_layout()
end

-- 标题栏按下事件
function ToolsBox:_on_title_pressed()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    self._drag_state.is_dragging = false
    self._drag_state.start_x = self.props.x
    self._drag_state.start_y = self.props.y
    self._drag_state.start_mouse_x = mouse_x
    self._drag_state.start_mouse_y = mouse_y
end

-- 标题栏拖动事件
function ToolsBox:_on_title_pressing()
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
function ToolsBox:_on_title_released()
    if self._drag_state.is_dragging then
        self:_emit("position_changed", self.props.x, self.props.y)
    end
    self._drag_state.is_dragging = false
end

-- 事件订阅
function ToolsBox:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function ToolsBox:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[工具箱] 事件回调错误:", err)
            end
        end
    end
end

-- 创建工具项
function ToolsBox:_create_tool_items()
    local y_offset = 4
    
    for i, tool in ipairs(self._tools) do
        self:_create_tool_item(tool, y_offset)
        y_offset = y_offset + self.props.item_height
    end
end

-- 创建单个工具项
function ToolsBox:_create_tool_item(tool, y_offset)
    local item_width = self.props.width - 8
    local item_height = self.props.item_height - 2
    
    local item_container = lv.obj_create(self.content)
    item_container:set_pos(4, y_offset)
    item_container:set_size(item_width, item_height)
    item_container:set_style_bg_color(0x404040, 0)
    item_container:set_style_radius(4, 0)
    item_container:set_style_border_width(0, 0)
    item_container:set_style_text_color(self.props.text_color, 0)
    item_container:set_style_pad_all(0, 0)
    item_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    item_container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    item_container:clear_layout()
    
    -- 图标区域
    local icon_box = lv.obj_create(item_container)
    icon_box:set_pos(2, 2)
    icon_box:set_size(36, 26)
    icon_box:set_style_bg_color(0x505050, 0)
    icon_box:set_style_radius(4, 0)
    icon_box:set_style_border_width(0, 0)
    icon_box:set_style_text_color(self.props.text_color, 0)
    icon_box:set_style_pad_all(0, 0)
    icon_box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    icon_box:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    
    local icon_label = lv.label_create(icon_box)
    icon_label:set_text(tool.icon or "?")
    --icon_label:set_long_mode(lv.LABEL_LONG_CLIP)  -- 防止自动换行
    icon_label:set_style_text_color(self.props.text_color, 0)
    icon_label:center()
    
    -- 名称（使用中文字体）
    local name_label = lv.label_create(item_container)
    name_label:set_text(tool.name)
    --name_label:set_long_mode(lv.LABEL_LONG_CLIP)  -- 防止自动换行
    name_label:set_style_text_color(self.props.text_color, 0)
    -- 设置中文字体
    local cjk_font = get_cjk_font()
    if cjk_font then
        name_label:set_style_text_font(cjk_font, 0)
    end
    name_label:align(lv.ALIGN_LEFT_MID, 42, 0)
    
    -- 工具项拖拽事件
    local this = self
    local tool_ref = tool
    
    -- 按下事件 - 开始拖拽准备
    item_container:add_event_cb(function(e)
        this:_on_tool_pressed(tool_ref)
    end, lv.EVENT_PRESSED, nil)
    
    -- 拖动事件 - 拖拽中
    item_container:add_event_cb(function(e)
        this:_on_tool_pressing(tool_ref)
    end, lv.EVENT_PRESSING, nil)
    
    -- 释放事件 - 完成拖拽
    item_container:add_event_cb(function(e)
        this:_on_tool_released(tool_ref)
    end, lv.EVENT_RELEASED, nil)
    
    return item_container
end

-- 工具项按下
function ToolsBox:_on_tool_pressed(tool)
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    -- 加载模块
    local module = self:_load_module(tool.module_path)
    if not module then return end
    
    self._tool_drag_state.is_dragging = false
    self._tool_drag_state.tool = tool
    self._tool_drag_state.module = module
    self._tool_drag_state.start_mouse_x = mouse_x
    self._tool_drag_state.start_mouse_y = mouse_y
    self._tool_drag_state.ghost = nil
    
    print("[工具箱] 按下工具: " .. tool.name)
end

-- 工具项拖动
function ToolsBox:_on_tool_pressing(tool)
    if self._tool_drag_state.tool ~= tool then return end
    
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    local delta_x = mouse_x - self._tool_drag_state.start_mouse_x
    local delta_y = mouse_y - self._tool_drag_state.start_mouse_y
    
    -- 检查是否开始拖拽
    if not self._tool_drag_state.is_dragging then
        if math.abs(delta_x) > 5 or math.abs(delta_y) > 5 then
            self._tool_drag_state.is_dragging = true
            -- 创建拖拽幽灵预览
            self:_create_drag_ghost(tool, mouse_x, mouse_y)
            print("[工具箱] 开始拖拽工具: " .. tool.name)
        else
            return
        end
    end
    
    -- 移动幽灵预览
    if self._tool_drag_state.ghost then
        self._tool_drag_state.ghost:set_pos(mouse_x - 30, mouse_y - 15)
    end
end

-- 工具项释放
function ToolsBox:_on_tool_released(tool)
    if self._tool_drag_state.tool ~= tool then return end
    
    local was_dragging = self._tool_drag_state.is_dragging
    local module = self._tool_drag_state.module
    
    -- 删除幽灵预览
    if self._tool_drag_state.ghost then
        self._tool_drag_state.ghost:delete()
        self._tool_drag_state.ghost = nil
    end
    
    if was_dragging and module then
        -- 获取鼠标释放位置
        local mouse_x = lv.get_mouse_x()
        local mouse_y = lv.get_mouse_y()
        
        print("[工具箱] 释放工具: " .. tool.name .. " @ (" .. mouse_x .. ", " .. mouse_y .. ")")
        
        -- 触发工具拖放事件，传递屏幕坐标
        self:_emit("tool_drag_drop", tool, module, mouse_x, mouse_y)
    end
    
    -- 重置状态
    self._tool_drag_state.is_dragging = false
    self._tool_drag_state.tool = nil
    self._tool_drag_state.module = nil
end

-- 创建拖拽幽灵预览
function ToolsBox:_create_drag_ghost(tool, x, y)
    -- 在屏幕上创建一个跟随鼠标的预览
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
function ToolsBox:_load_module(module_path)
    if self._loaded_modules[module_path] then
        return self._loaded_modules[module_path]
    end
    
    local ok, module = pcall(require, module_path)
    if ok then
        self._loaded_modules[module_path] = module
        print("[工具箱] 模块加载成功: " .. module_path)
        return module
    else
        print("[工具箱] 加载模块失败: " .. module_path .. " - " .. tostring(module))
        return nil
    end
end

-- 折叠/展开
function ToolsBox:toggle_collapse()
    self.props.collapsed = not self.props.collapsed
    self:_apply_collapsed_state()
    self:_emit("collapse_changed", self.props.collapsed)
end

-- 应用折叠状态
function ToolsBox:_apply_collapsed_state()
    if self.props.collapsed then
        -- 折叠：只显示标题栏
        self.content:add_flag(lv.OBJ_FLAG_HIDDEN)
        self.container:set_height(self.props.title_height)
        self.collapse_label:set_text("+")
    else
        -- 展开：显示全部
        self.content:remove_flag(lv.OBJ_FLAG_HIDDEN)
        self.container:set_height(self._total_height)
        self.collapse_label:set_text("-")
    end
end

-- 折叠
function ToolsBox:collapse()
    if not self.props.collapsed then
        self:toggle_collapse()
    end
end

-- 展开
function ToolsBox:expand()
    if self.props.collapsed then
        self:toggle_collapse()
    end
end

-- 是否折叠
function ToolsBox:is_collapsed()
    return self.props.collapsed
end

-- 显示工具箱
function ToolsBox:show()
    self.props.visible = true
    self.container:remove_flag(lv.OBJ_FLAG_HIDDEN)
    self:_emit("visibility_changed", true)
    print("[工具箱] 显示")
end

-- 隐藏工具箱
function ToolsBox:hide()
    self.props.visible = false
    self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
    self:_emit("visibility_changed", false)
    print("[工具箱] 隐藏")
end

-- 切换显示/隐藏
function ToolsBox:toggle()
    if self.props.visible then
        self:hide()
    else
        self:show()
    end
end

-- 是否可见
function ToolsBox:is_visible()
    return self.props.visible
end

-- 设置位置
function ToolsBox:set_pos(x, y)
    self.props.x = x
    self.props.y = y
    self.container:set_pos(x, y)
end

-- 获取位置
function ToolsBox:get_pos()
    return self.props.x, self.props.y
end

-- 获取容器
function ToolsBox:get_container()
    return self.container
end

-- 添加自定义工具
function ToolsBox:add_tool(tool_def)
    table.insert(self._tools, tool_def)
end

-- 获取所有工具
function ToolsBox:get_tools()
    return self._tools
end

-- 检查是否正在拖拽工具
function ToolsBox:is_dragging_tool()
    return self._tool_drag_state.is_dragging
end

-- 获取当前拖拽的工具
function ToolsBox:get_dragging_tool()
    if self._tool_drag_state.is_dragging then
        return self._tool_drag_state.tool, self._tool_drag_state.module
    end
    return nil, nil
end

return ToolsBox
