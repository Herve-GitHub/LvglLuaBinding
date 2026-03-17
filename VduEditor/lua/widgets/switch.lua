-- Switch.lua - 最终修复版
-- 带元数据的开关示例，支持编辑器拖动和选中
local lv = require("lvgl")
local gen = require("general")
local DataAction = require("editor.DataAction")
local SitwchAction = require("actions.SitwchAction")
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
   -- { name = "bg_color_on", type = "color", default = "#4CAF50", label = "开启背景色" },
    
    -- 数据配置
    { name = "bind_point", type = "string", default = "", label = "绑定数据点" },
    { name = "websocket_url", type = "string", default = "", label = "WebSocket" },
    
    -- 事件配置
    { name = "event_action", type = "enum", default = "写入绑定数据点",
      options = {"写入绑定数据点", "读取绑定数据点", "读写数据点",  -- 将"连接WebSocket"改为"读写数据点"
                 "写入自定义地址", "读取自定义地址", "发送HTTP请求"},
      label = "事件动作", description = "点击时执行的动作" },
    { name = "off_value", type = "string", default = "0", label = "关闭值" },
    { name = "on_value", type = "string", default = "1", label = "开启值" },
    
    
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
    return 0x888888
end

-- 设置颜色 - 只设置 INDICATOR 部分
local function set_indicator_color(self, color)
    if not self.switch or not self.switch.set_style_bg_color then return end
    
    -- 设置 INDICATOR 部分的颜色（这是开关实际显示颜色的部分）
    self.switch:set_style_bg_color(color, lv.PART_INDICATOR)
    
    -- 强制重绘
    if self.switch.invalidate then
        self.switch:invalidate()
    end
end

-- 应用样式
local function apply_styles(self)
    if not self.switch then return end
    
    -- 解析颜色
    local bg_color_off = parse_color(self.props.bg_color_off or "#888888")
    local bg_color_on = parse_color(self.props.bg_color_on or "#4CAF50")
    
    -- 根据当前状态设置 INDICATOR 颜色
    local current_color = self.props.switch_state and bg_color_on or bg_color_off
    set_indicator_color(self, current_color)
    
    -- 设置旋钮颜色（保持不变）
    if self.switch.set_style_bg_color then
        self.switch:set_style_bg_color(0xFFFFFF, lv.PART_KNOB)
    end
end

-- 更新开关状态
local function update_switch_state(self, new_state)
    -- 更新 props 中的 switch_state
    self.props.switch_state = new_state
    
    -- 更新LVGL对象的状态
    if self.switch then
        if new_state then
            if self.switch.add_state then
                self.switch:add_state(lv.STATE_CHECKED)
            end
        else
            if self.switch.remove_state then
                self.switch:remove_state(lv.STATE_CHECKED)
            end
        end
    end
    
    -- 更新颜色
    apply_styles(self)
end

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
    
    -- 设置初始颜色
    local bg_color_off = parse_color(self.props.bg_color_off or "#888888")
    set_indicator_color(self, bg_color_off)
    
    if self.props.switch_state then
        if self.switch.add_state then
            self.switch:add_state(lv.STATE_CHECKED)
        end
        local bg_color_on = parse_color(self.props.bg_color_on or "#4CAF50")
        set_indicator_color(self, bg_color_on)
    end
    
    -- 保存回调
    self._callbacks = {}
    
    -- 创建值改变事件回调
-- 创建值改变事件回调
local function on_value_changed(e)
    -- 获取当前状态
    local new_state = false
    if self.switch.has_state then
        new_state = self.switch:has_state(lv.STATE_CHECKED)
    end
    
    -- 更新 props
    self.props.switch_state = new_state
    
    -- 更新颜色
    local bg_color_off = parse_color(self.props.bg_color_off or "#888888")
    local bg_color_on = parse_color(self.props.bg_color_on or "#4CAF50")
    local new_color = new_state and bg_color_on or bg_color_off
    set_indicator_color(self, new_color)
    
    -- 如果是设计模式，只更新状态，不执行后续动作
    if self.props.design_mode then
        if self._callbacks.property_changed then
            self._callbacks.property_changed("switch_state", new_state)
        end
        return
    end
    
    -- ===== 修改：支持读写模式的状态改变写入 =====
    -- 执行数据动作：开关状态改变时写入对应的值
    if self.props.event_action == "写入绑定数据点" and self.props.bind_point and self.props.bind_point ~= "" then
        local value = new_state and self.props.on_value or self.props.off_value
        print("[Switch] 状态改变，写入: " .. self.props.bind_point .. " = " .. value)
        
        -- 调用 SitwchAction
        local callback = SitwchAction.create_callback("写入绑定数据点", {
            bind_point = self.props.bind_point,
            value = value,
            websocket_url = self.props.websocket_url
        })
        if callback then
            pcall(callback)
        end
    elseif self.props.event_action == "读写数据点" and self.props.bind_point and self.props.bind_point ~= "" then
        -- 读写模式：状态改变时也写入数据
        if self._write_callback then
            print("[Switch] 读写模式状态改变，执行写入")
            pcall(self._write_callback, new_state)
        else
            -- 如果没有保存的写入回调，动态创建
            local value = new_state and self.props.on_value or self.props.off_value
            print("[Switch] 读写模式状态改变，动态写入: " .. self.props.bind_point .. " = " .. value)
            
            local callback = SitwchAction.create_callback("写入绑定数据点", {
                bind_point = self.props.bind_point,
                value = value,
                websocket_url = self.props.websocket_url
            })
            if callback then
                pcall(callback)
            end
        end
    end
    -- ===== 修改结束 =====
    
    -- 调用用户回调
    if self._callbacks.value_changed then
        pcall(self._callbacks.value_changed, self, {state = new_state})
    end
