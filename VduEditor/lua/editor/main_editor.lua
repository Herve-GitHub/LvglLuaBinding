-- main_editor.lua
-- 主编辑器入口：整合菜单栏、画布、左侧面板（工具箱+图页列表）、右侧属性面板
local lv = require("lvgl")
local gen = require("general")

-- 获取应用程序目录（由 C++ 设置的全局变量）
local APP_DIR = _G.APP_DIR or ""

-- 辅助函数：构建完整路径
local function build_path(relative_path)
    if APP_DIR and APP_DIR ~= "" then
        -- 将正斜杠转换为反斜杠（Windows）
        local path = APP_DIR .. relative_path:gsub("/", "\\")
        return path
    end
    return relative_path
end

-- 加载图标模块
local Icons = require("icons")

-- 尝试加载图标字体（Font Awesome），如果失败则使用中文图标
local icon_font = nil
local icon_font_loaded = false

-- 尝试加载 Font Awesome 字体
local function try_load_icon_font()
    local font_path = build_path("fonts/fa-solid-900.ttf")
    print("[图标] 尝试加载字体: " .. font_path)
    
    local ok, font = pcall(function()
        return lv.tiny_ttf_create_file(font_path, 16)
    end)
    if ok and font then
        icon_font = font
        icon_font_loaded = true
        Icons.use("fa")
        print("[图标] Font Awesome 字体加载成功")
        return true
    else
        print("[图标] Font Awesome 字体未找到，使用中文图标")
        Icons.use("cn")
        return false
    end
end

-- 延迟加载图标字体（避免阻塞启动）
--try_load_icon_font()  -- 暂时禁用，直接使用中文图标

-- 默认使用中文图标（兼容 SimHei 字体）
Icons.use("cn")

-- 加载编辑器组件
local MenuBar = require("MenuBar")
local CanvasArea = require("CanvasArea")
local LeftPanel = require("LeftPanel")
local PropertyArea = require("PropertyArea")
local StatusBar = require("widgets.status_bar")
local ProjectManager = require("ProjectManager")
local ProjectCompiler = require("ProjectCompiler")
local FileDialog = require("FileDialog")

-- 辅助函数：解析颜色值（支持字符串 "#RRGGBB" 或数字）
local function parse_color(value, default)
    default = default or 0x1E1E1E
    if type(value) == "number" then
        return value
    elseif type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
        return tonumber(value:sub(2), 16) or default
    end
    return default
end

-- 获取屏幕
local scr = lv.scr_act()

-- 清除屏幕的 flex 布局
scr:clear_layout()

-- 设置屏幕背景色
scr:set_style_bg_color(0x1E1E1E, 0)

-- 禁用屏幕滚动
scr:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 重置屏幕的 padding
scr:set_style_pad_all(0, 0)

-- 设置默认文字颜色
scr:set_style_text_color(0xFFFFFF, 0)

print("=== VDU 编辑器启动 ===")
print("[编辑器] 应用目录: " .. (APP_DIR or "(未设置)"))

-- 布局常量
local STATUSBAR_HEIGHT = 28
local LEFT_PANEL_WIDTH = 250
local RIGHT_PANEL_WIDTH = 280

-- 获取窗口尺寸
local function get_window_size()
    local w, h = 1024, 768
    if scr and scr.get_width and scr.get_height then
        local ok1, ww = pcall(function() return scr:get_width() end)
        local ok2, hh = pcall(function() return scr:get_height() end)
        if ok1 and type(ww) == "number" and ww > 0 then w = ww end
        if ok2 and type(hh) == "number" and hh > 0 then h = hh end
    end
    return w, h
end

local WINDOW_WIDTH, WINDOW_HEIGHT = get_window_size()

-- 状态栏实例
local status_bar = nil
local status_bar_position = "bottom"

-- 工程管理器实例
local project_manager = ProjectManager.new()

-- 工程编译器实例
local project_compiler = ProjectCompiler.new()

-- 仿真进程管理
local simulator_process = nil  -- 存储仿真进程句柄/PID

-- 当前活动的图页索引
local current_page_index = 0

-- 模块缓存
local loaded_modules = {}

