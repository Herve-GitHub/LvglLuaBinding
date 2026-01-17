-- checkbox.lua
-- 复选框控件，支持选中/取消选中状态
local lv = require("lvgl")

local Checkbox = {}

Checkbox.__widget_meta = {
    id = "checkbox",
    name = "Checkbox",
    description = "复选框控件，支持选中/取消选中状态切换",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        -- 实例名称（用于编译时变量命名）
        { name = "instance_name", type = "string", default = "", label = "实例名称",
          description = "用于编译时的变量名，留空则自动生成" },
        { name = "text", type = "string", default = "选项", label = "文本" },
        { name = "x", type = "number", default = 0, label = "X" },
        { name = "y", type = "number", default = 0, label = "Y" },
        { name = "width", type = "number", default = 120, label = "宽度" },
        { name = "height", type = "number", default = 30, label = "高度" },
        { name = "checked", type = "boolean", default = false, label = "选中状态" },
        { name = "text_color", type = "color", default = "#FFFFFF", label = "文本颜色" },
        { name = "check_color", type = "color", default = "#007ACC", label = "选中颜色" },
        { name = "box_color", type = "color", default = "#3C3C3C", label = "框体颜色" },
        { name = "box_size", type = "number", default = 20, label = "框体大小" },
        { name = "enabled", type = "boolean", default = true, label = "启用" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
        -- 事件处理代码属性
        { name = "on_changed_handler", type = "code", default = "", label = "状态变化处理代码",
          event = "changed", description = "选中状态变化时执行的Lua代码" },
    },
    events = { "changed" },
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

-- new(parent, state)
function Checkbox.new(parent, state)
    state = state or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(Checkbox.__widget_meta.properties) do
        if state[p.name] ~= nil then
            self.props[p.name] = state[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    -- 事件监听器
    self._event_listeners = {}

    -- 创建主容器
    self.container = lv.obj_create(parent)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_style_bg_opa(0, 0)  -- 透明背景
    self.container:set_style_border_width(0, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:add_flag(lv.OBJ_FLAG_CLICKABLE)

    -- 创建复选框框体
    local box_size = self.props.box_size
    self.box = lv.obj_create(self.container)
    self.box:set_size(box_size, box_size)
    self.box:set_pos(0, math.floor((self.props.height - box_size) / 2))
    self.box:set_style_bg_color(parse_color(self.props.box_color), 0)
    self.box:set_style_border_width(2, 0)
    self.box:set_style_border_color(0x555555, 0)
    self.box:set_style_radius(3, 0)
    self.box:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.box:remove_flag(lv.OBJ_FLAG_CLICKABLE)

    -- 创建选中标记（使用简单的方块或线条代替勾号，避免字体问题）
    self.check_mark = lv.obj_create(self.box)
    local mark_size = math.floor(box_size * 0.5)
    local mark_offset = math.floor((box_size - mark_size) / 2) - 1
    self.check_mark:set_size(mark_size, mark_size)
    self.check_mark:set_pos(mark_offset, mark_offset)
    self.check_mark:set_style_bg_color(0xFFFFFF, 0)
    self.check_mark:set_style_radius(2, 0)
    self.check_mark:set_style_border_width(0, 0)
    self.check_mark:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.check_mark:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    if not self.props.checked then
        self.check_mark:add_flag(lv.OBJ_FLAG_HIDDEN)
    end

    -- 创建文本标签
    self.label = lv.label_create(self.container)
    self.label:set_text(self.props.text)
    self.label:set_style_text_color(parse_color(self.props.text_color), 0)
    self.label:set_pos(box_size + 8, math.floor((self.props.height - 16) / 2))

    -- 点击事件处理
    local this = self
    self.container:add_event_cb(function(e)
        if not this.props.enabled then return end
        if this.props.design_mode then return end
        
        -- 切换选中状态
        this.props.checked = not this.props.checked
        this:_update_check_state()
        
        -- 触发 changed 事件
        this:_emit("changed", this.props.checked)
    end, lv.EVENT_CLICKED, nil)

    -- 事件订阅
    function self.on(self, event_name, callback)
        if not self._event_listeners[event_name] then
            self._event_listeners[event_name] = {}
        end
        table.insert(self._event_listeners[event_name], callback)
    end

    -- 触发事件
    function self._emit(self, event_name, ...)
        local listeners = self._event_listeners[event_name]
        if listeners then
            for _, cb in ipairs(listeners) do
                local ok, err = pcall(cb, self, ...)
                if not ok then
                    print("[Checkbox] callback error:", err)
                end
            end
        end
    end

    -- 更新选中状态的视觉显示
    function self._update_check_state(self)
        if self.props.checked then
            self.check_mark:remove_flag(lv.OBJ_FLAG_HIDDEN)
            self.box:set_style_bg_color(parse_color(self.props.check_color), 0)
        else
            self.check_mark:add_flag(lv.OBJ_FLAG_HIDDEN)
            self.box:set_style_bg_color(parse_color(self.props.box_color), 0)
        end
    end

    -- 获取属性
    function self.get_property(self, name)
        return self.props[name]
    end

    -- 设置属性
    function self.set_property(self, name, value)
        self.props[name] = value

        if name == "text" then
            if self.label and self.label.set_text then
                self.label:set_text(value)
            end
        elseif name == "text_color" then
            local col = parse_color(value)
            if self.label then
                self.label:set_style_text_color(col, 0)
            end
        elseif name == "check_color" then
            local col = parse_color(value)
            -- 选中标记现在是一个对象，不需要设置文本颜色
            if self.props.checked and self.box then
                self.box:set_style_bg_color(col, 0)
            end
        elseif name == "box_color" then
            if not self.props.checked and self.box then
                self.box:set_style_bg_color(parse_color(value), 0)
            end
        elseif name == "box_size" then
            local box_size = value
            if self.box then
                self.box:set_size(box_size, box_size)
                self.box:set_pos(0, math.floor((self.props.height - box_size) / 2))
            end
            if self.label then
                self.label:set_pos(box_size + 8, math.floor((self.props.height - 16) / 2))
            end
        elseif name == "checked" then
            self:_update_check_state()
        elseif name == "x" or name == "y" then
            self.container:set_pos(self.props.x, self.props.y)
        elseif name == "width" or name == "height" then
            self.container:set_size(self.props.width, self.props.height)
            -- 重新居中框体和文本
            local box_size = self.props.box_size
            if self.box then
                self.box:set_pos(0, math.floor((self.props.height - box_size) / 2))
            end
            if self.label then
                self.label:set_pos(box_size + 8, math.floor((self.props.height - 16) / 2))
            end
        elseif name == "enabled" then
            if not value then
                -- 禁用状态显示为灰色
                if self.label then
                    self.label:set_style_text_color(0x888888, 0)
                end
                if self.box then
                    self.box:set_style_border_color(0x444444, 0)
                end
            else
                -- 恢复正常颜色
                if self.label then
                    self.label:set_style_text_color(parse_color(self.props.text_color), 0)
                end
                if self.box then
                    self.box:set_style_border_color(0x555555, 0)
                end
            end
        end
        return true
    end

    -- 获取所有属性
    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do
            out[k] = v
        end
        return out
    end

    -- 应用属性表
    function self.apply_properties(self, props_table)
        for k, v in pairs(props_table) do
            self:set_property(k, v)
        end
        return true
    end

    -- 导出状态
    function self.to_state(self)
        return self:get_properties()
    end

    -- 获取容器
    function self.get_container(self)
        return self.container
    end

    -- 设置选中状态
    function self.set_checked(self, checked)
        self:set_property("checked", checked)
    end

    -- 获取选中状态
    function self.is_checked(self)
        return self.props.checked
    end

    return self
end

return Checkbox
