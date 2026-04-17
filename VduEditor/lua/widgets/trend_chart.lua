-- TrendChart.lua (修复版)
local lv = require("lvgl")
local DataManager = require("editor.DataManager")

local TrendChart = {}

TrendChart.__widget_meta = {
    id = "trend_chart",
    name = "Trend Chart",
    description = "折线/趋势图，可自动刷新数据",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        { name = "instance_name", type = "string", default = "", label = "实例名称" },
        { name = "x", type = "number", default = 0, label = "X" },
        { name = "y", type = "number", default = 0, label = "Y" },
        { name = "width", type = "number", default = 300, label = "宽度" },
        { name = "height", type = "number", default = 120, label = "高度" },
        { name = "point_count", type = "number", default = 300, label = "点数" },
        { name = "update_interval", type = "number", default = 1000, label = "刷新间隔(ms)" },
        { name = "range_min", type = "number", default = 0, label = "最小值" },
        { name = "range_max", type = "number", default = 100, label = "最大值" },
        { name = "auto_update", type = "boolean", default = true, label = "自动更新" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },

        { name = "bind_point", type = "string", default = "", label = "绑定数据点" },
        { name = "event_action", type = "string", default = "读取绑定数据点", label = "事件动作" },
        { name = "websocket_url", type = "string", default = "", label = "WebSocket地址" },

        { name = "show_x_labels", type = "boolean", default = true, label = "显示X轴标签" },
        { name = "x_label_count", type = "number", default = 5, label = "X轴标签数量" },
        { name = "x_label_height", type = "number", default = 20, label = "X轴标签高度" },
        { name = "x_label_texts", type = "string", default = "0s,5s,10s", label = "X轴自定义" },
        { name = "x_label_color", type = "color", default = "#CCCCCC", label = "X轴标签颜色" },
        { name = "on_updated_handler", type = "code", default = "", label = "更新处理代码" },
    },
    events = { "updated" },
}

local function parse_color(color)
    if type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then
        return tonumber(color:sub(2), 16)
    elseif type(color) == "number" then
        return color
    end
    return 0xCCCCCC
end

