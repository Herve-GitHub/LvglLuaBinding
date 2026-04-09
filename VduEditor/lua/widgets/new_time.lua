-- TimeLabel.lua
-- 实时时间标签组件（自动刷新系统时间）
local lv = require("lvgl")

local TimeLabel = {}
TimeLabel.__index = TimeLabel

TimeLabel.__widget_meta = {
  id = "time_label",
  name = "TimeLabel",
  description = "实时时间标签组件，自动显示系统时间",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    { name = "instance_name", type = "string", default = "", label = "实例名称" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 200, label = "宽度" },
    { name = "height", type = "number", default = 30, label = "高度" },
    { name = "text_color", type = "color", default = "#FFFFFF", label = "文本颜色" },
    { name = "bg_color", type = "color", default = "#000000", label = "背景颜色" }, -- 新增背景色
    { name = "bg_opa", type = "number", default = 255, label = "背景透明度", min = 0, max = 255 },
    { name = "visible", type = "boolean", default = true, label = "可见" },
    { name = "design_mode", type = "boolean", default = false, label = "设计模式" },
  },
  events = {},
}

-- 解析颜色
local function parse_color(c)
  if type(c) == "string" then
    if c:match("^#%x%x%x%x%x%x$") then
      return tonumber(c:sub(2), 16)
    end
  elseif type(c) == "number" then
    return c
  end
  return 0xFFFFFF
end

-- 构造函数
function TimeLabel.new(parent, state)
  state = state or {}
  local self = setmetatable({}, TimeLabel)

  -- 初始化属性
  self.props = {}
  for _, p in ipairs(TimeLabel.__widget_meta.properties) do
    self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
  end

  -- 创建容器
  self.container = lv.obj_create(parent)
  self.container:set_pos(self.props.x, self.props.y)
  self.container:set_size(self.props.width, self.props.height)
  self.container:set_style_bg_color(parse_color(self.props.bg_color), 0)  -- 背景色
  self.container:set_style_bg_opa(self.props.bg_opa, 0)                    -- 背景透明度
  self.container:set_style_radius(0, 0)
  self.container:set_style_border_width(0, 0)
  self.container:set_style_pad_all(0, 0)
  self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

  -- 创建标签
  self.label = lv.create_time_label(self.container)
  self.label:set_text("2025-01-01 00:00:00")
  self.label:set_style_text_color(parse_color(self.props.text_color), 0)
  self.label:set_size(self.props.width, self.props.height)
  self.label:align(lv.ALIGN_CENTER, 0, 0)

  -- 可见性
  if not self.props.visible then
    self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
  end

  return self
end

-- 设置属性
function TimeLabel:set_property(name, value)
  self.props[name] = value

  if name == "x" or name == "y" then
    self.container:set_pos(self.props.x, self.props.y)
  elseif name == "width" then
    self.container:set_width(value)
    self.label:set_width(value)
  elseif name == "height" then
    self.container:set_height(value)
    self.label:set_height(value)
  elseif name == "text_color" then
    self.label:set_style_text_color(parse_color(value), 0)
  elseif name == "bg_color" then
    self.container:set_style_bg_color(parse_color(value), 0)
  elseif name == "bg_opa" then
    self.container:set_style_bg_opa(value, 0)
  elseif name == "visible" then
    if value then
      self.container:remove_flag(lv.OBJ_FLAG_HIDDEN)
    else
      self.container:add_flag(lv.OBJ_FLAG_HIDDEN)
    end
  end
end

function TimeLabel:get_property(name)
  return self.props[name]
end

-- 获取所有属性
function TimeLabel:get_properties()
  local out = {}
  for k, v in pairs(self.props) do
    out[k] = v
  end
  return out
end

-- 应用属性表
function TimeLabel:apply_properties(props_table)
  for k, v in pairs(props_table) do
    self:set_property(k, v)
  end
  return true
end

-- 导出状态（必须有！编辑器保存用）
function TimeLabel:to_state()
  return self:get_properties()
end

-- 外部更新时间文本
function TimeLabel:set_time(text)
  if self.label then
    self.label:set_text(text)
  end
end

-- 位置设置
function TimeLabel:set_pos(x, y)
  self:set_property("x", x)
  self:set_property("y", y)
end

-- 大小设置
function TimeLabel:set_size(w, h)
  self:set_property("width", w)
  self:set_property("height", h)
end

-- 获取根对象
function TimeLabel:get_container()
  return self.container
end

-- 销毁
function TimeLabel:destroy()
  if self.container then
    self.container:delete()
    self.container = nil
    self.label = nil
  end
end

return TimeLabel