local lv = require("lvgl")
local gen = require("general")
local Container = {}

Container.__widget_meta = {
    id = "custom_container",
    name = "Container",
    description = "通用容器组件，可作为其他控件的父容器",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        { name = "instance_name", type = "string", default = "", label = "实例名称" },
        { name = "x", type = "number", default = 0, label = "X" },
        { name = "y", type = "number", default = 0, label = "Y" },
        { name = "width", type = "number", default = 200, label = "宽度" },
        { name = "height", type = "number", default = 150, label = "高度" },
        { name = "bg_color", type = "color", default = "#333333", label = "背景色" },
        { name = "border_color", type = "color", default = "#666666", label = "边框色" },
        { name = "border_width", type = "number", default = 1, label = "边框宽度" },
        { name = "radius", type = "number", default = 0, label = "圆角" },
        { name = "opa", type = "number", default = 255, label = "透明度(0-255)" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    },
    events = {},
}

local function parse_color(color)
    if type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then
        return tonumber(color:sub(2), 16)
    elseif type(color) == "number" then
        return color
    end
    return 0x333333
end

function Container.new(parent, state)
    state = state or {}
    local self = {}

    self.props = {}
    for _, p in ipairs(Container.__widget_meta.properties) do
        if state[p.name] ~= nil then
            self.props[p.name] = state[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    -- 创建容器
    self.container = lv.obj_create(parent)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_pos(self.props.x, self.props.y)

    -- 基础样式
    self.container:set_style_bg_opa(255, 0)
    self.container:set_style_border_opa(255, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    function self.on(self, event_name, callback)
        -- 容器无默认事件
    end

    function self.get_property(self, name)
        return self.props[name]
    end

    function self.set_property(self, name, value)
        self.props[name] = value

        if name == "x" or name == "y" then
            self.container:set_pos(self.props.x, self.props.y)

        elseif name == "width" or name == "height" then
            self.container:set_size(self.props.width, self.props.height)

        elseif name == "bg_color" then
            local c = parse_color(value)
            self.container:set_style_bg_color(c, 0)

        elseif name == "border_color" then
            local c = parse_color(value)
            self.container:set_style_border_color(c, 0)

        elseif name == "border_width" then
            self.container:set_style_border_width(value, 0)

        elseif name == "radius" then
            self.container:set_style_radius(value, 0)

        elseif name == "opa" then
            local opa = math.max(0, math.min(255, value))
            self.container:set_style_opa(opa, 0)
        end

        return true
    end

    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do out[k] = v end
        return out
    end

    function self.apply_properties(self, props_table)
        for k, v in pairs(props_table) do
            self:set_property(k, v)
        end
        return true
    end

    function self.to_state(self)
        return self:get_properties()
    end

    -- 初始化应用属性
    self:apply_properties(self.props)

    return self
end

return Container