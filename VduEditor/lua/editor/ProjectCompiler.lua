 -- ProjectCompiler.lua
-- 工程编译器：将JSON工程文件转换为可运行的Lua脚本

local json = require("json")

local ProjectCompiler = {}
ProjectCompiler.__index = ProjectCompiler

-- 控件类型到模块路径的映射
local WIDGET_TYPE_TO_MODULE = {
    ["custom_button"] = "widgets.button",
    ["button"] = "widgets.button",
    ["valve"] = "widgets.valve",
    ["trend_chart"] = "widgets.trend_chart",
    ["status_bar"] = "widgets.status_bar",
}

-- 控件类型对应的事件列表
local WIDGET_EVENTS = {
    ["custom_button"] = { "clicked", "single_clicked", "double_clicked" },
    ["button"] = { "clicked", "single_clicked", "double_clicked" },
    ["valve"] = { "angle_changed", "toggled" },
    ["trend_chart"] = { "updated" },
    ["status_bar"] = { "updated", "time_tick" },
}

-- 事件回调函数的参数签名（用于生成代码）
-- 使用 _ 作为不常用参数的占位符，与 demo 代码风格一致
local EVENT_CALLBACK_PARAMS = {
    -- button 事件：function(self)
    ["clicked"] = "_",
    ["single_clicked"] = "_",
    ["double_clicked"] = "_",
    -- valve 事件
    ["angle_changed"] = "_, angle",
    ["toggled"] = "_, is_open",
    -- trend_chart 事件：参考 demo_trend_chart.lua 的写法
    ["updated"] = "_, value",
    -- status_bar 事件
    ["time_tick"] = "_, time_str",
}

-- actions 模块列表（需要引入到生成代码中）
local ACTION_MODULES = {
    "actions.page_navigation",
}

-- 构造函数
function ProjectCompiler.new()
    local self = setmetatable({}, ProjectCompiler)
    return self
end

-- 转义字符串中的特殊字符
local function escape_string(str)
    if type(str) ~= "string" then
        return tostring(str)
    end
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")
    return str
end

-- 生成合法的 Lua 变量名
local function make_valid_var_name(name)
    if not name or name == "" then
        return nil
    end
    -- 移除非法字符，只保留字母、数字、下划线
    local valid_name = name:gsub("[^%w_]", "_")
    -- 确保不以数字开头
    if valid_name:match("^%d") then
        valid_name = "_" .. valid_name
    end
    -- 确保不为空
    if valid_name == "" or valid_name == "_" then
        return nil
    end
    return valid_name
end

-- 将Lua值转换为字符串表示
local function value_to_string(value, indent)
    indent = indent or ""
    local t = type(value)
    
    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        return '"' .. escape_string(value) .. '"'
    elseif t == "table" then
        local parts = {}
        local is_array = true
        local max_index = 0
        
        -- 检查是否是数组
        for k, _ in pairs(value) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
                break
            end
            if k > max_index then
                max_index = k
            end
        end
        
        if is_array and max_index > 0 then
            for i = 1, max_index do
                table.insert(parts, value_to_string(value[i], indent .. "    "))
            end
            return "{ " .. table.concat(parts, ", ") .. " }"
        else
            local new_indent = indent .. "    "
            for k, v in pairs(value) do
                local key_str
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key_str = k
                else
                    key_str = "[" .. value_to_string(k) .. "]"
                end
                table.insert(parts, new_indent .. key_str .. " = " .. value_to_string(v, new_indent))
            end
            if #parts == 0 then
                return "{}"
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        end
    else
        return '"' .. tostring(value) .. '"'
    end
end

