local lv = require("lvgl")
local DataAction = require("editor.DataAction")

local Label = {}
Label.__index = Label

Label.__widget_meta = {
  id = "label",
  name = "Label",
  description = "文本标签控件，支持数据绑定动态更新文本",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    { name = "instance_name", type = "string", default = "", label = "实例名称" },
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
      options = { { value = "left", label = "左对齐" }, { value = "center", label = "居中" }, { value = "right", label = "右对齐" } }
    },
    { name = "long_mode", type = "enum", default = "wrap", label = "长文本模式",
      options = { { value = "wrap", label = "自动换行" }, { value = "scroll", label = "滚动" }, { value = "dot", label = "省略号" }, { value = "clip", label = "裁剪" } }
    },
    { name = "visible", type = "boolean", default = true, label = "可见" },
    { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    
    { name = "bind_point", type = "string", default = "", label = "绑定数据点" },
    { name = "display_format", type = "string", default = "%s", label = "显示格式" },
    { name = "websocket_url", type = "string", default = "", label = "WebSocket" },
    
    { name = "event_action", type = "enum", default = "读取绑定数据点",
      options = {"无动作", "读取绑定数据点", "读取自定义地址", "连接WebSocket", "发送HTTP请求"},
      label = "事件动作" },
    { name = "custom_address", type = "string", default = "", label = "自定义地址" },
    { name = "click_value", type = "string", default = "1", label = "点击值" },
    
    { name = "on_clicked_handler", type = "code", default = "", label = "点击处理代码", event = "clicked" },
    { name = "on_data_updated_handler", type = "code", default = "", label = "数据更新处理代码", event = "data_updated" },
  },
  events = { "clicked", "data_updated" },
}

local function parse_color(c)
  if type(c) == "string" then
    if c:match("^#%x%x%x%x%x%x%x%x$") then return tonumber(c:sub(4), 16)
    elseif c:match("^#%x%x%x%x%x%x$") then return tonumber(c:sub(2), 16) end
  elseif type(c) == "number" then return c end
  return 0xFFFFFF
end

local function get_long_mode(mode)
  if mode == "wrap" then return lv.LABEL_LONG_MODE_WRAP or lv.LABEL_LONG_WRAP or 0
  elseif mode == "scroll" then return lv.LABEL_LONG_MODE_SCROLL or lv.LABEL_LONG_SCROLL or 1
  elseif mode == "dot" then return lv.LABEL_LONG_MODE_DOT or lv.LABEL_LONG_DOT or 2
  elseif mode == "clip" then return lv.LABEL_LONG_MODE_CLIP or lv.LABEL_LONG_CLIP or 3 end
  return 0
end

local function get_text_align(align)
  if align == "left" then return lv.TEXT_ALIGN_LEFT or 0
  elseif align == "center" then return lv.TEXT_ALIGN_CENTER or 1
  elseif align == "right" then return lv.TEXT_ALIGN_RIGHT or 2 end
  return lv.TEXT_ALIGN_LEFT or 0
end

function Label.new(parent, state)
  state = state or {}
  local self = setmetatable({}, Label)
  
  self.props = {}
  for _, p in ipairs(Label.__widget_meta.properties) do
    self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
  end
  
  self._event_listeners = {}
  self._callbacks = {}
  self._update_timer = nil
  self._last_value = nil
  
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
  
  self.label = lv.label_create(self.container)
  self.label:set_text(self.props.text)
  self.label:set_style_text_color(parse_color(self.props.text_color), 0)
  self.label:set_size(self.props.width, self.props.height)
  
  if self.label.set_long_mode then
    self.label:set_long_mode(get_long_mode(self.props.long_mode))
  end
  
  self:_apply_alignment()
  
  if not self.props.visible then
    self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
  end
  
  local this = self
  self.container:add_event_cb(function(e)
    if self.props.design_mode then return end
    this:_on_clicked()
  end, lv.EVENT_CLICKED, nil)
  
  if not self.props.design_mode then
    self:_start_data_updates()
  end
  
  return self
end

function Label:_on_clicked()
  self:_emit("clicked")
  
  local event_action = self.props.event_action
  if event_action and event_action ~= "无动作" then
    if event_action == "读取绑定数据点" and self.props.bind_point ~= "" then
      local callback = DataAction.create_callback(event_action, { bind_point = self.props.bind_point })
      if callback then pcall(callback) end
    elseif event_action == "读取自定义地址" and self.props.custom_address ~= "" then
      local callback = DataAction.create_callback(event_action, { address = self.props.custom_address })
      if callback then pcall(callback) end
    elseif event_action == "连接WebSocket" and self.props.websocket_url ~= "" then
      local callback = DataAction.create_callback(event_action, { url = self.props.websocket_url })
      if callback then pcall(callback) end
    end
  end