function TrendChart.new(parent, props)
    props = props or {}
    local self = {}

    self.props = {}
    for _, p in ipairs(TrendChart.__widget_meta.properties) do
        if props[p.name] ~= nil then
            self.props[p.name] = props[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    self._parent = parent
    self._event_listeners = { updated = {} }
    self.x_labels = {}
    self.label_container = nil
    self.data_history = {}

    self.chart = lv.chart_create(parent)
    self.chart:set_pos(self.props.x, self.props.y)
    self.chart:set_size(self.props.width, self.props.height)
    self.chart:set_type(lv.CHART_TYPE_LINE)
    self.chart:set_point_count(self.props.point_count)
    self.chart:set_update_mode(lv.CHART_UPDATE_MODE_SHIFT)
   -- self.chart:set_div_line_count(3, 3)

    --self.chart:set_style_bg_color(0x000000, 0)
    --self.chart:set_style_bg_opa(lv.OPA_COVER, 0)
   -- self.chart:set_style_border_width(1, 0)


    --self.chart:set_range(lv.CHART_AXIS_PRIMARY_Y, self.props.range_min, self.props.range_max)
    self.series = self.chart:add_series(0xFF0000, lv.CHART_AXIS_PRIMARY_Y)
    --self.chart:set_range(lv.CHART_AXIS_PRIMARY_Y, self.props.range_min, self.props.range_max)

    function self._emit(self, event_name, ...)
        local listeners = self._event_listeners[event_name]
        if listeners then
            for _, cb in ipairs(listeners) do
                local ok, err = pcall(cb, self, ...)
                if not ok then
                    print("[TrendChart] callback error:", err)
                end
            end
        end
    end

    function self.update_x_labels(self)
        if self.label_container then
            self.label_container:delete()
            self.label_container = nil
            self.x_labels = {}
        end
        
        if not self.props.show_x_labels then
            return
        end
        
        self.label_container = lv.obj_create(self._parent)
        self.label_container:set_size(self.props.width+50, self.props.x_label_height + 15)
        self.label_container:set_pos(math.floor(self.props.x-25), math.floor(self.props.y + self.props.height))
        self.label_container:set_style_bg_opa(0, 0)
        self.label_container:set_style_border_opa(0, 0)
        self.label_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        
        local custom_texts = {}
        if self.props.x_label_texts and self.props.x_label_texts ~= "" then
            for text in string.gmatch(self.props.x_label_texts, "([^,]+)") do
                local trimmed = text:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    table.insert(custom_texts, trimmed)
                end
            end
        end
        
        local label_count
        local label_texts = {}
        
        if #custom_texts > 0 then
            label_count = #custom_texts
            label_texts = custom_texts
        else
            label_count = self.props.x_label_count
            for i = 0, label_count - 1 do
                label_texts[i + 1] = tostring(math.floor(i * (self.props.point_count / (label_count - 1))))
            end
        end
        
        local label_spacing = self.props.width / (label_count - 1)
        local label_color = parse_color(self.props.x_label_color)
        
        local temp_labels = {}
        
        for i = 1, label_count do
            local label = lv.label_create(self.label_container)
            label:set_style_text_color(label_color, 0)
            label:set_style_text_align(lv.TEXT_ALIGN_CENTER, 0)
            label:set_text(label_texts[i])
            table.insert(temp_labels, label)
        end
        
        for i = 1, label_count do
            local label = temp_labels[i]
            local label_width = label:get_width()
            local label_x = (i - 1) * label_spacing - label_width / 2
            label_x = math.floor(label_x + 0.5)
            if label_x < 0 then label_x = 0 end
            if label_x + label_width > self.props.width then
                label_x = self.props.width - label_width
            end
            label:set_pos(label_x, 0)
            table.insert(self.x_labels, label)
        end
    end

    -- 🔧 修复1：确保update_value方法存在且正确
    function self.update_value(self, value)
        local val = tonumber(value) or 0
        -- 限制范围
        if val < self.props.range_min then val = self.props.range_min end
        if val > self.props.range_max then val = self.props.range_max end
        
        self.chart:set_next_value(self.series, val)
        table.insert(self.data_history, val)
        while #self.data_history > self.props.point_count do
            table.remove(self.data_history, 1)
        end
        self:_emit("updated", val)
    end

    function self.update(self)
        local val = 50 + math.random(self.props.range_min, self.props.range_max) % 20
        self:update_value(val)  -- 复用update_value方法
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

    function self.add_data_point(self, value)
        self:update_value(value)  -- 复用update_value方法
    end

    function self.clear_data(self)
        self.data_history = {}
        -- 可选：清空图表显示
        for i = 1, self.props.point_count do
            self.chart:set_next_value(self.series, 0)
        end
    end

    function self.set_x_labels(self, label_texts)
        if type(label_texts) == "table" then
            self.props.x_label_texts = table.concat(label_texts, ",")
            self:update_x_labels()
        end
    end

    function self.get_property(self, name)
        return self.props[name]
    end

    function self.set_property(self, name, value)
        self.props[name] = value
        if name == "x" or name == "y" then
            self.chart:set_pos(self.props.x, self.props.y)
            if self.label_container then
                self.label_container:set_pos(self.props.x, self.props.y + self.props.height)
            end
        elseif name == "width" or name == "height" then
            self.chart:set_size(self.props.width, self.props.height)
            if self.label_container then
                self.label_container:set_size(self.props.width, self.props.x_label_height + 10)
                self.label_container:set_pos(self.props.x, self.props.y + self.props.height)
                self:update_x_labels()
            end
        elseif name == "point_count" then
            self.chart:set_point_count(value)
            self:update_x_labels()
        elseif name == "update_interval" then
            if self.timer then
                self:stop()
                self:start()
            end
        elseif name == "range_min" or name == "range_max" then
            self.chart:set_range(lv.CHART_AXIS_PRIMARY_Y, self.props.range_min, self.props.range_max)
        elseif name == "auto_update" then
            if value then self:start() else self:stop() end
        elseif name == "show_x_labels" or name == "x_label_count" or name == "x_label_height" or 
               name == "x_label_texts" or name == "x_label_color" then
            self:update_x_labels()
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
        if not self._event_listeners[event_name] then 
            self._event_listeners[event_name] = {} 
        end
        table.insert(self._event_listeners[event_name], callback)
    end

    -- 🔧 修复2：确保_bind_event在正确时机调用
    function self._bind_event(self)
        local action = self.props.event_action or "读取绑定数据点"
        local addr = self.props.bind_point
        
        print("[TrendChart] _bind_event检查: action=" .. tostring(action) .. ", addr=" .. tostring(addr))
        
        -- 🔧 修复3：即使design_mode也要注册，但要检查bind_point
        if addr and addr ~= "" then
            if action == "读取绑定数据点" or action == "读写数据点" then
                DataManager.register_chart(addr, self)
                print("[TrendChart] ✅ 已注册到数据中心：" .. addr)
                return true
            else
                print("[TrendChart] 未设置读取动作，当前action=" .. action)
            end
        else
            print("[TrendChart] bind_point为空，跳过注册")
        end
        return false
    end

    -- 先创建UI
    self:update_x_labels()
    
    -- 🔧 修复4：无论是否设计模式，只要不是设计模式或需要数据绑定就注册
    -- 但设计模式下的预览也要能看到数据
    if self.props.bind_point and self.props.bind_point ~= "" then
        self:_bind_event()
    end
    
    -- 自动更新定时器
    if self.props.auto_update and not self.props.design_mode then 
        self:start() 
    end

    return self
end

return TrendChart