-- 生成控件创建代码
local function generate_widget_code(widget, index, page_var, used_names)
    local lines = {}
    local widget_type = widget.type or "custom_button"
    local module_path = widget.module_path or WIDGET_TYPE_TO_MODULE[widget_type] or "widgets.button"
    local props = widget.props or {}
    
    -- 确保 design_mode = false
    props.design_mode = false
    
    -- 确定变量名：优先使用 instance_name，否则使用默认名称
    local instance_name = props.instance_name
    local var_name = make_valid_var_name(instance_name)
    
    if not var_name then
        -- 没有有效的实例名称，使用默认名称
        var_name = "widget_" .. index
    else
        -- 检查变量名是否重复
        if used_names[var_name] then
            -- 如果重复，添加索引后缀
            var_name = var_name .. "_" .. index
        end
    end
    
    -- 记录已使用的变量名
    used_names[var_name] = true
    
    -- 生成属性表
    local props_str = value_to_string(props, "    ")
    
    -- 生成注释，包含实例名称信息
    local comment = "控件 " .. index .. ": " .. widget_type
    if instance_name and instance_name ~= "" then
        comment = comment .. " (" .. instance_name .. ")"
    end
    
    table.insert(lines, "    -- " .. comment)
    table.insert(lines, "    local " .. var_name .. " = " .. module_path:gsub("%.", "_") .. ".new(" .. page_var .. ", " .. props_str .. ")")
    table.insert(lines, "")
    
    -- 获取该控件类型支持的事件列表
    local events = WIDGET_EVENTS[widget_type] or { "clicked", "single_clicked", "double_clicked" }
    
    -- 生成事件处理代码
    for _, event_name in ipairs(events) do
        local handler_prop = "on_" .. event_name .. "_handler"
        local handler_code = props[handler_prop]
        
        if handler_code and handler_code ~= "" then
            -- 获取回调参数签名
            local callback_params = EVENT_CALLBACK_PARAMS[event_name] or "self"
            
            table.insert(lines, "    -- " .. event_name .. " 事件处理")
            table.insert(lines, "    " .. var_name .. ':on("' .. event_name .. '", function(' .. callback_params .. ')')
            -- 将处理代码按行添加，并添加适当缩进
            for line in handler_code:gmatch("[^\n]+") do
                table.insert(lines, "        " .. line)
            end
            table.insert(lines, "    end)")
            table.insert(lines, "")
        end
    end
    
    return table.concat(lines, "\n"), module_path, var_name
end

-- 生成图页代码
local function generate_page_code(page, page_index)
    local lines = {}
    local page_var = "page_" .. page_index
    local required_modules = {}
    local widget_vars = {}  -- 记录控件变量名
    local used_names = {}   -- 记录已使用的变量名
    
    table.insert(lines, "-- ========== 图页 " .. page_index .. ": " .. (page.name or "未命名") .. " ==========")
    table.insert(lines, "local function create_" .. page_var .. "(parent)")
    table.insert(lines, "    -- 创建图页容器")
    table.insert(lines, "    local container = lv.obj_create(parent)")
    table.insert(lines, "    container:set_pos(0, 0)")
    table.insert(lines, "    container:set_size(lv.display_get_hor_res(), lv.display_get_ver_res())")
    table.insert(lines, "    container:set_style_bg_color(0x1E1E1E, 0)")
    table.insert(lines, "    container:set_style_border_width(0, 0)")
    table.insert(lines, "    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)")
    table.insert(lines, "    container:clear_layout()")
    table.insert(lines, "")
    
    -- 生成控件代码
    if page.widgets and #page.widgets > 0 then
        for i, widget in ipairs(page.widgets) do
            local widget_code, module_path, var_name = generate_widget_code(widget, i, "container", used_names)
            table.insert(lines, widget_code)
            required_modules[module_path] = true
            table.insert(widget_vars, var_name)
        end
    end
    
    table.insert(lines, "    return container")
    table.insert(lines, "end")
    table.insert(lines, "")
    
    return table.concat(lines, "\n"), required_modules, widget_vars
end

