local lv = require("lvgl")
local DataAction = require("editor.DataAction")
local config = require("widgets.config")
local ImageDialog = require("ImageDialog")

local Image = {}

Image.__widget_meta = {
  id = "custom_image",
  name = "Custom Image",
  description = "图像控件拖拽调整",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    { name = "instance_name", type = "string", default = "", label = "实例名称" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 100, label = "宽度" },
    { name = "height", type = "number", default = 100, label = "高度" },
    { name = "src", type = "boolean", default = false, label = "选择图片" },
    { name = "mode", type = "enum", default = "normal", options = {"normal","cover","contain","stretch"}, label = "显示模式" },
    { name = "rotation", type = "number", default = 0, label = "旋转角度" },
    { name = "scale", type = "number", default = 256, label = "缩放" },
    { name = "scale_x", type = "number", default = 256, label = "水平缩放" },
    { name = "scale_y", type = "number", default = 256, label = "垂直缩放" },
    { name = "opa", type = "number", default = 255, label = "透明度", min=0,max=255 },
  },
}

-- 判断是否为 Windows 绝对路径 C:\ D:\
local function is_windows_absolute(path)
    return type(path) == "string" and path:match("^%a:\\")
end

local function get_image_real_path(filename)
    if not filename or filename == "" then
        return ""
    end

    -- 绝对路径 → 直接返回
    if is_windows_absolute(filename) then
        return filename
    end

    -- 相对路径 → 拼接目录
    if package.config:sub(1,1) == "/" then
        return config.linux_path .. filename
    else
        return config.image_path .. filename
    end
end

local function load_image(img, filename)
    if not img or not filename or filename == "" then return end
    local path = get_image_real_path(filename)
    img:set_src(path)
end

function Image.new(parent, state)
    state = state or {}
    local self = {}

    self.props = {}
    self.image_path = ""

    for _, p in ipairs(Image.__widget_meta.properties) do
        self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
    end

    self.image = lv.image_create(parent)
    self.obj = self.image

    self.image:set_size(self.props.width, self.props.height)
    self.image:set_pos(self.props.x, self.props.y)

    -- 初始化加载
    if state.src and type(state.src) == "string" then
        self.image_path = state.src
        load_image(self.image, self.image_path)
    end

    -- 属性应用
    if self.image.set_rotation then self.image:set_rotation(self.props.rotation) end
    if self.image.set_scale then self.image:set_scale(self.props.scale) end
    if self.image.set_scale_x then self.image:set_scale_x(self.props.scale_x) end
    if self.image.set_scale_y then self.image:set_scale_y(self.props.scale_y) end
    if self.image.set_opa then self.image:set_opa(self.props.opa) end

    self._callbacks = {}

    function self:on(event_name, callback)
        if event_name == "loaded" then
            self._callbacks.loaded = callback
        elseif event_name == "property_changed" then
            self._callbacks.property_changed = callback
        end
    end

    function self:get_container()
        return self.image
    end

    function self:get_property(name)
        if name == "src" then
            return self.image_path
        end
        return self.props[name]
    end

    function self:set_property(name, value)
        self.props[name] = value
        if not self.image then return true end

        if name == "x" or name == "y" then
            self.image:set_pos(self.props.x, self.props.y)
        elseif name == "width" or name == "height" then
            self.image:set_size(self.props.width, self.props.height)
        elseif name == "src" then
            -- 打开系统选择框
            ImageDialog.new(nil, {
                initial_dir = config.image_path,
                callback = function(full_path)
                    if full_path then
                        self.image_path = full_path
                        load_image(self.image, full_path)
                    end
                end
            })
        elseif name == "rotation" then
            self.image:set_rotation(value or 0)
        elseif name == "scale" then
            self.image:set_scale(value or 255)
        elseif name == "scale_x" then
            self.image:set_scale_x(value or 255)
        elseif name == "scale_y" then
            self.image:set_scale_y(value or 255)
        elseif name == "opa" then
            self.image:set_opa(value or 255)
        end

        if self.image.invalidate then
            self.image:invalidate()
        end

        if self._callbacks.property_changed then
            self._callbacks.property_changed(name, value)
        end

        return true
    end

    function self:get_properties()
        local out = {}
        for k, v in pairs(self.props) do
            out[k] = v
        end
        out.src = self.image_path
        return out
    end

    function self:apply_properties(props_table)
        for k, v in pairs(props_table) do
            self:set_property(k, v)
        end
        return true
    end

    function self:to_state()
        return self:get_properties()
    end

    function self:get_id()
        return self.props.instance_name or tostring(self)
    end

    return self
end

return Image