end
    
    -- 注册事件
    if self.switch.add_event_cb then
        self.switch:add_event_cb(on_value_changed, lv.EVENT_VALUE_CHANGED, nil)
    end
    
    -- ========== 绑定事件方法（内部使用）==========
-- ========== 绑定事件方法（内部使用）==========
function self._bind_event(self)
    local event_action = self.props.event_action
    local bind_point = self.props.bind_point
    local on_value = self.props.on_value
    local off_value = self.props.off_value
    local url = self.props.websocket_url
    
    print("[Switch] 绑定事件: " .. (event_action or "none") .. ", 数据点: " .. (bind_point or "none"))
    
    if event_action == "读取绑定数据点" and bind_point and bind_point ~= "" then
        -- 读取模式：根据数据点值自动更新开关状态
        print("[Switch] 设置读取模式: " .. bind_point)
        
        -- 注册读取回调
        local callback = SitwchAction.create_callback("读取绑定数据点", {
            bind_point = bind_point,
            websocket_url = url,
            switch = self  -- 传入 switch 实例，用于更新状态
        })
        
        -- 存储回调以便后续使用
self._read_callback = callback

-- 立即执行一次读取
-- 延迟执行，确保WebSocket已连接
if lvgl and lvgl.timer_create then
    if callback then
        print("[Switch] 设置自动读取: " .. bind_point)
        
        -- 添加执行标志，确保只执行一次
        local executed = false
        
        lvgl.timer_create(function()
            -- 如果已经执行过，直接返回
            if executed then
                -- print("[定时器] 已经执行过，忽略")
                return
            end
            
            executed = true
            print("[Switch] 延迟读取数据点: " .. bind_point)
            callback()  -- 执行读取
        end, 500, nil)  -- 500ms后自动读取
    end
else
    -- 如果没有 timer_create，立即执行
    if callback then
        print("[Switch] 立即读取数据点: " .. bind_point)
        callback()
    end
end
        
    elseif event_action == "读写数据点" and bind_point and bind_point ~= "" then
        -- 读写模式：既能写入又能读取
        print("[Switch] 设置读写模式: " .. bind_point)
        
        -- 注册读写回调
        local callback = SitwchAction.create_callback("读写数据点", {
            bind_point = bind_point,
            write_value = {on = on_value, off = off_value},
            websocket_url = url,
            switch = self
        })
        
        if callback then
            callback()  -- 执行初始化
        end
    end
end
    
    -- ========== 必须实现的标准接口 ==========
    
    function self.on(self, event_name, callback)
        if event_name == "value_changed" then
            self._callbacks.value_changed = callback
        elseif event_name == "property_changed" then
            self._callbacks.property_changed = callback
        end
    end
    
    function self.get_container(self)
        return self.switch
    end
    
    function self.get_property(self, name)
        return self.props[name]
    end
    
    function self.set_property(self, name, value)
        local old_value = self.props[name]
        self.props[name] = value
        
        if not self.switch then
            return true
        end
        
        if name == "switch_state" then
            -- 更新开关状态
            if value then
                if self.switch.add_state then
                    self.switch:add_state(lv.STATE_CHECKED)
                end
                local bg_color_on = parse_color(self.props.bg_color_on or "#4CAF50")
                set_indicator_color(self, bg_color_on)
            else
                if self.switch.remove_state then
                    self.switch:remove_state(lv.STATE_CHECKED)
                end
                local bg_color_off = parse_color(self.props.bg_color_off or "#888888")
                set_indicator_color(self, bg_color_off)
            end
            
            -- 如果事件动作是写入绑定数据点，状态改变时立即写入
            if self.props.event_action == "写入绑定数据点" and self.props.bind_point and self.props.bind_point ~= "" then
                local write_value = value and self.props.on_value or self.props.off_value
                print("[Switch] 属性改变，写入: " .. self.props.bind_point .. " = " .. write_value)
                
                local callback = SitwchAction.create_callback("写入绑定数据点", {
                    bind_point = self.props.bind_point,
                    value = write_value,
                    websocket_url = self.props.websocket_url
                })
                if callback then
                    pcall(callback)
                end
            end
            
        elseif name == "x" or name == "y" then
            if self.switch.set_pos then
                self.switch:set_pos(self.props.x, self.props.y)
            end
            
        elseif name == "width" or name == "height" then
            if self.switch.set_size then
                self.switch:set_size(self.props.width, self.props.height)
            end
            
        elseif name == "bg_color_off" then
            if not self.props.switch_state then
                local color = parse_color(value)
                set_indicator_color(self, color)
            end
            
        elseif name == "bg_color_on" then
            if self.props.switch_state then
                local color = parse_color(value)
                set_indicator_color(self, color)
            end
            
        elseif name == "event_action" and value ~= old_value then
            -- 事件动作改变时，重新绑定
            self:_bind_event()
        end
        
        if self._callbacks.property_changed then
            self._callbacks.property_changed(name, value)
        end
        
        return true
    end
    
    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do 
            out[k] = v 
        end
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
    
    function self.get_id(self)
        if self.props.instance_name and self.props.instance_name ~= "" then
            return self.props.instance_name
        end
        return tostring(self)
    end

    -- 自动绑定事件（如果不是设计模式）
    if not self.props.design_mode then
        self:_bind_event()
    end

    return self
end

return Switch