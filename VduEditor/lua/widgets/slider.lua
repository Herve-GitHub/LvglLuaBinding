-- slider.lua
-- 滑块控件，支持数值范围选择
local lv = require("lvgl")

local Slider = {}

Slider.__widget_meta = {
    id = "slider",
    name = "Slider",
    description = "滑块控件，支持数值范围选择",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        -- 实例名称（用于编译时变量命名）
        { name = "instance_name", type = "string", default = "", label = "实例名称",
          description = "用于编译时的变量名，留空则自动生成" },
        { name = "x", type = "number", default = 0, label = "X" },
        { name = "y", type = "number", default = 0, label = "Y" },
        { name = "width", type = "number", default = 150, label = "宽度" },
        { name = "height", type = "number", default = 20, label = "高度" },
        { name = "min_value", type = "number", default = 0, label = "最小值" },
        { name = "max_value", type = "number", default = 100, label = "最大值" },
        { name = "value", type = "number", default = 50, label = "当前值" },
        { name = "bg_color", type = "color", default = "#3C3C3C", label = "背景色" },
        { name = "indicator_color", type = "color", default = "#007ACC", label = "指示器颜色" },
        { name = "knob_color", type = "color", default = "#FFFFFF", label = "滑块颜色" },
        { name = "show_value", type = "boolean", default = true, label = "显示数值" },
        { name = "enabled", type = "boolean", default = true, label = "启用" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
        -- 事件处理代码属性
        { name = "on_changed_handler", type = "code", default = "", label = "值变化处理代码",
          event = "changed", description = "滑块值变化时执行的Lua代码" },
    },
    events = { "changed" },
}

-- 解析颜色值（支持 "#RRGGBB" 字符串或数字）
local function parse_color(c)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
        return tonumber(c:sub(2), 16)
    elseif type(c) == "number" then
        return c
    end
    return 0xFFFFFF
end

