-- PropertyDataEditor.lua
-- 数据操作页面 - 简化版
local lv = require("lvgl")

local PropertyDataEditor = {}

-- 当前编辑状态
local _current_state = {
    dropdown_list = nil,
    is_dropdown_open = false,
    selected_widget = nil,
    saved_data = {}
}

-- 数据类型选项
local data_type_options = {
    { name = "实时数据", value = "realtime" },
    { name = "历史数据", value = "history" },
    { name = "批量数据", value = "batch" },
    { name = "告警数据", value = "alarm" },
    { name = "统计数据", value = "statistic" }
}

-- 获取控件唯一ID
local function get_widget_id(widget_entry)
    if not widget_entry then return nil end
    
    if widget_entry.instance and widget_entry.instance.get_id then
        return widget_entry.instance:get_id()
    end
    
    return tostring(widget_entry)
end

-- 获取控件的数据配置
local function get_widget_data(widget_entry)
    local widget_id = get_widget_id(widget_entry)
    if not widget_id then
        return {
            bind_point = "",
            websocket_url = "",
            http_config = {
                data_type = "实时数据",
                url = "",
                token = ""
            }
        }
    end
    
    if not _current_state.saved_data[widget_id] then
        _current_state.saved_data[widget_id] = {
            bind_point = "",
            websocket_url = "",
            http_config = {
                data_type = "实时数据",
                url = "",
                token = ""
            }
        }
    end
    
    return _current_state.saved_data[widget_id]
end

-- 保存控件的数据配置
local function save_widget_data(widget_entry, data)
    local widget_id = get_widget_id(widget_entry)
    if widget_id then
        _current_state.saved_data[widget_id] = data
        print("[数据编辑器] 保存控件 " .. widget_id .. " 的数据配置")
    end
end

-- 关闭下拉列表
local function close_dropdown()
    if _current_state.dropdown_list then
        pcall(function() _current_state.dropdown_list:delete() end)
        _current_state.dropdown_list = nil
        _current_state.is_dropdown_open = false
    end
end

