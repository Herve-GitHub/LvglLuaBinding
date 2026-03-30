-- PopupButton.lua
local lv = require("lvgl")
local DataAction = require("editor.DataAction")
-- 引入 DataManager（核心：复用其全局回调）
local DataManager = require("editor.DataManager")

local PopupButton = {}

PopupButton.__widget_meta = {
  id = "popup_button_simple",
  name = "简单弹窗按钮",
  description = "点击按钮弹出带输入框的简单弹窗",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    { name = "label", type = "string", default = "弹窗按钮", label = "按钮文本" },
    { name = "x", type = "number", default = 0, label = "X" },
    { name = "y", type = "number", default = 0, label = "Y" },
    { name = "width", type = "number", default = 100, label = "宽度" },
    { name = "height", type = "number", default = 40, label = "高度" },
    { name = "color", type = "color", default = "#ffffff", label = "文本颜色" },
    { name = "font_size", type = "number", default = 16, label = "字体大小" },
    { name = "alignment", type = "string", default = "center", label = "对齐方式" },
    { name = "bg_color", type = "color", default = "#007acc", label = "背景色" },
    { name = "popup_title", type = "string", default = "请输入", label = "弹窗标题" },
    { name = "input_hint", type = "string", default = "请输入...", label = "输入框提示" },
    { name = "bind_point", type = "string", default = "", label = "绑定数据点",
      description = "例如: Device1.E, PLC1.D100" },
    { name = "websocket_url", type = "string", default = "", label = "WebSocket",
      description = "例如: ws://192.168.1.100:8080" },
  },
  events = { "confirm", "cancel" },
}

-- 仅保留实例列表用于手动清理（不再用于回调）
PopupButton.instances = {}

local function parse_color(c)
     if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then 
           return tonumber(c:sub(2), 16)
     elseif type(c) == "number" then 
           return c
      end
      return 0xffffff
end

local function apply_styles(self)
    local bg_color = parse_color(self.props.bg_color or "#007acc")
    if self.btn and self.btn.set_style_bg_color then 
        self.btn:set_style_bg_color(bg_color, 0)
    end

    local text_color = parse_color(self.props.color or "#ffffff")
    if self.label_widget and self.label_widget.set_style_text_color then 
        self.label_widget:set_style_text_color(text_color, 0)
    end
end

-- 更新按钮标签显示
local function update_button_label(self)
    local label_text = self.props.label
    if self.bind_point_value and self.bind_point_value ~= "" then
        label_text = self.bind_point_value
    end
    self.label_widget:set_text(label_text)
end

local function create_popup(self, parent)
    local scr = parent or lv.scr_act()
    local mask = lv.obj_create(scr)
    mask:set_size(scr:get_width(), scr:get_height())
    mask:set_style_bg_color(0x000000, 0)
    mask:set_style_bg_opa(64, 0)
    mask:add_flag(lv.OBJ_FLAG_CLICKABLE)
    mask:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    -- 弹窗尺寸和位置
    local scale = 1.3
    local popup_w = math.floor(220 * scale)
    local popup_h = math.floor(120 * scale)
    local popup = lv.obj_create(mask)
    popup:set_size(popup_w+10, popup_h+10)
    popup:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    local btn_x = self.btn:get_x()
    local btn_y = self.btn:get_y()
    local btn_w = self.btn:get_width()
    local btn_h = self.btn:get_height()
    local popup_x = btn_x + (btn_w - popup_w) / 2
    local popup_y = btn_y - popup_h - 6
    if popup_y < 0 then popup_y = 0 end
    popup:set_pos(popup_x+500, popup_y+300)

    -- 标题
    local title = lv.label_create(popup)
    title:set_text(self.props.popup_title)
    title:set_pos(100,2)
    
    -- 输入框
    local textarea_margin = math.floor(popup_w * 0.07)
    local textarea_width = popup_w - 2 * textarea_margin
    local textarea = lv.textarea_create(popup)
    textarea:set_width(textarea_width-10)
    textarea:set_one_line(true)
    textarea:set_pos(textarea_margin-15, 36)
    textarea:set_placeholder_text(self.props.input_hint or "请输入...")

    --创建键盘
    local keyboard = lv.keyboard_create(scr)
   -- keyboard : set_size(500,500)

    -- 初始隐藏键盘
    keyboard:add_flag(lvgl.OBJ_FLAG_HIDDEN)

