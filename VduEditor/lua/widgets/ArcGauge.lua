local lv = require("lvgl")
local DataAction = require("editor.DataAction")
local config = require("widgets.config")

local ArcGauge = {}

ArcGauge.__widget_meta = {
  id = "custom_arc_gauge",
  name = "圆弧仪表盘",
  description = "带标题、数值、单位的圆弧仪表盘组件",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    { name = "instance_name", type = "string", default = "", label = "实例名称" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 150, label = "宽度" },
    { name = "height", type = "number", default = 150, label = "高度" },

    { name = "gauge_title", type = "string", default = "仪表盘", label = "仪表盘标题" },
    { name = "unit", type = "string", default = "%", label = "单位" },
    { name = "value", type = "number", default = 0, label = "当前数值" },
    
    { name = "arc_color", type = "color", default = 0xffd700, label = "圆弧颜色" },
    { name = "arc_width", type = "number", default = 6, label = "圆弧宽度" },
    { name = "arc_size", type = "number", default = 130, label = "圆弧大小", min = 100, max = 300 },
    
    -- 事件处理代码属性
    { name = "on_value_changed_handler", type = "code", default = "", label = "数值变化处理代码",
      event = "value_changed", description = "数值变化时执行的Lua代码" },
  },
  events = { "value_changed" },
}

function ArcGauge.new(parent, state)
    state = state or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(ArcGauge.__widget_meta.properties) do
        self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
    end

    -- 保存父元素引用
    self._parent = parent
    
    -- 事件监听器
    self._event_listeners = { value_changed = {} }

    -- 创建根容器
    self.container = lv.obj_create(parent)
    self.obj = self.container
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_style_bg_color(0x16213e, 0)
    self.container:set_style_radius(150, 0)
    self.container:set_style_border_width(3, 0)
    self.container:set_style_border_color(0x0f3460, 0)

    -- 标题
    self.title_label = lv.label_create(self.container)
    self.title_label:set_style_text_color(0xffffff, 255)
    self.title_label:align(lv.ALIGN_TOP_MID, 0, 30)

    -- 进度圆弧
    self.arc = lv.arc_create(self.container)
    self.arc:set_size(self.props.arc_size, self.props.arc_size)
    self.arc:align(lv.ALIGN_CENTER, 0, 0)
    self.arc:arc_set_angles(135, 135)

    -- 中心数值
    self.value_label = lv.label_create(self.container)
    self.value_label:set_style_text_color(0xffffff, 255)
    self.value_label:align(lv.ALIGN_CENTER, 0, 0)

    -- 单位
    self.unit_label = lv.label_create(self.container)
    self.unit_label:set_style_text_color(0xcccccc, 255)
    self.unit_label:align(lv.ALIGN_CENTER, 0, 30)

    -- ========== 触发事件函数 ==========
    function self._emit(self, event_name, ...)
        local listeners = self._event_listeners[event_name]
        if listeners then
            for _, cb in ipairs(listeners) do
                local ok, err = pcall(cb, self, ...)
                if not ok then
                    print("[ArcGauge] callback error:", err)
                end
            end
        end
    end

    -- 外部可调用：更新数值
    function self.set_value(self, val)
        val = math.max(0, math.min(100, val))
        self.props.value = val
        local angle = math.floor(135 + val * 2.7)
        self.arc:arc_set_angles(135, angle)
        self.value_label:set_text(tostring(math.floor(val)))
        
        -- 触发数值变化事件
        self:_emit("value_changed", val)
    end

    -- 应用所有属性
    function self.apply_all_props(self)
        self.container:set_size(self.props.width, self.props.height)
        self.container:set_pos(self.props.x, self.props.y)
        self.title_label:set_text(self.props.gauge_title)
        self.unit_label:set_text(self.props.unit)
        self.arc:set_size(self.props.arc_size, self.props.arc_size)
        self.arc:align(lv.ALIGN_CENTER, 0, 0)
        self.arc:arc_set_style_arc_color(self.props.arc_color)
        self.arc:arc_set_style_arc_width(self.props.arc_width)
        self:set_value(self.props.value)
    end

    self:apply_all_props()

    -- 标准接口
    function self.on(self, event_name, callback)
        if not self._event_listeners[event_name] then 
            self._event_listeners[event_name] = {} 
        end
        table.insert(self._event_listeners[event_name], callback)
    end

    function self.get_container(self) return self.container end
    function self.get_property(self, name) return self.props[name] end

    function self.set_property(self, name, value)
        self.props[name] = value
        
        if name == "x" or name == "y" then
            self.container:set_pos(self.props.x, self.props.y)
        elseif name == "width" or name == "height" then
            self.container:set_size(self.props.width, self.props.height)
        elseif name == "gauge_title" then
            self.title_label:set_text(value)
        elseif name == "unit" then
            self.unit_label:set_text(value)
        elseif name == "value" then
            self:set_value(value)
        elseif name == "arc_size" then
            self.arc:set_size(value, value)
            self.arc:align(lv.ALIGN_CENTER, 0, 0)
        elseif name == "arc_color" then
            self.arc:arc_set_style_arc_color(value)
        elseif name == "arc_width" then
            self.arc:arc_set_style_arc_width(value)
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

    function self.to_state(self) return self:get_properties() end
    function self.get_id(self) return self.props.instance_name or tostring(self) end

    return self
end

return ArcGauge