-- Switch.lua - 完整修复版
-- 带元数据的开关示例，支持编辑器拖动和选中
local lv = require("lvgl")
local gen = require("general")
local DataAction = require("editor.DataAction")

local Switch = {}

Switch.__widget_meta = {
  id = "custom_switch",
  name = "Custom Switch",
  description = "开关控件，支持编辑器拖拽调整",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    -- 实例名称
    { name = "instance_name", type = "string", default = "", label = "实例名称" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 60, label = "宽度" },
    { name = "height", type = "number", default = 30, label = "高度" },
    { name = "switch_state", type = "boolean", default = false, label = "开关状态",
      description = "当前开关状态：开/关" },
    
    -- 颜色配置
    { name = "bg_color_off", type = "color", default = "#888888", label = "关闭背景色" },
    { name = "bg_color_on", type = "color", default = "#4CAF50", label = "开启背景色" },
  --  { name = "indicator_color", type = "color", default = "#FFFFFF", label = "指示器颜色" },
    
    -- 数据配置
    { name = "bind_point", type = "string", default = "", label = "绑定数据点" },
    { name = "websocket_url", type = "string", default = "", label = "WebSocket" },
    
    -- 事件配置
    { name = "event_action", type = "enum", default = "切换绑定数据点",
      options = {"写入绑定数据点", "读取绑定数据点", "切换绑定数据点"},
      label = "事件动作" },
    { name = "on_value", type = "string", default = "1", label = "开启值" },
    { name = "off_value", type = "string", default = "0", label = "关闭值" },
    
    -- 事件处理代码
    { name = "on_value_changed_handler", type = "code", default = "", label = "值改变处理代码",
      event = "value_changed" },
  },
  events = { "value_changed" },
}

-- 辅助函数：解析颜色
local function parse_color(c)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
        return tonumber(c:sub(2), 16)
    elseif type(c) == "number" then
        return c
    end
    return 0xffffff
end

-- 应用样式
local function apply_styles(self)
    if not self.switch then return end
    
    -- 解析颜色
    local bg_color_off = parse_color(self.props.bg_color_off or "#888888")
    local bg_color_on = parse_color(self.props.bg_color_on or "#4CAF50")
    
    -- 1. 设置主体背景色（MAIN）- 可以根据状态改变
    if self.switch.set_style_bg_color then
        -- 设置主体背景色（关闭状态）
        self.switch:set_style_bg_color(bg_color_off, lv.PART_MAIN)
        -- 设置主体背景色（打开状态）- 如果需要主体也改变颜色
        self.switch:set_style_bg_color(bg_color_on, lv.PART_MAIN + lv.STATE_CHECKED)
    end
    
    -- 2. 设置指示器部分（INDICATOR）
    if self.switch.set_style_bg_opa and self.switch.set_style_bg_color then
        -- 设置指示器不透明度
        self.switch:set_style_bg_opa(255, lv.PART_INDICATOR)
        
        -- 设置指示器关闭状态的颜色
        self.switch:set_style_bg_color(bg_color_off, lv.PART_INDICATOR)
        
        -- 设置指示器打开状态的颜色
        self.switch:set_style_bg_color(bg_color_on, lv.PART_INDICATOR + lv.STATE_CHECKED)
    end
    
    -- 3. 设置旋钮部分（KNOB）
    if self.switch.set_style_bg_color then
        -- 旋钮颜色，可以根据状态改变
        self.switch:set_style_bg_color(0xFFFFFF, lv.PART_KNOB)
        -- 如果需要旋钮在打开状态下变色
        -- self.switch:set_style_bg_color(0xDDDDDD, lv.PART_KNOB + lv.STATE_CHECKED)
    end
    
    -- 强制重绘
    if self.switch.invalidate then
        self.switch:invalidate()
    end
end
-- 更新开关状态
-- 更新开关状态
local function update_switch_state(self, new_state)
    -- 更新 props 中的 switch_state
    self.props.switch_state = new_state
    
    -- 更新LVGL对象 - 使用标准的 LVGL API
    if self.switch then
        if new_state then
            -- 手动打开开关（添加 CHECKED 状态）
            if self.switch.add_state then
                self.switch:add_state(lv.STATE_CHECKED)
            end
        else
            -- 手动关闭开关（移除 CHECKED 状态）
            if self.switch.remove_state then
                self.switch:remove_state(lv.STATE_CHECKED)
            end
        end
    end
    
    -- 更新样式
    apply_styles(self)