-- 3. 为文本框添加事件（回调函数直接接收事件代码）
    textarea:add_event_cb(function(code)
         if code == lvgl.EVENT_CLICKED then
        keyboard:keyboard_set_textarea(textarea, keyboard)
        keyboard:remove_flag(lvgl.OBJ_FLAG_HIDDEN)
    --elseif code == lvgl.EVENT_DEFOCUSED then
       -- keyboard:add_flag(lvgl.OBJ_FLAG_HIDDEN)
    end
end, 0)

-- 4. 键盘取消按钮事件
keyboard:add_event_cb(function(code)
    -- 取消按钮
    if code == lvgl.EVENT_CANCEL then
        keyboard:add_flag(lvgl.OBJ_FLAG_HIDDEN)
    end
    -- 确认按钮（回车/OK）
    if code == lvgl.EVENT_READY then
        keyboard:add_flag(lvgl.OBJ_FLAG_HIDDEN)
        -- 这里可以加你确认后要执行的逻辑
    end
end, 0)




    -- 确认/取消按钮
    local btn_w2 = math.floor(popup_w * 0.31)
    local btn_h2 = 32
    local btn_spacing = math.floor(popup_w * 0.08)
    local btn_y = popup_h - btn_h2 - 16

    local confirm_btn = lv.button_create(popup)
    confirm_btn:set_size(btn_w2, btn_h2-5)
    confirm_btn:set_pos(btn_spacing-18, btn_y-3)
    local confirm_label = lv.label_create(confirm_btn)
    confirm_label:set_text("确认")
    confirm_label:center()

    local cancel_btn = lv.button_create(popup)
    cancel_btn:set_size(btn_w2, btn_h2-5)
    cancel_btn:set_pos(popup_w - btn_w2 - btn_spacing-16, btn_y-3)
    local cancel_label = lv.label_create(cancel_btn)
    cancel_label:set_text("取消")
    cancel_label:center()

    -- 蒙版初始隐藏
    mask:add_flag(lv.OBJ_FLAG_HIDDEN)

    -- 弹窗控制方法
    self._popup_mask = mask
    self._popup_textarea = textarea

    function self:show_popup()
        if self.bind_point_value then
            self._popup_textarea:set_text(self.bind_point_value)
        else
            self._popup_textarea:set_text("")
        end
        self._popup_mask:remove_flag(lv.OBJ_FLAG_HIDDEN)
    end

    function self:hide_popup()
        self._popup_mask:add_flag(lv.OBJ_FLAG_HIDDEN)
    end

    -- 确认按钮事件（核心：仅调用DataManager.write，不处理回调）
    confirm_btn:add_event_cb(function()
        local value = textarea:get_text()
        
        -- 触发confirm回调
        if self._callbacks and self._callbacks.confirm then
            pcall(self._callbacks.confirm, self, value)
        end
        
        -- 仅通过DataManager写入数据（关键：让DataManager的中央回调处理所有更新）
        if self.props.bind_point and self.props.bind_point ~= "" then
            print("[PopupButton] 发送数据到数据点: " .. self.props.bind_point .. " = " .. value)
            DataManager.write(self.props.bind_point, value)
            
            -- WebSocket逻辑（保留）
            if self.props.websocket_url and self.props.websocket_url ~= "" then
                print("[PopupButton] 通过 WebSocket 发送数据: " .. self.props.websocket_url)
            end
        end
        
        self:hide_popup()
    end, lv.EVENT_CLICKED, nil)

    -- 取消按钮事件
    cancel_btn:add_event_cb(function()
        if self._callbacks and self._callbacks.cancel then
            pcall(self._callbacks.cancel, self)
        end
        self:hide_popup()
    end, lv.EVENT_CLICKED, nil)

    -- 蒙版点击关闭（修复事件参数）
    mask:add_event_cb(function(e)
        if type(e) == "number" then
            self:hide_popup()
            if self._callbacks and self._callbacks.cancel then
                pcall(self._callbacks.cancel, self)
            end
            return
        end
        if e and e.get_target and e:get_target() == mask then
            self:hide_popup()
            if self._callbacks and self._callbacks.cancel then
                pcall(self._callbacks.cancel, self)
            end
        end
    end, lv.EVENT_CLICKED, nil)
