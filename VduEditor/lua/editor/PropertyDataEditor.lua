-- editor/PropertyDataEditor.lua
-- 数据配置面板 - 修复版

local lv = require("lvgl")
-- 确保 json 模块已引入
local json = require("json") or require("dkjson")
local DataAction = require("editor.DataAction") or {}

local PropertyDataEditor = {}

-- 默认配置（仅在首次运行/配置文件丢失时使用）
local DEFAULT_CONFIG = {
    websocket_urls = {
        "ws://192.168.0.100:8085/ws",
        "ws://192.168.0.60:8085/ws",
        "ws://192.168.0.99:8085/ws",
        "ws://localhost:8085/ws"
    },
    data_points = {
        "Device1.tag0001",
        "Device1.tag0002",
        "Device2.tag0001",
        "user.tag0001",
        "Device2.humidity",
        "System.status"
    }
}

-- 实际使用的配置（会从文件加载）
local config = {}

-- 配置文件路径
local CONFIG_FILE = "data_editor_config.json"

-- 加载配置（修复核心：优先加载文件，文件不存在时使用默认配置）
local function load_config()
    -- 先清空现有配置
    config = {}
    
    local file = io.open(CONFIG_FILE, "r")
    if file then
        -- 有配置文件，加载文件内容
        local content = file:read("*a")
        file:close()
        local ok, loaded = pcall(json.decode, content)
        if ok and loaded then
            config = loaded
        else
            -- 配置文件损坏，使用默认配置
            config = table.deepcopy(DEFAULT_CONFIG)
        end
    else
        -- 无配置文件，使用默认配置
        config = table.deepcopy(DEFAULT_CONFIG)
    end
end

-- 保存配置（增加错误处理）
local function save_config()
    local ok, content = pcall(json.encode, config)
    if ok then
        local file, err = io.open(CONFIG_FILE, "w")
        if file then
            file:write(content)
            file:close()
        else
            print("[错误] 保存配置失败:", err)
        end
    else
        print("[错误] 编码配置失败:", content)
    end
end