-- 编译工程JSON为Lua脚本
function ProjectCompiler:compile(project_data)
    if not project_data then
        return nil, "无效的工程数据"
    end
    
    local lines = {}
    local all_required_modules = {}
    
    -- 文件头
    table.insert(lines, "-- ==============================================")
    table.insert(lines, "-- 自动生成的Lua脚本")
    table.insert(lines, "-- 由 VduEditor 编译生成")
    table.insert(lines, "-- 生成时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(lines, "-- 工程版本: " .. (project_data.version or "1.0"))
    table.insert(lines, "-- ==============================================")
    table.insert(lines, "")
    
    -- 先收集所有需要的模块
    if project_data.pages then
        for _, page in ipairs(project_data.pages) do
            if page.widgets then
                for _, widget in ipairs(page.widgets) do
                    local widget_type = widget.type or "custom_button"
                    local module_path = widget.module_path or WIDGET_TYPE_TO_MODULE[widget_type] or "widgets.button"
                    all_required_modules[module_path] = true
                end
            end
        end
    end
    
    -- 生成模块引用
    table.insert(lines, "-- 引用 LVGL")
    table.insert(lines, "local lv = require(\"lvgl\")")
    table.insert(lines, "")
    
    -- 引用控件模块
    table.insert(lines, "-- 引用控件模块")
    for module_path, _ in pairs(all_required_modules) do
        local var_name = module_path:gsub("%.", "_")
        table.insert(lines, "local " .. var_name .. " = require(\"" .. module_path .. "\")")
    end
    table.insert(lines, "")
    
    -- 引用 actions 模块
    table.insert(lines, "-- 引用动作模块")
    for _, action_module in ipairs(ACTION_MODULES) do
        local var_name = action_module:gsub("%.", "_")
        table.insert(lines, "local " .. var_name .. " = require(\"" .. action_module .. "\")")
    end
    table.insert(lines, "")
    
    -- 获取屏幕
    table.insert(lines, "-- 获取活动屏幕")
    table.insert(lines, "local scr = lv.scr_act()")
    table.insert(lines, "scr:set_style_bg_color(0x1E1E1E, 0)")
    table.insert(lines, "scr:remove_flag(lv.OBJ_FLAG_SCROLLABLE)")
    table.insert(lines, "scr:clear_layout()")
    table.insert(lines, "")
    
    -- 生成每个图页的代码
    local page_functions = {}
    if project_data.pages and #project_data.pages > 0 then
        for i, page in ipairs(project_data.pages) do
            local page_code, modules, widget_vars = generate_page_code(page, i)
            table.insert(lines, page_code)
            table.insert(page_functions, "create_page_" .. i)
        end
    end
    
    -- 生成图页管理器
    table.insert(lines, "-- ========== 图页管理 ==========")
    table.insert(lines, "local PageManager = {}")
    table.insert(lines, "PageManager.pages = {}")
    table.insert(lines, "PageManager.current_page = nil")
    table.insert(lines, "PageManager.current_index = 0")
    table.insert(lines, "")
    
    -- 注册所有图页
    table.insert(lines, "-- 注册图页创建函数")
    for i, func_name in ipairs(page_functions) do
        local page_name = project_data.pages[i] and project_data.pages[i].name or ("图页 " .. i)
        table.insert(lines, 'PageManager.pages[' .. i .. '] = { name = "' .. escape_string(page_name) .. '", create = ' .. func_name .. ' }')
    end
    table.insert(lines, "")
    
    -- 获取图页数量
    table.insert(lines, "-- 获取图页数量")
    table.insert(lines, "function PageManager.get_page_count()")
    table.insert(lines, "    return #PageManager.pages")
    table.insert(lines, "end")
    table.insert(lines, "")
    
    -- 获取当前选中的图页
    table.insert(lines, "-- 获取当前选中的图页")
    table.insert(lines, "function PageManager.get_selected_page()")
    table.insert(lines, "    if PageManager.current_index > 0 then")
    table.insert(lines, "        return PageManager.pages[PageManager.current_index], PageManager.current_index")
    table.insert(lines, "    end")
    table.insert(lines, "    return nil, 0")
    table.insert(lines, "end")
    table.insert(lines, "")
    
    -- 获取所有图页
    table.insert(lines, "-- 获取所有图页")
    table.insert(lines, "function PageManager.get_pages()")
    table.insert(lines, "    return PageManager.pages")
    table.insert(lines, "end")
    table.insert(lines, "")
    
    -- 选择图页（与 goto_page 相同，用于兼容）
    table.insert(lines, "-- 选择图页（与 goto_page 相同）")
    table.insert(lines, "function PageManager.select_page(index)")
    table.insert(lines, "    return PageManager.goto_page(index)")
    table.insert(lines, "end")
    table.insert(lines, "")
    
    -- 图页切换函数
    table.insert(lines, "-- 切换图页")
    table.insert(lines, "function PageManager.goto_page(index)")
    table.insert(lines, "    if index < 1 or index > #PageManager.pages then")
    table.insert(lines, '        print("[PageManager] 无效的图页索引: " .. tostring(index))')
    table.insert(lines, "        return false")
    table.insert(lines, "    end")
    table.insert(lines, "")
    table.insert(lines, "    -- 删除当前图页")
    table.insert(lines, "    if PageManager.current_page then")
    table.insert(lines, "        PageManager.current_page:delete()")
    table.insert(lines, "        PageManager.current_page = nil")
    table.insert(lines, "    end")
    table.insert(lines, "")
    table.insert(lines, "    -- 创建新图页")
    table.insert(lines, "    local page_info = PageManager.pages[index]")
    table.insert(lines, "    if page_info and page_info.create then")
    table.insert(lines, "        PageManager.current_page = page_info.create(scr)")
    table.insert(lines, "        PageManager.current_index = index")
    table.insert(lines, '        print("[PageManager] 切换到图页 " .. index .. ": " .. page_info.name)')
    table.insert(lines, "        return true")
    table.insert(lines, "    end")
    table.insert(lines, "")
    table.insert(lines, "    return false")
    table.insert(lines, "end")
    table.insert(lines, "")
    
    -- 导出 PageManager 到全局
    table.insert(lines, "-- 导出图页管理器到全局")
    table.insert(lines, "_G.PageManager = PageManager")
    table.insert(lines, "")
    
    -- 创建模拟编辑器接口（供 actions 模块使用）
    table.insert(lines, "-- 创建模拟编辑器接口（供 actions 模块使用）")
    table.insert(lines, "_G.Editor = {")
    table.insert(lines, "    get_canvas_list = function()")
    table.insert(lines, "        return PageManager")
    table.insert(lines, "    end")
    table.insert(lines, "}")
    table.insert(lines, "")
    
    -- 启动代码
    local start_page = project_data.current_page_index or 1
    table.insert(lines, "-- ========== 启动 ==========")
    table.insert(lines, 'print("=== 组态程序启动 ===")')
    table.insert(lines, 'print("图页数量: " .. #PageManager.pages)')
    table.insert(lines, "")
    table.insert(lines, "-- 显示初始图页")
    table.insert(lines, "PageManager.goto_page(" .. start_page .. ")")
    table.insert(lines, "")
    table.insert(lines, 'print("=== 组态程序已就绪 ===")')
    table.insert(lines, "")
    
    return table.concat(lines, "\n"), nil
end

-- 从文件编译
function ProjectCompiler:compile_from_file(json_filepath, output_filepath)
    -- 读取JSON文件
    local file, err = io.open(json_filepath, "r")
    if not file then
        return false, "无法打开文件: " .. (err or "未知错误")
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or #content == 0 then
        return false, "文件为空"
    end
    
    -- 解析JSON
    local ok, project_data = pcall(json.decode, content)
    if not ok then
        return false, "JSON解析失败: " .. tostring(project_data)
    end
    
    -- 编译
    local lua_code, compile_err = self:compile(project_data)
    if not lua_code then
        return false, "编译失败: " .. (compile_err or "未知错误")
    end
    
    -- 写入输出文件
    local out_file, out_err = io.open(output_filepath, "w")
    if not out_file then
        return false, "无法创建输出文件: " .. (out_err or "未知错误")
    end
    
    out_file:write(lua_code)
    out_file:close()
    
    print("[ProjectCompiler] 编译完成: " .. output_filepath)
    
    return true, nil
end

-- 从工程数据编译并保存
function ProjectCompiler:compile_and_save(project_data, output_filepath)
    local lua_code, compile_err = self:compile(project_data)
    if not lua_code then
        return false, "编译失败: " .. (compile_err or "未知错误")
    end
    
    -- 确保输出目录存在
    local dir = output_filepath:match("(.+)[/\\]")
    if dir then
        local cmd = 'if not exist "' .. dir .. '" mkdir "' .. dir .. '"'
        os.execute(cmd)
    end
    
    -- 写入输出文件
    local out_file, out_err = io.open(output_filepath, "w")
    if not out_file then
        return false, "无法创建输出文件: " .. (out_err or "未知错误")
    end
    
    out_file:write(lua_code)
    out_file:close()
    
    print("[ProjectCompiler] 编译完成: " .. output_filepath)
    
    return true, nil
end

return ProjectCompiler
