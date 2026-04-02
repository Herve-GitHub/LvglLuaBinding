local lv = require("lvgl")

local TrendChart = {}

TrendChart.__widget_meta = {
    id = "trend_chart",
    name = "Trend Chart",
    description = "折线/趋势图，可自动刷新数据",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        -- 实例名称（用于编译时变量命名）
        { name = "instance_name", type = "string", default = "", label = "实例名称",
          description = "用于编译时的变量名，留空则自动生成" },
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
        -- X轴标签相关属性（增强自定义能力）
        { name = "show_x_labels", type = "boolean", default = true, label = "显示X轴标签" },
        { name = "x_label_count", type = "number", default = 5, label = "X轴标签数量", min = 2, max = 20 },
        { name = "x_label_height", type = "number", default = 20, label = "X轴标签高度" },
        { name = "x_label_texts", type = "string", default = "0s,5s,10s", label = "X轴自定义",
          description = "自定义标签文本，用逗号分隔，如：0s,5s,10s"   },
        { name = "x_label_color", type = "color", default = "#CCCCCC", label = "X轴标签颜色",
          description = "支持#RRGGBB格式或16进制数字" },
        -- 事件处理代码属性
        { name = "on_updated_handler", type = "code", default = "", label = "更新处理代码",
          event = "updated", description = "数据更新时执行的Lua代码" },
    },
    events = { "updated" },
}

-- 颜色解析辅助函数
local function parse_color(color)
    if type(color) == "string" and color:match("^#%x%x%x%x%x%x$") then
        return tonumber(color:sub(2), 16)
    elseif type(color) == "number" then
        return color
    end
    return 0xCCCCCC  -- 默认灰色
end