end

function PopupButton.new(parent, state)
    state = state or {}
    local self = {}
    self.props = {}
    self.bind_point_value = ""  -- 本地缓存值
    
    -- 初始化属性
    for _, p in ipairs(PopupButton.__widget_meta.properties) do
        self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
    end

    self._callbacks = {}

    -- 创建按钮UI
    self.btn = lv.button_create(parent)
    self.btn:set_size(self.props.width, self.props.height)
    self.btn:set_pos(self.props.x, self.props.y)
    self.label_widget = lv.label_create(self.btn)
    update_button_label(self)
    self.label_widget:center()
    apply_styles(self)

    -- 事件订阅接口
    function self.on(self, event_name, callback)
        self._callbacks[event_name] = callback
    end

    -- 属性操作接口
    function self.get_container(self) return self.btn end
    function self.get_property(self, name) return self.props[name] end
    function self.set_property(self, name, value)
        local old_value = self.props[name]
        self.props[name] = value
        
        if name == "label" then update_button_label(self) end
        if name == "bind_point" then
            self.bind_point_value = ""
            update_button_label(self)
            if value and value ~= "" then
                -- 仅注册到DataManager，由DataManager处理数据更新
                DataManager.register_button(value, {
                    set_label = function(_, val)
                        self.bind_point_value = val
                        update_button_label(self)
                    end,
                    set_text = function(_, val)
                        self.bind_point_value = val
                        update_button_label(self)
                    end
                })
                DataManager.read(value)
            end
        end
        if name == "x" or name == "y" then self.btn:set_pos(self.props.x, self.props.y) end
        if name == "width" or name == "height" then self.btn:set_size(self.props.width, self.props.height) end
        if name == "color" or name =="bg_color" then apply_styles(self) end
        
        return true
    end
    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do out[k] = v end
        return out
    end
    function self.apply_properties(self, props_table)
        for k, v in pairs(props_table) do self:set_property(k, v) end
        return true
    end
    function self.to_state(self) return self:get_properties() end
    function self.get_id(self) return tostring(self) end

    -- 创建弹窗
    create_popup(self, lv.scr_act())

    -- 按钮点击显示弹窗
    self.btn:add_event_cb(function()
        self:show_popup()
    end, lv.EVENT_CLICKED, nil)

    -- 加入实例列表
    table.insert(PopupButton.instances, self)
    
    -- 初始化（仅调用DataManager.init，不注册任何LVGL回调）
    DataManager.init()
    
    -- 注册到DataManager（核心：让DataManager的中央回调更新当前按钮）
    if self.props.bind_point and self.props.bind_point ~= "" then
        DataManager.register_button(self.props.bind_point, {
            set_label = function(_, value)
                self.bind_point_value = value
                update_button_label(self)
            end,
            set_text = function(_, value)
                self.bind_point_value = value
                update_button_label(self)
            end
        })
        DataManager.read(self.props.bind_point)

        -- WebSocket连接（保留）
       -- if self.props.websocket_url and self.props.websocket_url ~= "" and lv then
           -- lv.connect(self.props.websocket_url, 3000)
       -- end
    end

    return self
end

return PopupButton