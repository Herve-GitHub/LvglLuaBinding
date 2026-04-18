-- ==============================================
-- 自动生成的Lua脚本
-- 由 json_to_lua.py 编译生成
-- 生成时间: 2026-04-18 08:16:00
-- 工程版本: 1.0
-- ==============================================

-- 启动网络服务
lvgl.start_network_service(3000)
lvgl.connect("ws://192.168.0.60:8085/ws/", 3000)

-- 引用 LVGL
local lv = require("lvgl")

-- 引用控件模块
local widgets_button = require("widgets.button")
local widgets_checkbox = require("widgets.checkbox")
local widgets_dropdown = require("widgets.dropdown")
local widgets_label = require("widgets.label")
local widgets_slider = require("widgets.slider")
local widgets_status_bar = require("widgets.status_bar")
local widgets_switch = require("widgets.switch")
local widgets_trend_chart = require("widgets.trend_chart")
local widgets_valve = require("widgets.valve")

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

-- ========== 状态栏 ==========
local status_bar = nil
local STATUS_BAR_HEIGHT = 28

local function create_status_bar()
    local sb_y = scr_height - STATUS_BAR_HEIGHT
    status_bar = widgets_status_bar.new(scr, {
        x = 0,
        y = sb_y,
        width = scr_width,
        height = STATUS_BAR_HEIGHT,
        position = "bottom",
        lamp_status = "#00FF00",
        lamp_text = "在线",
        bg_color = "#252526",
        text_color = "#CCCCCC",
        show_time = true,
        lamp_size = 14,
        design_mode = false,
    })
    status_bar:start()
    return status_bar
end

