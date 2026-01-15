-- ==============================================
-- 自动生成的Lua脚本
-- 由 VduEditor 编译生成
-- 生成时间: 2026-01-15 20:47:39
-- 工程版本: 1.0
-- ==============================================

-- 引用 LVGL
local lv = require("lvgl")

-- 引用控件模块
local widgets_trend_chart = require("widgets.trend_chart")
local widgets_valve = require("widgets.valve")
local widgets_button = require("widgets.button")

-- 引用动作模块
local actions_page_navigation = require("actions.page_navigation")

-- 获取活动屏幕
local scr = lv.scr_act()
scr:set_style_bg_color(0x1E1E1E, 0)
scr:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
scr:clear_layout()

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
        y = 84,
        x = 53,
        on_clicked_handler = "",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "function(self)\n    print(\"按钮1被点击了！\")\n    self:set_property(\"label\", \"已点击\")\n    self:set_property(\"bg_color\", \"#E91E63\")\nend",
        label = "点我",
        instance_name = "btn1",
        on_double_clicked_handler = "function(self)\n    print(\"按钮1被双击了！\")\n    self:set_property(\"label\", \"已双击\")\n    self:set_property(\"bg_color\", \"#4CAF50\") -- 变为绿色\nend",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
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
        y = 149,
        x = 53,
        on_clicked_handler = "function(self)\n    print(\"重置按钮被点击！\")\n    btn1:set_property(\"label\", \"点击我\")\n    btn1:set_property(\"bg_color\", \"#2196F3\") -- 变为蓝色\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "重置",
        instance_name = "btn2",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
    })

    -- clicked 事件处理
    btn2:on("clicked", function(self)
    print("重置按钮被点击！")
    btn1:set_property("label", "点击我")
    btn1:set_property("bg_color", "#2196F3") -- 变为蓝色
end)

    -- 控件 3: custom_button (btnNext)
    local btnNext = widgets_button.new(container, {
        y = 264,
        x = 49,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_next_page()\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "下一页",
        instance_name = "btnNext",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = 53708
    })

    -- clicked 事件处理
    btnNext:on("clicked", function(self)
    actions_page_navigation.goto_next_page()
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
        y = 43,
        x = 41,
        point_count = 300,
        range_max = 100,
        range_min = 0,
        instance_name = "chart1",
        height = 300,
        auto_update = true,
        width = 700,
        update_interval = 1000,
        design_mode = false,
        on_updated_handler = "function(_, value)\n    print(\"TrendChart updated value:\", value)\nend"
    })

    -- updated 事件处理
    chart1:on("updated", function(_, value)
    print("TrendChart updated value:", value)
end)

    -- 控件 2: custom_button (btn_prepage)
    local btn_prepage = widgets_button.new(container, {
        y = 400,
        x = 62,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_prev_page()\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "上一页",
        instance_name = "btn_prepage",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
    })

    -- clicked 事件处理
    btn_prepage:on("clicked", function(self)
    actions_page_navigation.goto_prev_page()
end)

    -- 控件 3: custom_button (btn_nextpage)
    local btn_nextpage = widgets_button.new(container, {
        y = 400,
        x = 196,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_next_page()\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "下一页",
        instance_name = "btn_nextpage",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
    })

    -- clicked 事件处理
    btn_nextpage:on("clicked", function(self)
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
        y = 78,
        x = 102,
        close_angle = 0,
        on_angle_changed_handler = "",
        on_toggled_handler = "print(\"V1 状态: \" .. (is_open and \"开\" or \"关\"))",
        handle_color = "#FF5722",
        open_angle = 90,
        instance_name = "v1",
        angle = 0,
        size = 100,
        design_mode = false
    })

    -- toggled 事件处理
    v1:on("toggled", function(self, is_open)
        print("V1 状态: " .. (is_open and "开" or "关"))
    end)

    -- 控件 2: valve (v2)
    local v2 = widgets_valve.new(container, {
        y = 78,
        x = 247,
        close_angle = 0,
        on_angle_changed_handler = "",
        on_toggled_handler = "function(self, is_open)\n     print(\"V2 状态: \" .. (is_open and \"开\" or \"关\")) \nend",
        handle_color = "#FF5722",
        open_angle = 90,
        instance_name = "v2",
        angle = 0,
        size = 100,
        design_mode = false
    })

    -- toggled 事件处理
    v2:on("toggled", function(self, is_open)
     print("V2 状态: " .. (is_open and "开" or "关")) 
end)

    -- 控件 3: custom_button (btn_open_all)
    local btn_open_all = widgets_button.new(container, {
        y = 215,
        x = 105,
        on_clicked_handler = "function()\n    print(\"执行：一键全开\")\n    Valve.open_all()\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "一键全开",
        instance_name = "btn_open_all",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
    })

    -- clicked 事件处理
    btn_open_all:on("clicked", function()
    print("执行：一键全开")
    Valve.open_all()
end)

    -- 控件 4: custom_button (btn_close_all)
    local btn_close_all = widgets_button.new(container, {
        y = 216,
        x = 269,
        on_clicked_handler = "function()\n    print(\"执行：一键全关\")\n    Valve.close_all()\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "一键全关",
        instance_name = "btn_close_all",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
    })

    -- clicked 事件处理
    btn_close_all:on("clicked", function()
    print("执行：一键全关")
    Valve.close_all()
end)

    -- 控件 5: valve (v3)
    local v3 = widgets_valve.new(container, {
        y = 78,
        x = 396,
        close_angle = 0,
        on_angle_changed_handler = "",
        on_toggled_handler = "function(self, is_open)\n     print(\"V3 状态: \" .. (is_open and \"开\" or \"关\")) \nend",
        handle_color = 5986293,
        open_angle = 90,
        instance_name = "v3",
        angle = 0,
        size = 100,
        design_mode = false
    })

    -- toggled 事件处理
    v3:on("toggled", function(self, is_open)
     print("V3 状态: " .. (is_open and "开" or "关")) 
end)

    -- 控件 6: custom_button (btn_prepage)
    local btn_prepage = widgets_button.new(container, {
        y = 342,
        x = 87,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_prev_page()\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "上一页",
        instance_name = "btn_prepage",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
    })

    -- clicked 事件处理
    btn_prepage:on("clicked", function(self)
    actions_page_navigation.goto_prev_page()
end)

    -- 控件 7: custom_button (btn_first)
    local btn_first = widgets_button.new(container, {
        y = 345,
        x = 213,
        on_clicked_handler = "function(self)\n    actions_page_navigation.goto_first_page()\nend",
        color = "#ffffff",
        height = 40,
        alignment = "center",
        on_single_clicked_handler = "",
        label = "首页",
        instance_name = "btn_first",
        on_double_clicked_handler = "",
        design_mode = false,
        enabled = true,
        width = 100,
        font_size = 16,
        bg_color = "#007acc"
    })

    -- clicked 事件处理
    btn_first:on("clicked", function(self)
    actions_page_navigation.goto_first_page()
end)

    return container
