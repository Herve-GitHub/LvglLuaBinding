-- ==============================================
-- 自动生成的Lua脚本
-- 由 VduEditor 编译生成
-- 生成时间: 2026-01-14 21:57:00
-- 工程版本: 1.0
-- ==============================================

-- 引用 LVGL
local lv = require("lvgl")

-- 引用控件模块
local widgets_trend_chart = require("widgets.trend_chart")

-- 引用动作模块
local actions_page_navigation = require("actions.page_navigation")

-- 获取活动屏幕
local scr = lv.scr_act()
scr:set_style_bg_color(0x1E1E1E, 0)
scr:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
scr:clear_layout()

-- ========== 图页 1: 图页 1 ==========
local function create_page_1(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(lv.display_get_hor_res(), lv.display_get_ver_res())
    container:set_style_bg_color(0x1E1E1E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: trend_chart (chart1)
    local chart1 = widgets_trend_chart.new(container, {
        instance_name = "chart1",
        range_min = 0,
        range_max = 100,
        x = 211,
        y = 101,
        on_updated_handler = "print(\"TrendChart updated value:\", value)",
        height = 120,
        point_count = 300,
        width = 300,
        auto_update = true,
        update_interval = 1000,
        on_updated_params = "print(\"TrendChart updated value:\", value)",
        design_mode = false
    })

    -- updated 事件处理
    chart1:on("updated", function(_, value)
        print("TrendChart updated value:", value)
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