-- 深拷贝函数（用于默认配置复制，避免引用问题）
function table.deepcopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in next, orig, nil do
            copy[table.deepcopy(k)] = table.deepcopy(v)
        end
        setmetatable(copy, table.deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- 创建带选择按钮的输入框
local function create_input_with_button(parent, x, y, width, height, placeholder, current_text, on_select)
    -- 输入框
    local input = lv.textarea_create(parent)
    input:set_pos(x, y)
    input:set_size(width - 45, height)
    input:set_style_bg_color(0x2D2D2D, 0)
    input:set_style_text_color(0xFFFFFF, 0)
    input:set_style_border_width(1, 0)
    input:set_style_border_color(0x555555, 0)
    input:set_style_radius(3, 0)
    input:set_style_pad_all(8, 0)
    input:set_one_line(true)
    input:set_text(current_text or "")
    input:set_placeholder_text(placeholder)
    
    -- 选择按钮
    local btn = lv.btn_create(parent)
    btn:set_pos(x + width - 40, y)
    btn:set_size(35, height)
    btn:set_style_bg_color(0x4A4A4A, 0)
    btn:set_style_radius(3, 0)
    
    local btn_label = lv.label_create(btn)
    btn_label:set_text("...")
    btn_label:center()
    
    -- 存储弹窗引用
    local list_popup = nil
    
    -- 按钮点击事件
    btn:add_event_cb(function()
        -- 如果弹窗已存在，则隐藏并删除
        if list_popup then
            pcall(function() list_popup:delete() end)
            list_popup = nil
            return
        end
        
        -- 创建选择列表弹窗
        local list_width = 250
        local list_height = 280
        local list_x = x + width - list_width
        local list_y = y + height + 5
        
        -- 确保列表在屏幕内
        if list_x < 0 then list_x = 5 end
        if list_y + list_height > 480 then list_y = y - list_height - 5 end
        
        -- 创建列表容器（修复弹窗位置错误）
        list_popup = lv.obj_create(lv.scr_act())
        list_popup:set_pos(list_x, list_y)  -- 移除了+500和+100的错误偏移
        list_popup:set_size(list_width, list_height)
        list_popup:set_style_bg_color(0x2D2D2D, 0)
        list_popup:set_style_border_width(1, 0)
        list_popup:set_style_border_color(0x555555, 0)
        list_popup:set_style_radius(5, 0)
        list_popup:set_style_shadow_width(10, 0)
        list_popup:set_style_shadow_color(0x000000, 0)
        list_popup:set_style_pad_all(5, 0)
        
        -- 标题
        local title = lv.label_create(list_popup)
        title:set_text(on_select == "url" and "选择WebSocket URL" or "选择数据点")
        title:set_style_text_color(0xAAAAAA, 0)
        title:align(lv.ALIGN_TOP_MID, 0, 5)
        
        -- 创建列表容器（不使用lv.list，直接用obj）
        local list_container = lv.obj_create(list_popup)
        list_container:set_size(list_width - 20, 150)
        list_container:align(lv.ALIGN_TOP_MID, 0, 30)
        list_container:set_style_bg_color(0x3D3D3D, 0)
        list_container:set_style_border_width(1, 0)
        list_container:set_style_border_color(0x555555, 0)
        list_container:set_style_pad_all(5, 0)
        list_container:set_style_radius(3, 0)
        
        -- 添加预设项
        local items = (on_select == "url") and config.websocket_urls or config.data_points
        local item_y = 5
        
        for i, item in ipairs(items) do
            -- 创建项目按钮
            local item_btn = lv.btn_create(list_container)
            item_btn:set_size(list_width - 40, 30)
            item_btn:set_pos(5, item_y)
            item_btn:set_style_bg_color(0x4A4A4A, 0)
            item_btn:set_style_radius(3, 0)
            
            -- 添加状态用于悬停效果
            item_btn:add_state(lv.STATE_FOCUSED)
            
            local item_label = lv.label_create(item_btn)
            item_label:set_text(item)
            item_label:center()
            item_label:set_style_text_color(0xFFFFFF, 0)
            
            -- 点击选择
            item_btn:add_event_cb(function()
                input:set_text(item)
                pcall(function() list_popup:delete() end)
                list_popup = nil
            end, lv.EVENT_CLICKED, nil)
            
            item_y = item_y + 35
        end
        
        -- 分隔线
        local line = lv.obj_create(list_popup)
        line:set_size(list_width - 40, 1)
        line:set_pos(20, 190)
        line:set_style_bg_color(0x555555, 0)
        line:set_style_border_width(0, 0)
        
        -- 自定义输入标签
        local custom_label = lv.label_create(list_popup)
        custom_label:set_text("添加新项:")
        custom_label:set_style_text_color(0xCCCCCC, 0)
        custom_label:set_pos(10, 200)
        
        -- 自定义输入框
        local custom_input = lv.textarea_create(list_popup)
        custom_input:set_size(list_width - 80, 30)
        custom_input:set_pos(10, 220)
        custom_input:set_style_bg_color(0x3D3D3D, 0)
        custom_input:set_style_text_color(0xFFFFFF, 0)
        custom_input:set_style_border_width(1, 0)
        custom_input:set_style_border_color(0x555555, 0)
        custom_input:set_style_radius(3, 0)
        custom_input:set_style_pad_all(5, 0)
        custom_input:set_one_line(true)
        custom_input:set_placeholder_text("输入新项...")
        
        -- 添加按钮
        local add_btn = lv.btn_create(list_popup)
        add_btn:set_size(60, 30)
        add_btn:set_pos(list_width - 70, 220)
        add_btn:set_style_bg_color(0x4A90E2, 0)
        add_btn:set_style_radius(3, 0)
        
        local add_label = lv.label_create(add_btn)
        add_label:set_text("添加")
        add_label:center()
        
        add_btn:add_event_cb(function()
            local new_text = custom_input:get_text()
            if new_text and #new_text > 0 then
                input:set_text(new_text)
                
                -- 添加到配置
                local target_list = (on_select == "url") and config.websocket_urls or config.data_points
                -- 避免重复添加
                local is_duplicate = false
                for _, v in ipairs(target_list) do
                    if v == new_text then
                        is_duplicate = true
                        break
                    end
                end
                if not is_duplicate then
                    table.insert(target_list, new_text)
                    save_config()  -- 立即保存
                end
                
                pcall(function() list_popup:delete() end)
                list_popup = nil
            end
        end, lv.EVENT_CLICKED, nil)
        
        -- 关闭按钮
        local close_btn = lv.btn_create(list_popup)
        close_btn:set_size(80, 25)
        close_btn:set_pos((list_width - 80) / 2, 255)
        close_btn:set_style_bg_color(0x666666, 0)
        close_btn:set_style_radius(3, 0)
        
        local close_label = lv.label_create(close_btn)
        close_label:set_text("关闭")
        close_label:center()
        
        close_btn:add_event_cb(function()
            pcall(function() list_popup:delete() end)
            list_popup = nil
        end, lv.EVENT_CLICKED, nil)
        
        -- 阻止点击弹窗内部时关闭
        list_popup:add_event_cb(function(e)
            -- 阻止事件冒泡
            return true
        end, lv.EVENT_CLICKED, nil)
        
    end, lv.EVENT_CLICKED, nil)
    
    return input, btn
end

-- 显示数据配置页面
function PropertyDataEditor.display(property_area)
    if not property_area or not property_area.content then
        return
    end
    
    -- 先加载配置（确保每次显示时都从文件读取最新配置）
    load_config()
    
    -- 清空内容区域
    property_area:_clear_content_area()
    
    -- 获取选中的控件
    local selected_items = property_area:get_selected_items()
    local widget = (selected_items and #selected_items > 0) and selected_items[1] or nil
    
    if not widget then
        local tip = lv.label_create(property_area.content)
        tip:set_text("请先选择一个控件")
        tip:set_style_text_color(0xFFA500, 0)
        tip:align(lv.ALIGN_TOP_MID, 0, 50)
        return
    end
    
    local instance = widget.instance
    if not instance or not instance.get_property then
        return
    end
    
    local content = property_area.content
    local props = property_area.props
    local y = 10
    
    -- 标题
    local title = lv.label_create(content)
    title:set_text("WebSocket 数据配置")
    title:set_style_text_color(0x4A90E2, 0)
    title:set_pos(10, y)
    y = y + 30
    
    -- 获取当前配置
    local bind_point = instance:get_property("bind_point") or ""
    local websocket_url = instance:get_property("websocket_url") or ""
    local custom_value = instance:get_property("custom_value") or ""
    
    -- ===== WebSocket URL =====
    local url_label = lv.label_create(content)
    url_label:set_text("WebSocket URL:")
    url_label:set_style_text_color(0xCCCCCC, 0)
    url_label:set_pos(10, y)
    y = y + 25
    
    -- 修复：接收两个返回值（input和btn）
    local url_input, url_btn = create_input_with_button(
        content, 10, y, props.width - 20, 35,
        "ws://192.168.1.100:8080/ws", websocket_url, "url"
    )
    y = y + 45
    
    -- ===== 数据点名称 =====
    local point_label = lv.label_create(content)
    point_label:set_text("数据点名称:")
    point_label:set_style_text_color(0xCCCCCC, 0)
    point_label:set_pos(10, y)
    y = y + 25
    
    -- 修复：接收两个返回值（input和btn）
    local point_input, point_btn = create_input_with_button(
        content, 10, y, props.width - 20, 35,
        "Device1.tag0001", bind_point, "point"
    )
    y = y + 45
    
    -- ===== 写入值 =====
    local value_label = lv.label_create(content)
    value_label:set_text("写入值:")
    value_label:set_style_text_color(0xCCCCCC, 0)
    value_label:set_pos(10, y)
    y = y + 25
    
    local value_input = lv.textarea_create(content)
    value_input:set_pos(10, y)
    value_input:set_size(props.width - 35, 35)
    value_input:set_style_bg_color(0x2D2D2D, 0)
    value_input:set_style_text_color(0xFFFFFF, 0)
    value_input:set_style_border_width(1, 0)
    value_input:set_style_border_color(0x555555, 0)
    value_input:set_style_radius(3, 0)
    value_input:set_style_pad_all(8, 0)
    value_input:set_one_line(true)
    value_input:set_text(custom_value)
    value_input:set_placeholder_text("42")
    y = y + 50
    
    -- ===== 保存按钮 =====
    local save_btn = lv.btn_create(content)
    save_btn:set_size(120, 35)
    save_btn:set_pos((props.width - 120) / 2, y)
    save_btn:set_style_bg_color(0x4A90E2, 0)
    save_btn:set_style_radius(5, 0)
    
    local save_label = lv.label_create(save_btn)
    save_label:set_text("保存配置")
    save_label:center()
    
    save_btn:add_event_cb(function()
        -- 获取输入值
        local new_url = url_input:get_text()
        local new_point = point_input:get_text()
        local new_value = value_input:get_text()
        
        -- 保存到控件
        if instance.set_property then
            instance:set_property("websocket_url", new_url)
            instance:set_property("bind_point", new_point)
            instance:set_property("custom_value", new_value)
            
            -- 显示成功提示
            local tip = lv.label_create(content)
            tip:set_text("保存成功")
            tip:set_style_text_color(0x00FF00, 0)
            tip:set_pos((props.width - 80) / 2, y + 45)
            
            lv.timer_create(function()
                pcall(function() tip:delete() end)
            end, 1500, nil)
            
            print("[数据] 已保存: " .. new_point .. " = " .. new_value .. " @ " .. new_url)
        end
    end, lv.EVENT_CLICKED, nil)
end

-- 初始化时先加载一次配置
load_config()

return PropertyDataEditor