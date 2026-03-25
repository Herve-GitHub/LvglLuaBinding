-- ==============================================
-- 自动生成的Lua脚本
-- 由 VduEditor 编译生成
-- 生成时间: 2026-03-25 11:02:57
-- 工程版本: 1.0
-- ==============================================

-- 启动网络服务
lvgl.start_network_service(3000)
lvgl.connect("", 3000)

-- 引用 LVGL
local lv = require("lvgl")

-- 引用控件模块
local widgets_new_label = require("widgets.new_label")
local widgets_checkbox = require("widgets.checkbox")
local widgets_new_button = require("widgets.new_button")

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
-- 图页尺寸: 1024x600
-- 背景颜色: 0x1E1E1E
local function create_page_1(parent)
    -- 创建图页容器
    local container = lv.obj_create(parent)
    container:set_pos(0, 0)
    container:set_size(1024, 600)
    container:set_style_bg_color(0x1E1E1E, 0)
    container:set_style_border_width(0, 0)
    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    container:clear_layout()

    -- 控件 1: custom_button
    local widget_1 = widgets_new_button.new(container, {
        http_url = "",
        false_bg_color = "#ffffff",
        false_color = "#ffffff",
        true_bg_color = "#ffffff",
        on_single_clicked_handler = "",
        event_action = "写入绑定数据点",
        bind_point = "",
        on_double_clicked_handler = "",
        label = "OK",
        x = 290,
        y = 110,
        enabled = true,
        on_clicked_handler = "",
        color = "#ffffff",
        width = 100,
        alignment = "center",
        http_token = "",
        compare_operator = "大于",
        bg_color = "#007acc",
        height = 40,
        design_mode = false,
        font_size = 16,
        custom_value = "",
        instance_name = "",
        custom_address = "",
        compare_value = "0",
        true_color = "#ffffff",
        websocket_url = "",
        http_data_type = "实时数据"
    })

    -- 控件 2: label
    local widget_2 = widgets_new_label.new(container, {
        http_url = "",
        false_bg_color = "#ffffff",
        visible = true,
        bind_point = "",
        false_color = "#ffffff",
        width = 100,
        event_action = "写入绑定数据点",
        bg_opa = 0,
        y = 180,
        x = 319,
        design_mode = false,
        custom_address = "",
        on_clicked_handler = "",
        long_mode = "wrap",
        compare_operator = "大于",
        alignment = "left",
        text_color = "#FFFFFF",
        text = "Label",
        font_size = 16,
        height = 30,
        http_token = "",
        bg_color = "#00000000",
        custom_value = "",
        instance_name = "",
        true_color = "#ffffff",
        compare_value = "0",
        true_bg_color = "#ffffff",
        websocket_url = "",
        http_data_type = "实时数据"
    })

    -- 控件 3: checkbox
    local widget_3 = widgets_checkbox.new(container, {
        y = 111,
        text_color = "#FFFFFF",
        design_mode = false,
        on_changed_handler = "",
        checked = false,
        height = 30,
        width = 120,
        text = "选项",
        check_color = "#007ACC",
        instance_name = "",
        x = 475,
        box_size = 20,
        enabled = true,
        box_color = "#3C3C3C"
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
