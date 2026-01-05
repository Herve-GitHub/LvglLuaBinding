local lv = require("lvgl")

local TrendChart = {}

TrendChart.__widget_meta = {
    id = "trend_chart",
    name = "Trend Chart",
    description = "折线/趋势图，可自动刷新数据",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        { name = "x", type = "number", default = 0, label = "X" },
        { name = "y", type = "number", default = 0, label = "Y" },
        { name = "width", type = "number", default = 200, label = "宽度" },
        { name = "height", type = "number", default = 100, label = "高度" },
        { name = "point_count", type = "number", default = 100, label = "点数", min = 1, max = 5000 },
        { name = "update_interval", type = "number", default = 1000, label = "刷新间隔(ms)", min = 10 },
        { name = "range_min", type = "number", default = 0, label = "最小值" },
        { name = "range_max", type = "number", default = 100, label = "最大值" },
        { name = "auto_update", type = "boolean", default = false, label = "自动更新" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    },
    events = { "updated" },
}

function TrendChart.new(parent, props)
    props = props or {}
    local self = {}

    -- init props
    self.props = {}
    for _, p in ipairs(TrendChart.__widget_meta.properties) do
        if props[p.name] ~= nil then
            self.props[p.name] = props[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    -- 创建一个简单的容器作为占位符（因为 chart 相关 API 尚未完全实现）
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(0x2D3436, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(0x636E72, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 添加标签显示控件名称
    self.label = lv.label_create(self.container)
    self.label:set_text("Trend Chart")
    self.label:set_style_text_color(0xB2BEC3, 0)
    self.label:center()

    -- event listeners
    self._event_listeners = { updated = {} }
    self._timer_running = false

    function self.update(self)
        -- placeholder: generate random value
        local val = 50 + math.random(0, 20)
        for _, cb in ipairs(self._event_listeners.updated) do cb(self, val) end
    end

    function self.start(self)
        -- 设计模式下不启动定时器
        if self.props.design_mode then return end
        -- 注意：lv.timer_create 尚未实现，暂时只设置标志
        self._timer_running = true
    end

    function self.stop(self)
        self._timer_running = false
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
        elseif name == "auto_update" then
            if value and not self.props.design_mode then 
                self:start() 
            else 
                self:stop() 
            end
        elseif name == "design_mode" then
            if value then
                self:stop()
            elseif self.props.auto_update then
                self:start()
            end
        end
        return true
    end

    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do out[k] = v end
        return out
    end

    function self.apply_properties(self, props_table)
        for k, v in pairs(props_table) do self:set_property(k, v) end
        return true
    end

    function self.to_state(self)
        return self:get_properties()
    end

    function self.on(self, event_name, callback)
        if not self._event_listeners[event_name] then self._event_listeners[event_name] = {} end
        table.insert(self._event_listeners[event_name], callback)
    end

    return self
end

return TrendChart
