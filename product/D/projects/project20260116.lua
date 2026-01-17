-- ==============================================
-- 自动生成的Lua脚本
-- 由 VduEditor 编译生成
-- 生成时间: 2026-01-17 13:43:18
-- 工程版本: 1.0
-- ==============================================

-- 引用 LVGL
local lv = require("lvgl")

-- 引用控件模块
local widgets_valve = require("widgets.valve")
local widgets_status_bar = require("widgets.status_bar")
local widgets_label = require("widgets.label")
local widgets_button = require("widgets.button")
local widgets_trend_chart = require("widgets.trend_chart")

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
        height = 40,
        enabled = true,
        font_size = 16,
        on_clicked_handler = "",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "function(self)\n    print(\"按钮1被双击了！\")\n    self:set_property(\"label\", \"已双击\")\n    self:set_property(\"bg_color\", \"#4CAF50\") -- 变为绿色\nend",
        design_mode = false,
        on_single_clicked_handler = "function(self)\n    print(\"按钮1被点击了！\")\n    self:set_property(\"label\", \"已点击\")\n    self:set_property(\"bg_color\", \"#E91E63\")\nend",
        width = 100,
        bg_color = "#00E0CC",
        instance_name = "btn1",
        label = "点我",
        x = 49,
        y = 84
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
        height = 40,
        enabled = true,
        font_size = 16,
        on_clicked_handler = "function(self)\n    print(\"重置按钮被点击！\")\n    btn1:set_property(\"label\", \"点击我\")\n    btn1:set_property(\"bg_color\", \"#2196F3\") -- 变为蓝色\nend",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_single_clicked_handler = "",
        width = 100,
        bg_color = "#007acc",
        instance_name = "btn2",
        label = "重置",
        x = 49,
        y = 149
    })

    -- clicked 事件处理
    btn2:on("clicked", function(self)
    print("重置按钮被点击！")
    btn1:set_property("label", "点击我")
    btn1:set_property("bg_color", "#2196F3") -- 变为蓝色
end)

    -- 控件 3: custom_button (btn_pg1_next)
    local btn_pg1_next = widgets_button.new(container, {
        height = 40,
        enabled = true,
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_next_page()\nend",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_single_clicked_handler = "",
        width = 100,
        bg_color = "#00D1CC",
        instance_name = "btn_pg1_next",
        label = "下一页",
        x = 49,
        y = 264
    })

    -- clicked 事件处理
    btn_pg1_next:on("clicked", function(self)
    actions_page_navigation.goto_next_page()
end)

    -- 控件 4: custom_button (btn_pg1_last)
    local btn_pg1_last = widgets_button.new(container, {
        height = 40,
        enabled = true,
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_last_page()\nend",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_single_clicked_handler = "",
        width = 100,
        bg_color = "#007acc",
        instance_name = "btn_pg1_last",
        label = "最后一页",
        x = 183,
        y = 264
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
        width = 700,
        y = 43,
        on_updated_handler = "function(_, value)\n    print(\"TrendChart updated value:\", value)\nend",
        design_mode = false,
        x = 41,
        update_interval = 1000,
        point_count = 300,
        range_min = 0,
        instance_name = "chart1",
        range_max = 100,
        auto_update = true
    })

    -- updated 事件处理
    chart1:on("updated", function(_, value)
    print("TrendChart updated value:", value)
end)

    -- 控件 2: custom_button (btn_page2_prepage)
    local btn_page2_prepage = widgets_button.new(container, {
        height = 40,
        enabled = true,
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_prev_page()\nend",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_single_clicked_handler = "",
        width = 100,
        bg_color = "#007acc",
        instance_name = "btn_page2_prepage",
        label = "上一页",
        x = 41,
        y = 400
    })

    -- clicked 事件处理
    btn_page2_prepage:on("clicked", function(self)
    actions_page_navigation.goto_prev_page()
end)

    -- 控件 3: custom_button (btn_page2_nextpage)
    local btn_page2_nextpage = widgets_button.new(container, {
        height = 40,
        enabled = true,
        font_size = 16,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_next_page()\nend",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_single_clicked_handler = "",
        width = 100,
        bg_color = "#007acc",
        instance_name = "btn_page2_nextpage",
        label = "下一页",
        x = 196,
        y = 400
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
        angle = 0,
        size = 100,
        handle_color = "#FF5722",
        close_angle = 0,
        design_mode = false,
        on_toggled_handler = "print(\"V1 状态: \" .. (is_open and \"开\" or \"关\"))",
        open_angle = 90,
        instance_name = "v1",
        on_angle_changed_handler = "",
        x = 87,
        y = 82
    })

    -- toggled 事件处理
    v1:on("toggled", function(self, is_open)
        print("V1 状态: " .. (is_open and "开" or "关"))
    end)

    -- 控件 2: valve (v2)
    local v2 = widgets_valve.new(container, {
        angle = 0,
        size = 100,
        handle_color = "#FF5722",
        close_angle = 0,
        design_mode = false,
        on_toggled_handler = "function(self, is_open)\n     print(\"V2 状态: \" .. (is_open and \"开\" or \"关\")) \nend",
        open_angle = 90,
        instance_name = "v2",
        on_angle_changed_handler = "",
        x = 213,
        y = 82
    })

    -- toggled 事件处理
    v2:on("toggled", function(self, is_open)
     print("V2 状态: " .. (is_open and "开" or "关")) 
end)

    -- 控件 3: custom_button (btn_open_all)
    local btn_open_all = widgets_button.new(container, {
        height = 40,
        width = 100,
        font_size = 16,
        on_single_clicked_handler = "",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_clicked_handler = "function()\n    print(\"执行：一键全开\")\n    widgets_valve.open_all()\nend",
        enabled = true,
        bg_color = "#007acc",
        instance_name = "btn_open_all",
        label = "一键全开",
        x = 80,
        y = 284
    })

    -- clicked 事件处理
    btn_open_all:on("clicked", function()
    print("执行：一键全开")
    widgets_valve.open_all()
end)

    -- 控件 4: custom_button (btn_close_all)
    local btn_close_all = widgets_button.new(container, {
        height = 40,
        width = 100,
        font_size = 16,
        on_single_clicked_handler = "",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_clicked_handler = "function()\n    print(\"执行：一键全关\")\n    widgets_valve.close_all()\nend",
        enabled = true,
        bg_color = "#007acc",
        instance_name = "btn_close_all",
        label = "一键全关",
        x = 206,
        y = 285
    })

    -- clicked 事件处理
    btn_close_all:on("clicked", function()
    print("执行：一键全关")
    widgets_valve.close_all()
end)

    -- 控件 5: valve (v3)
    local v3 = widgets_valve.new(container, {
        angle = 0,
        size = 100,
        handle_color = "#5B57F5",
        close_angle = 0,
        design_mode = false,
        on_toggled_handler = "function(self, is_open)\n     print(\"V3 状态: \" .. (is_open and \"开\" or \"关\")) \nend",
        open_angle = 90,
        instance_name = "v3",
        on_angle_changed_handler = "",
        x = 344,
        y = 82
    })

    -- toggled 事件处理
    v3:on("toggled", function(self, is_open)
     print("V3 状态: " .. (is_open and "开" or "关")) 
end)

    -- 控件 6: custom_button (btn_page3_prepage)
    local btn_page3_prepage = widgets_button.new(container, {
        height = 40,
        width = 100,
        font_size = 16,
        on_single_clicked_handler = "",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_prev_page()\nend",
        enabled = true,
        bg_color = "#007acc",
        instance_name = "btn_page3_prepage",
        label = "上一页",
        x = 80,
        y = 411
    })

    -- clicked 事件处理
    btn_page3_prepage:on("clicked", function(self)
    actions_page_navigation.goto_prev_page()
end)

    -- 控件 7: custom_button (btn_page3_first)
    local btn_page3_first = widgets_button.new(container, {
        height = 40,
        width = 100,
        font_size = 16,
        on_single_clicked_handler = "",
        alignment = "center",
        color = "#ffffff",
        on_double_clicked_handler = "",
        design_mode = false,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_first_page()\nend",
        enabled = true,
        bg_color = "#007acc",
        instance_name = "btn_page3_first",
        label = "首页",
        x = 206,
        y = 414
    })

    -- clicked 事件处理
    btn_page3_first:on("clicked", function(self)
    actions_page_navigation.goto_first_page()
end)

    -- 控件 8: label (lb_v1)
    local lb_v1 = widgets_label.new(container, {
        height = 30,
        width = 100,
        font_size = 16,
        text = "阀门1",
        alignment = "center",
        visible = true,
        on_clicked_handler = "",
        design_mode = false,
        text_color = "#FFFFFF",
        instance_name = "lb_v1",
        bg_color = "#00000000",
        bg_opa = 0,
        long_mode = "wrap",
        x = 87,
        y = 218
    })

    -- 控件 9: label (lb_v2)
    local lb_v2 = widgets_label.new(container, {
        height = 30,
        width = 100,
        font_size = 16,
        text = "阀门2",
        alignment = "center",
        visible = true,
        on_clicked_handler = "",
        design_mode = false,
        text_color = "#FFFFFF",
        instance_name = "lb_v2",
        bg_color = "#00000000",
        bg_opa = 0,
        long_mode = "wrap",
        x = 213,
        y = 218
    })

    -- 控件 10: label (lb_v3)
    local lb_v3 = widgets_label.new(container, {
        height = 30,
        width = 100,
        font_size = 16,
        text = "阀门3",
        alignment = "center",
        visible = true,
        on_clicked_handler = "",
        design_mode = false,
        text_color = "#FFFFFF",
        instance_name = "lb_v3",
        bg_color = "#00000000",
        bg_opa = 0,
        long_mode = "wrap",
        x = 344,
        y = 218
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
