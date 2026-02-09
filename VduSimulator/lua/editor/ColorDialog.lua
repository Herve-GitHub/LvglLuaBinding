-- ColorDialog.lua
-- 颜色选择对话框：用于在属性编辑中选择颜色
-- 注意：移除了遮罩层以避免程序卡住
local lv = require("lvgl")

local ColorDialog = {}
ColorDialog.__index = ColorDialog

ColorDialog.__widget_meta = {
    id = "color_dialog",
    name = "颜色选择对话框",
    description = "用于选择颜色的对话框（非模态）",
    schema_version = "1.0",
    version = "1.0",
}

-- 构造函数
function ColorDialog.new(parent, props)
    props = props or {}
    local self = setmetatable({}, ColorDialog)
    
    -- 属性
    self.props = {
        x = props.x or 400,
        y = props.y or 150,
        width = props.width or 320,
        height = props.height or 380,
        title_height = props.title_height or 28,
        bg_color = props.bg_color or 0x2D2D2D,
        title_bg_color = props.title_bg_color or 0x3D3D3D,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
        initial_color = props.initial_color or 0x007ACC,
    }
    
    -- 保存父元素引用
    self._parent = parent
    
    -- 当前选中的颜色 (RGB 分量)
    self._red = 0
    self._green = 122
    self._blue = 204
    
    -- 解析初始颜色
    self:_parse_color(self.props.initial_color)
    
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
    
    -- 不使用遮罩层（会导致程序卡住）
    self.overlay = nil
    
    -- 创建主容器（对话框窗口）
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_bg_opa(255, 0)
    self.container:set_style_radius(6, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(self.props.border_color, 0)
    self.container:set_style_shadow_width(12, 0)
    self.container:set_style_shadow_color(0x000000, 0)
    self.container:set_style_shadow_opa(150, 0)
    self.container:set_style_text_color(self.props.text_color, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.container:clear_layout()
    
    -- 创建标题栏
    self:_create_title_bar()
    
    -- 创建内容区域
    self:_create_content_area()
    
    -- 创建按钮区域
    self:_create_button_area()
    
    return self
end

-- 解析颜色值
function ColorDialog:_parse_color(color)
    if type(color) == "number" then
        self._red = math.floor(color / 65536) % 256
        self._green = math.floor(color / 256) % 256
        self._blue = color % 256
    elseif type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then
        local hex = tonumber(color:sub(2), 16)
        self._red = math.floor(hex / 65536) % 256
        self._green = math.floor(hex / 256) % 256
        self._blue = hex % 256
    end
end

-- 获取当前颜色值（数字格式）
function ColorDialog:_get_color_value()
    return self._red * 65536 + self._green * 256 + self._blue
end

-- 获取当前颜色值（十六进制字符串格式）
function ColorDialog:_get_color_hex()
    return string.format("#%02X%02X%02X", self._red, self._green, self._blue)
end

-- 创建标题栏
function ColorDialog:_create_title_bar()
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
    
    -- 标题文本
    self.title_label = lv.label_create(self.title_bar)
    self.title_label:set_text("选择颜色")
    self.title_label:set_style_text_color(self.props.text_color, 0)
    self.title_label:align(lv.ALIGN_LEFT_MID, 10, 0)
    
    -- 关闭按钮 (X)
    self.close_btn = lv.obj_create(self.title_bar)
    self.close_btn:set_size(20, 20)
    self.close_btn:align(lv.ALIGN_RIGHT_MID, -4, 0)
    self.close_btn:set_style_bg_color(0x555555, 0)
    self.close_btn:set_style_radius(3, 0)
    self.close_btn:set_style_border_width(0, 0)
    self.close_btn:set_style_pad_all(0, 0)
    self.close_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local close_label = lv.label_create(self.close_btn)
    close_label:set_text("X")
    close_label:set_style_text_color(self.props.text_color, 0)
    close_label:center()
    
    -- 关闭按钮事件
    self.close_btn:add_event_cb(function(e)
        this:cancel()
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
function ColorDialog:_create_content_area()
    local this = self
    local content_y = self.props.title_height + 10
    
    self.content = lv.obj_create(self.container)
    self.content:set_pos(10, content_y)
    self.content:set_size(self.props.width - 20, self.props.height - self.props.title_height - 60)
    self.content:set_style_bg_opa(0, 0)
    self.content:set_style_border_width(0, 0)
    self.content:set_style_text_color(self.props.text_color, 0)
    self.content:set_style_pad_all(0, 0)
    self.content:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.content:clear_layout()
    
    local y_pos = 0
    
    -- 颜色预览区域
    local preview_label = lv.label_create(self.content)
    preview_label:set_text("颜色预览:")
    preview_label:set_style_text_color(self.props.text_color, 0)
    preview_label:set_pos(0, y_pos)
    y_pos = y_pos + 20
    
    -- 预览框容器（包含新颜色和原颜色）
    local preview_container = lv.obj_create(self.content)
    preview_container:set_pos(0, y_pos)
    preview_container:set_size(self.props.width - 20, 60)
    preview_container:set_style_bg_opa(0, 0)
    preview_container:set_style_border_width(0, 0)
    preview_container:set_style_pad_all(0, 0)
    preview_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    preview_container:clear_layout()
    
    -- 新颜色预览
    local new_label = lv.label_create(preview_container)
    new_label:set_text("新")
    new_label:set_style_text_color(0xAAAAAA, 0)
    new_label:set_pos(0, 0)
    
    self.preview_new = lv.obj_create(preview_container)
    self.preview_new:set_pos(0, 18)
    self.preview_new:set_size(130, 40)
    self.preview_new:set_style_bg_color(self:_get_color_value(), 0)
    self.preview_new:set_style_border_width(1, 0)
    self.preview_new:set_style_border_color(0x555555, 0)
    self.preview_new:set_style_radius(4, 0)
    self.preview_new:set_style_pad_all(0, 0)
    self.preview_new:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 原颜色预览
    local old_label = lv.label_create(preview_container)
    old_label:set_text("原")
    old_label:set_style_text_color(0xAAAAAA, 0)
    old_label:set_pos(150, 0)
    
    self.preview_old = lv.obj_create(preview_container)
    self.preview_old:set_pos(150, 18)
    self.preview_old:set_size(130, 40)
    self.preview_old:set_style_bg_color(self.props.initial_color, 0)
    self.preview_old:set_style_border_width(1, 0)
    self.preview_old:set_style_border_color(0x555555, 0)
    self.preview_old:set_style_radius(4, 0)
    self.preview_old:set_style_pad_all(0, 0)
    self.preview_old:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    y_pos = y_pos + 70
    
    -- RGB 滑块
    self:_create_color_slider("R", "red", 0xFF0000, y_pos)
    y_pos = y_pos + 50
    
    self:_create_color_slider("G", "green", 0x00FF00, y_pos)
    y_pos = y_pos + 50
    
    self:_create_color_slider("B", "blue", 0x0000FF, y_pos)
    y_pos = y_pos + 50
    
    -- 十六进制颜色值显示
    local hex_label = lv.label_create(self.content)
    hex_label:set_text("HEX:")
    hex_label:set_style_text_color(self.props.text_color, 0)
    hex_label:set_pos(0, y_pos + 5)
    
    self.hex_input = lv.textarea_create(self.content)
    self.hex_input:set_pos(40, y_pos)
    self.hex_input:set_size(100, 28)
    self.hex_input:set_style_bg_color(0x1E1E1E, 0)
    self.hex_input:set_style_border_width(1, 0)
    self.hex_input:set_style_border_color(0x555555, 0)
    self.hex_input:set_style_text_color(0xFFFFFF, 0)
    self.hex_input:set_style_radius(3, 0)
    self.hex_input:set_style_pad_all(4, 0)
    self.hex_input:set_one_line(true)
    self.hex_input:set_text(self:_get_color_hex())
    self.hex_input:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- HEX 输入变更事件
    self.hex_input:add_event_cb(function(e)
        local hex_text = this.hex_input:get_text()
        if hex_text:match("^#%x%x%x%x%x%x$") then
            this:_parse_color(hex_text)
            this:_update_sliders()
            this:_update_preview()
        end
    end, lv.EVENT_VALUE_CHANGED, nil)
    
    -- RGB 数值显示
    self.rgb_label = lv.label_create(self.content)
    self.rgb_label:set_text(string.format("RGB(%d, %d, %d)", self._red, self._green, self._blue))
    self.rgb_label:set_style_text_color(0xAAAAAA, 0)
    self.rgb_label:set_pos(150, y_pos + 5)
end

-- 创建颜色滑块
function ColorDialog:_create_color_slider(label_text, color_name, indicator_color, y_pos)
    local this = self
    
    -- 标签
    local label = lv.label_create(self.content)
    label:set_text(label_text .. ":")
    label:set_style_text_color(self.props.text_color, 0)
    label:set_pos(0, y_pos + 8)
    
    -- 滑块
    local slider = lv.slider_create(self.content)
    slider:set_pos(25, y_pos + 5)
    slider:set_size(200, 20)
    slider:set_range(0, 255)
    
    -- 设置滑块样式
    slider:set_style_bg_color(0x404040, 0)  -- 轨道背景
    slider:set_style_bg_color(indicator_color, lv.PART_INDICATOR)  -- 指示器颜色
    slider:set_style_bg_color(0xFFFFFF, lv.PART_KNOB)  -- 滑块颜色
    slider:set_style_radius(5, 0)
    slider:set_style_radius(5, lv.PART_INDICATOR)
    slider:set_style_radius(10, lv.PART_KNOB)
    
    -- 设置初始值
    local initial_value = 0
    if color_name == "red" then
        initial_value = self._red
    elseif color_name == "green" then
        initial_value = self._green
    elseif color_name == "blue" then
        initial_value = self._blue
    end
    slider:set_value(initial_value, lv.ANIM_OFF)
    
    -- 数值显示
    local value_label = lv.label_create(self.content)
    value_label:set_text(tostring(initial_value))
    value_label:set_style_text_color(self.props.text_color, 0)
    value_label:set_pos(235, y_pos + 8)
    value_label:set_width(35)
    
    -- 保存引用
    if color_name == "red" then
        self.slider_red = slider
        self.label_red = value_label
    elseif color_name == "green" then
        self.slider_green = slider
        self.label_green = value_label
    elseif color_name == "blue" then
        self.slider_blue = slider
        self.label_blue = value_label
    end
    
    -- 滑块值变更事件
    slider:add_event_cb(function(e)
        local value = slider:get_value()
        value_label:set_text(tostring(value))
        
        if color_name == "red" then
            this._red = value
        elseif color_name == "green" then
            this._green = value
        elseif color_name == "blue" then
            this._blue = value
        end
        
        this:_update_preview()
        this:_update_hex_display()
    end, lv.EVENT_VALUE_CHANGED, nil)
end

-- 更新预览
function ColorDialog:_update_preview()
    local color = self:_get_color_value()
    self.preview_new:set_style_bg_color(color, 0)
    self.rgb_label:set_text(string.format("RGB(%d, %d, %d)", self._red, self._green, self._blue))
end

-- 更新十六进制显示
function ColorDialog:_update_hex_display()
    self.hex_input:set_text(self:_get_color_hex())
end

-- 更新滑块
function ColorDialog:_update_sliders()
    if self.slider_red then
        self.slider_red:set_value(self._red, lv.ANIM_OFF)
        self.label_red:set_text(tostring(self._red))
    end
    if self.slider_green then
        self.slider_green:set_value(self._green, lv.ANIM_OFF)
        self.label_green:set_text(tostring(self._green))
    end
    if self.slider_blue then
        self.slider_blue:set_value(self._blue, lv.ANIM_OFF)
        self.label_blue:set_text(tostring(self._blue))
    end
end

-- 创建按钮区域
function ColorDialog:_create_button_area()
    local this = self
    local btn_y = self.props.height - 45
    local btn_width = 80
    local btn_height = 32
    
    -- 确定按钮
    self.ok_btn = lv.btn_create(self.container)
    self.ok_btn:set_pos(self.props.width - btn_width * 2 - 30, btn_y)
    self.ok_btn:set_size(btn_width, btn_height)
    self.ok_btn:set_style_bg_color(0x007ACC, 0)
    self.ok_btn:set_style_radius(4, 0)
    
    local ok_label = lv.label_create(self.ok_btn)
    ok_label:set_text("确定")
    ok_label:set_style_text_color(0xFFFFFF, 0)
    ok_label:center()
    
    self.ok_btn:add_event_cb(function(e)
        this:confirm()
    end, lv.EVENT_CLICKED, nil)
    
    -- 取消按钮
    self.cancel_btn = lv.btn_create(self.container)
    self.cancel_btn:set_pos(self.props.width - btn_width - 15, btn_y)
    self.cancel_btn:set_size(btn_width, btn_height)
    self.cancel_btn:set_style_bg_color(0x555555, 0)
    self.cancel_btn:set_style_radius(4, 0)
    
    local cancel_label = lv.label_create(self.cancel_btn)
    cancel_label:set_text("取消")
    cancel_label:set_style_text_color(0xFFFFFF, 0)
    cancel_label:center()
    
    self.cancel_btn:add_event_cb(function(e)
        this:cancel()
    end, lv.EVENT_CLICKED, nil)
end

-- 标题栏按下事件
function ColorDialog:_on_title_pressed()
    local mouse_x = lv.get_mouse_x()
    local mouse_y = lv.get_mouse_y()
    
    self._drag_state.is_dragging = false
    self._drag_state.start_x = self.props.x
    self._drag_state.start_y = self.props.y
    self._drag_state.start_mouse_x = mouse_x
    self._drag_state.start_mouse_y = mouse_y
end

-- 标题栏拖动事件
function ColorDialog:_on_title_pressing()
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
function ColorDialog:_on_title_released()
    self._drag_state.is_dragging = false
end

-- 事件订阅
function ColorDialog:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function ColorDialog:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[颜色对话框] 事件回调错误:", err)
            end
        end
    end
end

-- 确认选择
function ColorDialog:confirm()
    local color_value = self:_get_color_value()
    local color_hex = self:_get_color_hex()
    
    print("[颜色对话框] 确认选择颜色: " .. color_hex)
    
    self:_emit("color_selected", color_value, color_hex)
    self:close()
end

-- 取消选择
function ColorDialog:cancel()
    print("[颜色对话框] 取消选择")
    
    self:_emit("cancelled")
    self:close()
end

-- 关闭对话框
function ColorDialog:close()
    if self.overlay then
        self.overlay:delete()
        self.overlay = nil
    end
    if self.container then
        self.container:delete()
        self.container = nil
    end
    
    self:_emit("closed")
end

-- 设置颜色
function ColorDialog:set_color(color)
    self:_parse_color(color)
    self:_update_sliders()
    self:_update_preview()
    self:_update_hex_display()
end

-- 获取当前选中的颜色
function ColorDialog:get_color()
    return self:_get_color_value()
end

-- 获取当前选中的颜色（十六进制字符串）
function ColorDialog:get_color_hex()
    return self:_get_color_hex()
end

-- 静态方法：显示颜色选择对话框
function ColorDialog.show(parent, initial_color, callback)
    local dialog = ColorDialog.new(parent, {
        initial_color = initial_color or 0x007ACC,
    })
    
    if callback then
        dialog:on("color_selected", function(self, color_value, color_hex)
            callback(color_value, color_hex)
        end)
    end
    
    return dialog
end

return ColorDialog
