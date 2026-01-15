-- ProjectManager.lua
-- 工程管理器：负责保存和加载工程文件

local json = require("json")

local ProjectManager = {}
ProjectManager.__index = ProjectManager

-- 项目文件版本
local PROJECT_VERSION = "1.0"

-- 默认项目目录
local DEFAULT_PROJECT_DIR = "projects"

-- 构造函数
function ProjectManager.new()
    local self = setmetatable({}, ProjectManager)
    
    -- 当前工程路径
    self._current_path = nil
    
    -- 确保项目目录存在
    self:_ensure_directory(DEFAULT_PROJECT_DIR)
    
    return self
end

-- 确保目录存在
function ProjectManager:_ensure_directory(path)
    -- 使用 os.execute 创建目录（Windows）
    local cmd = 'if not exist "' .. path .. '" mkdir "' .. path .. '"'
    os.execute(cmd)
end

-- 从编辑器导出工程数据
function ProjectManager:export_project_data(editor)
    local canvas = editor.get_canvas()
    local canvas_list = editor.get_canvas_list()
    local status_bar = editor.get_status_bar()
    
    -- 获取当前画布状态并保存到当前图页
    local current_page, current_index = canvas_list:get_selected_page()
    if current_page and current_index > 0 then
        local state = canvas:export_state()
        if state and state.widgets then
            local widgets_data = {}
            local current_widgets = canvas:get_widgets()
            
            for i, widget_state in ipairs(state.widgets) do
                local widget_entry = current_widgets[i]
                local module_path = nil
                
                if widget_entry and widget_entry.module_path then
                    module_path = widget_entry.module_path
                end
                
                table.insert(widgets_data, {
                    type = widget_state.type,
                    props = widget_state.props,
                    module_path = module_path,
                })
            end
            
            canvas_list:update_page_data(current_index, widgets_data)
        end
    end
    
    -- 构建工程数据
    local project_data = {
        version = PROJECT_VERSION,
        created_at = os.date("%Y-%m-%d %H:%M:%S"),
        modified_at = os.date("%Y-%m-%d %H:%M:%S"),
        
        -- 编辑器设置
        settings = {
            window_width = 1024,
            window_height = 768,
            show_grid = canvas:is_grid_visible(),
            snap_to_grid = canvas:is_snap_to_grid(),
            grid_size = canvas.props.grid_size or 20,
        },
        
        -- 状态栏设置
        status_bar = nil,
        
        -- 图页列表
        pages = {},
    }
    
    -- 导出状态栏设置
    if status_bar then
        project_data.status_bar = {
            enabled = true,
            position = "bottom",
            lamp_status = status_bar.props.lamp_status or "#00FF00",
            lamp_text = status_bar.props.lamp_text or "CH1",
        }
    end
    
    -- 导出所有图页
    local pages = canvas_list:get_pages()
    for i, page in ipairs(pages) do
        local page_data = {
            id = page.id,
            name = page.name,
            width = page.width or 800,
            height = page.height or 600,
            bg_color = page.bg_color or 0x1E1E1E,
            widgets = page.widgets or {},
        }
        table.insert(project_data.pages, page_data)
    end
    
    -- 记录当前选中的图页
    project_data.current_page_index = current_index
    
    return project_data
end

-- 保存工程到文件
function ProjectManager:save_project(filepath, project_data)
    if not filepath or not project_data then
        return false, "无效的参数"
    end
    
    -- 确保目录存在
    local dir = filepath:match("(.+)[/\\]")
    if dir then
        self:_ensure_directory(dir)
    end
    
    -- 编码为 JSON
    local json_str = json.encode(project_data, true)  -- true 表示美化输出
    if not json_str then
        return false, "JSON 编码失败"
    end
    
    -- 写入文件
    local file, err = io.open(filepath, "w")
    if not file then
        return false, "无法创建文件: " .. (err or "未知错误")
    end
    
    file:write(json_str)
    file:close()
    
    self._current_path = filepath
    print("[ProjectManager] 工程已保存到: " .. filepath)
    
    return true, nil
end