end

-- new(parent, state)
function Switch.new(parent, state)
    state = state or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(Switch.__widget_meta.properties) do
        if state[p.name] ~= nil then
            self.props[p.name] = state[p.name]
        else
            self.props[p.name] = p.default
        end
    end
    
    -- 创建LVGL开关
    self.switch = lv.switch_create(parent)
    if not self.switch then
        print("[Switch] 创建失败")
        return nil
    end
    self.obj = self.switch
    
    -- 设置初始大小和位置
    self.switch:set_size(self.props.width, self.props.height)
    self.switch:set_pos(self.props.x, self.props.y)
    
    -- 设置初始状态
    update_switch_state(self, self.props.switch_state)
    
    -- 保存回调
    self._callbacks = {}
    
    -- 创建值改变事件回调
    local function on_value_changed(e)
        -- 获取当前状态
        local new_state = false
        if self.switch.has_state then
            new_state = self.switch:has_state(lv.STATE_CHECKED)
        elseif self.switch.get_state then
            new_state = self.switch:get_state() == lv.STATE_CHECKED
        end
        
        -- 更新内部状态
        update_switch_state(self, new_state)
        
        -- 如果是设计模式，只更新状态，不执行后续动作
        if self.props.design_mode then
            -- 可以在这里触发属性面板更新
            if self._callbacks.property_changed then
                self._callbacks.property_changed("switch_state", new_state)
            end
            return
        end
        
        -- 执行数据动作
        if self.props.event_action and self.props.bind_point ~= "" then
            local value = new_state and self.props.on_value or self.props.off_value
            local callback = DataAction.create_callback("写入绑定数据点", {
                bind_point = self.props.bind_point,
                value = value
            })
            if callback then
                pcall(callback)
            end
        end
        
        -- 调用用户回调
        if self._callbacks.value_changed then
            pcall(self._callbacks.value_changed, self, {state = new_state})
        end
    end
    
    -- 注册事件
    if self.switch.add_event_cb then
        self.switch:add_event_cb(on_value_changed, lv.EVENT_VALUE_CHANGED, nil)
    end
    
    -- ========== 必须实现的标准接口 ==========
    
    -- on: 事件订阅
    function self.on(self, event_name, callback)
        if event_name == "value_changed" then
            self._callbacks.value_changed = callback
        elseif event_name == "property_changed" then
            self._callbacks.property_changed = callback
        end
    end
    
    -- get_container: 获取LVGL容器对象
    function self.get_container(self)
        return self.switch
    end
    
    -- get_property: 获取属性值
    function self.get_property(self, name)
        return self.props[name]
    end
    
    -- set_property: 设置属性值
    function self.set_property(self, name, value)
        local old_value = self.props[name]
        self.props[name] = value
        
        -- 确保switch对象存在
        if not self.switch then
            return true
        end
        
        -- 处理各种属性变化
        if name == "switch_state" then
            -- 更新开关状态
            update_switch_state(self, value)
            
        elseif name == "x" or name == "y" then
            -- 位置变化
            if self.switch.set_pos then
                self.switch:set_pos(self.props.x, self.props.y)
                if self.switch.invalidate then
                    self.switch:invalidate()
                end
            end
            
        elseif name == "width" or name == "height" then
            -- 大小变化
            if self.switch.set_size then
                self.switch:set_size(self.props.width, self.props.height)
                if self.switch.invalidate then
                    self.switch:invalidate()
                end
            end
            
        elseif name == "bg_color_off" or name == "bg_color_on" or name == "indicator_color" then
            -- 颜色变化
            apply_styles(self)
        end
        
        -- 通知属性已改变
        if self._callbacks.property_changed then
            self._callbacks.property_changed(name, value)
        end
        
        return true
    end
    
    -- get_properties: 获取所有属性
    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do 
            out[k] = v 
        end
        return out
    end
    
    -- apply_properties: 批量应用属性
    function self.apply_properties(self, props_table)
        for k, v in pairs(props_table) do
            self:set_property(k, v)
        end
        return true
    end
    
    -- to_state: 导出状态
    function self.to_state(self)
        return self:get_properties()
    end
    
    -- get_id: 获取控件ID
    function self.get_id(self)
        if self.props.instance_name and self.props.instance_name ~= "" then
            return self.props.instance_name
        end
        return tostring(self)
    end

    return self
end

return Switch