-- StatusBar.lua
-- 状态栏组件，独立于画布，显示在编辑器顶部或底部
local lv = require("lvgl")

local StatusBar = {}
StatusBar.__index = StatusBar

StatusBar.__widget_meta = {
  id = "status_bar",
  name = "Status Bar",
  description = "状态栏组件，独立于画布，可放置于顶部或底部",
  schema_version = "1.0",
  version = "1.0",
  -- 标记为全局组件，不绘制在画布中
  is_global = true,
  properties = {
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 800, label = "宽度" },
    { name = "height", type = "number", default = 28, label = "高度" },
    { name = "bg_color", type = "color", default = "#252526", label = "背景色" },
    { name = "text_color", type = "color", default = "#CCCCCC", label = "文本颜色" },
    { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    { name = "show_time", type = "boolean", default = true, label = "显示时间" },
    { name = "position", type = "string", default = "bottom", label = "位置(top/bottom)" },
    { name = "lamp_status", type = "color", default = "#00FF00", label = "通道状态" },
    { name = "lamp_text", type = "string", default = "CH1", label = "通道名称" },
    { name = "lamp_size", type = "number", default = 14, label = "状态灯大小" },
  },
  events = { "updated", "time_tick" },
}

-- 解析颜色值（支持 "#RRGGBB" 字符串或数字）
local function parse_color(c)
  if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
    return tonumber(c:sub(2), 16)
  elseif type(c) == "number" then
    return c
  end
  return 0xFFFFFF
end

-- 获取当前时间字符串
local function get_time_string()
  return os.date("%H:%M:%S")
end

-- 获取当前日期字符串
local function get_date_string()
  return os.date("%Y-%m-%d")
end

function StatusBar.new(parent, state)
  state = state or {}
  local self = setmetatable({}, StatusBar)
  
  -- 初始化属性
  self.props = {}
  for _, p in ipairs(StatusBar.__widget_meta.properties) do
    self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
  end
  
  -- 保存父元素引用
  self._parent = parent
  
  -- 定时器引用（暂时禁用，因为 lv.timer_create 未实现）
  self._timer = nil
  self._timer_running = false
  
  -- 事件监听器
  self._event_listeners = {}
  
  -- 创建主容器
  self.container = lv.obj_create(parent)
  self.container:set_size(self.props.width, self.props.height)
  self.container:set_pos(self.props.x, self.props.y)
  self.container:set_style_bg_color(parse_color(self.props.bg_color), 0)
  self.container:set_style_bg_opa(255, 0)
  self.container:set_style_radius(0, 0)
  self.container:set_style_border_width(1, 0)
  self.container:set_style_border_color(0x3C3C3C, 0)
  self.container:set_style_pad_left(10, 0)
  self.container:set_style_pad_right(10, 0)
  self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
  self.container:remove_flag(lv.OBJ_FLAG_CLICKABLE)
  self.container:clear_layout()
  
  -- 创建通道状态灯（左侧）
  self:_create_status_lamp()
  
  -- 创建日期显示（中间）
  self:_create_date_display()
  
  -- 创建时间显示（右侧）
  self:_create_time_display()
  
  return self
end

-- 创建通道状态灯
function StatusBar:_create_status_lamp()
  local lamp_size = self.props.lamp_size
  local container_height = self.props.height
  local y_offset = math.floor((container_height - lamp_size) / 2)
  
  -- 状态灯（圆形）
  self.lamp = lv.obj_create(self.container)
  self.lamp:set_pos(0, y_offset)
  self.lamp:set_size(lamp_size, lamp_size)
  self.lamp:set_style_bg_color(parse_color(self.props.lamp_status), 0)
  self.lamp:set_style_bg_opa(255, 0)
  self.lamp:set_style_radius(math.floor(lamp_size / 2), 0)  -- 圆形
  self.lamp:set_style_border_width(1, 0)
  self.lamp:set_style_border_color(0x555555, 0)
  self.lamp:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
  self.lamp:remove_flag(lv.OBJ_FLAG_CLICKABLE)
  
  -- 状态文字标签
  self.lamp_label = lv.label_create(self.container)
  self.lamp_label:set_text(self.props.lamp_text)
  self.lamp_label:set_style_text_color(parse_color(self.props.text_color), 0)
  self.lamp_label:set_pos(lamp_size + 6, y_offset)
end

-- 创建时间显示
function StatusBar:_create_time_display()
  self.time_label = lv.label_create(self.container)
  -- 设计模式下显示固定时间，运行模式显示当前时间
  if self.props.design_mode then
    self.time_label:set_text("00:00:00")
  else
    self.time_label:set_text(get_time_string())
  end
  self.time_label:set_style_text_color(parse_color(self.props.text_color), 0)
  self.time_label:align(lv.ALIGN_RIGHT_MID, -8, 0)
  
  if not self.props.show_time then
    self.time_label:add_flag(lv.OBJ_FLAG_HIDDEN)
  end
end

-- 创建日期显示
function StatusBar:_create_date_display()
  self.date_label = lv.label_create(self.container)
  -- 设计模式下显示固定日期，运行模式显示当前日期
  if self.props.design_mode then
    self.date_label:set_text("0000-00-00")
  else
    self.date_label:set_text(get_date_string())
  end
  self.date_label:set_style_text_color(parse_color(self.props.text_color), 0)
  self.date_label:center()
end

