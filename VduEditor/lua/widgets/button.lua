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
    -- clicked 事件绑定
    { name = "on_clicked_action", type = "action", default = "", label = "点击动作", 
      action_module = "actions.page_navigation", event = "clicked",
      description = "点击按钮时执行的动作" },
    { name = "on_clicked_params", type = "action_params", default = "{}", label = "点击参数",
      event = "clicked", description = "点击动作的参数" },
    -- single_clicked 事件绑定
    { name = "on_single_clicked_action", type = "action", default = "", label = "单击动作", 
      action_module = "actions.page_navigation", event = "single_clicked",
      description = "单击按钮时执行的动作" },
    { name = "on_single_clicked_params", type = "action_params", default = "{}", label = "单击参数",
      event = "single_clicked", description = "单击动作的参数" },
    -- double_clicked 事件绑定
    { name = "on_double_clicked_action", type = "action", default = "", label = "双击动作", 
      action_module = "actions.page_navigation", event = "double_clicked",
      description = "双击按钮时执行的动作" },
    { name = "on_double_clicked_params", type = "action_params", default = "{}", label = "双击参数",
      event = "double_clicked", description = "双击动作的参数" },
  },
  events = { "clicked", "single_clicked", "double_clicked" },
}

-- 解析动作参数的辅助函数
local function parse_action_params(params_str)
  local params = {}
  if params_str and params_str ~= "" and params_str ~= "{}" then
    local ok, parsed = pcall(function()
      local content = params_str:match("^%s*{(.*)%s*}%s*$") or params_str
      local result = {}
      for key, value in content:gmatch('([%w_]+)%s*=%s*([^,}]+)') do
        value = value:gsub('^%s*"(.*)"%s*$', '%1')
        value = value:gsub("^%s*'(.*)'%s*$", '%1')
        value = value:gsub("^%s*(.-)%s*$", '%1')
        local num = tonumber(value)
        if num then
          result[key] = num
        else
          result[key] = value
        end
      end
      return result
    end)
    if ok then
      params = parsed
    end
  end
  return params
end

-- new(parent, state)
function Button.new(parent, state)
  state = state or {}
  local self = {}

  -- 初始化属性
  self.props = {}
  for _, p in ipairs(Button.__widget_meta.properties) do
    self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
  end

  -- 创建 lv 按钮与标签
  self.btn = lv.button_create(parent)
  self.btn:set_size(self.props.width, self.props.height)
  self.btn:set_pos(self.props.x, self.props.y)

  self.label = lv.label_create(self.btn)
  self.label:set_text(self.props.label)
  self.label:center()

  -- 保存各事件的动作回调
  self._action_callbacks = {
    clicked = nil,
    single_clicked = nil,
    double_clicked = nil,
  }

  -- 绑定单个事件的动作
  function self._bind_event_action(self, event_name)
    local action_prop = "on_" .. event_name .. "_action"
    local params_prop = "on_" .. event_name .. "_params"
    
    local action_id = self.props[action_prop]
    if not action_id or action_id == "" then
      self._action_callbacks[event_name] = nil
      return
    end

    local ok, action_module = pcall(require, "actions.page_navigation")
    if not ok then
      print("[button] cannot load action module: " .. tostring(action_module))
      return
    end

    local params = parse_action_params(self.props[params_prop])

    if action_module.create_action_callback then
      self._action_callbacks[event_name] = action_module.create_action_callback(action_id, params)
      print("[button] bindaction " .. event_name .. ": " .. action_id)
    end

    if not self.props.design_mode and self._action_callbacks[event_name] then
      local action_cb = self._action_callbacks[event_name]
      local evt_cb = function(e)
        if not self.props.enabled then return end
        if self.props.design_mode then return end
        local ok2, err = pcall(action_cb)
        if not ok2 then print("[button] action error:", err) end
      end
      
      local ev_code
      if event_name == "clicked" then
        ev_code = lv.EVENT_CLICKED
      elseif event_name == "single_clicked" then
        ev_code = lv.EVENT_SINGLE_CLICKED
      elseif event_name == "double_clicked" then
        ev_code = lv.EVENT_DOUBLE_CLICKED
      end
      
      if ev_code then
        if self.btn.add_event_cb then
          self.btn:add_event_cb(evt_cb, ev_code, nil)
        elseif lv.obj_add_event_cb then
          lv.obj_add_event_cb(self.btn, evt_cb, ev_code, nil)
        end
      end
    end
  end

  -- 绑定所有事件动作
  function self._bind_all_actions(self)
    for _, event_name in ipairs(Button.__widget_meta.events) do
      self:_bind_event_action(event_name)
    end
  end

  self:_bind_all_actions()
  
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
      if self.label and self.label.set_text then
        self.label:set_text(value)
      end
    elseif name == "bg_color" then
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
      end
    elseif name == "x" or name == "y" then
      self.btn:set_pos(self.props.x, self.props.y)
    elseif name == "width" or name == "height" then
      self.btn:set_size(self.props.width, self.props.height)
    elseif name:match("^on_.*_action$") or name:match("^on_.*_params$") then
      local event_name = name:match("^on_(.*)_action$") or name:match("^on_(.*)_params$")
      if event_name then
        self:_bind_event_action(event_name)
      end
    elseif name == "enabled" then
      if not value then
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
