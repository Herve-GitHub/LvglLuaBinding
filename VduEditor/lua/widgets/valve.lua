local lv = require("lvgl")

local Valve = {}

-- 元数据，编辑器将读取此表生成属性面板
Valve.__widget_meta = {
    id = "valve",
    name = "Valve",
    description = "旋转阀门控件，可设置角度与尺寸",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        { name = "x", type = "number", default = 0, label = "X" },
        { name = "y", type = "number", default = 0, label = "Y" },
        { name = "size", type = "number", default = 80, label = "尺寸", min = 8, max = 1024 },
        { name = "angle", type = "number", default = 0, label = "当前角度", min = 0, max = 360 },
        { name = "open_angle", type = "number", default = 90, label = "开启角度", min = 0, max = 360 },
        { name = "close_angle", type = "number", default = 0, label = "关闭角度", min = 0, max = 360 },
        { name = "handle_color", type = "color", default = "#FF5722", label = "把手颜色" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    },
    events = { "angle_changed", "toggled" },
}

Valve.instances = {}

function Valve.open_all()
    for _, v in pairs(Valve.instances) do
        v:open()
    end
end

function Valve.close_all()
    for _, v in pairs(Valve.instances) do
        v:close()
    end
end

-- 颜色转换：允许编辑器传入 #RRGGBB 或 hex number
local function parse_color(c)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
        return tonumber(c:sub(2), 16)
    elseif type(c) == "number" then
        return c
    end
    return 0xFF5722
end

