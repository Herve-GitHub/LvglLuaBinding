-- 按钮点击弹出带标题和输入框的弹窗（含确认/取消按钮），弹窗贴近按钮，无del/destroy
local lv = require("lvgl")
local DataAction = require("editor.DataAction")

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
    
    -- 新增数据点绑定属性
    { name = "bind_point", type = "string", default = "", label = "绑定数据点",
      description = "例如: Device1.E, PLC1.D100" },
    { name = "websocket_url", type = "string", default = "", label = "WebSocket",
      description = "例如: ws://192.168.1.100:8080" },
  },
  events = { "confirm", "cancel" },
}

local function parse_color(c)
     if type(c) == "string"  and c:match("^#%x%x%x%x%x%x$")   then 
           return tonumber(c:sub(2), 16)
     elseif type(c) == "number" then 
           return c
      end
      return 0xffffff
end

local function apply_styles(self)
    -- 背景色
    local bg_color = parse_color(self.props.bg_color or "#007acc")
    if self.btn and self.btn.set_style_bg_color then 
        self.btn:set_style_bg_color(bg_color, 0)
    end

    -- 文本颜色
    local text_color = parse_color(self.props.color or "#ffffff")
    if self.label_widget and self.label_widget.set_style_text_color then 
        self.label_widget:set_style_text_color(text_color, 0)
    end
end

local function create_popup(self, parent)
    local scr = parent or lv.scr_act()
    local mask = lv.obj_create(scr)
    mask:set_size(scr:get_width(), scr:get_height())
    mask:set_style_bg_color(0x000000, 0)
    mask:set_style_bg_opa(64, 0)
    mask:add_flag(lv.OBJ_FLAG_CLICKABLE)
    mask:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    -- 等比例缩放弹窗整体大小
    local scale = 1.3
    local popup_w = math.floor(220 * scale)
    local popup_h = math.floor(120 * scale)

    -- 弹窗主体
    local popup = lv.obj_create(mask)
    popup:set_size(popup_w+10, popup_h+10)
    popup:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    -- 获取按钮参数
    local btn_x = self.btn:get_x()
    local btn_y = self.btn:get_y()
    local btn_w = self.btn:get_width()
    local btn_h = self.btn:get_height()

    -- 弹窗位置：水平居中对齐按钮，弹窗底部与按钮顶部对齐
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

    -- 按钮尺寸和位置
    local btn_w2 = math.floor(popup_w * 0.31)
    local btn_h2 = 32
    local btn_spacing = math.floor(popup_w * 0.08)
    local btn_y = popup_h - btn_h2 - 16

    -- 确认按钮
    local confirm_btn = lv.button_create(popup)
    confirm_btn:set_size(btn_w2, btn_h2-5)
    confirm_btn:set_pos(btn_spacing-18, btn_y-3)
    local confirm_label = lv.label_create(confirm_btn)
    confirm_label:set_text("确认")
    confirm_label:center()

    -- 取消按钮
    local cancel_btn = lv.button_create(popup)
    cancel_btn:set_size(btn_w2, btn_h2-5)
    cancel_btn:set_pos(popup_w - btn_w2 - btn_spacing-16, btn_y-3)
    local cancel_label = lv.label_create(cancel_btn)
    cancel_label:set_text("取消")
    cancel_label:center()

    -- 蒙版初始隐藏
    mask:add_flag(lv.OBJ_FLAG_HIDDEN)

    -- 公共句柄
    self._popup_mask = mask
    self._popup_textarea = textarea

    function self:show_popup()
        self._popup_textarea:set_text("")
        self._popup_mask:remove_flag(lv.OBJ_FLAG_HIDDEN)
    end

    function self:hide_popup()
        self._popup_mask:add_flag(lv.OBJ_FLAG_HIDDEN)
    end

    -- 确认按钮事件
    confirm_btn:add_event_cb(function()
        local value = textarea:get_text()
        
        -- 调用 confirm 回调
        if self._callbacks and self._callbacks.confirm then
            pcall(self._callbacks.confirm, self, value)
        end
        
        -- 如果绑定了数据点，发送数据
        if self.props.bind_point and self.props.bind_point ~= "" then
            print("[PopupButton] 发送数据到数据点: " .. self.props.bind_point .. " = " .. value)
            
            -- 使用 DataAction 发送数据
            if lvgl then
                lvgl.write(self.props.bind_point, value)
            else
                print("[PopupButton] 错误: lvgl 不存在")
            end
            
            -- 如果有 WebSocket 配置，也通过 WebSocket 发送
            if self.props.websocket_url and self.props.websocket_url ~= "" then
                -- 这里可以添加 WebSocket 发送逻辑
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

    -- 蒙版点击关闭
    mask:add_event_cb(function(e)
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
    for _, p in ipairs(PopupButton.__widget_meta.properties) do
        self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
    end

    self._callbacks = {}

    self.btn = lv.button_create(parent)
    self.btn:set_size(self.props.width, self.props.height)
    self.btn:set_pos(self.props.x, self.props.y)
    self.label_widget = lv.label_create(self.btn)
    self.label_widget:set_text(self.props.label)
    self.label_widget:center()

    apply_styles(self)

    -- 显示当前绑定数据点信息（如果有）
    local function update_button_label()
        local label_text = self.props.label
        if self.props.bind_point and self.props.bind_point ~= "" then
            label_text = label_text .. " [" .. self.props.bind_point .. "]"
        end
        self.label_widget:set_text(label_text)
    end
    update_button_label()

    -- 事件订阅接口
    function self.on(self, event_name, callback)
        self._callbacks[event_name] = callback
    end

    -- 获取LVGL容器
    function self.get_container(self) return self.btn end
    
    -- 获取单个属性
    function self.get_property(self, name) return self.props[name] end
    
    -- 设置单个属性
    function self.set_property(self, name, value)
        local old_value = self.props[name]
        self.props[name] = value
        
        if name == "label" then 
            local label_text = value
            if self.props.bind_point and self.props.bind_point ~= "" then
                label_text = label_text .. " [" .. self.props.bind_point .. "]"
            end
            self.label_widget:set_text(label_text) 
        end
       -- if name == "bind_point" then
            -- 更新按钮文本显示绑定点信息
          --  local label_text = self.props.label
          --  if value and value ~= "" then
          --      label_text = label_text .. " [" .. value .. "]"
         --   end
         --   self.label_widget:set_text(label_text)
       -- end
        if name == "x" or name == "y" then 
            self.btn:set_pos(self.props.x, self.props.y) 
        end
        if name == "width" or name == "height" then 
            self.btn:set_size(self.props.width, self.props.height) 
        end
        if name == "color" or name =="bg_color" then 
            apply_styles(self) 
        end
        
        return true
    end
    
    -- 获取所有属性
    function self.get_properties(self)
        local out = {}
        for k, v in pairs(self.props) do out[k] = v end
        return out
    end
    
    -- 批量应用属性
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
    
    -- 获取控件ID
    function self.get_id(self) 
        return tostring(self) 
    end

    -- 创建弹窗
    create_popup(self, lv.scr_act())

    -- 按钮点击事件：显示弹窗
    self.btn:add_event_cb(function()
        self:show_popup()
    end, lv.EVENT_CLICKED, nil)

    return self
end

return PopupButton