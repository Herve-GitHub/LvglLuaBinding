-- dropdown.lua
-- 下拉框控件，支持选项列表选择
local lv = require("lvgl")

local Dropdown = {}

Dropdown.__widget_meta = {
    id = "dropdown",
    name = "Dropdown",
    description = "下拉框控件，支持从选项列表中选择",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        -- 实例名称（用于编译时变量命名）
        { name = "instance_name", type = "string", default = "", label = "实例名称",
          description = "用于编译时的变量名，留空则自动生成" },
        { name = "x", type = "number", default = 0, label = "X" },
        { name = "y", type = "number", default = 0, label = "Y" },
        { name = "width", type = "number", default = 150, label = "宽度" },
        { name = "height", type = "number", default = 32, label = "高度" },
        { name = "options", type = "string", default = "选项1\n选项2\n选项3", label = "选项列表",
          multiline = true, lines = 3, description = "每行一个选项，用换行符分隔" },
        { name = "selected_index", type = "number", default = 0, label = "选中索引" },
        { name = "text_color", type = "color", default = "#FFFFFF", label = "文本颜色" },
        { name = "bg_color", type = "color", default = "#3C3C3C", label = "背景色" },
        { name = "list_bg_color", type = "color", default = "#2D2D2D", label = "列表背景色" },
        { name = "selected_color", type = "color", default = "#007ACC", label = "选中颜色" },
        { name = "border_color", type = "color", default = "#555555", label = "边框颜色" },
        { name = "enabled", type = "boolean", default = true, label = "启用" },
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
        -- 事件处理代码属性
        { name = "on_changed_handler", type = "code", default = "", label = "选择变化处理代码",
          event = "changed", description = "选择变化时执行的Lua代码" },
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
function Dropdown.new(parent, state)
    state = state or {}
    local self = {}

    -- 初始化属性
    self.props = {}
    for _, p in ipairs(Dropdown.__widget_meta.properties) do
        if state[p.name] ~= nil then
            self.props[p.name] = state[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    -- 保存父元素引用
    self._parent = parent

    -- 事件监听器
    self._event_listeners = {}

    -- 下拉列表状态
    self._is_open = false
    self._dropdown_list = nil
    
    -- 选项数据
    self._options = {}

    -- ========== 方法定义（必须在调用之前） ==========

    -- 解析选项字符串
    function self._parse_options(self, options_str)
        self._options = {}
        if options_str and options_str ~= "" then
            for line in options_str:gmatch("[^\n]+") do
                local trimmed = line:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    table.insert(self._options, trimmed)
                end
            end
        end
    end

    -- 更新显示文本
    function self._update_display_text(self)
        local idx = self.props.selected_index + 1  -- Lua 索引从 1 开始
        if idx >= 1 and idx <= #self._options then
            self.display_label:set_text(self._options[idx])
        elseif #self._options > 0 then
            self.display_label:set_text(self._options[1])
        else
            self.display_label:set_text("")
        end
    end

    -- 触发事件
    function self._emit(self, event_name, ...)
        local listeners = self._event_listeners[event_name]
        if listeners then
            for _, cb in ipairs(listeners) do
                local ok, err = pcall(cb, self, ...)
                if not ok then
                    print("[Dropdown] callback error:", err)
                end
            end
        end
    end

    -- 选择选项
    function self._select_option(self, index)
        local old_index = self.props.selected_index
        self.props.selected_index = index
        self:_update_display_text()
        self:_close_dropdown()
        
        if old_index ~= index then
            self:_emit("changed", index, self._options[index + 1])
        end
    end

    -- 关闭下拉列表
    function self._close_dropdown(self)
        if not self._is_open then return end
        
        if self._dropdown_list then
            pcall(function() self._dropdown_list:delete() end)
            self._dropdown_list = nil
        end
        
        self._is_open = false
        self.arrow_label:set_text("v")
    end

    -- 打开下拉列表
    function self._open_dropdown(self)
        if self._is_open then return end
        
        local list_height = math.min(#self._options * 28 + 6, 150)
        
        -- 在屏幕层创建下拉列表
        local scr = lv.scr_act()
        self._dropdown_list = lv.obj_create(scr)
        
        -- 计算绝对位置
        local abs_x = self.props.x
        local abs_y = self.props.y + self.props.height
        
        self._dropdown_list:set_pos(abs_x, abs_y)
        self._dropdown_list:set_size(self.props.width, list_height)
        self._dropdown_list:set_style_bg_color(parse_color(self.props.list_bg_color), 0)
        self._dropdown_list:set_style_border_width(1, 0)
        self._dropdown_list:set_style_border_color(parse_color(self.props.border_color), 0)
        self._dropdown_list:set_style_radius(4, 0)
        self._dropdown_list:set_style_pad_all(3, 0)
        self._dropdown_list:add_flag(lv.OBJ_FLAG_SCROLLABLE)
        self._dropdown_list:clear_layout()
        
        -- 创建选项
        local this_ref = self
        for i, opt_text in ipairs(self._options) do
            local item = lv.obj_create(self._dropdown_list)
            item:set_pos(0, (i - 1) * 26)
            item:set_size(self.props.width - 10, 24)
            
            local is_selected = (i - 1) == self.props.selected_index
            item:set_style_bg_color(is_selected and parse_color(self.props.selected_color) or parse_color(self.props.list_bg_color), 0)
            item:set_style_radius(3, 0)
            item:set_style_border_width(0, 0)
            item:set_style_pad_all(0, 0)
            item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            item:add_flag(lv.OBJ_FLAG_CLICKABLE)
            
            local item_label = lv.label_create(item)
            item_label:set_text(opt_text)
            item_label:set_style_text_color(parse_color(self.props.text_color), 0)
            item_label:align(lv.ALIGN_LEFT_MID, 6, 0)
            
            -- 选项点击事件
            local opt_index = i - 1  -- 转为 0-based 索引
            item:add_event_cb(function(e)
                this_ref:_select_option(opt_index)
            end, lv.EVENT_CLICKED, nil)
        end
        
        self._is_open = true
        self.arrow_label:set_text("^")
    end

    -- 切换下拉列表显示
    function self._toggle_dropdown(self)
        if self._is_open then
            self:_close_dropdown()
        else
            self:_open_dropdown()
        end
    end

    -- ========== 创建 UI 元素 ==========

    -- 创建主容器
    self.container = lv.obj_create(parent)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_style_bg_color(parse_color(self.props.bg_color), 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(parse_color(self.props.border_color), 0)
    self.container:set_style_radius(4, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:add_flag(lv.OBJ_FLAG_CLICKABLE)

    -- 解析选项
    self:_parse_options(self.props.options)

    -- 创建显示标签（显示当前选中项）
    self.display_label = lv.label_create(self.container)
    self.display_label:set_style_text_color(parse_color(self.props.text_color), 0)
    self.display_label:align(lv.ALIGN_LEFT_MID, 8, 0)
    self:_update_display_text()

    -- 创建下拉箭头
    self.arrow_label = lv.label_create(self.container)
    self.arrow_label:set_text("v")
    self.arrow_label:set_style_text_color(parse_color(self.props.text_color), 0)
    self.arrow_label:align(lv.ALIGN_RIGHT_MID, -8, 0)

    -- 点击事件处理
    local this = self
    self.container:add_event_cb(function(e)
        if not this.props.enabled then return end
        if this.props.design_mode then return end
        
        this:_toggle_dropdown()
    end, lv.EVENT_CLICKED, nil)

    -- ========== 其余方法定义 ==========

    -- 事件订阅
    function self.on(self, event_name, callback)
        if not self._event_listeners[event_name] then
            self._event_listeners[event_name] = {}
        end
        table.insert(self._event_listeners[event_name], callback)
    end

    -- 获取属性
    function self.get_property(self, name)
        return self.props[name]
    end

    -- 设置属性
    function self.set_property(self, name, value)
        self.props[name] = value

        if name == "options" then
            self:_parse_options(value)
            self:_update_display_text()
        elseif name == "selected_index" then
            self:_update_display_text()
        elseif name == "text_color" then
            local col = parse_color(value)
            if self.display_label then
                self.display_label:set_style_text_color(col, 0)
            end
            if self.arrow_label then
                self.arrow_label:set_style_text_color(col, 0)
            end
        elseif name == "bg_color" then
            self.container:set_style_bg_color(parse_color(value), 0)
        elseif name == "border_color" then
            self.container:set_style_border_color(parse_color(value), 0)
        elseif name == "x" or name == "y" then
            self.container:set_pos(self.props.x, self.props.y)
        elseif name == "width" or name == "height" then
            self.container:set_size(self.props.width, self.props.height)
            -- 重新对齐标签
            if self.display_label then
                self.display_label:align(lv.ALIGN_LEFT_MID, 8, 0)
            end
            if self.arrow_label then
                self.arrow_label:align(lv.ALIGN_RIGHT_MID, -8, 0)
            end
        elseif name == "enabled" then
            if not value then
                self.container:set_style_bg_color(0x555555, 0)
                if self.display_label then
                    self.display_label:set_style_text_color(0x888888, 0)
                end
            else
                self.container:set_style_bg_color(parse_color(self.props.bg_color), 0)
                if self.display_label then
                    self.display_label:set_style_text_color(parse_color(self.props.text_color), 0)
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

    -- 获取当前选中索引
    function self.get_selected_index(self)
        return self.props.selected_index
    end

    -- 设置选中索引
    function self.set_selected_index(self, index)
        self:set_property("selected_index", index)
    end

    -- 获取当前选中的文本
    function self.get_selected_text(self)
        local idx = self.props.selected_index + 1
        if idx >= 1 and idx <= #self._options then
            return self._options[idx]
        end
        return ""
    end

    -- 获取选项列表
    function self.get_options(self)
        return self._options
    end

    -- 设置选项列表
    function self.set_options(self, options_str)
        self:set_property("options", options_str)
    end

    return self
end

return Dropdown
