local lv = require("lvgl")
local DataAction = require("editor.DataAction")

local Image = {}

Image.__widget_meta = {
  id = "custom_image",
  name = "Custom Image",
  description = "图像控件，支持编辑器拖拽调整",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    { name = "instance_name", type = "string", default = "", label = "实例名称" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 100, label = "宽度" },
    { name = "height", type = "number", default = 100, label = "高度" },
    { name = "src", type = "string", default = "", label = "图像路径" },
    { name = "mode", type = "enum", default = "normal",
      options = {"normal", "cover", "contain", "stretch"}, label = "显示模式" },
    { name = "rotation", type = "number", default = 0, label = "旋转角度",
      description = "图像旋转角度（0-3600，0.1度为单位）" },
    { name = "scale", type = "number", default = 256, label = "缩放",
      description = "整体缩放（256=100%）" },
    { name = "scale_x", type = "number", default = 256, label = "水平缩放",
      description = "水平方向缩放（256=100%）" },
    { name = "scale_y", type = "number", default = 256, label = "垂直缩放",
      description = "垂直方向缩放（256=100%）" },
    { name = "opa", type = "number", default = 255, label = "透明度",
      min = 0, max = 255, description = "0-255，255为完全不透明" },
    { name = "on_loaded_handler", type = "code", default = "", label = "加载完成处理",
      event = "loaded" },
  },
}

-- 修复路径字符串的辅助函数
local function fix_path(path)
    if not path or type(path) ~= "string" then return path end
    
    -- 修复分号问题 (C; -> C:)
    local fixed = path:gsub("^([A-Za-z]);", "%1:")
    fixed = fixed:gsub(";", ":")
    
    -- 确保反斜杠格式正确
    fixed = fixed:gsub("\\\\", "\\")
    
    return fixed
end

function Image.new(parent, state)
    state = state or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(Image.__widget_meta.properties) do
        local value = state[p.name] ~= nil and state[p.name] or p.default
        -- 对src属性进行路径修复
        if p.name == "src" and type(value) == "string" then
            value = fix_path(value)
        end
        self.props[p.name] = value
    end
    
    -- 创建LVGL图像对象
    self.image = lv.image_create(parent)
    if not self.image then 
        print("[Image] 创建失败")
        return nil 
    end
    self.obj = self.image
    
    -- 设置基本属性
    self.image:set_size(self.props.width, self.props.height)
    self.image:set_pos(self.props.x, self.props.y)
    
    -- 设置图像源
    if self.props.src and self.props.src ~= "" then
        print("[Image] 设置图像源:", self.props.src)
        local success, err = pcall(function()
            self.image:set_src(self.props.src)
        end)
        if not success then
            print("[Image] 设置图像源失败:", err)
        end
    end
    
    -- 设置旋转
    if self.image.set_rotation and self.props.rotation and self.props.rotation ~= 0 then
        self.image:set_rotation(self.props.rotation)
    end
    
    -- 设置整体缩放
    if self.image.set_scale and self.props.scale and self.props.scale ~= 256 then
        self.image:set_scale(self.props.scale)
    end
    
    -- 设置水平缩放
    if self.image.set_scale_x and self.props.scale_x and self.props.scale_x ~= 256 then
        self.image:set_scale_x(self.props.scale_x)
    end
    
    -- 设置垂直缩放
    if self.image.set_scale_y and self.props.scale_y and self.props.scale_y ~= 256 then
        self.image:set_scale_y(self.props.scale_y)
    end
    
    -- 设置透明度
    if self.image.set_opa and self.props.opa and self.props.opa ~= 255 then
        self.image:set_opa(self.props.opa)
    end
    
    self._callbacks = {}
    
    -- 加载完成事件
    local function on_loaded(e)
        if self._callbacks.loaded then
            pcall(self._callbacks.loaded, self, {})
        end
    end
    
    if self.image.add_event_cb then
        self.image:add_event_cb(on_loaded, lv.EVENT_READY, nil)
    end
    
    -- 标准接口
    function self.on(self, event_name, callback)
        if event_name == "loaded" then
            self._callbacks.loaded = callback
        elseif event_name == "property_changed" then
            self._callbacks.property_changed = callback
        end
    end
    
    function self.get_container(self)
        return self.image
    end
    
    function self.get_property(self, name)
        return self.props[name]
    end
    
    function self.set_property(self, name, value)
        -- 对src属性进行路径修复
        if name == "src" and type(value) == "string" then
            value = fix_path(value)
        end
        
        self.props[name] = value
        
        if not self.image then return true end
        
        if name == "x" or name == "y" then
            self.image:set_pos(self.props.x, self.props.y)
            if self.image.invalidate then self.image:invalidate() end
            
        elseif name == "width" or name == "height" then
            self.image:set_size(self.props.width, self.props.height)
            if self.image.invalidate then self.image:invalidate() end
            
        elseif name == "src" then
            if self.image.set_src and value and value ~= "" then
                print("[Image] 更新图像源:", value)
                local success, err = pcall(function()
                    self.image:set_src(value)
                end)
                if not success then
                    print("[Image] 更新图像源失败:", err)
                end
                if self.image.invalidate then self.image:invalidate() end
            end
            
        elseif name == "rotation" then
            if self.image.set_rotation then
                self.image:set_rotation(value or 0)
                if self.image.invalidate then self.image:invalidate() end
            end
            
        elseif name == "scale" then
            if self.image.set_scale then
                self.image:set_scale(value or 256)
                if self.image.invalidate then self.image:invalidate() end
            end
            
        elseif name == "scale_x" then
            if self.image.set_scale_x then
                self.image:set_scale_x(value or 256)
                if self.image.invalidate then self.image:invalidate() end
            end
            
        elseif name == "scale_y" then
            if self.image.set_scale_y then
                self.image:set_scale_y(value or 256)
                if self.image.invalidate then self.image:invalidate() end
            end
            
        elseif name == "opa" then
            if self.image.set_opa then
                self.image:set_opa(value or 255)
                if self.image.invalidate then self.image:invalidate() end
            end
            
        elseif name == "mode" then
            if self.image.invalidate then self.image:invalidate() end
        end
        
        if self._callbacks.property_changed then
            self._callbacks.property_changed(name, value)
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
    
    function self.get_id(self)
        if self.props.instance_name and self.props.instance_name ~= "" then
            return self.props.instance_name
        end
        return tostring(self)
    end

    return self
end

return Image