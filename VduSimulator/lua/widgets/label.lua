-- Label.lua
-- 文本标签控件，用于显示静态或动态文本
local lv = require("lvgl")

local Label = {}
Label.__index = Label

Label.__widget_meta = {
  id = "label",
  name = "Label",
  description = "文本标签控件，用于显示静态或动态文本",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    -- 实例名称（用于编译时变量命名）
    { name = "instance_name", type = "string", default = "", label = "实例名称",
      description = "用于编译时的变量名，留空则自动生成" },
    { name = "text", type = "string", default = "Label", label = "文本" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 100, label = "宽度" },
    { name = "height", type = "number", default = 30, label = "高度" },
    { name = "text_color", type = "color", default = "#FFFFFF", label = "文本颜色" },
    { name = "bg_color", type = "color", default = "#00000000", label = "背景色" },
    { name = "bg_opa", type = "number", default = 0, label = "背景透明度", min = 0, max = 255 },
    { name = "font_size", type = "number", default = 16, label = "字体大小" },
    { name = "alignment", type = "enum", default = "left", label = "对齐方式",
      options = {
        { value = "left", label = "左对齐" },
        { value = "center", label = "居中" },
        { value = "right", label = "右对齐" },
      }
    },
    { name = "long_mode", type = "enum", default = "wrap", label = "长文本模式",
      options = {
        { value = "wrap", label = "自动换行" },
        { value = "scroll", label = "滚动" },
        { value = "dot", label = "省略号" },
        { value = "clip", label = "裁剪" },
      }
    },
    { name = "visible", type = "boolean", default = true, label = "可见" },
    { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    -- 事件处理代码属性
    { name = "on_clicked_handler", type = "code", default = "", label = "点击处理代码",
      event = "clicked", description = "点击标签时执行的Lua代码" },
  },
  events = { "clicked" },
}

-- 解析颜色值（支持 "#RRGGBB" 或 "#AARRGGBB" 字符串或数字）
local function parse_color(c)
  if type(c) == "string" then
    if c:match("^#%x%x%x%x%x%x%x%x$") then
      -- #AARRGGBB 格式，忽略 alpha
      return tonumber(c:sub(4), 16)
    elseif c:match("^#%x%x%x%x%x%x$") then
      return tonumber(c:sub(2), 16)
    end
  elseif type(c) == "number" then
    return c
  end
  return 0xFFFFFF
end

-- 获取 long_mode 枚举值
local function get_long_mode(mode)
  if mode == "wrap" then
    return lv.LABEL_LONG_MODE_WRAP or lv.LABEL_LONG_WRAP or 0
  elseif mode == "scroll" then
    return lv.LABEL_LONG_MODE_SCROLL or lv.LABEL_LONG_SCROLL or 1
  elseif mode == "dot" then
    return lv.LABEL_LONG_MODE_DOT or lv.LABEL_LONG_DOT or 2
  elseif mode == "clip" then
    return lv.LABEL_LONG_MODE_CLIP or lv.LABEL_LONG_CLIP or 3
  end
  return 0
end

-- 获取文本对齐枚举值
local function get_text_align(align)
  if align == "left" then
    return lv.TEXT_ALIGN_LEFT or 0
  elseif align == "center" then
    return lv.TEXT_ALIGN_CENTER or 1
  elseif align == "right" then
    return lv.TEXT_ALIGN_RIGHT or 2
  end
  return lv.TEXT_ALIGN_LEFT or 0
end

-- 构造函数
function Label.new(parent, state)
  state = state or {}
  local self = setmetatable({}, Label)
  
  -- 初始化属性
  self.props = {}
  for _, p in ipairs(Label.__widget_meta.properties) do
    if state[p.name] ~= nil then
      self.props[p.name] = state[p.name]
    else
      self.props[p.name] = p.default
    end
  end
  
  -- 事件监听器
  self._event_listeners = {}
  
  -- 创建容器（用于设置背景和尺寸）
  self.container = lv.obj_create(parent)
  self.container:set_pos(self.props.x, self.props.y)
  self.container:set_size(self.props.width, self.props.height)
  self.container:set_style_bg_color(parse_color(self.props.bg_color), 0)
  self.container:set_style_bg_opa(self.props.bg_opa, 0)
  self.container:set_style_radius(0, 0)
  self.container:set_style_border_width(0, 0)
  self.container:set_style_pad_all(0, 0)
  self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
  self.container:clear_layout()
  
  -- 创建标签
  self.label = lv.label_create(self.container)
  self.label:set_text(self.props.text)
  self.label:set_style_text_color(parse_color(self.props.text_color), 0)
  
  -- 设置标签尺寸与容器一致
  self.label:set_size(self.props.width, self.props.height)
  
  -- 设置长文本模式
  if self.label.set_long_mode then
    self.label:set_long_mode(get_long_mode(self.props.long_mode))
  end
  
  -- 设置文本对齐方式
  self:_apply_alignment()
  
  -- 设置可见性
  if not self.props.visible then
    self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
  end
  
  -- 设置点击事件（用于设计模式下的选中）
  local this = self
  self.container:add_event_cb(function(e)
    if not this.props.design_mode then
      this:_emit("clicked")
    end
  end, lv.EVENT_CLICKED, nil)
  
  return self
