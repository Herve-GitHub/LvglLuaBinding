-- main_editor.lua
-- 主编辑器入口：整合菜单栏、画布、工具箱、状态栏
local lv = require("lvgl")
local gen = require("general")

-- 加载编辑器组件
local MenuBar = require("MenuBar")
local CanvasArea = require("CanvasArea")
local ToolsBox = require("tools_box")
local PropertyArea = require("PropertyArea")
local CanvasList = require("CanvasList")
local StatusBar = require("widgets.status_bar")
local ProjectManager = require("ProjectManager")
local FileDialog = require("FileDialog")

-- 获取屏幕
local scr = lv.scr_act()

-- 重要：清除屏幕的 flex 布局（Win32Window 默认设置了 flex column 布局）
scr:clear_layout()

-- 设置屏幕背景色
scr:set_style_bg_color(0x1E1E1E, 0)

-- 禁用屏幕滚动，防止拖动时整个画面移动
scr:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 重置屏幕的 padding（Win32Window 默认设置了 10）
scr:set_style_pad_all(0, 0)

-- 设置默认文字颜色为白色
scr:set_style_text_color(0xFFFFFF, 0)

print("=== VDU 编辑器启动 ===")

-- 定义布局尺寸
local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 768
local MENUBAR_HEIGHT = 36
local STATUSBAR_HEIGHT = 28

-- 状态栏实例（全局，独立于画布）
local status_bar = nil
local status_bar_position = "bottom"  -- 默认在底部

-- 工程管理器实例
local project_manager = ProjectManager.new()

-- 计算画布区域（根据状态栏位置）
local function get_canvas_bounds()
    local canvas_y = MENUBAR_HEIGHT
    local canvas_height = WINDOW_HEIGHT - MENUBAR_HEIGHT
    
    if status_bar then
        if status_bar_position == "top" then
            canvas_y = MENUBAR_HEIGHT + STATUSBAR_HEIGHT
            canvas_height = WINDOW_HEIGHT - MENUBAR_HEIGHT - STATUSBAR_HEIGHT
        else  -- bottom
            canvas_height = WINDOW_HEIGHT - MENUBAR_HEIGHT - STATUSBAR_HEIGHT
        end
    end
    
    return 0, canvas_y, WINDOW_WIDTH, canvas_height
end

-- ========== 创建菜单栏 ==========
local menu_bar = MenuBar.new(scr, {
    x = 0,
    y = 0,
    width = WINDOW_WIDTH,
    height = MENUBAR_HEIGHT,
})

-- ========== 创建画布（占满整个工作区域）==========
local canvas_x, canvas_y, canvas_width, canvas_height = get_canvas_bounds()
local canvas = CanvasArea.new(scr, {
    x = canvas_x,
    y = canvas_y,
    width = canvas_width,
    height = canvas_height,
    show_grid = false,
    snap_to_grid = false,
    grid_size = 20,
})

-- ========== 创建浮动工具箱（在画布上方）==========
local toolbox = ToolsBox.new(scr, {
    x = 20,
    y = MENUBAR_HEIGHT + 30,
    width = 150,
})

-- 创建属性窗口
local property_area = PropertyArea.new(scr, {
    x = 620,
    y = MENUBAR_HEIGHT + 30,
    width = 400,
    visible = true
})

-- 创建图页列表窗口
local canvas_list = CanvasList.new(scr, {
    x = 10,
    y = MENUBAR_HEIGHT + 30 + 200,
    width = 200,
    visible = true
})

-- 当前活动的图页索引
local current_page_index = 0

-- 模块路径到模块的映射缓存
local loaded_modules = {}

-- 控件 ID 到模块路径的映射（用于兼容不同的控件定义方式）
local widget_id_to_module_path = {
    ["custom_button"] = "widgets.button",  -- button.lua 中定义的 id 是 custom_button
    ["button"] = "widgets.button",          -- 兼容工具箱中的 id
    ["valve"] = "widgets.valve",
    ["trend_chart"] = "widgets.trend_chart",
    ["status_bar"] = "widgets.status_bar",
}

-- 加载模块辅助函数
local function load_module(module_path)
    if loaded_modules[module_path] then
        return loaded_modules[module_path]
    end
    local ok, module = pcall(require, module_path)
    if ok then
        loaded_modules[module_path] = module
        return module
    else
        print("[编辑器] 加载模块失败: " .. module_path .. " - " .. tostring(module))
        return nil
    end
