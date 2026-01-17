-- ==============================================
-- 自动生成的Lua脚本
-- 由 VduEditor 编译生成
-- 生成时间: 2026-01-17 20:53:12
-- 工程版本: 1.0
-- ==============================================

-- 引用 LVGL
local lv = require("lvgl")

-- 引用控件模块
local widgets_slider = require("widgets.slider")
local widgets_label = require("widgets.label")
local widgets_status_bar = require("widgets.status_bar")
local widgets_trend_chart = require("widgets.trend_chart")
local widgets_button = require("widgets.button")
local widgets_checkbox = require("widgets.checkbox")
local widgets_valve = require("widgets.valve")

-- 引用动作模块
local actions_page_navigation = require("actions.page_navigation")

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
        lamp_text = "CH1",
        bg_color = "#252526",
        text_color = "#CCCCCC",
        show_time = true,
        lamp_size = 14,
        design_mode = false,
    })
    status_bar:start()
    return status_bar
end

-- ========== 图页 1: 图页 1 ==========
-- 图页尺寸: 801x601
-- 背景颜色: 0x1E4B1E
local function create_page_1(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(801, 601)
    container:set_style_bg_color(0x1E4B1E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: custom_button (btn1)
    local btn1 = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 84,
        design_mode = false,
        x = 49,
        instance_name = "btn1",
        color = "#ffffff",
        width = 100,
        on_single_clicked_handler = "function(self)\n    print(\"按钮1被点击了！\")\n    self:set_property(\"label\", \"已点击\")\n    self:set_property(\"bg_color\", \"#E91E63\")\nend",
        on_double_clicked_handler = "function(self)\n    print(\"按钮1被双击了！\")\n    self:set_property(\"label\", \"已双击\")\n    self:set_property(\"bg_color\", \"#4CAF50\") -- 变为绿色\nend",
        bg_color = "#00E0CC",
        font_size = 16,
        on_clicked_handler = "",
        label = "点我",
        alignment = "center"
    })

    -- single_clicked 事件处理
    btn1:on("single_clicked", function(self)
    print("按钮1被点击了！")
    self:set_property("label", "已点击")
    self:set_property("bg_color", "#E91E63")
end)

    -- double_clicked 事件处理
    btn1:on("double_clicked", function(self)
    print("按钮1被双击了！")
    self:set_property("label", "已双击")
    self:set_property("bg_color", "#4CAF50") -- 变为绿色
end)

    -- 控件 2: custom_button (btn2)
    local btn2 = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 149,
        design_mode = false,
        x = 49,
        instance_name = "btn2",
        color = "#ffffff",
        width = 100,
        on_single_clicked_handler = "",
        on_double_clicked_handler = "",
        bg_color = "#007acc",
        font_size = 16,
        on_clicked_handler = "function(self)\n    print(\"重置按钮被点击！\")\n    btn1:set_property(\"label\", \"点击我\")\n    btn1:set_property(\"bg_color\", \"#2196F3\") -- 变为蓝色\nend",
        label = "重置",
        alignment = "center"
    })

    -- clicked 事件处理
    btn2:on("clicked", function(self)
    print("重置按钮被点击！")
    btn1:set_property("label", "点击我")
    btn1:set_property("bg_color", "#2196F3") -- 变为蓝色
end)

    -- 控件 3: custom_button (btn_pg1_next)
    local btn_pg1_next = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 264,
        design_mode = false,
        x = 49,
        instance_name = "btn_pg1_next",
        color = "#ffffff",
        width = 100,
        on_single_clicked_handler = "",
        on_double_clicked_handler = "",
        bg_color = "#00D1CC",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_next_page()\nend",
        label = "下一页",
        alignment = "center"
    })

    -- clicked 事件处理
    btn_pg1_next:on("clicked", function(self)
    actions_page_navigation.goto_next_page()
end)

    -- 控件 4: custom_button (btn_pg1_last)
    local btn_pg1_last = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 264,
        design_mode = false,
        x = 183,
        instance_name = "btn_pg1_last",
        color = "#ffffff",
        width = 100,
        on_single_clicked_handler = "",
        on_double_clicked_handler = "",
        bg_color = "#007acc",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_last_page()\nend",
        label = "最后一页",
        alignment = "center"
    })

    -- clicked 事件处理
    btn_pg1_last:on("clicked", function(self)
    actions_page_navigation.goto_last_page()
end)

    return container
end