-- 构造函数：new(parent, props_or_state)
function Valve.new(parent, props)
    props = props or {}
    local self = {}
    
    -- 注册实例
    table.insert(Valve.instances, self)

    -- 初始化属性（使用元数据默认值）
    self.props = {}
    for _, p in ipairs(Valve.__widget_meta.properties) do
        if props[p.name] ~= nil then
            self.props[p.name] = props[p.name]
        else
            self.props[p.name] = p.default
        end
    end
    
    -- 内部状态
    self.is_open = false
    if math.abs(self.props.angle - self.props.open_angle) < 1 then
        self.is_open = true
    end

    -- 创建容器
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.size, self.props.size)
    self.container:set_style_radius(math.floor(self.props.size / 2), 0)  -- 圆形
    self.container:set_style_bg_color(0xE0E0E0, 0)
    self.container:set_style_border_width(2, 0)
    self.container:set_style_border_color(0x606060, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    -- handle
    self.handle = lv.obj_create(self.container)
    local h_w = math.floor(self.props.size * 0.8)
    local h_h = math.floor(self.props.size * 0.2)
    self.handle:set_size(h_w, h_h)
    self.handle:center()

    self.handle:set_style_bg_color(parse_color(self.props.handle_color), 0)
    self.handle:set_style_radius(4, 0)
    self.handle:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    -- pivot
    self.pivot = lv.obj_create(self.container)
    self.pivot:set_size(math.floor(self.props.size * 0.15), math.floor(self.props.size * 0.15))
    self.pivot:center()
    self.pivot:set_style_radius(math.floor(self.props.size * 0.15 / 2), 0)  -- 圆形
    self.pivot:set_style_bg_color(0x333333, 0)

    -- 事件监听
    self._event_listeners = { angle_changed = {}, toggled = {} }

    -- 实例方法：属性接口
    function self.get_property(_, name)
        return self.props[name]
    end

    function self.set_property(_, name, value)
        self.props[name] = value
        if name == "x" or name == "y" then
            self.container:set_pos(self.props.x, self.props.y)
        elseif name == "size" then
            local s = math.floor(value)
            self.container:set_size(s, s)
            local h_w = math.floor(s * 0.8)
            local h_h = math.floor(s * 0.2)
            self.handle:set_size(h_w, h_h)
            self.pivot:set_size(math.floor(s * 0.15), math.floor(s * 0.15))
            self.handle:center()
            self.pivot:center()
            if self.handle.set_style_transform_pivot_x then
                self.handle:set_style_transform_pivot_x(h_w / 2, 0)
                self.handle:set_style_transform_pivot_y(h_h / 2, 0)
            end
        elseif name == "angle" then
            self:set_angle(value)
            -- notify
            for _, cb in ipairs(self._event_listeners.angle_changed) do cb(self, value) end
        elseif name == "handle_color" then
            local c = parse_color(value)
            self.handle:set_style_bg_color(c, 0)
        elseif name == "open_angle" or name == "close_angle" then
            -- just update prop
        end
        return true
    end

    function self.get_properties()
        local out = {}
        for k, v in pairs(self.props) do out[k] = v end
        return out
    end

    function self.apply_properties(_, props_table)
        for k, v in pairs(props_table) do
            self:set_property(k, v)
        end
        return true
    end

    function self.to_state()
        return self:get_properties()
    end

    function self.on(_, event_name, callback)
        if not self._event_listeners[event_name] then self._event_listeners[event_name] = {} end
        table.insert(self._event_listeners[event_name], callback)
    end

    -- 旋转函数（使用 LVGL 的样式变换）
    function self.set_angle(_, angle)
        self.props.angle = angle
        if self.handle.set_style_transform_rotation then
            self.handle:set_style_transform_rotation(math.floor(angle * 10), 0)
        end
    end

    function self.get_angle()
        return self.props.angle
    end
    
    -- 开启阀门
    function self.open(self)
        if self.props.design_mode then return end
        self:set_angle(self.props.open_angle)
        self.is_open = true
        -- notify
        for _, cb in ipairs(self._event_listeners.toggled) do cb(self, true) end
    end
    
    -- 关闭阀门
    function self.close(self)
        if self.props.design_mode then return end
        self:set_angle(self.props.close_angle)
        self.is_open = false
        -- notify
        for _, cb in ipairs(self._event_listeners.toggled) do cb(self, false) end
    end
    
    -- 切换状态
    function self.toggle(self)
        if self.props.design_mode then return end
        if self.is_open then
            self:close()
        else
            self:open()
        end
    end
    
    -- 显示确认对话框（设计模式下不显示）
    function self.show_confirm_dialog(self)
        if self.props.design_mode then return end
        
        local scr = lv.scr_act()
        
        -- 创建模态遮罩
        local modal = lv.obj_create(scr)
        modal:set_size(lv.pct(100), lv.pct(100))
        modal:set_style_bg_color(0x000000, 0)
        modal:set_style_bg_opa(128, 0) -- 半透明
        modal:center()
        
        -- 创建对话框面板
        local panel = lv.obj_create(modal)
        panel:set_size(300, 180)
        panel:center()
        panel:set_style_bg_color(0xFFFFFF, 0)
        panel:set_style_radius(8, 0)
        
        -- 标题/文本
        local label = lv.label_create(panel)
        local action_text = self.is_open and "关闭" or "开启"
        label:set_text("确认要" .. action_text .. "阀门吗？")
        label:set_width(260)
        label:set_style_text_align(lv.TEXT_ALIGN_CENTER, 0)
        label:align(lv.ALIGN_TOP_MID, 0, 20)
        
        -- 确认按钮
        local btn_yes = lv.btn_create(panel)
        btn_yes:set_size(100, 40)
        btn_yes:align(lv.ALIGN_BOTTOM_LEFT, 10, -10)
        local lbl_yes = lv.label_create(btn_yes)
        lbl_yes:set_text("确认")
        lbl_yes:center()
        
        -- 取消按钮
        local btn_no = lv.btn_create(panel)
        btn_no:set_size(100, 40)
        btn_no:align(lv.ALIGN_BOTTOM_RIGHT, -10, -10)
        local lbl_no = lv.label_create(btn_no)
        lbl_no:set_text("取消")
        lbl_no:center()
        
        -- 按钮回调
        local function close_modal()
            modal:delete() -- 删除模态框及其子对象
        end
        
        btn_yes:add_event_cb(function()
            self:toggle()
            close_modal()
        end, lv.EVENT_CLICKED, nil)
        
        btn_no:add_event_cb(function()
            close_modal()
        end, lv.EVENT_CLICKED, nil)
    end

    -- 初始化角度
    if self.props.angle then
        self:set_angle(self.props.angle)
    end

    return self
end

return Valve