end

-- ========== 图页管理 ==========
local PageManager = {}
PageManager.pages = {}
PageManager.current_page = nil
PageManager.current_index = 0

-- 注册图页创建函数
PageManager.pages[1] = { name = "图页 1", create = create_page_1 }
PageManager.pages[2] = { name = "图页 2", create = create_page_2 }
PageManager.pages[3] = { name = "图页 3", create = create_page_3 }

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

-- 切换图页
function PageManager.goto_page(index)
    if index < 1 or index > #PageManager.pages then
        print("[PageManager] 无效的图页索引: " .. tostring(index))
        return false
    end

    -- 删除当前图页
    if PageManager.current_page then
        PageManager.current_page:delete()
        PageManager.current_page = nil
    end

    -- 创建新图页
    local page_info = PageManager.pages[index]
    if page_info and page_info.create then
        PageManager.current_page = page_info.create(scr)
        PageManager.current_index = index
        print("[PageManager] 切换到图页 " .. index .. ": " .. page_info.name)
        return true
    end

    return false
end

-- 导出图页管理器到全局
_G.PageManager = PageManager

-- 创建模拟编辑器接口（供 actions 模块使用）
_G.Editor = {
    get_canvas_list = function()
        return PageManager
    end
}

-- ========== 启动 ==========
print("=== 组态程序启动 ===")
print("图页数量: " .. #PageManager.pages)

-- 显示初始图页
PageManager.goto_page(1)

print("=== 组态程序已就绪 ===")