function PropertyDataEditor.display(property_area)
    if not property_area or not property_area.content then
        print("[数据编辑器] 无效的属性区域")
        return
    end
    
    -- 先清空内容区域
    property_area:_clear_content_area()
    
    -- 获取当前选中的控件
    local selected_items = property_area:get_selected_items()
    local selected_widget = (selected_items and #selected_items > 0) and selected_items[1] or nil
    
    -- 如果没有选中控件，显示提示信息
    if not selected_widget then
        local placeholder = lv.label_create(property_area.content)
        placeholder:set_text("请先选择一个控件\n\n然后在数据页面配置该控件的数据绑定")
        placeholder:set_style_text_color(property_area.props.text_inactive_color, 0)
        placeholder:set_long_mode(lv.LABEL_LONG_WRAP)
        placeholder:set_width(property_area.props.width - 20)
        placeholder:align(lv.ALIGN_TOP_MID, 0, 50)
        return
    end
    
    -- 更新当前选中的控件
    _current_state.selected_widget = selected_widget
    
    -- 获取该控件的数据
    local widget_data = get_widget_data(selected_widget)
    
    local content = property_area.content
    local props = property_area.props
    
    -- 关闭可能打开的下拉框
    close_dropdown()
    
    -- 创建数据分类标签页
    local tab_height = 32
    local tab_y = 0
    
    local data_tab_bar = lv.obj_create(content)
    data_tab_bar:set_pos(0, tab_y)
    data_tab_bar:set_size(props.width, tab_height)
    data_tab_bar:set_style_bg_color(props.bg_color, 0)
    data_tab_bar:set_style_radius(0, 0)
    data_tab_bar:set_style_border_width(0, 1)
    data_tab_bar:set_style_border_color(props.border_color, 0)
    data_tab_bar:set_style_pad_all(0, 0)
    
    local tab_width = (props.width - 10) / 3
    
    -- 绑定数据点标签
    local bind_tab = lv.btn_create(data_tab_bar)
    bind_tab:set_size(tab_width, tab_height - 4)
    bind_tab:set_pos(5, 2)
    bind_tab:set_style_bg_color(props.tab_active_color, 0)
    
    local bind_label = lv.label_create(bind_tab)
    bind_label:set_text("绑定数据点")
    bind_label:center()
    
    -- WebSocket标签
    local ws_tab = lv.btn_create(data_tab_bar)
    ws_tab:set_size(tab_width, tab_height - 4)
    ws_tab:set_pos(5 + tab_width, 2)
    ws_tab:set_style_bg_color(props.tab_bg_color, 0)
    
    local ws_label = lv.label_create(ws_tab)
    ws_label:set_text("WebSocket")
    ws_label:center()
    
    -- HTTP标签
    local http_tab = lv.btn_create(data_tab_bar)
    http_tab:set_size(tab_width, tab_height - 4)
    http_tab:set_pos(5 + tab_width * 2, 2)
    http_tab:set_style_bg_color(props.tab_bg_color, 0)
    
    local http_label = lv.label_create(http_tab)
    http_label:set_text("HTTP")
    http_label:center()
    
    -- 内容展示区域
    local content_area_y = tab_height + 5
    local content_area_height = props.height - property_area.props.title_height - 
                                property_area.props.tab_height - tab_height - 10
    
    local content_area = lv.obj_create(content)
    content_area:set_pos(0, content_area_y)
    content_area:set_size(props.width, content_area_height)
    content_area:set_style_bg_opa(0, 0)
    content_area:set_style_border_width(0, 0)
    content_area:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 保存内容区域引用
    PropertyDataEditor.content_area = content_area
    PropertyDataEditor.props = props
    PropertyDataEditor.parent = property_area._parent
    PropertyDataEditor.abs_x = property_area.props.x
    PropertyDataEditor.abs_y = property_area.props.y + property_area.props.title_height + property_area.props.tab_height
    PropertyDataEditor.widget_data = widget_data
    PropertyDataEditor.selected_widget = selected_widget
    PropertyDataEditor.property_area = property_area
    
    -- 初始显示绑定数据点页面
    PropertyDataEditor._show_bind_page(content_area, props, widget_data)
    
    -- 添加标签切换事件
    bind_tab:add_event_cb(function()
        bind_tab:set_style_bg_color(props.tab_active_color, 0)
        ws_tab:set_style_bg_color(props.tab_bg_color, 0)
        http_tab:set_style_bg_color(props.tab_bg_color, 0)
        
        close_dropdown()
        PropertyDataEditor._clear_content_area(content_area)
        PropertyDataEditor._show_bind_page(content_area, props, widget_data)
    end, lv.EVENT_CLICKED, nil)
    
    ws_tab:add_event_cb(function()
        bind_tab:set_style_bg_color(props.tab_bg_color, 0)
        ws_tab:set_style_bg_color(props.tab_active_color, 0)
        http_tab:set_style_bg_color(props.tab_bg_color, 0)
        
        close_dropdown()
        PropertyDataEditor._clear_content_area(content_area)
        PropertyDataEditor._show_websocket_page(content_area, props, widget_data)
    end, lv.EVENT_CLICKED, nil)
    
    http_tab:add_event_cb(function()
        bind_tab:set_style_bg_color(props.tab_bg_color, 0)
        ws_tab:set_style_bg_color(props.tab_bg_color, 0)
        http_tab:set_style_bg_color(props.tab_active_color, 0)
        
        close_dropdown()
        PropertyDataEditor._clear_content_area(content_area)
        PropertyDataEditor._show_http_page(content_area, props, widget_data)
    end, lv.EVENT_CLICKED, nil)
end

function PropertyDataEditor._clear_content_area(area)
    if not area then
        return
    end
    
    local child = area:get_child(0)
    while child do
        child:delete()
        child = area:get_child(0)
    end
end

-- 显示绑定数据点页面
function PropertyDataEditor._show_bind_page(area, props, widget_data)
    local y = 20
    
    local title = lv.label_create(area)
    title:set_text("绑定数据点配置")
    title:set_style_text_color(props.text_color, 0)
    title:set_pos(10, y)
    
    y = y + 30
    
    local name_label = lv.label_create(area)
    name_label:set_text("数据点名称:")
    name_label:set_style_text_color(props.text_color, 0)
    name_label:set_pos(10, y)
    
    y = y + 25
    
    local name_input = lv.textarea_create(area)
    name_input:set_size(props.width - 40, 35)
    name_input:set_pos(10, y)
    name_input:set_style_bg_color(0x404040, 0)
    name_input:set_style_text_color(props.text_color, 0)
    name_input:set_style_radius(3, 0)
    name_input:set_style_border_width(1, 0)
    name_input:set_style_border_color(0x555555, 0)
    name_input:set_style_pad_all(5, 0)
    name_input:set_text(widget_data.bind_point or "")
    name_input:set_placeholder_text("请输入数据点名称")
    name_input:set_one_line(true)
    
    y = y + 50
    
    local save_btn = lv.btn_create(area)
    save_btn:set_size(120, 40)
    save_btn:set_pos((props.width - 120) / 2, y)
    save_btn:set_style_bg_color(0x4A90E2, 0)
    save_btn:set_style_radius(5, 0)
    
    local save_label = lv.label_create(save_btn)
    save_label:set_text("保存配置")
    save_label:center()
    
    save_btn:add_event_cb(function()
        local point_name = name_input:get_text()
        widget_data.bind_point = point_name
        save_widget_data(PropertyDataEditor.selected_widget, widget_data)
        print("[数据编辑器] 保存数据点名称: " .. point_name)
        PropertyDataEditor._show_success_tip(area, props, y + 50)
    end, lv.EVENT_CLICKED, nil)
end

-- 显示WebSocket页面
function PropertyDataEditor._show_websocket_page(area, props, widget_data)
    local y = 20
    
    local title = lv.label_create(area)
    title:set_text("WebSocket配置")
    title:set_style_text_color(props.text_color, 0)
    title:set_pos(10, y)
    
    y = y + 30
    
    local url_label = lv.label_create(area)
    url_label:set_text("WebSocket URL:")
    url_label:set_style_text_color(props.text_color, 0)
    url_label:set_pos(10, y)
    
    y = y + 25
    
    local url_input = lv.textarea_create(area)
    url_input:set_size(props.width - 40, 35)
    url_input:set_pos(10, y)
    url_input:set_style_bg_color(0x404040, 0)
    url_input:set_style_text_color(props.text_color, 0)
    url_input:set_style_radius(3, 0)
    url_input:set_style_border_width(1, 0)
    url_input:set_style_border_color(0x555555, 0)
    url_input:set_style_pad_all(5, 0)
    url_input:set_text(widget_data.websocket_url or "")
    url_input:set_placeholder_text("例如: ws://192.168.1.100:8080")
    url_input:set_one_line(true)
    
    y = y + 50
    
    local save_btn = lv.btn_create(area)
    save_btn:set_size(120, 40)
    save_btn:set_pos((props.width - 120) / 2, y)
    save_btn:set_style_bg_color(0x4A90E2, 0)
    save_btn:set_style_radius(5, 0)
    
    local save_label = lv.label_create(save_btn)
    save_label:set_text("保存配置")
    save_label:center()
    
    save_btn:add_event_cb(function()
        local ws_url = url_input:get_text()
        widget_data.websocket_url = ws_url
        save_widget_data(PropertyDataEditor.selected_widget, widget_data)
        print("[数据编辑器] 保存WebSocket URL: " .. ws_url)
        PropertyDataEditor._show_success_tip(area, props, y + 50)
    end, lv.EVENT_CLICKED, nil)
end

-- 创建数据类型下拉框
local function create_data_type_dropdown(area, props, y_pos, widget_data)
    local dropdown_container = lv.obj_create(area)
    dropdown_container:set_pos(70, y_pos)
    dropdown_container:set_size(props.width - 90, 26)
    dropdown_container:set_style_bg_color(0x1E1E1E, 0)
    dropdown_container:set_style_border_width(1, 0)
    dropdown_container:set_style_border_color(0x555555, 0)
    dropdown_container:set_style_radius(3, 0)
    dropdown_container:set_style_pad_all(2, 0)
    dropdown_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    dropdown_container:add_flag(lv.OBJ_FLAG_CLICKABLE)
    
    local current_type = widget_data.http_config.data_type or "实时数据"
    
    local display_label = lv.label_create(dropdown_container)
    display_label:set_text(current_type)
    display_label:set_style_text_color(0xFFFFFF, 0)
    display_label:align(lv.ALIGN_LEFT_MID, 6, 0)
    
    local arrow_label = lv.label_create(dropdown_container)
    arrow_label:set_text("▼")
    arrow_label:set_style_text_color(0xAAAAAA, 0)
    arrow_label:align(lv.ALIGN_RIGHT_MID, -6, 0)
    
    local function open_dropdown()
        if _current_state.is_dropdown_open then
            close_dropdown()
            return
        end
        
        close_dropdown()
        
        local list = lv.obj_create(PropertyDataEditor.parent or lv.scr_act())
        local list_height = #data_type_options * 26 + 6
        list:set_size(props.width - 90, list_height)
        
        local abs_x = PropertyDataEditor.abs_x + 70
        local abs_y = PropertyDataEditor.abs_y + y_pos + 30
        list:set_pos(abs_x, abs_y)
        
        list:set_style_bg_color(0x2D2D2D, 0)
        list:set_style_border_width(1, 0)
        list:set_style_border_color(0x555555, 0)
        list:set_style_radius(4, 0)
        list:set_style_pad_all(3, 0)
        list:add_flag(lv.OBJ_FLAG_SCROLLABLE)
        list:clear_layout()
        
        for i, option in ipairs(data_type_options) do
            local item = lv.obj_create(list)
            item:set_pos(0, (i - 1) * 26)
            item:set_size(props.width - 100, 24)
            item:set_style_bg_color(option.name == current_type and 0x007ACC or 0x3D3D3D, 0)
            item:set_style_radius(3, 0)
            item:set_style_border_width(0, 0)
            item:set_style_pad_all(0, 0)
            item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            item:add_flag(lv.OBJ_FLAG_CLICKABLE)
            
            local item_label = lv.label_create(item)
            item_label:set_text(option.name)
            item_label:set_style_text_color(0xFFFFFF, 0)
            item_label:align(lv.ALIGN_LEFT_MID, 8, 0)
            
            local opt_name = option.name
            item:add_event_cb(function(e)
                display_label:set_text(opt_name)
                widget_data.http_config.data_type = opt_name
                close_dropdown()
            end, lv.EVENT_CLICKED, nil)
        end
        
        _current_state.dropdown_list = list
        _current_state.is_dropdown_open = true
    end
    
    dropdown_container:add_event_cb(function(e)
        open_dropdown()
    end, lv.EVENT_CLICKED, nil)
    
    return dropdown_container
end

-- 显示HTTP页面
function PropertyDataEditor._show_http_page(area, props, widget_data)
    local y = 20
    
    local title = lv.label_create(area)
    title:set_text("HTTP配置")
    title:set_style_text_color(props.text_color, 0)
    title:set_pos(10, y)
    
    y = y + 30
    
    local type_label = lv.label_create(area)
    type_label:set_text("数据类型:")
    type_label:set_style_text_color(props.text_color, 0)
    type_label:set_pos(10, y + 3)
    
    create_data_type_dropdown(area, props, y, widget_data)
    y = y + 35
    
    local url_label = lv.label_create(area)
    url_label:set_text("URL地址:")
    url_label:set_style_text_color(props.text_color, 0)
    url_label:set_pos(10, y)
    
    y = y + 25
    
    local url_input = lv.textarea_create(area)
    url_input:set_size(props.width - 40, 35)
    url_input:set_pos(10, y)
    url_input:set_style_bg_color(0x404040, 0)
    url_input:set_style_text_color(props.text_color, 0)
    url_input:set_style_radius(3, 0)
    url_input:set_style_border_width(1, 0)
    url_input:set_style_border_color(0x555555, 0)
    url_input:set_style_pad_all(5, 0)
    url_input:set_text(widget_data.http_config.url or "")
    url_input:set_placeholder_text("例如: http://192.168.1.100/api/data")
    url_input:set_one_line(true)
    
    y = y + 50
    
    local token_label = lv.label_create(area)
    token_label:set_text("Token:")
    token_label:set_style_text_color(props.text_color, 0)
    token_label:set_pos(10, y)
    
    y = y + 25
    
    local token_input = lv.textarea_create(area)
    token_input:set_size(props.width - 40, 35)
    token_input:set_pos(10, y)
    token_input:set_style_bg_color(0x404040, 0)
    token_input:set_style_text_color(props.text_color, 0)
    token_input:set_style_radius(3, 0)
    token_input:set_style_border_width(1, 0)
    token_input:set_style_border_color(0x555555, 0)
    token_input:set_style_pad_all(5, 0)
    token_input:set_text(widget_data.http_config.token or "")
    token_input:set_placeholder_text("请输入认证Token")
    token_input:set_one_line(true)
    
    y = y + 50
    
    local save_btn = lv.btn_create(area)
    save_btn:set_size(120, 40)
    save_btn:set_pos((props.width - 120) / 2, y)
    save_btn:set_style_bg_color(0x4A90E2, 0)
    save_btn:set_style_radius(5, 0)
    
    local save_label = lv.label_create(save_btn)
    save_label:set_text("保存配置")
    save_label:center()
    
    save_btn:add_event_cb(function()
        widget_data.http_config.url = url_input:get_text()
        widget_data.http_config.token = token_input:get_text()
        save_widget_data(PropertyDataEditor.selected_widget, widget_data)
        
        print("[数据编辑器] 保存HTTP配置:")
        print("  数据类型: " .. widget_data.http_config.data_type)
        print("  URL: " .. widget_data.http_config.url)
        print("  Token: " .. widget_data.http_config.token)
        
        PropertyDataEditor._show_success_tip(area, props, y + 50)
    end, lv.EVENT_CLICKED, nil)
end

-- 显示保存成功提示
-- 显示保存成功提示
function PropertyDataEditor._show_success_tip(area, props, y_pos)
    local tip = lv.label_create(area)
    tip:set_text("保存成功！")
    tip:set_style_text_color(0x00FF00, 0)
    tip:set_pos((props.width - 80) / 2, y_pos)
    
    -- 2秒后直接删除，不管是否存在
    lv.timer_create(function()
        pcall(function() tip:delete() end)
    end, 2000, nil)
end

return PropertyDataEditor