-- new(parent, state)
function Slider.new(parent, state)
    state = state or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(Slider.__widget_meta.properties) do
        if state[p.name] ~= nil then
            self.props[p.name] = state[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    -- 保存父元素引用
    self._parent = parent

    -- 事件监听器
    self._event_listeners = {}

    -- ========== 方法定义（必须在调用之前） ==========

    -- 触发事件
    function self._emit(self, event_name, ...)
        local listeners = self._event_listeners[event_name]
        if listeners then
            for _, cb in ipairs(listeners) do
                local ok, err = pcall(cb, self, ...)
                if not ok then
                    print("[Slider] callback error:", err)
                end
            end
        end
    end

    -- 更新数值标签
    function self._update_value_label(self)
        if self.value_label and self.props.show_value then
            self.value_label:set_text(tostring(self.props.value))
        end
    end

    -- ========== 创建 UI 元素 ==========

    -- 直接创建滑块作为主控件（container 指向 slider 本身）
    self.slider = lv.slider_create(parent)
    self.slider:set_size(self.props.width, self.props.height)
    self.slider:set_pos(self.props.x, self.props.y)
    self.slider:set_range(self.props.min_value, self.props.max_value)
    self.slider:set_value(self.props.value, lv.ANIM_OFF)
    
    -- container 指向 slider 本身，用于画布的拖拽和选择操作
    self.container = self.slider
    
    -- 设置滑块样式
    -- 背景（轨道）
    self.slider:set_style_bg_color(parse_color(self.props.bg_color), lv.PART_MAIN)
    self.slider:set_style_bg_opa(255, lv.PART_MAIN)
    self.slider:set_style_radius(5, lv.PART_MAIN)
    self.slider:set_style_border_width(0, lv.PART_MAIN)
    self.slider:set_style_pad_all(0, lv.PART_MAIN)
    self.slider:set_style_outline_width(0, lv.PART_MAIN)
    self.slider:set_style_shadow_width(0, lv.PART_MAIN)
    
    -- 指示器（已填充部分）
    self.slider:set_style_bg_color(parse_color(self.props.indicator_color), lv.PART_INDICATOR)
    self.slider:set_style_bg_opa(255, lv.PART_INDICATOR)
    self.slider:set_style_radius(5, lv.PART_INDICATOR)
    self.slider:set_style_border_width(0, lv.PART_INDICATOR)
    
    -- 滑块把手
    self.slider:set_style_bg_color(parse_color(self.props.knob_color), lv.PART_KNOB)
    self.slider:set_style_bg_opa(255, lv.PART_KNOB)
    self.slider:set_style_radius(10, lv.PART_KNOB)
    self.slider:set_style_pad_all(3, lv.PART_KNOB)
    self.slider:set_style_border_width(0, lv.PART_KNOB)
    self.slider:set_style_outline_width(0, lv.PART_KNOB)
    self.slider:set_style_shadow_width(0, lv.PART_KNOB)
    
    -- 聚焦状态样式（去掉聚焦时的额外边框/背景）
    self.slider:set_style_outline_width(0, lv.PART_MAIN + lv.STATE_FOCUSED)
    self.slider:set_style_outline_width(0, lv.PART_KNOB + lv.STATE_FOCUSED)
    self.slider:set_style_shadow_width(0, lv.PART_KNOB + lv.STATE_FOCUSED)

    -- 创建数值标签（在父容器上创建，位置跟随滑块）
    if self.props.show_value then
        self.value_label = lv.label_create(parent)
        self.value_label:set_text(tostring(self.props.value))
        self.value_label:set_style_text_color(0xCCCCCC, 0)
        -- 标签位置在滑块下方居中
        local label_x = self.props.x + math.floor(self.props.width / 2)
        self.value_label:set_pos(label_x, self.props.y + self.props.height + 2)
        self.value_label:set_style_text_align(lv.TEXT_ALIGN_CENTER, 0)
    else
        self.value_label = nil
    end

    -- 滑块值变化事件
    local this = self
    self.slider:add_event_cb(function(e)
        if not this.props.enabled then return end
        if this.props.design_mode then return end
        
        local new_value = this.slider:get_value()
        if new_value ~= this.props.value then
            this.props.value = new_value
            this:_update_value_label()
            this:_emit("changed", new_value)
        end
    end, lv.EVENT_VALUE_CHANGED, nil)

    -- 设计模式下禁用滑块交互
    if self.props.design_mode then
        self.slider:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    end

    -- ========== 其余方法定义 ==========

    -- 事件订阅
    function self.on(self, event_name, callback)
        if not self._event_listeners[event_name] then
            self._event_listeners[event_name] = {}
        end
        table.insert(self._event_listeners[event_name], callback)
    end

    -- 获取属性
    function self.get_property(self, name)
        return self.props[name]
    end

    -- 设置属性
    function self.set_property(self, name, value)
        self.props[name] = value

        if name == "x" or name == "y" then
            self.slider:set_pos(self.props.x, self.props.y)
            -- 更新数值标签位置
            if self.value_label then
                local label_x = self.props.x + math.floor(self.props.width / 2)
                self.value_label:set_pos(label_x, self.props.y + self.props.height + 2)
            end
        elseif name == "width" then
            self.slider:set_width(value)
            -- 更新数值标签位置
            if self.value_label then
                local label_x = self.props.x + math.floor(value / 2)
                self.value_label:set_pos(label_x, self.props.y + self.props.height + 2)
            end
        elseif name == "height" then
            self.slider:set_height(value)
            -- 更新数值标签位置
            if self.value_label then
                local label_x = self.props.x + math.floor(self.props.width / 2)
                self.value_label:set_pos(label_x, self.props.y + value + 2)
            end
        elseif name == "min_value" or name == "max_value" then
            self.slider:set_range(self.props.min_value, self.props.max_value)
            -- 确保当前值在范围内
            if self.props.value < self.props.min_value then
                self.props.value = self.props.min_value
            elseif self.props.value > self.props.max_value then
                self.props.value = self.props.max_value
            end
            self.slider:set_value(self.props.value, lv.ANIM_OFF)
            self:_update_value_label()
        elseif name == "value" then
            self.slider:set_value(value, lv.ANIM_OFF)
            self:_update_value_label()
        elseif name == "bg_color" then
            self.slider:set_style_bg_color(parse_color(value), lv.PART_MAIN)
        elseif name == "indicator_color" then
            self.slider:set_style_bg_color(parse_color(value), lv.PART_INDICATOR)
        elseif name == "knob_color" then
            self.slider:set_style_bg_color(parse_color(value), lv.PART_KNOB)
        elseif name == "show_value" then
            if self.value_label then
                if value then
                    self.value_label:remove_flag(lv.OBJ_FLAG_HIDDEN)
                else
                    self.value_label:add_flag(lv.OBJ_FLAG_HIDDEN)
                end
            end
        elseif name == "enabled" then
            if not value then
                self.slider:set_style_bg_color(0x555555, lv.PART_MAIN)
                self.slider:set_style_bg_color(0x666666, lv.PART_INDICATOR)
            else
                self.slider:set_style_bg_color(parse_color(self.props.bg_color), lv.PART_MAIN)
                self.slider:set_style_bg_color(parse_color(self.props.indicator_color), lv.PART_INDICATOR)
            end
        elseif name == "design_mode" then
            if value then
                self.slider:remove_flag(lv.OBJ_FLAG_CLICKABLE)
            else
                self.slider:add_flag(lv.OBJ_FLAG_CLICKABLE)
            end
        end
        return true
    end

    -- 获取所有属性
    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do
            out[k] = v
        end
        return out
    end

    -- 应用属性表
    function self.apply_properties(self, props_table)
        for k, v in pairs(props_table) do
            self:set_property(k, v)
        end
        return true
    end

    -- 导出状态
    function self.to_state(self)
        return self:get_properties()
    end

    -- 获取容器
    function self.get_container(self)
        return self.container
    end

    -- 获取当前值
    function self.get_value(self)
        return self.props.value
    end

    -- 设置当前值
    function self.set_value(self, value)
        self:set_property("value", value)
    end

    -- 获取范围
    function self.get_range(self)
        return self.props.min_value, self.props.max_value
    end

    -- 设置范围
    function self.set_range(self, min_val, max_val)
        self.props.min_value = min_val
        self.props.max_value = max_val
        self.slider:set_range(min_val, max_val)
    end

    return self
end

return Slider