function TrendChart.new(parent, props)
    props = props or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(TrendChart.__widget_meta.properties) do
        if props[p.name] ~= nil then
            self.props[p.name] = props[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    -- 保存父元素引用
    self._parent = parent
    
    -- 事件监听器（移除x_label事件，仅保留updated）
    self._event_listeners = { updated = {} }
    
    -- 存储标签对象
    self.x_labels = {}
    self.label_container = nil
    self.data_history = {}  -- 保留数据历史，但不再关联标签

    -- ========== 创建图表 ==========
    self.chart = lv.chart_create(parent)
    self.chart:set_pos(self.props.x, self.props.y)
    self.chart:set_size(self.props.width, self.props.height)
    self.chart:set_type(lv.CHART_TYPE_LINE)
    self.chart:set_point_count(self.props.point_count)
    self.chart:set_update_mode(lv.CHART_UPDATE_MODE_SHIFT)
    self.chart:set_div_line_count(3, 3)

    self.chart:set_style_bg_color(0x000000, 0)    -- 白色背景（跟仿真一样！）
self.chart:set_style_bg_opa(lv.OPA_COVER, 0)   -- 完全不透明
self.chart:set_style_border_width(1, 0)       -- 加边框

    self.series = self.chart:add_series(0xFF0000, lv.CHART_AXIS_PRIMARY_Y)
    self.chart:set_range(lv.CHART_AXIS_PRIMARY_Y, self.props.range_min, self.props.range_max)

    -- ========== 触发事件函数 ==========
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

    -- ========== 创建/更新X轴标签（纯自定义，无动态数据关联） ==========
-- ========== 创建/更新X轴标签（纯自定义，无动态数据关联） ==========
-- ========== 创建/更新X轴标签（纯自定义，无动态数据关联） ==========
-- ========== 创建/更新X轴标签 ==========
function self.update_x_labels(self)
    -- 删除旧标签容器
    if self.label_container then
        self.label_container:delete()
        self.label_container = nil
        self.x_labels = {}
    end
    
    -- 如果不显示标签，直接返回
    if not self.props.show_x_labels then
        return
    end
    
    -- 创建标签容器
    self.label_container = lv.obj_create(self._parent)
    self.label_container:set_size(self.props.width+50, self.props.x_label_height + 15)
    self.label_container:set_pos(math.floor(self.props.x-25), math.floor(self.props.y + self.props.height))
    self.label_container:set_style_bg_opa(0, 0)
    self.label_container:set_style_border_opa(0, 0)
    self.label_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 解析自定义标签文本（从逗号分隔的字符串）
    local custom_texts = {}
    if self.props.x_label_texts and self.props.x_label_texts ~= "" then
        -- 按逗号分割，并去除前后空格
        for text in string.gmatch(self.props.x_label_texts, "([^,]+)") do
            local trimmed = text:match("^%s*(.-)%s*$")  -- 去除前后空格
            if trimmed ~= "" then
                table.insert(custom_texts, trimmed)
            end
        end
    end
    
    -- 调试输出
    print("Custom texts:", table.concat(custom_texts, ", "))
    
    -- 确定使用的标签数量和文本
    local label_count
    local label_texts = {}
    
    if #custom_texts > 0 then
        -- 使用完全自定义
        label_count = #custom_texts
        label_texts = custom_texts
        print("Using custom labels, count:", label_count)
    else
        -- 使用自动生成（注意：这里不需要+1）
        label_count = self.props.x_label_count
        for i = 0, label_count - 1 do
            label_texts[i + 1] = tostring(math.floor(i * (self.props.point_count / (label_count - 1))))
        end
        print("Using auto labels, count:", label_count)
    end
    
    -- 计算标签间距
    local label_spacing = self.props.width / (label_count - 1)
    local label_color = parse_color(self.props.x_label_color)
    
    -- 先创建所有标签并设置文本，然后再调整位置
    local temp_labels = {}
    
    -- 第一步：创建所有标签并设置文本
    for i = 1, label_count do
        local label = lv.label_create(self.label_container)
        
        -- 设置标签样式
        label:set_style_text_color(label_color, 0)
        label:set_style_text_align(lv.TEXT_ALIGN_CENTER, 0)
        
        -- 设置标签文本
        label:set_text(label_texts[i])
        
        -- 临时存储
        table.insert(temp_labels, label)
    end
    
    -- 第二步：调整所有标签的位置
    for i = 1, label_count do
        local label = temp_labels[i]
        
        -- 获取标签的实际宽度
        local label_width = label:get_width()
        
        -- 计算标签位置（居中显示）
        local label_x = (i - 1) * label_spacing - label_width / 2
        
        -- 取整（四舍五入）
        label_x = math.floor(label_x + 0.5)
        
        -- 确保标签不超出边界
        if label_x < 0 then
            label_x = 0
        elseif label_x + label_width > self.props.width then
            label_x = self.props.width - label_width
        end
        
        -- 调试输出
        print(string.format("Label %d: text='%s', width=%d, x=%d", i, label_texts[i], label_width, label_x))
        
        label:set_pos(label_x, 0)
        table.insert(self.x_labels, label)
    end
end

    -- ========== 公共方法 ==========
    function self.update(self)
        -- 生成随机值
        local val = 50 + math.random(self.props.range_min, self.props.range_max) % 20
        self.chart:set_next_value(self.series, val)
        
        -- 存储历史数据（仅用于数据记录，不关联标签）
        table.insert(self.data_history, val)
        while #self.data_history > self.props.point_count do
            table.remove(self.data_history, 1)
        end
        
        -- 触发更新事件（不再更新标签）
        self:_emit("updated", val)
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

    -- 手动添加数据点（仅添加数据，不更新标签）
    function self.add_data_point(self, value)
        value = tonumber(value) or 0
        if value < self.props.range_min then value = self.props.range_min end
        if value > self.props.range_max then value = self.props.range_max end
        
        self.chart:set_next_value(self.series, value)
        
        table.insert(self.data_history, value)
        while #self.data_history > self.props.point_count do
            table.remove(self.data_history, 1)
        end
        
        self:_emit("updated", value)
    end
    
    -- 清空数据（仅清空数据，标签保持不变）
    function self.clear_data(self)
        self.data_history = {}
    end

    -- ========== 快速设置X轴标签（新增便捷方法） ==========
    function self.set_x_labels(self, label_texts)
        if type(label_texts) == "table" then
            self.props.x_label_texts = label_texts
            self:update_x_labels()  -- 立即更新标签显示
        end
    end

    -- ========== 属性管理 ==========
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
                self:update_x_labels()  -- 重建标签
            end
        elseif name == "point_count" then
            self.chart:set_point_count(value)
            self:update_x_labels()  -- 重建标签（数字标签适配点数）
        elseif name == "update_interval" then
            if self.timer then
                self:stop()
                self:start()
            end
        elseif name == "range_min" or name == "range_max" then
            self.chart:set_range(lv.CHART_AXIS_PRIMARY_Y, self.props.range_min, self.props.range_max)
        elseif name == "auto_update" then
            if value then self:start() else self:stop() end
        -- 标签相关属性更新
        elseif name == "show_x_labels" or name == "x_label_count" or name == "x_label_height" or 
               name == "x_label_texts" or name == "x_label_color" then
            self:update_x_labels()  -- 重建标签
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
        print("self.on", event_name, callback)
        if not self._event_listeners[event_name] then 
            self._event_listeners[event_name] = {} 
        end
        table.insert(self._event_listeners[event_name], callback)
    end

    -- 初始化创建标签
    self:update_x_labels()

    -- 自动启动（非设计模式且开启自动更新）
    if self.props.auto_update and not self.props.design_mode then 
        print("self:start")
        self:start() 
    end

    return self
end

return TrendChart