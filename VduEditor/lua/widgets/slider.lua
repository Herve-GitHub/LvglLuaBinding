-- slider.lua 纯净版（无文字标签）
local lv = require("lvgl")

local Slider = {}

Slider.__widget_meta = {
    id = "slider",
    name = "Slider",
    description = "滑块控件，支持数值范围选择",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        { name = "instance_name", type = "string", default = "", label = "实例名称" },
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
        { name = "enabled", type = "boolean", default = true, label = "启用" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
        { name = "on_changed_handler", type = "code", default = "", label = "值变化处理代码", event = "changed" },
    },
    events = { "changed" },
}

local function parse_color(c)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
        return tonumber(c:sub(2), 16)
    elseif type(c) == "number" then
        return c
    end
    return 0xFFFFFF
end

function Slider.new(parent, state)
    state = state or {}
    local self = {}

    self.props = {}
    for i = 1, #Slider.__widget_meta.properties do
        local p = Slider.__widget_meta.properties[i]
        self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
    end

    self._event_listeners = {}

    -- 事件触发
    function self._emit(event_name, ...)
        local list = self._event_listeners[event_name]
        if list then
            for i = 1, #list do
                pcall(list[i], self, ...)
            end
        end
    end

    -- 创建滑块
    self.slider = lv.slider_create(parent)
    self.slider:set_size(self.props.width, self.props.height)
    self.slider:set_pos(self.props.x, self.props.y)
    self.slider:set_range(self.props.min_value, self.props.max_value)
    self.slider:set_value(self.props.value, lv.ANIM_OFF)
    
    self.container = self.slider

    -- 样式
    self.slider:set_style_bg_color(parse_color(self.props.bg_color), lv.PART_MAIN)
    self.slider:set_style_bg_opa(255, lv.PART_MAIN)
    self.slider:set_style_radius(5, lv.PART_MAIN)
    self.slider:set_style_border_width(0, lv.PART_MAIN)
    self.slider:set_style_pad_all(0, lv.PART_MAIN)
    self.slider:set_style_outline_width(0, lv.PART_MAIN)
    self.slider:set_style_shadow_width(0, lv.PART_MAIN)
    
    self.slider:set_style_bg_color(parse_color(self.props.indicator_color), lv.PART_INDICATOR)
    self.slider:set_style_bg_opa(255, lv.PART_INDICATOR)
    self.slider:set_style_radius(5, lv.PART_INDICATOR)
    self.slider:set_style_border_width(0, lv.PART_INDICATOR)
    
    self.slider:set_style_bg_color(parse_color(self.props.knob_color), lv.PART_KNOB)
    self.slider:set_style_bg_opa(255, lv.PART_KNOB)
    self.slider:set_style_radius(10, lv.PART_KNOB)
    self.slider:set_style_pad_all(3, lv.PART_KNOB)
    self.slider:set_style_border_width(0, lv.PART_KNOB)
    self.slider:set_style_outline_width(0, lv.PART_KNOB)
    self.slider:set_style_shadow_width(0, lv.PART_KNOB)
    
    self.slider:set_style_outline_width(0, lv.PART_MAIN + lv.STATE_FOCUSED)
    self.slider:set_style_outline_width(0, lv.PART_KNOB + lv.STATE_FOCUSED)
    self.slider:set_style_shadow_width(0, lv.PART_KNOB + lv.STATE_FOCUSED)

    -- 滑块事件
    local this = self
    self.slider:add_event_cb(function(e)
        if not this.props.enabled or this.props.design_mode then return end
        local v = this.slider:get_value()
        this.props.value = v
        this._emit("changed", v)
    end, lv.EVENT_VALUE_CHANGED)

    if self.props.design_mode then
        self.slider:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    end

    -- 方法
    function self:on(event_name, callback)
        self._event_listeners[event_name] = self._event_listeners[event_name] or {}
        table.insert(self._event_listeners[event_name], callback)
    end

    function self:get_property(name)
        return self.props[name]
    end

    function self:set_property(name, value)
        self.props[name] = value

        if name == "x" or name == "y" then
            self.slider:set_pos(self.props.x, self.props.y)
        elseif name == "width" then
            self.slider:set_width(value)
        elseif name == "height" then
            self.slider:set_height(value)
        elseif name == "min_value" or name == "max_value" then
            self.slider:set_range(self.props.min_value, self.props.max_value)
        elseif name == "value" then
            self.slider:set_value(value, lv.ANIM_OFF)
        elseif name == "bg_color" then
            self.slider:set_style_bg_color(parse_color(value), lv.PART_MAIN)
        elseif name == "indicator_color" then
            self.slider:set_style_bg_color(parse_color(value), lv.PART_INDICATOR)
        elseif name == "knob_color" then
            self.slider:set_style_bg_color(parse_color(value), lv.PART_KNOB)
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

    function self:get_properties()
        local out = {}
        for k, v in pairs(self.props) do out[k] = v end
        return out
    end

    function self:apply_properties(t)
        for k, v in pairs(t) do self:set_property(k, v) end
        return true
    end

    function self:to_state()
        return self.props
    end

    function self:get_container()
        return self.container
    end

    return self
end

return Slider