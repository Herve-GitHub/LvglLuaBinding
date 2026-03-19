-- ==============================================
-- 自动生成的Lua脚本
-- 由 VduEditor 编译生成
-- 生成时间: 2026-03-19 13:50:08
-- 工程版本: 1.0
-- ==============================================

-- 启动网络服务
lvgl.start_network_service(100)
lvgl.connect("ws://192.168.0.80:8085/ws/", 3000)

-- 引用 LVGL
local lv = require("lvgl")

-- 引用控件模块
local widgets_PopupButton = require("widgets.PopupButton")
local widgets_new_button = require("widgets.new_button")
local widgets_new_label = require("widgets.new_label")
local widgets_switch = require("widgets.switch")
local widgets_image = require("widgets.image")

-- 引用动作模块
local actions_page_navigation = require("actions.page_navigation")
local editor_DataAction = require("editor.DataAction")
local actions_LabelAction = require("actions.LabelAction")
local actions_SitwchAction = require("actions.SitwchAction")

-- 获取活动屏幕
local scr = lv.scr_act()
scr:set_style_bg_color(0x1E1E1E, 0)
scr:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
scr:clear_layout()

-- 获取屏幕尺寸
local scr_width = scr:get_width()
local scr_height = scr:get_height()

-- ========== 图页 1: 图页 1 ==========
-- 图页尺寸: 800x600
-- 背景颜色: 0x1E1E1E
local function create_page_1(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(800, 600)
    container:set_style_bg_color(0x1E1E1E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: custom_image
    local widget_1 = widgets_image.new(container, {
        rotation = 0,
        scale = 256,
        instance_name = "",
        design_mode = false,
        on_loaded_handler = "",
        width = 800,
        src = "C:/Test/LUATEST2/ahu3.png",
        scale_x = 256,
        height = 600,
        x = 0,
        opa = 255,
        y = 0,
        scale_y = 256,
        mode = "normal"
    })

    -- 控件 2: custom_button
    local widget_2 = widgets_new_button.new(container, {
        http_url = "",
        instance_name = "",
        design_mode = false,
        false_color = "#ffffff",
        width = 80,
        on_clicked_handler = "",
        font_size = 16,
        height = 30,
        true_bg_color = "#ffffff",
        bg_color = "#5C400E",
        http_token = "",
        bind_point = "THmeter.AirRoomTemp1",
        label = "OK",
        alignment = "center",
        enabled = true,
        color = "#ffffff",
        http_data_type = "实时数据",
        custom_address = "",
        websocket_url = "ws://192.168.0.80:8085/ws/",
        on_single_clicked_handler = "",
        compare_operator = "大于",
        event_action = "读取绑定数据点",
        compare_value = "0",
        true_color = "#ffffff",
        custom_value = "",
        x = 289,
        y = 20,
        false_bg_color = "#ffffff",
        on_double_clicked_handler = ""
    })

    -- 控件 3: label
    local widget_3 = widgets_new_label.new(container, {
        http_url = "",
        bind_point = "",
        design_mode = false,
        instance_name = "",
        text = "温度",
        on_clicked_handler = "",
        font_size = 16,
        height = 30,
        true_bg_color = "#ffffff",
        bg_opa = 0,
        text_color = "#FFFFFF",
        visible = true,
        bg_color = "#00000000",
        websocket_url = "",
        true_color = "#ffffff",
        custom_address = "",
        width = 100,
        long_mode = "wrap",
        http_token = "",
        custom_value = "",
        compare_operator = "大于",
        event_action = "写入绑定数据点",
        compare_value = "0",
        alignment = "left",
        false_color = "#ffffff",
        x = 249,
        y = 29,
        http_data_type = "实时数据",
        false_bg_color = "#ffffff"
    })

    -- 控件 4: popup_button_simple
    local widget_4 = widgets_PopupButton.new(container, {
        bind_point = "THmeter.AirRoomTemp1",
        design_mode = false,
        popup_title = "请输入",
        color = "#ffffff",
        websocket_url = "ws://192.168.0.80:8085/ws/",
        width = 80,
        alignment = "center",
        input_hint = "请输入...",
        height = 30,
        y = 72,
        bg_color = "#5C400E",
        font_size = 16,
        x = 292,
        label = "OK"
    })

    -- 控件 5: label
    local widget_5 = widgets_new_label.new(container, {
        http_url = "",
        bind_point = "",
        design_mode = false,
        instance_name = "",
        text = "℃",
        on_clicked_handler = "",
        font_size = 16,
        height = 30,
        true_bg_color = "#ffffff",
        bg_opa = 0,
        text_color = "#FFFFFF",
        visible = true,
        bg_color = "#00000000",
        websocket_url = "",
        true_color = "#ffffff",
        custom_address = "",
        width = 100,
        long_mode = "wrap",
        http_token = "",
        custom_value = "",
        compare_operator = "大于",
        event_action = "写入绑定数据点",
        compare_value = "0",
        alignment = "left",
        false_color = "#ffffff",
        x = 371,
        y = 28,
        http_data_type = "实时数据",
        false_bg_color = "#ffffff"
    })

    -- 控件 6: popup_button_simple
    local widget_6 = widgets_PopupButton.new(container, {
        bind_point = "THmeter.AirRoomTemp2",
        design_mode = false,
        popup_title = "请输入",
        color = "#ffffff",
        websocket_url = "ws://192.168.0.80:8085/ws/",
        width = 80,
        alignment = "center",
        input_hint = "请输入...",
        height = 30,
        y = 127,
        bg_color = "#5C400E",
        font_size = 16,
        x = 291,
        label = "OK"
    })

    -- 控件 7: custom_image
    local widget_7 = widgets_image.new(container, {
        rotation = 0,
        scale = 256,
        instance_name = "",
        design_mode = false,
        on_loaded_handler = "",
        width = 100,
        src = "jjjj.png",
        scale_x = 256,
        height = 100,
        x = 547,
        opa = 255,
        y = 114,
        scale_y = 256,
        mode = "normal"
    })

    -- 控件 8: custom_switch
    local widget_8 = widgets_switch.new(container, {
        bind_point = "THmeter.AirRoomTemp3",
        design_mode = false,
        instance_name = "",
        switch_state = true,
        bg_color_off = "#888888",
        width = 60,
        on_value_changed_handler = "",
        websocket_url = "ws://192.168.0.80:8085/ws/",
        height = 30,
        x = 503,
        on_value = "1",
        y = 128,
        off_value = "0",
        event_action = "读取绑定数据点"
    })

    return container
end

-- ========== 图页管理（预创建模式） ==========
local PageManager = {}
PageManager.pages = {}        -- 图页信息
PageManager.containers = {}   -- 预创建的图页容器
PageManager.current_index = 0

-- 注册图页创建函数
PageManager.pages[1] = { name = "图页 1", create = create_page_1 }

-- 预创建所有图页（启动时调用）
function PageManager.init()
    print("[PageManager] 预创建所有图页...")
    for i, page_info in ipairs(PageManager.pages) do
        if page_info.create then
            local container = page_info.create(scr)
            -- 默认隐藏所有图页
            container:add_flag(lv.OBJ_FLAG_HIDDEN)
            PageManager.containers[i] = container
            print("[PageManager] 图页 " .. i .. " 已创建: " .. page_info.name)
        end
    end
    print("[PageManager] 所有图页创建完成，共 " .. #PageManager.containers .. " 个")
end

-- 获取图页数量
function PageManager.get_page_count()
    return #PageManager.pages
end

-- 获取当前选中的图页
function PageManager.get_selected_page()
    if PageManager.current_index > 0 then
        return PageManager.pages[PageManager.current_index], PageManager.current_index
    end
    return nil, 0
end

-- 获取所有图页
function PageManager.get_pages()
    return PageManager.pages
end

-- 选择图页（与 goto_page 相同）
function PageManager.select_page(index)
    return PageManager.goto_page(index)
end

-- 切换图页（显示/隐藏模式，不销毁图页）
function PageManager.goto_page(index)
    if index < 1 or index > #PageManager.pages then
        print("[PageManager] 无效的图页索引: " .. tostring(index))
        return false
    end

    -- 隐藏当前图页
    if PageManager.current_index > 0 and PageManager.containers[PageManager.current_index] then
        PageManager.containers[PageManager.current_index]:add_flag(lv.OBJ_FLAG_HIDDEN)
    end

    -- 显示目标图页
    if PageManager.containers[index] then
        PageManager.containers[index]:remove_flag(lv.OBJ_FLAG_HIDDEN)
        PageManager.current_index = index
        print("[PageManager] 切换到图页 " .. index .. ": " .. PageManager.pages[index].name)
        return true
    end

    return false
end

-- 获取指定图页的容器
function PageManager.get_page_container(index)
    return PageManager.containers[index]
end

-- 获取当前图页的容器
function PageManager.get_current_container()
    return PageManager.containers[PageManager.current_index]
end

-- 导出图页管理器到全局
_G.PageManager = PageManager

-- 创建模拟编辑器接口（供 actions 模块使用）
_G.Editor = {
    get_canvas_list = function()
        return PageManager
    end,
}

-- ========== 启动 ==========
print("=== 组态程序启动 ===")
print("图页数量: " .. #PageManager.pages)

-- 预创建所有图页
PageManager.init()

-- 显示初始图页
PageManager.goto_page(1)

print("=== 组态程序已就绪 ===")
