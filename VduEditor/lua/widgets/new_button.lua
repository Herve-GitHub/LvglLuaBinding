-- Button.lua - 修改版
-- 带元数据的按钮示例，添加数据配置支持
local lv = require("lvgl")
local gen = require("general")
local DataAction = require("editor.DataAction")

local Button = {}

Button.__widget_meta = {
  id = "custom_button",
  name = "Custom Button",
  description = "示例按钮，包含数据绑定和事件配置",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    -- 实例名称（用于编译时变量命名）
    { name = "instance_name", type = "string", default = "", label = "实例名称",
      description = "用于编译时的变量名，留空则自动生成" },
    { name = "label", type = "string", default = "OK", label = "文本" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 100, label = "宽度" },
    { name = "height", type = "number", default = 40, label = "高度" },
    { name = "color", type = "color", default = "#ffffff", label = "文本颜色" },
    { name = "font_size", type = "number", default = 16, label = "字体大小" },
    { name = "alignment", type = "string", default = "center", label = "对齐方式" },
    { name = "bg_color", type = "color", default = "#007acc", label = "背景色" },
    { name = "enabled", type = "boolean", default = true, label = "启用" },
    { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    
   -- 数据配置 - 这些属性会被数据编辑器修改
    { name = "bind_point", type = "string", default = "", label = "绑定数据点",
      description = "例如: Device1.E, PLC1.D100" },
    { name = "websocket_url", type = "string", default = "", label = "WebSocket",
      description = "例如: ws://192.168.1.100:8080" },
    { name = "http_data_type", type = "enum", default = "实时数据", 
      options = {"实时数据", "历史数据", "批量数据", "告警数据", "统计数据"},
      label = "HTTP" },
    { name = "http_url", type = "string", default = "", label = "HTTP URL",
      description = "例如: http://192.168.1.100/api/data" },
    { name = "http_token", type = "string", default = "", label = "HTTP Token",
      description = "认证令牌" },
      -- 在控件的 __widget_meta.properties 中添加
{ name = "compare_operator", type = "string", default = "大于", label = "比较运算符" },
{ name = "compare_value", type = "string", default = "0", label = "比较值" },
{ name = "true_color", type = "color", default = "#ffffff", label = "条件满足时文本颜色" },
{ name = "false_color", type = "color", default = "#ffffff", label = "条件不满足时文本颜色" },
{ name = "true_bg_color", type = "color", default = "#ffffff", label = "条件满足时背景颜色" },
{ name = "false_bg_color", type = "color", default = "#ffffff", label = "条件不满足时背景颜色" },
    
    -- 事件配置 - 这些属性会被事件编辑器修改
    { name = "event_action", type = "enum", default = "写入绑定数据点",
      options = {"写入绑定数据点", "读取绑定数据点", "读写数据点",  -- 将"连接WebSocket"改为"读写数据点"
                 "写入自定义地址", "读取自定义地址", "发送HTTP请求"},
      label = "事件动作", description = "点击时执行的动作" },
    { name = "custom_address", type = "string", default = "", label = "自定义地址",
      description = "写入/读取自定义地址时使用" },
    { name = "custom_value", type = "string", default = "", label = "写入值",
      description = "写入自定义地址时的值" },
    
    -- 原始代码事件处理（保持兼容）
    { name = "on_clicked_handler", type = "code", default = "", label = "点击处理代码",
      event = "clicked", description = "点击按钮时执行的Lua代码" },
    { name = "on_single_clicked_handler", type = "code", default = "", label = "单击处理代码",
      event = "single_clicked", description = "单击按钮时执行的Lua代码" },
    { name = "on_double_clicked_handler", type = "code", default = "", label = "双击处理代码",
      event = "double_clicked", description = "双击按钮时执行的Lua代码" },
  },
  events = { "clicked", "single_clicked", "double_clicked" },
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
    -- 背景色
    local bg_color = parse_color(self.props.bg_color or "#007acc")
    if self.btn and self.btn.set_style_bg_color then
        if self.props.enabled then
            self.btn:set_style_bg_color(bg_color, 0)
        else
            self.btn:set_style_bg_color(0x888888, 0)
        end
    end
    
    -- 文本颜色
    local text_color = parse_color(self.props.color or "#ffffff")
    if self.label and self.label.set_style_text_color then
        self.label:set_style_text_color(text_color, 0)
    end
end

-- new(parent, state)
function Button.new(parent, state)
    state = state or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(Button.__widget_meta.properties) do
        if state[p.name] ~= nil then
            self.props[p.name] = state[p.name]
        else
            self.props[p.name] = p.default
        end
    end
    
    -- 创建 lv 按钮与标签
    self.btn = lv.button_create(parent)
    self.btn:set_size(self.props.width, self.props.height)
    self.btn:set_pos(self.props.x, self.props.y)

    self.label = lv.label_create(self.btn)
    self.label:set_text(self.props.label)
    self.label:center()
    
    -- 应用样式
    apply_styles(self)
    
    -- 保存回调
    self._callbacks = {}
    
    -- ===== 必须实现的标准接口 =====
    
    -- on: 事件订阅
    function self.on(self, event_name, callback)
        local function create_safe_callback()
            return function(e)
                if not self.props.enabled then return end
                if self.props.design_mode then 
                    print("[Button] 设计模式，忽略事件")
                    return 
                end
                local ok, err = pcall(callback, self, e)
                if not ok then 
                    print("[button] callback error:", err) 
                end
            end
        end

        if event_name == "clicked" then
            local evt_cb = create_safe_callback()
            self._callbacks.clicked = evt_cb
            local ev_code = lv.EVENT_CLICKED
            if self.btn.add_event_cb then
                self.btn:add_event_cb(evt_cb, ev_code, nil)
            end
        elseif event_name == "single_clicked" then
            local evt_cb = create_safe_callback()
            self._callbacks.single_clicked = evt_cb
            local ev_code = lv.EVENT_SINGLE_CLICKED
            if self.btn.add_event_cb then
                self.btn:add_event_cb(evt_cb, ev_code, nil)
            end
        elseif event_name == "double_clicked" then
            local evt_cb = create_safe_callback()
            self._callbacks.double_clicked = evt_cb
            local ev_code = lv.EVENT_DOUBLE_CLICKED
            if self.btn.add_event_cb then
                self.btn:add_event_cb(evt_cb, ev_code, nil)
            end
        end
    end
    
    -- get_container: 获取LVGL容器对象
    function self.get_container(self)
        return self.btn
    end
    
    -- get_property: 获取属性值
    function self.get_property(self, name)
        return self.props[name]
    end
    
    -- set_property: 设置属性值
    function self.set_property(self, name, value)
        local old_value = self.props[name]
        self.props[name] = value
        
        if name == "label" then
            if self.label and self.label.set_text then
                self.label:set_text(value)
            end
        elseif name == "color" or name == "bg_color" or name == "enabled" then
            apply_styles(self)
        elseif name == "x" or name == "y" then
            self.btn:set_pos(self.props.x, self.props.y)
        elseif name == "width" or name == "height" then
            self.btn:set_size(self.props.width, self.props.height)
        elseif name == "event_action" and value ~= old_value then
            print("[Button] 事件动作更新为: " .. tostring(value))
            if not self.props.design_mode then
                self:_bind_event()
            end
        end
        
        return true
    end
    
    -- get_properties: 获取所有属性
    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do out[k] = v end
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
    
    -- 设置标签的便捷方法
    function self.set_label(self, new_text)
        if self.label and self.label.set_text then
            self.label:set_text(new_text)
            self.props.label = new_text
            print("[Button] 标签已更新: " .. new_text)
        end
    end
    
    -- 绑定事件（内部使用）
  -- 绑定事件（内部使用）
function self._bind_event(self)
    local event_action = self.props.event_action
    local bind_point = self.props.bind_point
    local value = self.props.custom_value or "1"
    local url = self.props.websocket_url
    
    -- 先清除旧的回调
    if self._callbacks.clicked then
        -- 注意：这里无法直接移除事件回调，需要更复杂的处理
        -- 简单起见，我们假设每次绑定前都是干净的
    end
    
    if event_action == "写入绑定数据点" and bind_point and bind_point ~= "" then
        local callback = DataAction.create_callback(event_action, {
            bind_point = bind_point,
            value = value,
            websocket_url = url,
            button = self
        })
        if callback then
            self:on("clicked", callback)
            print("[Button] 已绑定写入事件: " .. bind_point .. " = " .. value)
        end
        
    elseif event_action == "读取绑定数据点" and bind_point and bind_point ~= "" then
    
    local callback = DataAction.create_callback(event_action, {
        bind_point = bind_point,
        websocket_url = url,
        button = self
    })
    
    if callback then
        print("[Button] 设置自动读取: " .. bind_point)
        
        -- 添加执行标志
        local executed = false
        
        lvgl.timer_create(function()
            -- 如果已经执行过，直接返回
            if executed then
              --  print("[定时器] 已经执行过，忽略")
                return
            end
            
            executed = true
            print("[定时器] 第1次执行")
            callback()
        end, 500, nil)
    end
        
    elseif event_action == "读写数据点" and bind_point and bind_point ~= "" then
        -- 先初始化读写模式（注册按钮，开始接收数据）
         local init_callback = DataAction.create_callback(event_action, {
            bind_point = bind_point,
            write_value = value,
            websocket_url = url,
            button = self
        })
        
        if init_callback then
            -- 执行初始化
            init_callback()
            print("[Button] 读写模式已初始化: " .. bind_point .. "，写入值: " .. value)
        end 
        
        -- 绑定点击事件 - 直接执行写入操作
        self:on("clicked", function()
            print("[Button] 读写模式按钮点击，执行写入: " .. bind_point .. " = " .. value)
            
            -- 直接调用写入函数
            if lvgl then
                lvgl.write(bind_point, value)
                lvgl.read(bind_point)
            else
                print("[Button] 错误: lvgl 不存在")
            end
        end)
        
        -- 立即执行一次读取，获取当前值
       -- if lvgl then
         --   print("[Button] 首次读取数据点: " .. bind_point)
         --   lvgl.read(bind_point)
      --  end
        
    else
        if event_action ~= "写入绑定数据点" and event_action ~= "读取绑定数据点" and 
           event_action ~= "读写数据点" then
            print("[Button] 未绑定事件: " .. tostring(event_action))
        elseif not bind_point or bind_point == "" then
            print("[Button] 未绑定事件: 数据点为空")
        end
    end
end

    -- 自动绑定事件（如果不是设计模式）
    if not self.props.design_mode then
        self:_bind_event()
    end

    return self
end

return Button