-- ========== 图页 2: 图页 2 ==========
-- 图页尺寸: 810x605
-- 背景颜色: 0x1E1E6B
local function create_page_2(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(810, 605)
    container:set_style_bg_color(0x1E1E6B, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: trend_chart (chart1)
    local chart1 = widgets_trend_chart.new(container, {
        height = 300,
        point_count = 300,
        design_mode = false,
        range_max = 100,
        instance_name = "chart1",
        on_updated_handler = "function(_, value)\n    print(\"TrendChart updated value:\", value)\nend",
        update_interval = 1000,
        auto_update = true,
        y = 43,
        width = 700,
        x = 41,
        range_min = 0
    })

    -- updated 事件处理
    chart1:on("updated", function(_, value)
    print("TrendChart updated value:", value)
end)

    -- 控件 2: custom_button (btn_page2_prepage)
    local btn_page2_prepage = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 400,
        design_mode = false,
        x = 41,
        instance_name = "btn_page2_prepage",
        color = "#ffffff",
        width = 100,
        on_single_clicked_handler = "",
        on_double_clicked_handler = "",
        bg_color = "#007acc",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_prev_page()\nend",
        label = "上一页",
        alignment = "center"
    })

    -- clicked 事件处理
    btn_page2_prepage:on("clicked", function(self)
    actions_page_navigation.goto_prev_page()
end)

    -- 控件 3: custom_button (btn_page2_nextpage)
    local btn_page2_nextpage = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 400,
        design_mode = false,
        x = 196,
        instance_name = "btn_page2_nextpage",
        color = "#ffffff",
        width = 100,
        on_single_clicked_handler = "",
        on_double_clicked_handler = "",
        bg_color = "#007acc",
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_next_page()\nend",
        label = "下一页",
        alignment = "center"
    })

    -- clicked 事件处理
    btn_page2_nextpage:on("clicked", function(self)
    actions_page_navigation.goto_next_page()
end)

    return container
end