-- ========== 图页 1: 主页 ==========
-- 图页尺寸: 1024x572
-- 背景颜色: 0x1E1E2E
local function create_page_1(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(1024, 572)
    container:set_style_bg_color(0x1E1E2E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: label (title_label)
    local title_label = widgets_label.new(container, {
        instance_name = "title_label",
        x = 50,
        y = 20,
        width = 400,
        height = 36,
        label = "设备监控系统",
        color = "#FFFFFF",
        font_size = 24,
        alignment = "left",
        design_mode = false
    })

    -- 控件 2: custom_button (btn_page2)
    local btn_page2 = widgets_button.new(container, {
        instance_name = "btn_page2",
        x = 50,
        y = 80,
        width = 120,
        height = 40,
        label = "趋势图",
        bg_color = "#007ACC",
        color = "#FFFFFF",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_page(2)\nend",
        design_mode = false
    })

    -- clicked 事件处理
    btn_page2:on("clicked", function(self)
    actions_page_navigation.goto_page(2)
end)

    -- 控件 3: custom_button (btn_page3)
    local btn_page3 = widgets_button.new(container, {
        instance_name = "btn_page3",
        x = 190,
        y = 80,
        width = 120,
        height = 40,
        label = "阀门控制",
        bg_color = "#388E3C",
        color = "#FFFFFF",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_page(3)\nend",
        design_mode = false
    })

    -- clicked 事件处理
    btn_page3:on("clicked", function(self)
    actions_page_navigation.goto_page(3)
end)

    -- 控件 4: custom_button (btn_read_temp)
    local btn_read_temp = widgets_button.new(container, {
        instance_name = "btn_read_temp",
        x = 50,
        y = 150,
        width = 160,
        height = 40,
        label = "读取温度",
        bg_color = "#5C6BC0",
        color = "#FFFFFF",
        font_size = 16,
        event_action = "读取绑定数据点",
        bind_point = "THmeter.AirRoomTemp1",
        websocket_url = "ws://192.168.0.60:8085/ws/",
        design_mode = false
    })

    -- 控件 5: label (temp_display)
    local temp_display = widgets_label.new(container, {
        instance_name = "temp_display",
        x = 230,
        y = 150,
        width = 200,
        height = 40,
        label = "温度: --",
        color = "#FFD700",
        font_size = 18,
        alignment = "left",
        design_mode = false
    })

    -- 控件 6: slider (brightness_slider)
    local brightness_slider = widgets_slider.new(container, {
        instance_name = "brightness_slider",
        x = 50,
        y = 220,
        width = 300,
        height = 24,
        min_value = 0,
        max_value = 100,
        value = 75,
        show_value = true,
        bg_color = "#3C3C3C",
        indicator_color = "#007ACC",
        knob_color = "#FFFFFF",
        on_changed_handler = "function(self)\n    print(\"亮度:\", self:get_property(\"value\"))\nend",
        design_mode = false
    })

    -- changed 事件处理
    brightness_slider:on("changed", function(self)
    print("亮度:", self:get_property("value"))
end)

    -- 控件 7: switch (light_switch)
    local light_switch = widgets_switch.new(container, {
        instance_name = "light_switch",
        x = 50,
        y = 270,
        width = 60,
        height = 30,
        on_changed_handler = "function(self)\n    local is_on = self:get_property(\"checked\")\n    print(\"灯:\", is_on and \"开\" or \"关\")\nend",
        design_mode = false
    })

    -- changed 事件处理
    light_switch:on("changed", function(self)
    local is_on = self:get_property("checked")
    print("灯:", is_on and "开" or "关")
end)

    -- 控件 8: checkbox (alarm_checkbox)
    local alarm_checkbox = widgets_checkbox.new(container, {
        instance_name = "alarm_checkbox",
        x = 50,
        y = 320,
        width = 160,
        height = 30,
        text = "启用报警",
        checked = false,
        text_color = "#FFFFFF",
        on_changed_handler = "function(self)\n    local checked = self:get_property(\"checked\")\n    print(\"报警:\", checked and \"已启用\" or \"已禁用\")\nend",
        design_mode = false
    })

    -- changed 事件处理
    alarm_checkbox:on("changed", function(self)
    local checked = self:get_property("checked")
    print("报警:", checked and "已启用" or "已禁用")
end)

    -- 控件 9: dropdown (channel_dropdown)
    local channel_dropdown = widgets_dropdown.new(container, {
        instance_name = "channel_dropdown",
        x = 50,
        y = 370,
        width = 200,
        height = 36,
        options = "通道1\n通道2\n通道3\n通道4",
        selected_index = 0,
        bg_color = "#3C3C3C",
        text_color = "#FFFFFF",
        on_changed_handler = "function(self)\n    local idx = self:get_property(\"selected_index\")\n    print(\"选择通道:\", idx + 1)\nend",
        design_mode = false
    })

    -- changed 事件处理
    channel_dropdown:on("changed", function(self)
    local idx = self:get_property("selected_index")
    print("选择通道:", idx + 1)
end)

    return container
end

-- ========== 图页 2: 趋势图 ==========
-- 图页尺寸: 1024x572
-- 背景颜色: 0x1E1E2E
local function create_page_2(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(1024, 572)
    container:set_style_bg_color(0x1E1E2E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: trend_chart (temp_chart)
    local temp_chart = widgets_trend_chart.new(container, {
        instance_name = "temp_chart",
        x = 30,
        y = 30,
        width = 700,
        height = 300,
        point_count = 120,
        update_interval = 1000,
        range_min = 0,
        range_max = 100,
        auto_update = true,
        on_updated_handler = "function(self, value)\n    print(\"图表更新:\", value)\nend",
        design_mode = false
    })

    -- updated 事件处理
    temp_chart:on("updated", function(self, value)
    print("图表更新:", value)
end)

    -- 控件 2: custom_button (btn_back_from_chart)
    local btn_back_from_chart = widgets_button.new(container, {
        instance_name = "btn_back_from_chart",
        x = 30,
        y = 360,
        width = 120,
        height = 40,
        label = "返回主页",
        bg_color = "#607D8B",
        color = "#FFFFFF",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_page(1)\nend",
        design_mode = false
    })

    -- clicked 事件处理
    btn_back_from_chart:on("clicked", function(self)
    actions_page_navigation.goto_page(1)
end)

    return container
end

-- ========== 图页 3: 阀门控制 ==========
-- 图页尺寸: 1024x572
-- 背景颜色: 0x1E2E1E
local function create_page_3(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(1024, 572)
    container:set_style_bg_color(0x1E2E1E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: valve (valve_inlet)
    local valve_inlet = widgets_valve.new(container, {
        instance_name = "valve_inlet",
        x = 80,
        y = 60,
        size = 120,
        angle = 0,
        open_angle = 90,
        close_angle = 0,
        handle_color = "#FF5722",
        on_toggled_handler = "function(self, is_open)\n    print(\"进水阀:\", is_open and \"开\" or \"关\")\n    if is_open then\n        lvgl.write(\"Device1.InletValve\", \"1\")\n    else\n        lvgl.write(\"Device1.InletValve\", \"0\")\n    end\nend",
        design_mode = false
    })

    -- toggled 事件处理
    valve_inlet:on("toggled", function(self, is_open)
    print("进水阀:", is_open and "开" or "关")
    if is_open then
        lvgl.write("Device1.InletValve", "1")
    else
        lvgl.write("Device1.InletValve", "0")
    end
end)

    -- 控件 2: valve (valve_outlet)
    local valve_outlet = widgets_valve.new(container, {
        instance_name = "valve_outlet",
        x = 240,
        y = 60,
        size = 120,
        angle = 0,
        open_angle = 90,
        close_angle = 0,
        handle_color = "#4CAF50",
        on_toggled_handler = "function(self, is_open)\n    print(\"出水阀:\", is_open and \"开\" or \"关\")\nend",
        design_mode = false
    })

    -- toggled 事件处理
    valve_outlet:on("toggled", function(self, is_open)
    print("出水阀:", is_open and "开" or "关")
end)

    -- 控件 3: custom_button (btn_open_all_valves)
    local btn_open_all_valves = widgets_button.new(container, {
        instance_name = "btn_open_all_valves",
        x = 80,
        y = 210,
        width = 120,
        height = 40,
        label = "一键全开",
        bg_color = "#388E3C",
        color = "#FFFFFF",
        font_size = 16,
        on_clicked_handler = "function()\n    print(\"执行：一键全开\")\n    widgets_valve.open_all()\nend",
        design_mode = false
    })

    -- clicked 事件处理
    btn_open_all_valves:on("clicked", function()
    print("执行：一键全开")
    widgets_valve.open_all()
end)

    -- 控件 4: custom_button (btn_close_all_valves)
    local btn_close_all_valves = widgets_button.new(container, {
        instance_name = "btn_close_all_valves",
        x = 220,
        y = 210,
        width = 120,
        height = 40,
        label = "一键全关",
        bg_color = "#C62828",
        color = "#FFFFFF",
        font_size = 16,
        on_clicked_handler = "function()\n    print(\"执行：一键全关\")\n    widgets_valve.close_all()\nend",
        design_mode = false
    })

    -- clicked 事件处理
    btn_close_all_valves:on("clicked", function()
    print("执行：一键全关")
    widgets_valve.close_all()
end)

    -- 控件 5: custom_button (btn_back_from_valve)
    local btn_back_from_valve = widgets_button.new(container, {
        instance_name = "btn_back_from_valve",
        x = 80,
        y = 270,
        width = 120,
        height = 40,
        label = "返回主页",
        bg_color = "#607D8B",
        color = "#FFFFFF",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_page(1)\nend",
        design_mode = false
    })

    -- clicked 事件处理
    btn_back_from_valve:on("clicked", function(self)
    actions_page_navigation.goto_page(1)
end)

    return container
end

-- ========== 图页管理（预创建模式） ==========
local PageManager = {}
PageManager.pages = {}        -- 图页信息
PageManager.containers = {}   -- 预创建的图页容器
PageManager.current_index = 0

-- 注册图页创建函数
PageManager.pages[1] = { name = "主页", create = create_page_1 }
PageManager.pages[2] = { name = "趋势图", create = create_page_2 }
PageManager.pages[3] = { name = "阀门控制", create = create_page_3 }

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
    get_status_bar = function()
        return status_bar
    end,
}

-- ========== 启动 ==========
print("=== 组态程序启动 ===")
print("图页数量: " .. #PageManager.pages)

-- 创建状态栏
create_status_bar()

-- 预创建所有图页
PageManager.init()

-- 显示初始图页
PageManager.goto_page(1)

print("=== 组态程序已就绪 ===")
