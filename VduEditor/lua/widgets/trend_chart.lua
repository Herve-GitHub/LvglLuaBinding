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
        { name = "width", type = "number", default = 300, label = "宽度" },
        { name = "height", type = "number", default = 120, label = "高度" },
        { name = "point_count", type = "number", default = 300, label = "点数", min = 1, max = 5000 },
        { name = "update_interval", type = "number", default = 1000, label = "刷新间隔(ms)", min = 10 },
        { name = "range_min", type = "number", default = 0, label = "最小值" },
        { name = "range_max", type = "number", default = 100, label = "最大值" },
        { name = "auto_update", type = "boolean", default = true, label = "自动更新" },
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

    -- create chart
    self.chart = lv.chart_create(parent)
    self.chart:set_pos(self.props.x, self.props.y)
    self.chart:set_size(self.props.width, self.props.height)
    self.chart:set_type(lv.CHART_TYPE_LINE)
    self.chart:set_point_count(self.props.point_count)
    self.chart:set_update_mode(lv.CHART_UPDATE_MODE_SHIFT)
    self.chart:set_div_line_count(3, 0)
    self.series = self.chart:add_series(0x2196F3, lv.CHART_AXIS_PRIMARY_Y)
    self.chart:set_range(lv.CHART_AXIS_PRIMARY_Y, self.props.range_min, self.props.range_max)

    -- event listeners
    self._event_listeners = { updated = {} }

    function self.update(self)
        -- placeholder: generate random value; editor/host can push real data by calling set_property or chart API
        local val = 50 + math.random(self.props.range_min, self.props.range_max)%20
        self.chart:set_next_value(self.series, val)
        for _, cb in ipairs(self._event_listeners.updated) do cb(self, val) end
    end

    function self.start(self)
        if self.timer then return end
        self.timer = lv.timer_create(function()
            self:update()
        end, self.props.update_interval)
    end

    function self.stop(self)
        if self.timer then
            lv.timer_delete(self.timer)
            self.timer = nil
        end
    end

    function self.get_property(self, name)
        return self.props[name]
    end

    function self.set_property(self, name, value)
        self.props[name] = value
        if name == "x" or name == "y" then
            self.chart:set_pos(self.props.x, self.props.y)
        elseif name == "width" or name == "height" then
            self.chart:set_size(self.props.width, self.props.height)
        elseif name == "point_count" then
            self.chart:set_point_count(value)
        elseif name == "update_interval" then
            if self.timer then
                self:stop()
                self:start()
            end
        elseif name == "range_min" or name == "range_max" then
            self.chart:set_range(0, self.props.range_min, self.props.range_max)
        elseif name == "auto_update" then
            if value then self:start() else self:stop() end
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

    -- auto start if requested
    if self.props.auto_update then self:start() end

    return self
end

return TrendChart