-- ========== 图页 3: 图页 3 ==========
-- 图页尺寸: 900x700
-- 背景颜色: 0x521E1E
local function create_page_3(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(900, 700)
    container:set_style_bg_color(0x521E1E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: valve (v1)
    local v1 = widgets_valve.new(container, {
        open_angle = 90,
        design_mode = false,
        on_angle_changed_handler = "",
        instance_name = "v1",
        size = 100,
        close_angle = 0,
        angle = 0,
        on_toggled_handler = "print(\"V1 状态: \" .. (is_open and \"开\" or \"关\"))",
        handle_color = "#FF5722",
        x = 87,
        y = 82
    })

    -- toggled 事件处理
    v1:on("toggled", function(self, is_open)
        print("V1 状态: " .. (is_open and "开" or "关"))
    end)

    -- 控件 2: valve (v2)
    local v2 = widgets_valve.new(container, {
        open_angle = 90,
        design_mode = false,
        on_angle_changed_handler = "",
        instance_name = "v2",
        size = 100,
        close_angle = 0,
        angle = 0,
        on_toggled_handler = "function(self, is_open)\n     print(\"V2 状态: \" .. (is_open and \"开\" or \"关\")) \nend",
        handle_color = "#FF5722",
        x = 213,
        y = 82
    })

    -- toggled 事件处理
    v2:on("toggled", function(self, is_open)
     print("V2 状态: " .. (is_open and "开" or "关")) 
end)

    -- 控件 3: custom_button (btn_open_all)
    local btn_open_all = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 284,
        design_mode = false,
        x = 80,
        instance_name = "btn_open_all",
        color = "#ffffff",
        on_single_clicked_handler = "",
        font_size = 16,
        width = 100,
        alignment = "center",
        bg_color = "#007acc",
        on_clicked_handler = "function()\n    print(\"执行：一键全开\")\n    widgets_valve.open_all()\nend",
        label = "一键全开",
        on_double_clicked_handler = ""
    })

    -- clicked 事件处理
    btn_open_all:on("clicked", function()
    print("执行：一键全开")
    widgets_valve.open_all()
end)

    -- 控件 4: custom_button (btn_close_all)
    local btn_close_all = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 285,
        design_mode = false,
        x = 206,
        instance_name = "btn_close_all",
        color = "#ffffff",
        on_single_clicked_handler = "",
        font_size = 16,
        width = 100,
        alignment = "center",
        bg_color = "#007acc",
        on_clicked_handler = "function()\n    print(\"执行：一键全关\")\n    widgets_valve.close_all()\nend",
        label = "一键全关",
        on_double_clicked_handler = ""
    })

    -- clicked 事件处理
    btn_close_all:on("clicked", function()
    print("执行：一键全关")
    widgets_valve.close_all()
end)

    -- 控件 5: valve (v3)
    local v3 = widgets_valve.new(container, {
        open_angle = 90,
        design_mode = false,
        on_angle_changed_handler = "",
        instance_name = "v3",
        size = 100,
        close_angle = 0,
        angle = 0,
        on_toggled_handler = "function(self, is_open)\n     print(\"V3 状态: \" .. (is_open and \"开\" or \"关\")) \nend",
        handle_color = "#5B57F5",
        x = 344,
        y = 82
    })

    -- toggled 事件处理
    v3:on("toggled", function(self, is_open)
     print("V3 状态: " .. (is_open and "开" or "关")) 
end)

    -- 控件 6: custom_button (btn_page3_prepage)
    local btn_page3_prepage = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 411,
        design_mode = false,
        x = 80,
        instance_name = "btn_page3_prepage",
        color = "#ffffff",
        on_single_clicked_handler = "",
        font_size = 16,
        width = 100,
        alignment = "center",
        bg_color = "#007acc",
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_prev_page()\nend",
        label = "上一页",
        on_double_clicked_handler = ""
    })

    -- clicked 事件处理
    btn_page3_prepage:on("clicked", function(self)
    actions_page_navigation.goto_prev_page()
end)

    -- 控件 7: custom_button (btn_page3_first)
    local btn_page3_first = widgets_button.new(container, {
        enabled = true,
        height = 40,
        y = 414,
        design_mode = false,
        x = 206,
        instance_name = "btn_page3_first",
        color = "#ffffff",
        on_single_clicked_handler = "",
        font_size = 16,
        width = 100,
        alignment = "center",
        bg_color = "#007acc",
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_first_page()\nend",
        label = "首页",
        on_double_clicked_handler = ""
    })

    -- clicked 事件处理
    btn_page3_first:on("clicked", function(self)
    actions_page_navigation.goto_first_page()
end)

    -- 控件 8: label (lb_v1)
    local lb_v1 = widgets_label.new(container, {
        text_color = "#FFFFFF",
        long_mode = "wrap",
        height = 30,
        design_mode = false,
        y = 218,
        visible = true,
        width = 100,
        instance_name = "lb_v1",
        text = "阀门1",
        bg_opa = 0,
        bg_color = "#00000000",
        font_size = 16,
        on_clicked_handler = "",
        x = 87,
        alignment = "center"
    })

    -- 控件 9: label (lb_v2)
    local lb_v2 = widgets_label.new(container, {
        text_color = "#FFFFFF",
        long_mode = "wrap",
        height = 30,
        design_mode = false,
        y = 218,
        visible = true,
        width = 100,
        instance_name = "lb_v2",
        text = "阀门2",
        bg_opa = 0,
        bg_color = "#00000000",
        font_size = 16,
        on_clicked_handler = "",
        x = 213,
        alignment = "center"
    })

    -- 控件 10: label (lb_v3)
    local lb_v3 = widgets_label.new(container, {
        text_color = "#FFFFFF",
        long_mode = "wrap",
        height = 30,
        design_mode = false,
        y = 218,
        visible = true,
        width = 100,
        instance_name = "lb_v3",
        text = "阀门3",
        bg_opa = 0,
        bg_color = "#00000000",
        font_size = 16,
        on_clicked_handler = "",
        x = 344,
        alignment = "center"
    })

    -- 控件 11: checkbox (ckBox1)
    local ckBox1 = widgets_checkbox.new(container, {
        text_color = "#FFFFFF",
        check_color = "#007ACC",
        height = 30,
        design_mode = false,
        checked = false,
        instance_name = "ckBox1",
        width = 120,
        text = "选项",
        box_color = "#3C3C3C",
        box_size = 20,
        on_changed_handler = "",
        enabled = true,
        x = 409,
        y = 337
    })

    -- 控件 12: slider
    local widget_12 = widgets_slider.new(container, {
        enabled = true,
        min_value = 0,
        max_value = 100,
        design_mode = false,
        value = 50,
        on_changed_handler = "",
        width = 150,
        instance_name = "",
        show_value = true,
        knob_color = 16777215,
        height = 20,
        bg_color = "#33292E",
        indicator_color = "#007ACC",
        x = 380,
        y = 436
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
PageManager.pages[2] = { name = "图页 2", create = create_page_2 }
PageManager.pages[3] = { name = "图页 3", create = create_page_3 }

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
PageManager.goto_page(3)

print("=== 组态程序已就绪 ===")