-- 从文件加载工程
function ProjectManager:load_project(filepath)
    if not filepath then
        return nil, "无效的文件路径"
    end
    
    print("[ProjectManager] 尝试加载文件: " .. filepath)
    
    -- 读取文件（使用二进制模式避免换行符转换问题）
    local file, err = io.open(filepath, "rb")
    if not file then
        return nil, "无法打开文件: " .. (err or "未知错误")
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content then
        return nil, "无法读取文件内容"
    end
    
    if #content == 0 then
        return nil, "文件为空"
    end
    
    print("[ProjectManager] 文件大小: " .. #content .. " 字节")
    print("[ProjectManager] 文件开头: " .. string.format("%02X %02X %02X", 
        content:byte(1) or 0, content:byte(2) or 0, content:byte(3) or 0))
    
    -- 解码 JSON
    local ok, project_data = pcall(json.decode, content)
    if not ok then
        return nil, "JSON 解析失败: " .. tostring(project_data)
    end
    
    if not project_data then
        return nil, "无效的工程数据"
    end
    
    -- 验证版本
    if project_data.version ~= PROJECT_VERSION then
        print("[ProjectManager] 警告: 工程版本不匹配，当前: " .. PROJECT_VERSION .. ", 文件: " .. (project_data.version or "未知"))
    end
    
    self._current_path = filepath
    print("[ProjectManager] 工程已加载: " .. filepath)
    
    return project_data, nil
end

-- 将工程数据导入到编辑器
function ProjectManager:import_project_data(editor, project_data)
    if not editor or not project_data then
        return false, "无效的参数"
    end
    
    local canvas = editor.get_canvas()
    local canvas_list = editor.get_canvas_list()
    
    -- 清空当前画布
    canvas:clear()
    
    -- 清空当前图页列表（保留至少一个）
    local page_count = canvas_list:get_page_count()
    while page_count > 1 do
        canvas_list:delete_page(page_count)
        page_count = canvas_list:get_page_count()
    end
    
    -- 恢复编辑器设置
    if project_data.settings then
        if project_data.settings.show_grid ~= nil then
            canvas:set_show_grid(project_data.settings.show_grid)
        end
        if project_data.settings.snap_to_grid ~= nil then
            canvas:set_snap_to_grid(project_data.settings.snap_to_grid)
        end
    end
    
    -- 恢复状态栏
    if project_data.status_bar and project_data.status_bar.enabled then
        local status_bar = editor.get_status_bar()
        if not status_bar then
            editor.create_status_bar(project_data.status_bar.position or "bottom")
        end
    else
        editor.remove_status_bar()
    end
    
    -- 恢复图页
    if project_data.pages and #project_data.pages > 0 then
        -- 处理第一个图页
        if project_data.pages[1] then
            local first_page = project_data.pages[1]
            canvas_list:rename_page(1, first_page.name)
            canvas_list:update_page_data(1, first_page.widgets or {})
            -- 恢复图页属性
            if first_page.width then
                canvas_list:update_page_property(1, "width", first_page.width)
            end
            if first_page.height then
                canvas_list:update_page_property(1, "height", first_page.height)
            end
            if first_page.bg_color then
                canvas_list:update_page_property(1, "bg_color", first_page.bg_color)
            end
        end
        
        -- 添加其余图页
        for i = 2, #project_data.pages do
            local page = project_data.pages[i]
            -- 添加图页时传入属性
            canvas_list:add_page(page.name, {
                width = page.width,
                height = page.height,
                bg_color = page.bg_color,
            })
            canvas_list:update_page_data(i, page.widgets or {})
        end
        
        -- 选择默认图页
        local target_index = project_data.current_page_index or 1
        if target_index > 0 and target_index <= canvas_list:get_page_count() then
            canvas_list:select_page(target_index)
        else
            canvas_list:select_page(1)
        end
    end
    
    print("[ProjectManager] 工程数据已导入，共 " .. #(project_data.pages or {}) .. " 个图页")
    
    return true, nil
end

-- 获取当前工程路径
function ProjectManager:get_current_path()
    return self._current_path
end

-- 设置当前工程路径
function ProjectManager:set_current_path(path)
    self._current_path = path
end

-- 新建工程
function ProjectManager:new_project(editor)
    local canvas = editor.get_canvas()
    local canvas_list = editor.get_canvas_list()
    
    -- 清空画布
    canvas:clear()
    
    -- 清空图页列表，只保留一个
    local page_count = canvas_list:get_page_count()
    while page_count > 1 do
        canvas_list:delete_page(page_count)
        page_count = canvas_list:get_page_count()
    end
    
    -- 重命名为默认名称
    canvas_list:rename_page(1, "图页 1")
    canvas_list:update_page_data(1, {})
    canvas_list:select_page(1)
    
    -- 移除状态栏
    editor.remove_status_bar()
    
    -- 重置当前路径
    self._current_path = nil
    
    print("[ProjectManager] 已创建新工程")
    
    return true
end

-- 检查文件是否存在
function ProjectManager:file_exists(filepath)
    local file = io.open(filepath, "r")
    if file then
        file:close()
        return true
    end
    return false
end

-- 获取默认项目目录
function ProjectManager:get_default_directory()
    return DEFAULT_PROJECT_DIR
end

return ProjectManager