-- 控件 ID 到模块路径的映射
local widget_id_to_module_path = {
    ["custom_button"] = "widgets.button",
    ["button"] = "widgets.button",
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

-- ========== 创建菜单栏 (Ribbon 风格) ==========
local menu_bar = MenuBar.new(scr, {
    x = 0,
    y = 0,
    width = WINDOW_WIDTH,
})

-- 从菜单栏获取实际高度
local MENUBAR_HEIGHT = menu_bar:get_height()

-- 计算画布区域
local function get_canvas_bounds()
    local canvas_x = LEFT_PANEL_WIDTH
    local canvas_y = MENUBAR_HEIGHT
    local canvas_width = WINDOW_WIDTH - LEFT_PANEL_WIDTH - RIGHT_PANEL_WIDTH
    local canvas_height = WINDOW_HEIGHT - MENUBAR_HEIGHT
    
    if status_bar then
        canvas_height = canvas_height - STATUSBAR_HEIGHT
    end
    
    return canvas_x, canvas_y, canvas_width, canvas_height
end

-- ========== 创建左侧面板（工具箱+图页列表）==========
local left_panel = LeftPanel.new(scr, {
    x = 0,
    y = MENUBAR_HEIGHT,
    width = LEFT_PANEL_WIDTH,
    height = WINDOW_HEIGHT - MENUBAR_HEIGHT,
})

-- ========== 创建右侧属性面板 ==========
local property_area = PropertyArea.new(scr, {
    x = WINDOW_WIDTH - RIGHT_PANEL_WIDTH,
    y = MENUBAR_HEIGHT,
    width = RIGHT_PANEL_WIDTH,
    height = WINDOW_HEIGHT - MENUBAR_HEIGHT,
})

-- ========== 创建画布区域 ==========
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

-- ========== 窗口大小变化监听 ==========

local function update_layout()
    local new_width, new_height = get_window_size()
    
    if new_width ~= WINDOW_WIDTH or new_height ~= WINDOW_HEIGHT then
        WINDOW_WIDTH = new_width
        WINDOW_HEIGHT = new_height
        
        -- 更新左侧面板高度
        left_panel:set_height(new_height - MENUBAR_HEIGHT)
        
        -- 更新右侧属性面板位置和高度
        property_area:set_pos(new_width - RIGHT_PANEL_WIDTH, MENUBAR_HEIGHT)
        property_area:set_height(new_height - MENUBAR_HEIGHT)
        
        -- 更新画布区域
        local cx, cy, cw, ch = get_canvas_bounds()
        canvas.props.x = cx
        canvas.props.y = cy
        canvas.props.width = cw
        canvas.props.height = ch
        canvas.container:set_pos(cx, cy)
        canvas.container:set_size(cw, ch)
        
        -- 更新状态栏
        if status_bar then
            local sb_y = new_height - STATUSBAR_HEIGHT
            status_bar:set_property("y", sb_y)
            status_bar:set_property("width", cw)
            status_bar.container:set_pos(cx, sb_y)
            status_bar.container:set_width(cw)
        end
        
        print("[编辑器] 窗口大小更新: " .. new_width .. "x" .. new_height)
    end
end

-- 创建布局更新定时器
local layout_timer = lv.timer_create(function(timer)
    update_layout()
end, 200)

-- ========== 状态栏管理 ==========

local function create_status_bar(position)
    position = position or "bottom"
    status_bar_position = position
    
    local sb_x = canvas_x
    local sb_y = WINDOW_HEIGHT - STATUSBAR_HEIGHT
    local sb_width = canvas_width
    
    status_bar = StatusBar.new(scr, {
        x = sb_x,
        y = sb_y,
        width = sb_width,
        height = STATUSBAR_HEIGHT,
        position = position,
        lamp_status = "#00FF00",
        lamp_text = "CH1",
    })
    
    -- 更新画布大小
    local cx, cy, cw, ch = get_canvas_bounds()
    canvas.props.height = ch
    canvas.container:set_height(ch)
    
    print("[编辑器] 状态栏已创建")
    return status_bar
end

local function remove_status_bar()
    if status_bar then
        status_bar:destroy()
        status_bar = nil
        
        local cx, cy, cw, ch = get_canvas_bounds()
        canvas.props.height = ch
        canvas.container:set_height(ch)
        
        print("[编辑器] 状态栏已移除")
    end
end

local function get_status_bar()
    return status_bar
end

-- ========== 保存/加载画布状态 ==========

local function save_canvas_to_page(page_index)
    if page_index < 1 then return end
    
    local state = canvas:export_state()
    if state and state.widgets then
        local widgets_data = {}
        local current_widgets = canvas:get_widgets()
        
        for i, widget_state in ipairs(state.widgets) do
            local widget_entry = current_widgets[i]
            local module_path = nil
            
            if widget_entry and widget_entry.module_path then
                module_path = widget_entry.module_path
            elseif widget_entry and widget_entry.module and widget_entry.module.__widget_meta then
                local widget_id = widget_entry.module.__widget_meta.id
                module_path = widget_id_to_module_path[widget_id]
            end
            
            table.insert(widgets_data, {
                type = widget_state.type,
                props = widget_state.props,
                module_path = module_path,
            })
        end
        
        left_panel:update_page_data(page_index, widgets_data)
        print("[编辑器] 保存画布到图页 " .. page_index)
    end
end

local function load_canvas_from_page(page_index)
    if page_index < 1 then return end
    
    local page_data = left_panel:get_page_data(page_index)
    if not page_data then return end
    
    canvas:clear()
    
    if page_data.widgets and #page_data.widgets > 0 then
        for _, widget_data in ipairs(page_data.widgets) do
            local module_path = widget_data.module_path
            if module_path then
                local widget_module = load_module(module_path)
                if widget_module then
                    local props = widget_data.props or {}
                    local widget_entry = canvas:add_widget(widget_module, props)
                    if widget_entry then
                        widget_entry.module_path = module_path
                    end
                end
            end
        end
        print("[编辑器] 从图页 " .. page_index .. " 加载完成")
    end
end

-- 创建默认图页
left_panel:add_page("图页 1")
current_page_index = 1

-- 同步菜单栏状态
menu_bar:set_state("show_grid", canvas:is_grid_visible())
menu_bar:set_state("snap_to_grid", canvas:is_snap_to_grid())

-- ========== 导出编辑器 API ==========
_G.Editor = {
    create_status_bar = create_status_bar,
    remove_status_bar = remove_status_bar,
    get_status_bar = get_status_bar,
    
    get_canvas = function() return canvas end,
    get_left_panel = function() return left_panel end,
    get_property_area = function() return property_area end,
    get_menu_bar = function() return menu_bar end,
    get_canvas_list = function() return left_panel end,  -- LeftPanel includes canvas list functionality
}

-- ========== 工程保存/加载功能 ==========

local function save_project_dialog()
    save_canvas_to_page(current_page_index)
    
    local current_path = project_manager:get_current_path()
    local default_filename = "project.json"
    if current_path then
        default_filename = current_path:match("([^/\\]+)$") or default_filename
    end
    
    FileDialog.new(scr, {
        mode = "save",
        title = "保存工程",
        default_filename = default_filename,
        callback = function(filepath, filename)
            local project_data = project_manager:export_project_data(_G.Editor)
            local success, err = project_manager:save_project(filepath, project_data)
            if success then
                print("[编辑器] 工程已保存: " .. filepath)
            else
                print("[编辑器] 保存失败: " .. (err or "未知错误"))
            end
        end
    })
end

local function open_project_dialog()
    FileDialog.new(scr, {
        mode = "open",
        title = "打开工程",
        default_filename = "",
        callback = function(filepath, filename)
            local project_data, err = project_manager:load_project(filepath)
            if project_data then
                current_page_index = 0
                local success, import_err = project_manager:import_project_data(_G.Editor, project_data)
                if success then
                    print("[编辑器] 工程已加载: " .. filepath)
                    current_page_index = project_data.current_page_index or 1
                    load_canvas_from_page(current_page_index)
                else
                    print("[编辑器] 导入失败: " .. (import_err or "未知错误"))
                    current_page_index = 1
                end
            else
                print("[编辑器] 加载失败: " .. (err or "未知错误"))
            end
        end
    })
end

local function quick_save()
    local current_path = project_manager:get_current_path()
    if current_path then
        save_canvas_to_page(current_page_index)
        local project_data = project_manager:export_project_data(_G.Editor)
        local success, err = project_manager:save_project(current_path, project_data)
        if success then
            print("[编辑器] 工程已保存: " .. current_path)
            return true, current_path
        else
            print("[编辑器] 保存失败: " .. (err or "未知错误"))
            return false, err
        end
    else
        -- 如果没有当前路径，使用默认路径保存
        local default_path = "projects/project.json"
        save_canvas_to_page(current_page_index)
        local project_data = project_manager:export_project_data(_G.Editor)
        local success, err = project_manager:save_project(default_path, project_data)
        if success then
            print("[编辑器] 工程已保存: " .. default_path)
            return true, default_path
        else
            print("[编辑器] 保存失败: " .. (err or "未知错误"))
            return false, err
        end
    end
end

-- ========== 工程编译功能 ==========

local function compile_project()
    print("[编辑器] ========== 开始编译工程 ==========")
    
    -- 1. 先保存当前工程
    local save_success, save_path = quick_save()
    if not save_success then
        print("[编辑器] 编译失败: 无法保存工程")
        return false, nil
    end
    
    -- 2. 获取工程数据
    local project_data = project_manager:export_project_data(_G.Editor)
    if not project_data then
        print("[编辑器] 编译失败: 无法导出工程数据")
        return false, nil
    end
    
    -- 3. 确定输出文件路径（与JSON文件同目录，扩展名改为.lua）
    local output_path = save_path:gsub("%.json$", ".lua")
    if output_path == save_path then
        -- 如果没有.json扩展名，直接添加.lua
        output_path = save_path .. ".lua"
    end
    
    -- 4. 编译并保存
    local success, err = project_compiler:compile_and_save(project_data, output_path)
    if success then
        print("[编辑器] ========== 编译成功 ==========")
        print("[编辑器] 输出文件: " .. output_path)
        print("[编辑器] 图页数量: " .. #(project_data.pages or {}))
        return true, output_path
    else
        print("[编辑器] ========== 编译失败 ==========")
        print("[编辑器] 错误: " .. (err or "未知错误"))
        return false, nil
    end
end

-- ========== 仿真管理功能 ==========

-- 获取仿真器路径
local function get_simulator_path()
    -- 仿真器位于与编辑器同级的目录
    local sim_path = "vdu_sim.exe"
    if APP_DIR and APP_DIR ~= "" then
        sim_path = APP_DIR .. "vdu_sim.exe"
    end
    return sim_path
end

-- 检查仿真器是否正在运行
local function is_simulator_running()
    if not simulator_process then
        return false
    end
    
    -- 使用 tasklist 检查进程是否存在
    local cmd = 'tasklist /FI "PID eq ' .. simulator_process .. '" /NH 2>nul'
    local handle = io.popen(cmd)
    if handle then
        local result = handle:read("*a")
        handle:close()
        -- 如果结果包含进程信息，说明进程仍在运行
        if result and result:match("vdu_sim") then
            return true
        end
    end
    
    -- 进程不存在，清除记录
    simulator_process = nil
    return false
end

-- 停止仿真
local function stop_simulator()
    if not simulator_process then
        print("[仿真] 没有正在运行的仿真进程")
        return true
    end
    
    print("[仿真] 停止仿真进程 (PID: " .. simulator_process .. ")")
    
    -- 使用 taskkill 终止进程
    local cmd = 'taskkill /PID ' .. simulator_process .. ' /F 2>nul'
    os.execute(cmd)
    
    -- 等待进程结束
    local wait_count = 0
    while is_simulator_running() and wait_count < 10 do
        -- 简单等待
        local start = os.clock()
        while os.clock() - start < 0.1 do end
        wait_count = wait_count + 1
    end
    
    if is_simulator_running() then
        print("[仿真] 警告: 进程可能未完全终止")
        return false
    end
    
    simulator_process = nil
    print("[仿真] 仿真进程已停止")
    return true
end

-- 启动仿真
local function start_simulator()
    -- 如果仿真器已在运行，先停止
    if is_simulator_running() then
        print("[仿真] 检测到仿真器正在运行，先停止...")
        stop_simulator()
    end
    
    print("[仿真] ========== 启动仿真 ==========")
    
    -- 1. 先编译工程
    local compile_success, compiled_script_path = compile_project()
    if not compile_success or not compiled_script_path then
        print("[仿真] 启动失败: 编译工程失败")
        return false
    end
    
    -- 2. 获取仿真器路径
    local sim_path = get_simulator_path()
    
    -- 检查仿真器是否存在
    local f = io.open(sim_path, "r")
    if not f then
        print("[仿真] 启动失败: 找不到仿真器 - " .. sim_path)
        return false
    end
    f:close()
    
    -- 3. 将编译好的脚本复制到仿真器可访问的位置
    -- 仿真器的 Lua 搜索路径是相对于其可执行文件的
    -- 从编译输出路径中提取文件名
    local script_filename = compiled_script_path:match("([^/\\]+)$") or "project.lua"
    local sim_script_dir = APP_DIR .. "lua\\"
    local sim_script_path = sim_script_dir .. script_filename
    
    -- 确保目录存在
    os.execute('if not exist "' .. sim_script_dir .. '" mkdir "' .. sim_script_dir .. '"')
    
    -- 复制编译好的脚本
    local src_file = io.open(compiled_script_path, "rb")
    if not src_file then
        print("[仿真] 启动失败: 无法读取编译后的脚本 - " .. compiled_script_path)
        return false
    end
    
    local content = src_file:read("*a")
    src_file:close()
    
    local dst_file = io.open(sim_script_path, "wb")
    if not dst_file then
        print("[仿真] 启动失败: 无法写入仿真脚本 - " .. sim_script_path)
        return false
    end
    
    dst_file:write(content)
    dst_file:close()
    
    print("[仿真] 脚本已复制到: " .. sim_script_path)
    
    -- 4. 构建命令行并启动仿真器
    -- 使用 start 命令在新窗口中启动，并使用 wmic 获取进程ID
    local script_arg = "lua\\" .. script_filename
    local cmd = 'start "" "' .. sim_path .. '" "' .. script_arg .. '"'
    
    print("[仿真] 执行命令: " .. cmd)
    os.execute(cmd)
    
    -- 等待一小段时间让进程启动
    local start_time = os.clock()
    while os.clock() - start_time < 0.5 do end
    
    -- 5. 获取仿真器进程ID
    local pid_cmd = 'wmic process where "name=\'vdu_sim.exe\'" get processid /format:value 2>nul'
    local pid_handle = io.popen(pid_cmd)
    if pid_handle then
        local pid_result = pid_handle:read("*a")
        pid_handle:close()
        
        -- 解析PID (格式: ProcessId=12345)
        local pid = pid_result:match("ProcessId=(%d+)")
        if pid then
            simulator_process = pid
            print("[仿真] 仿真器已启动 (PID: " .. pid .. ")")
        else
            print("[仿真] 警告: 无法获取仿真器进程ID")
        end
    end
    
    print("[仿真] ========== 仿真已启动 ==========")
    return true
end

-- ========== 菜单事件处理 ==========
menu_bar:on("menu_action", function(self, menu_key, item_id)
    print("[Ribbon] 按钮点击: " .. tostring(item_id))
    
    if item_id == "new" then
        project_manager:new_project(_G.Editor)
        current_page_index = 1
        print("新建工程")
    elseif item_id == "open" then
        open_project_dialog()
    elseif item_id == "save" then
        quick_save()
    elseif item_id == "save_as" then
        save_project_dialog()
    elseif item_id == "cut" then
        canvas:cut_selected()
    elseif item_id == "copy" then
        canvas:copy_selected()
    elseif item_id == "paste" then
        canvas:paste()
    elseif item_id == "delete" then
        canvas:delete_selected()
    elseif item_id == "undo" then
        canvas:undo()
    elseif item_id == "redo" then
        canvas:redo()
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
    elseif item_id == "distribute_h" then
        canvas:distribute_selected("horizontal")
    elseif item_id == "distribute_v" then
        canvas:distribute_selected("vertical")
    elseif item_id == "zoom_in" then
        canvas:zoom_in()
    elseif item_id == "zoom_out" then
        canvas:zoom_out()
    elseif item_id == "zoom_reset" then
        canvas:zoom_reset()
    elseif item_id == "show_grid" then
        local new_state = canvas:toggle_grid()
        menu_bar:set_state("show_grid", new_state)
    elseif item_id == "snap_to_grid" then
        local new_state = canvas:toggle_snap_to_grid()
        menu_bar:set_state("snap_to_grid", new_state)
    elseif item_id == "show_toolbox" then
        left_panel:toggle_toolbox()
    elseif item_id == "show_properties" then
        property_area:toggle_visible()
    elseif item_id == "show_canvas_list" then
        left_panel:toggle_canvas_list()
    elseif item_id == "export" then
        print("导出工程")
    elseif item_id == "export_image" then
        print("导出图片")
    elseif item_id == "compile" then
        -- 编译工程
        compile_project()
    elseif item_id == "startInstall" then
        print("启动下装")
    elseif item_id == "stopInstall" then
        print("停止下装")
    elseif item_id == "startSim" then
        -- 启动仿真
        start_simulator()
    elseif item_id == "stopSim" then
        -- 停止仿真
        stop_simulator()
    elseif item_id == "exit" then
        print("退出编辑器")
    end
end)

-- ========== 画布事件处理 ==========
canvas:on("widget_added", function(self, widget_entry)
    print("[画布] 添加控件: " .. widget_entry.id)
end)

canvas:on("widget_selected", function(self, widget_entry)
    property_area:onSelectedItem(widget_entry)
    print("[画布] 选中控件: " .. widget_entry.id)
end)

canvas:on("widgets_selected", function(self, widget_entries)
    property_area:onSelectedItem(widget_entries)
    print("[画布] 多选控件: " .. #widget_entries .. " 个")
end)

canvas:on("widget_deselected", function(self, prev_widget)
    -- 控件取消选中时，显示当前图页属性
    if current_page_index > 0 then
        local page_data = left_panel:get_page_data(current_page_index)
        local page_meta = left_panel:get_page_meta()
        property_area:onSelectedPage(page_data, current_page_index, page_meta)
    else
        property_area:onSelectedItem(nil)
    end
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

-- ========== 左侧面板事件处理 ==========
left_panel:on("tool_drag_drop", function(self, tool, module, screen_x, screen_y)
    print("[左侧面板] 拖放工具: " .. tool.name)
    
    -- 检查是否是全局组件
    if module.__widget_meta and module.__widget_meta.is_global then
        if module.__widget_meta.id == "status_bar" then
            if not status_bar then
                create_status_bar("bottom")
            end
        end
        return
    end
    
    -- 将屏幕坐标转换为画布坐标
    local canvas_local_x = screen_x - canvas.props.x
    local canvas_local_y = screen_y - canvas.props.y
    
    -- 检查是否在画布范围内
    if canvas_local_x >= 0 and canvas_local_x < canvas.props.width and
       canvas_local_y >= 0 and canvas_local_y < canvas.props.height then
        local widget = canvas:handle_drop(module, canvas_local_x, canvas_local_y)
        if widget then
            widget.module_path = tool.module_path
            canvas:select_widget(widget)
        end
    else
        print("[左侧面板] 释放位置不在画布范围内")
    end
end)

left_panel:on("page_selected", function(self, page_data, index)
    print("[左侧面板] 切换到图页: " .. page_data.name)
    
    -- 先取消画布上的选中
    canvas:deselect_all()
    
    if index == current_page_index then
        -- 即使是同一个图页，也显示图页属性
        local page_meta = left_panel:get_page_meta()
        property_area:onSelectedPage(page_data, index, page_meta)
        return
    end
    
    if current_page_index > 0 and current_page_index <= left_panel:get_page_count() then
        save_canvas_to_page(current_page_index)
    end
    
    current_page_index = index
    load_canvas_from_page(index)
    
    -- 应用图页的背景颜色到画布
    if page_data.bg_color then
        local bg_color_num = parse_color(page_data.bg_color, 0x1E1E1E)
        canvas.container:set_style_bg_color(bg_color_num, 0)
        canvas.props.bg_color = bg_color_num
    end
    
    -- 显示图页属性
    local page_meta = left_panel:get_page_meta()
    property_area:onSelectedPage(page_data, index, page_meta)
end)

left_panel:on("page_added", function(self, page_data)
    print("[左侧面板] 新增图页: " .. page_data.name)
end)

left_panel:on("page_deleted", function(self, page_data, deleted_index)
    print("[左侧面板] 删除图页: " .. page_data.name)
    
    if deleted_index == current_page_index then
        current_page_index = 0
    elseif deleted_index < current_page_index then
        current_page_index = current_page_index - 1
    end
end)

-- ========== 属性窗口事件处理 ==========
property_area:on("page_property_changed", function(self, prop_name, prop_value, page_index)
    print("[属性窗口] 图页属性变更: " .. prop_name .. " = " .. tostring(prop_value))
    
    -- 更新图页数据
    left_panel:update_page_property(page_index, prop_name, prop_value)
    
    -- 如果是当前图页，同步更新画布
    if page_index == current_page_index then
        if prop_name == "width" or prop_name == "height" then
            -- 更新画布大小
            local page_data = left_panel:get_page_data(page_index)
            if page_data then
                -- 注意：这里可以根据需要调整画布大小
                -- 目前画布大小由窗口布局决定，图页大小可用于导出或预览
                print("[编辑器] 图页尺寸变更: " .. page_data.width .. "x" .. page_data.height)
            end
        elseif prop_name == "bg_color" then
            -- 更新画布背景颜色
            local bg_color_num = parse_color(prop_value, 0x1E1E1E)
            canvas.container:set_style_bg_color(bg_color_num, 0)
            canvas.props.bg_color = bg_color_num
            print("[编辑器] 画布背景颜色变更: " .. string.format("0x%06X", bg_color_num))
        end
    end
end)

print("=== 编辑器初始化完成 ===")