end

-- ========== 状态栏管理 ==========

-- 创建状态栏（全局组件，独立于画布）
local function create_status_bar(position)
    position = position or "bottom"
    status_bar_position = position
    
    local sb_y = 0
    if position == "top" then
        sb_y = MENUBAR_HEIGHT
    else  -- bottom
        sb_y = WINDOW_HEIGHT - STATUSBAR_HEIGHT
    end
    
    status_bar = StatusBar.new(scr, {
        x = 0,
        y = sb_y,
        width = WINDOW_WIDTH,
        height = STATUSBAR_HEIGHT,
        position = position,
        lamp_status = "#00FF00",
        lamp_text = "CH1",
    })
    
    -- 更新画布位置和大小
    local cx, cy, cw, ch = get_canvas_bounds()
    canvas.props.x = cx
    canvas.props.y = cy
    canvas.props.width = cw
    canvas.props.height = ch
    canvas.container:set_pos(cx, cy)
    canvas.container:set_size(cw, ch)
    
    print("[编辑器] 状态栏已创建，位置: " .. position)
    return status_bar
end

-- 移除状态栏
local function remove_status_bar()
    if status_bar then
        status_bar:destroy()
        status_bar = nil
        
        -- 恢复画布大小
        local cx, cy, cw, ch = get_canvas_bounds()
        canvas.props.x = cx
        canvas.props.y = cy
        canvas.props.width = cw
        canvas.props.height = ch
        canvas.container:set_pos(cx, cy)
        canvas.container:set_size(cw, ch)
        
        print("[编辑器] 状态栏已移除")
    end
end

-- 设置状态栏位置
local function set_status_bar_position(position)
    if not status_bar then return end
    if position ~= "top" and position ~= "bottom" then return end
    
    status_bar_position = position
    
    local sb_y = 0
    if position == "top" then
        sb_y = MENUBAR_HEIGHT
    else
        sb_y = WINDOW_HEIGHT - STATUSBAR_HEIGHT
    end
    
    status_bar:set_property("y", sb_y)
    status_bar:set_property("position", position)
    
    -- 更新画布位置和大小
    local cx, cy, cw, ch = get_canvas_bounds()
    canvas.props.x = cx
    canvas.props.y = cy
    canvas.props.width = cw
    canvas.props.height = ch
    canvas.container:set_pos(cx, cy)
    canvas.container:set_size(cw, ch)
    
    print("[编辑器] 状态栏位置已更新: " .. position)
end

-- 获取状态栏实例
local function get_status_bar()
    return status_bar
end

-- ========== 保存/加载画布状态 ==========

