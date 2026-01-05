-- 带元数据的按钮示例，演示如何将属性暴露给编辑器
local lv = require("lvgl")

local Button = {}

Button.__widget_meta = {
  id = "custom_button",
  name = "Custom Button",
  description = "示例按钮，包含 label 与尺寸/位置属性",
  schema_version = "1.0",
  version = "1.0",
  properties = {
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
  },
  events = { "clicked", "single_clicked", "double_clicked" },
}

-- new(parent, state)
function Button.new(parent, state)
  state = state or {}
  local self = {}

  -- 初始化属性
  self.props = {}
  for _, p in ipairs(Button.__widget_meta.properties) do
    self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
  end

  -- 创建 lv 按钮与标签 (使用 button_create 而不是 btn_create)
  self.btn = lv.button_create(parent)
  self.btn:set_size(self.props.width, self.props.height)
  self.btn:set_pos(self.props.x, self.props.y)

  self.label = lv.label_create(self.btn)
  self.label:set_text(self.props.label)
  self.label:center()
  
  -- 事件订阅：统一接口 on(event_name, callback)
  -- callback(self, ...) 将在事件触发时被调用
  function self.on(self, event_name, callback)
    -- 设计模式下不注册事件
    if self.props.design_mode then return end
    
    -- 定义通用的内部回调处理逻辑
    local function create_safe_callback()
      return function(e)
          if not self.props.enabled then return end
          if self.props.design_mode then return end
          local ok, err = pcall(callback, self)
          if not ok then print("[button] callback error:", err) end
      end
    end

    -- 处理普通点击 (Clicked)
    if event_name == "clicked" then
      local evt_cb = create_safe_callback()
      local ev_code = lv.EVENT_CLICKED
      if self.btn.add_event_cb then
        self.btn:add_event_cb(evt_cb, ev_code, nil)
      elseif lv.obj_add_event_cb then
        lv.obj_add_event_cb(self.btn, evt_cb, ev_code, nil)
      end
    end

    -- 处理单次点击 (Single Clicked - 兼容双击)
    if event_name == "single_clicked" then
      local evt_cb = create_safe_callback()
      local ev_code = lv.EVENT_SINGLE_CLICKED
      if self.btn.add_event_cb then
        self.btn:add_event_cb(evt_cb, ev_code, nil)
      elseif lv.obj_add_event_cb then
        lv.obj_add_event_cb(self.btn, evt_cb, ev_code, nil)
      end
    end

    -- 处理双击事件
    if event_name == "double_clicked" then
      local evt_cb = create_safe_callback()
      local ev_code = lv.EVENT_DOUBLE_CLICKED
      
      -- 优先使用对象方法注册（Lua 绑定通常提供 obj:add_event_cb）
      if self.btn.add_event_cb then
        self.btn:add_event_cb(evt_cb, ev_code, nil)
      elseif lv.obj_add_event_cb then
        lv.obj_add_event_cb(self.btn, evt_cb, ev_code, nil)
      end
    end

  end

  function self.get_property(self, name)
    return self.props[name]
  end

  function self.set_property(self, name, value)
    self.props[name] = value
    if name == "label" then
      -- use object method
      if self.label and self.label.set_text then
        self.label:set_text(value)
      end
    elseif name == "bg_color" then
      -- 支持字符串 "#RRGGBB" 或 数字
      local function parse_color(c)
        if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
          return tonumber(c:sub(2), 16)
        elseif type(c) == "number" then
          return c
        end
        return 0x007acc
      end
      local col = parse_color(value)
      if self.btn.set_style_bg_color then
        self.btn:set_style_bg_color(col, 0)
      else
        -- fallback: try lv.obj_set_style_bg_color if available
        if lv.obj_set_style_bg_color then lv.obj_set_style_bg_color(self.btn, col, 0) end
      end
    elseif name == "x" or name == "y" then
      self.btn:set_pos(self.props.x, self.props.y)
    elseif name == "width" or name == "height" then
      self.btn:set_size(self.props.width, self.props.height)
    elseif name == "enabled" then
      -- store flag only; event handler will respect this flag
      if not value then
        -- visually dim the button when disabled if possible
        if self.btn and self.btn.set_style_bg_color then
          self.btn:set_style_bg_color(0x888888, 0)
        end
      else
        if self.btn and self.btn.set_style_bg_color then
          -- restore to configured bg_color
          local col = 0x007acc
          if self.props.bg_color then
            if type(self.props.bg_color) == "string" then
              col = tonumber(self.props.bg_color:sub(2), 16) or col
            elseif type(self.props.bg_color) == "number" then
              col = self.props.bg_color
            end
          end
          self.btn:set_style_bg_color(col, 0)
        end
      end
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

  function self.to_state(self)
    return self:get_properties()
  end

  return self
end

return Button