end

function Label:_start_data_updates()
  if self.props.bind_point and self.props.bind_point ~= "" then
    self:_update_data()
  end
end

function Label:_update_data()
  if not self.props.bind_point or self.props.bind_point == "" then return end
  
  local callback = DataAction.create_callback("读取绑定数据点", {
    
    bind_point = self.props.bind_point,
    callback = function(data) self:_on_data_received(data) end
  })
  
  if callback then pcall(callback) end
end

function Label:_on_data_received(data)
  if data == nil or data == self._last_value then return end
  self._last_value = data
  
  local display_text = tostring(data)
  if self.props.display_format and self.props.display_format ~= "%s" then
    local success, result = pcall(string.format, self.props.display_format, data)
    if success then display_text = result end
  end
  
  if self.label and self.label.set_text then
    self.label:set_text(display_text)
  end
  
  self:_emit("data_updated", { value = data, display_text = display_text })
  
  if self._callbacks.data_updated then
    pcall(self._callbacks.data_updated, self, { value = data, display_text = display_text })
  end
end

function Label:_apply_alignment()
  if not self.label then return end
  
  if self.label.set_style_text_align then
    self.label:set_style_text_align(get_text_align(self.props.alignment), 0)
  end
  
  self.label:set_pos(0, 0)
  self.label:align(lv.ALIGN_CENTER, 0, 0)
end

function Label:on(event_name, callback)
  if event_name == "clicked" then
    self._callbacks.clicked = callback
  elseif event_name == "data_updated" then
    self._callbacks.data_updated = callback
  end
  
  if not self._event_listeners[event_name] then
    self._event_listeners[event_name] = {}
  end
  table.insert(self._event_listeners[event_name], callback)
  
  if event_name == "clicked" and not self.props.design_mode then
    self.container:add_flag(lv.OBJ_FLAG_CLICKABLE)
  end
end

function Label:_emit(event_name, ...)
  local listeners = self._event_listeners[event_name]
  if listeners then
    for _, cb in ipairs(listeners) do
      local ok, err = pcall(cb, self, ...)
      if not ok then print("[Label] 事件回调错误:", err) end
    end
  end
end

function Label:get_property(name)
  return self.props[name]
end

function Label:set_property(name, value)
  self.props[name] = value
  
  if name == "text" then
    if self.label then self.label:set_text(value) end
  elseif name == "text_color" then
    if self.label then self.label:set_style_text_color(parse_color(value), 0) end
  elseif name == "bg_color" then
    if self.container then self.container:set_style_bg_color(parse_color(value), 0) end
  elseif name == "bg_opa" then
    if self.container then self.container:set_style_bg_opa(value, 0) end
  elseif name == "x" or name == "y" then
    if self.container then self.container:set_pos(self.props.x, self.props.y) end
  elseif name == "width" then
    if self.container then self.container:set_width(value) end
    if self.label then self.label:set_width(value); self:_apply_alignment() end
  elseif name == "height" then
    if self.container then self.container:set_height(value) end
    if self.label then self.label:set_height(value); self:_apply_alignment() end
  elseif name == "alignment" then
    self:_apply_alignment()
  elseif name == "long_mode" then
    if self.label and self.label.set_long_mode then
      self.label:set_long_mode(get_long_mode(value))
    end
  elseif name == "visible" then
    if self.container then
      if value then self.container:remove_flag(lv.OBJ_FLAG_HIDDEN)
      else self.container:add_flag(lv.OBJ_FLAG_HIDDEN) end
    end
  elseif name == "design_mode" then
    if value then
      self.container:remove_flag(lv.OBJ_FLAG_CLICKABLE)
      if self._update_timer then lv.timer_del(self._update_timer); self._update_timer = nil end
    else
      self:_start_data_updates()
    end
  elseif name == "bind_point" then
    if not self.props.design_mode then
      self:_start_data_updates()
    end
  elseif name == "display_format" and self._last_value then
    self:_on_data_received(self._last_value)
  end
  
  return true
end

function Label:get_properties()
  local out = {}
  for k, v in pairs(self.props) do out[k] = v end
  return out
end

function Label:apply_properties(props_table)
  for k, v in pairs(props_table) do self:set_property(k, v) end
  return true
end

function Label:to_state()
  return self:get_properties()
end

function Label:get_container()
  return self.container
end

function Label:set_text(text)
  self:set_property("text", text)
end

function Label:get_text()
  return self.props.text
end

function Label:show()
  self:set_property("visible", true)
end

function Label:hide()
  self:set_property("visible", false)
end

function Label:refresh()
  self:_update_data()
end

function Label:destroy()
  if self._update_timer then lv.timer_del(self._update_timer); self._update_timer = nil end
  if self.container then self.container:delete(); self.container = nil; self.label = nil end
end

return Label