-- 保存当前画布状态到指定图页
local function save_canvas_to_page(page_index)
    if page_index < 1 then return end
    
    local state = canvas:export_state()
    if state and state.widgets then
        -- 为每个控件保存模块路径
        local widgets_data = {}
        local current_widgets = canvas:get_widgets()
        
        for i, widget_state in ipairs(state.widgets) do
            local widget_entry = current_widgets[i]
            local module_path = nil
            
            -- 优先使用 widget_entry 中保存的 module_path（如果有）
            if widget_entry and widget_entry.module_path then
                module_path = widget_entry.module_path
            elseif widget_entry and widget_entry.module and widget_entry.module.__widget_meta then
                -- 根据控件ID查找模块路径
                local widget_id = widget_entry.module.__widget_meta.id
                module_path = widget_id_to_module_path[widget_id]
                
                if not module_path then
                    print("[编辑器] 警告: 未知控件类型 " .. tostring(widget_id))
                end
            end
            
            table.insert(widgets_data, {
                type = widget_state.type,
                props = widget_state.props,
                module_path = module_path,
            })
        end
        
        canvas_list:update_page_data(page_index, widgets_data)
        print("[编辑器] 保存画布到图页 " .. page_index .. "，控件数: " .. #widgets_data)
    end
end

-- 从指定图页加载画布状态
local function load_canvas_from_page(page_index)
    if page_index < 1 then return end
    
    local page_data = canvas_list:get_page_data(page_index)
    if not page_data then return end
    
    -- 清空当前画布
    canvas:clear()
    
    -- 恢复控件
    if page_data.widgets and #page_data.widgets > 0 then
        for _, widget_data in ipairs(page_data.widgets) do
            local module_path = widget_data.module_path
            if module_path then
                local widget_module = load_module(module_path)
                if widget_module then
                    local props = widget_data.props or {}
                    local widget_entry = canvas:add_widget(widget_module, props)
                    -- 保存模块路径到 widget_entry 以便后续保存
                    if widget_entry then
                        widget_entry.module_path = module_path
                    end
                    print("[编辑器] 恢复控件: " .. (widget_data.type or "unknown") .. 
                          " @ (" .. (props.x or 0) .. ", " .. (props.y or 0) .. ")")
                end
            else
                print("[编辑器] 警告: 控件缺少 module_path，无法恢复: " .. (widget_data.type or "unknown"))
            end
        end
        print("[编辑器] 从图页 " .. page_index .. " 加载完成，控件数: " .. #page_data.widgets)
    else
        print("[编辑器] 图页 " .. page_index .. " 无控件数据")
    end
end

-- 创建默认图页
canvas_list:add_page("图页 1")
current_page_index = 1

-- 同步菜单栏状态与画布/工具箱/属性窗口/图页列表状态
menu_bar:set_state("show_grid", canvas:is_grid_visible())
menu_bar:set_state("snap_to_grid", canvas:is_snap_to_grid())
menu_bar:set_state("show_toolbox", toolbox:is_visible())
menu_bar:set_state("show_properties", property_area:is_visible())
menu_bar:set_state("show_canvas_list", canvas_list:is_visible())

-- ========== 导出编辑器 API（提前定义，供后续使用）==========
_G.Editor = {
    -- 状态栏相关
    create_status_bar = create_status_bar,
    remove_status_bar = remove_status_bar,
    set_status_bar_position = set_status_bar_position,
    get_status_bar = get_status_bar,
    
    -- 获取各组件实例
    get_canvas = function() return canvas end,
    get_toolbox = function() return toolbox end,
    get_property_area = function() return property_area end,
    get_canvas_list = function() return canvas_list end,
    get_menu_bar = function() return menu_bar end,
}

-- ========== 工程保存/加载功能 ==========

-- 保存工程
local function save_project_dialog()
    -- 先保存当前图页
    save_canvas_to_page(current_page_index)
    
    -- 获取当前工程路径作为默认文件名
    local current_path = project_manager:get_current_path()
    local default_filename = "project.json"
    if current_path then
        default_filename = current_path:match("([^/\\]+)$") or default_filename
    end
    
    -- 创建保存对话框
    FileDialog.new(scr, {
        mode = "save",
        title = "保存工程",
        default_filename = default_filename,
        callback = function(filepath, filename)
            -- 导出工程数据
            local project_data = project_manager:export_project_data(_G.Editor)
            
            -- 保存到文件
            local success, err = project_manager:save_project(filepath, project_data)
            if success then
                print("[编辑器] 工程已保存: " .. filepath)
            else
                print("[编辑器] 保存失败: " .. (err or "未知错误"))
            end
        end
    })
end

-- 打开工程
local function open_project_dialog()
    -- 创建打开对话框
    FileDialog.new(scr, {
        mode = "open",
        title = "打开工程",
        default_filename = "",
        callback = function(filepath, filename)
            -- 加载工程数据
            local project_data, err = project_manager:load_project(filepath)
            if project_data then
                -- 重置当前图页索引，避免导入时触发无效的保存
                current_page_index = 0
                
                -- 导入工程数据到编辑器
                local success, import_err = project_manager:import_project_data(_G.Editor, project_data)
                if success then
                    print("[编辑器] 工程已加载: " .. filepath)
                    -- 设置当前图页索引（import_project_data 会触发 select_page，
                    -- 但由于 current_page_index 是 0，不会保存空数据到任何图页）
                    current_page_index = project_data.current_page_index or 1
                    
                    -- 确保画布显示正确的图页内容
                    load_canvas_from_page(current_page_index)
                else
                    print("[编辑器] 导入失败: " .. (import_err or "未知错误"))
                    current_page_index = 1  -- 恢复默认值
                end
            else
                print("[编辑器] 加载失败: " .. (err or "未知错误"))
            end
        end
    })
end

-- 快速保存（直接保存到当前路径）
local function quick_save()
    local current_path = project_manager:get_current_path()
    if current_path then
        -- 先保存当前图页
        save_canvas_to_page(current_page_index)
        
        -- 导出工程数据
        local project_data = project_manager:export_project_data(_G.Editor)
        
        -- 保存到文件
        local success, err = project_manager:save_project(current_path, project_data)
        if success then
            print("[编辑器] 工程已保存: " .. current_path)
        else
            print("[编辑器] 保存失败: " .. (err or "未知错误"))
        end
    else
        -- 如果没有当前路径，打开保存对话框
        save_project_dialog()
    end
end

-- 菜单事件处理
menu_bar:on("menu_action", function(self, menu_key, item_id)
    print("[菜单] " .. menu_key .. " -> " .. item_id)
    
    if item_id == "new" then
        -- 新建工程
        project_manager:new_project(_G.Editor)
        current_page_index = 1
        print("新建工程")
    elseif item_id == "open" then
        -- 打开工程
        open_project_dialog()
    elseif item_id == "save" then
        -- 快速保存
        quick_save()
    elseif item_id == "save_as" then
        -- 另存为
        save_project_dialog()
    elseif item_id == "delete" then
        canvas:delete_selected()
    elseif item_id == "align_left" then
        canvas:align_selected("left")
    elseif item_id == "align_center" then
        canvas:align_selected("center_h")
    elseif item_id == "align_right" then
        canvas:align_selected("right")
    elseif item_id == "align_top" then
        canvas:align_selected("top")
    elseif item_id == "align_middle" then
        canvas:align_selected("center_v")
    elseif item_id == "align_bottom" then
        canvas:align_selected("bottom")
    elseif item_id == "show_grid" then
        -- 切换网格显示
        local new_state = canvas:toggle_grid()
        menu_bar:set_state("show_grid", new_state)
        print("网格显示: " .. tostring(new_state))
    elseif item_id == "snap_to_grid" then
        -- 切换对齐到网格
        local new_state = canvas:toggle_snap_to_grid()
        menu_bar:set_state("snap_to_grid", new_state)
        print("对齐到网格: " .. tostring(new_state))
    elseif item_id == "show_toolbox" then
        -- 切换工具箱显示/隐藏
        toolbox:toggle()
        menu_bar:set_state("show_toolbox", toolbox:is_visible())
    elseif item_id == "show_properties" then
        -- 切换属性窗口显示/隐藏
        property_area:toggle()
        menu_bar:set_state("show_properties", property_area:is_visible())
    elseif item_id == "show_canvas_list" then
        -- 切换图页列表显示/隐藏
        canvas_list:toggle()
        menu_bar:set_state("show_canvas_list", canvas_list:is_visible())
    elseif item_id == "exit" then
        print("退出编辑器")
    end
end)

-- 画布事件处理
canvas:on("widget_added", function(self, widget_entry)
    print("[画布] 添加控件: " .. widget_entry.id)
end)

canvas:on("widget_selected", function(self, widget_entry)
    --通知属性
    property_area:onSelectedItem(widget_entry)
    print("[画布] 选中控件: " .. widget_entry.id)
end)

canvas:on("widgets_selected", function(self, widget_entries)
    --通知属性
    property_area:onSelectedItem(widget_entries)
    print("[画布] 多选控件: " .. #widget_entries .. " 个")
    for _, w in ipairs(widget_entries) do
        print("  - " .. w.id)
    end
end)

canvas:on("widget_deselected", function(self, prev_widget)
    property_area:onSelectedItem(nil)
    print("[画布] 取消选中")
end)

canvas:on("widget_deleted", function(self, widget_entry)
    print("[画布] 删除控件: " .. widget_entry.id)
end)

canvas:on("widget_moved", function(self, widget_entry)
    print("[画布] 控件移动: " .. widget_entry.id)
end)

canvas:on("widgets_moved", function(self, widget_entries)
    print("[画布] 多个控件移动: " .. #widget_entries .. " 个")
end)

-- 工具箱拖放事件处理（新的拖拽方式）
toolbox:on("tool_drag_drop", function(self, tool, module, screen_x, screen_y)
    print("[工具箱] 拖放工具: " .. tool.name .. " 屏幕坐标: (" .. screen_x .. ", " .. screen_y .. ")")
    
    -- 检查是否是全局组件（如状态栏）
    if module.__widget_meta and module.__widget_meta.is_global then
        print("[工具箱] 检测到全局组件: " .. tool.name)
        
        -- 状态栏特殊处理
        if module.__widget_meta.id == "status_bar" then
            if status_bar then
                print("[工具箱] 状态栏已存在，忽略重复创建")
            else
                -- 根据释放位置决定状态栏位置
                local position = "bottom"
                if screen_y < WINDOW_HEIGHT / 2 then
                    position = "top"
                end
                create_status_bar(position)
            end
        end
        return
    end
    
    -- 将屏幕坐标转换为画布坐标
    local canvas_x = screen_x - canvas.props.x
    local canvas_y = screen_y - canvas.props.y
    
    print("[工具箱] 画布坐标: (" .. canvas_x .. ", " .. canvas_y .. ")")
    
    -- 检查是否在画布范围内
    if canvas_x >= 0 and canvas_x < canvas.props.width and
       canvas_y >= 0 and canvas_y < canvas.props.height then
        -- 在画布内，创建控件
        local widget = canvas:handle_drop(module, canvas_x, canvas_y)
        if widget then
            -- 保存模块路径到 widget_entry
            widget.module_path = tool.module_path
            print("[工具箱] 控件创建成功: " .. widget.id .. ", module_path: " .. (tool.module_path or "nil"))
            -- 自动选中新创建的控件
            canvas:select_widget(widget)
        end
    else
        print("[工具箱] 释放位置不在画布范围内，取消创建")
    end
end)

-- 兼容旧的点击放置方式
toolbox:on("tool_dropped", function(self, tool, module, x, y)
    print("[工具箱] 点击放置工具: " .. tool.name)
    
    -- 检查是否是全局组件
    if module.__widget_meta and module.__widget_meta.is_global then
        if module.__widget_meta.id == "status_bar" then
            if not status_bar then
                create_status_bar("bottom")
            end
        end
        return
    end
    
    -- 默认放置位置（画布中心附近）
    local default_x = 200
    local default_y = 150
    
    local widget = canvas:handle_drop(module, default_x, default_y)
    if widget then
        -- 保存模块路径到 widget_entry
        widget.module_path = tool.module_path
        print("[工具箱] 控件创建成功: " .. widget.id .. ", module_path: " .. (tool.module_path or "nil"))
        canvas:select_widget(widget)
    end
end)

-- 工具箱/属性窗口/图页列表状态同步
toolbox:on("visibility_changed", function(self, visible)
    print("[工具箱] 可见性变化: " .. tostring(visible))
    menu_bar:set_state("show_toolbox", visible)
end)

property_area:on("visibility_changed", function(self, visible)
    print("[属性窗口] 可见性变化: " .. tostring(visible))
    menu_bar:set_state("show_properties", visible)
end)

canvas_list:on("visibility_changed", function(self, visible)
    print("[图页列表] 可见性变化: " .. tostring(visible))
    menu_bar:set_state("show_canvas_list", visible)
end)

-- 图页列表事件处理
canvas_list:on("page_selected", function(self, page_data, index)
    print("[图页列表] 切换到图页: " .. page_data.name .. " (索引: " .. index .. ")")
    
    -- 如果选中的是当前页，不需要切换
    if index == current_page_index then
        print("[图页列表] 已经是当前图页，无需切换")
        return
    end
    
    -- 保存当前画布状态到之前的图页（仅当之前有有效图页时）
    if current_page_index > 0 and current_page_index <= canvas_list:get_page_count() then
        save_canvas_to_page(current_page_index)
    end
    
    -- 更新当前图页索引
    current_page_index = index
    
    -- 加载新图页的内容
    load_canvas_from_page(index)
    
    -- 清除属性面板的选中状态
    property_area:onSelectedItem(nil)
    
    -- 注意：状态栏是全局组件，切换图页时不受影响
end)

canvas_list:on("page_added", function(self, page_data)
    print("[图页列表] 新增图页: " .. page_data.name)
end)

canvas_list:on("page_deleted", function(self, page_data, deleted_index)
    print("[图页列表] 删除图页: " .. page_data.name)
    
    -- 如果删除的是当前页，需要更新当前页索引
    if deleted_index == current_page_index then
        -- 删除后会自动选中新的图页，current_page_index 会在 page_selected 事件中更新
        current_page_index = 0
    elseif deleted_index < current_page_index then
        -- 如果删除的是当前页之前的页，需要调整索引
        current_page_index = current_page_index - 1
    end
end)

print("=== 编辑器初始化完成 ===")