-- 更新时间显示
function StatusBar:_update_time()
  -- 设计模式下不更新时间
  if self.props.design_mode then
    return
  end
  
  if self.time_label then
    self.time_label:set_text(get_time_string())
  end
  if self.date_label then
    self.date_label:set_text(get_date_string())
  end
  self:_emit("time_tick", get_time_string())
end

-- 启动定时器（暂时禁用，因为 timer_create 未实现）
function StatusBar:start()
  -- 设计模式下不启动定时器
  if self.props.design_mode then
    return
  end
  
  -- 注意：lv.timer_create 尚未在 Lua 绑定中实现
  -- 目前仅更新一次时间
  self:_update_time()
  self._timer_running = true
end

-- 停止定时器
function StatusBar:stop()
  self._timer_running = false
end

-- 设置通道状态灯颜色
function StatusBar:set_lamp_status(color)
  self.props.lamp_status = color
  if self.lamp then
    self.lamp:set_style_bg_color(parse_color(color), 0)
  end
  self:_emit("updated", "lamp_status", color)
end

-- 获取通道状态灯颜色
function StatusBar:get_lamp_status()
  return self.props.lamp_status
end

-- 设置通道标签文字
function StatusBar:set_lamp_text(text)
  self.props.lamp_text = text
  if self.lamp_label then
    self.lamp_label:set_text(text)
  end
end

-- 设置位置（top/bottom）
function StatusBar:set_position(position)
  self.props.position = position
  self:_emit("position_changed", position)
end

-- 获取位置
function StatusBar:get_position()
  return self.props.position
end

-- 显示/隐藏时间
function StatusBar:set_show_time(show)
  self.props.show_time = show
  if self.time_label then
    if show then
      self.time_label:remove_flag(lv.OBJ_FLAG_HIDDEN)
    else
      self.time_label:add_flag(lv.OBJ_FLAG_HIDDEN)
    end
  end
end

-- 显示状态栏
function StatusBar:show()
  if self.container then
    self.container:remove_flag(lv.OBJ_FLAG_HIDDEN)
  end
end

-- 隐藏状态栏
function StatusBar:hide()
  if self.container then
    self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
  end
end

-- 设置宽度（用于响应窗口大小变化）
function StatusBar:set_width(width)
  self.props.width = width
  if self.container then
    self.container:set_width(width)
    -- 重新居中日期标签
    if self.date_label then
      self.date_label:center()
    end
    -- 重新对齐时间标签
    if self.time_label then
      self.time_label:align(lv.ALIGN_RIGHT_MID, -8, 0)
    end
  end
end

-- 设置设计模式
function StatusBar:set_design_mode(enabled)
  self.props.design_mode = enabled
  
  if enabled then
    -- 进入设计模式：停止定时器，显示固定时间
    self:stop()
    if self.time_label then
      self.time_label:set_text("00:00:00")
    end
    if self.date_label then
      self.date_label:set_text("0000-00-00")
    end
  else
    -- 退出设计模式：立即更新时间并启动定时器
    if self.time_label then
      self.time_label:set_text(get_time_string())
    end
    if self.date_label then
      self.date_label:set_text(get_date_string())
    end
    self:start()
  end
end

-- 获取设计模式状态
function StatusBar:is_design_mode()
  return self.props.design_mode
end

-- 事件订阅
function StatusBar:on(event_name, callback)
  if not self._event_listeners[event_name] then
    self._event_listeners[event_name] = {}
  end
  table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function StatusBar:_emit(event_name, ...)
  local listeners = self._event_listeners[event_name]
  if listeners then
    for _, cb in ipairs(listeners) do
      local ok, err = pcall(cb, self, ...)
      if not ok then
        print("[StatusBar] 事件回调错误:", err)
      end
    end
  end
end

-- 获取属性
function StatusBar:get_property(name)
  return self.props[name]
end

-- 设置属性
function StatusBar:set_property(name, value)
  self.props[name] = value
  
  if name == "x" or name == "y" then
    self.container:set_pos(self.props.x, self.props.y)
  elseif name == "width" then
    self:set_width(value)
  elseif name == "height" then
    self.container:set_height(value)
  elseif name == "bg_color" then
    self.container:set_style_bg_color(parse_color(value), 0)
  elseif name == "text_color" then
    local color = parse_color(value)
    if self.time_label then
      self.time_label:set_style_text_color(color, 0)
    end
    if self.date_label then
      self.date_label:set_style_text_color(color, 0)
    end
    if self.lamp_label then
      self.lamp_label:set_style_text_color(color, 0)
    end
  elseif name == "lamp_status" then
    self:set_lamp_status(value)
  elseif name == "lamp_text" then
    self:set_lamp_text(value)
  elseif name == "show_time" then
    self:set_show_time(value)
  elseif name == "position" then
    self:set_position(value)
  elseif name == "design_mode" then
    self:set_design_mode(value)
  end
  
  return true
end

-- 获取所有属性
function StatusBar:get_properties()
  local out = {}
  for k, v in pairs(self.props) do
    out[k] = v
  end
  return out
end

-- 应用属性表
function StatusBar:apply_properties(props_table)
  for k, v in pairs(props_table) do
    self:set_property(k, v)
  end
  return true
end

-- 导出状态（用于保存）
function StatusBar:to_state()
  return self:get_properties()
end

-- 获取容器对象
function StatusBar:get_container()
  return self.container
end

-- 销毁组件
function StatusBar:destroy()
  self:stop()
  if self.container then
    self.container:delete()
    self.container = nil
  end
end

return StatusBar