end

-- 应用对齐方式
function Label:_apply_alignment()
  if not self.label then return end
  
  local align = self.props.alignment
  
  -- 使用 set_style_text_align 设置文本对齐
  if self.label.set_style_text_align then
    self.label:set_style_text_align(get_text_align(align), 0)
  end
  
  -- 同时设置标签在容器中的垂直居中位置
  self.label:set_pos(0, 0)
  self.label:align(lv.ALIGN_CENTER, 0, 0)
end

-- 事件订阅
function Label:on(event_name, callback)
  if not self._event_listeners[event_name] then
    self._event_listeners[event_name] = {}
  end
  table.insert(self._event_listeners[event_name], callback)
  
  -- 如果是点击事件，确保容器可点击
  if event_name == "clicked" and not self.props.design_mode then
    self.container:add_flag(lv.OBJ_FLAG_CLICKABLE)
  end
end

-- 触发事件
function Label:_emit(event_name, ...)
  local listeners = self._event_listeners[event_name]
  if listeners then
    for _, cb in ipairs(listeners) do
      local ok, err = pcall(cb, self, ...)
      if not ok then
        print("[Label] 事件回调错误:", err)
      end
    end
  end
end

-- 获取属性
function Label:get_property(name)
  return self.props[name]
end

-- 设置属性
function Label:set_property(name, value)
  self.props[name] = value
  
  if name == "text" then
    if self.label and self.label.set_text then
      self.label:set_text(value)
    end
  elseif name == "text_color" then
    local color = parse_color(value)
    if self.label then
      self.label:set_style_text_color(color, 0)
    end
  elseif name == "bg_color" then
    local color = parse_color(value)
    if self.container then
      self.container:set_style_bg_color(color, 0)
    end
  elseif name == "bg_opa" then
    if self.container then
      self.container:set_style_bg_opa(value, 0)
    end
  elseif name == "x" or name == "y" then
    if self.container then
      self.container:set_pos(self.props.x, self.props.y)
    end
  elseif name == "width" then
    if self.container then
      self.container:set_width(value)
    end
    if self.label then
      self.label:set_width(value)
      self:_apply_alignment()
    end
  elseif name == "height" then
    if self.container then
      self.container:set_height(value)
    end
    if self.label then
      self.label:set_height(value)
      self:_apply_alignment()
    end
  elseif name == "alignment" then
    self:_apply_alignment()
  elseif name == "long_mode" then
    if self.label and self.label.set_long_mode then
      self.label:set_long_mode(get_long_mode(value))
    end
  elseif name == "visible" then
    if self.container then
      if value then
        self.container:remove_flag(lv.OBJ_FLAG_HIDDEN)
      else
        self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
      end
    end
  elseif name == "design_mode" then
    -- 设计模式下禁用点击事件
    if value then
      self.container:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    end
  elseif name:match("^on_.*_handler$") then
    local event_name = name:match("^on_(.*)_handler$")
    if event_name then
      print("[Label] 事件处理代码已更新: " .. event_name)
    end
  end
  
  return true
end

-- 获取所有属性
function Label:get_properties()
  local out = {}
  for k, v in pairs(self.props) do
    out[k] = v
  end
  return out
end

-- 应用属性表
function Label:apply_properties(props_table)
  for k, v in pairs(props_table) do
    self:set_property(k, v)
  end
  return true
end

-- 导出状态（用于保存）
function Label:to_state()
  return self:get_properties()
end

-- 获取容器对象
function Label:get_container()
  return self.container
end

-- 设置文本（便捷方法）
function Label:set_text(text)
  self:set_property("text", text)
end

-- 获取文本（便捷方法）
function Label:get_text()
  return self.props.text
end

-- 显示
function Label:show()
  self:set_property("visible", true)
end

-- 隐藏
function Label:hide()
  self:set_property("visible", false)
end

-- 销毁控件
function Label:destroy()
  if self.container then
    self.container:delete()
    self.container = nil
    self.label = nil
  end
end

return Label
