-- FileDialog.lua
-- 文件对话框组件（基于 LVGL 实现）

local lv = require("lvgl")

local FileDialog = {}
FileDialog.__index = FileDialog

-- 默认配置
local DEFAULT_WIDTH = 500
local DEFAULT_PATH = "projects"

-- 构造函数
function FileDialog.new(parent, props)
    props = props or {}
    local self = setmetatable({}, FileDialog)
    
    self._parent = parent or lv.scr_act()
    self._mode = props.mode or "save"  -- "save" 或 "open"
    self._title = props.title or (self._mode == "save" and "保存工程" or "打开工程")
    self._filter = props.filter or ".json"
    self._default_filename = props.default_filename or "project.json"
    self._callback = props.callback or function() end
    self._current_path = DEFAULT_PATH
    
    -- 根据模式设置对话框高度
    -- save: 路径 + 文件名 + 提示 + 按钮 = 250
    -- open: 标题栏40 + 路径区42 + 文件列表区182 + 文件名区42 + 按钮区56 = 362
    local dialog_height = self._mode == "open" and 380 or 250
    self._dialog_height = dialog_height
    
    -- 创建遮罩层
    self._overlay = lv.obj_create(self._parent)
    self._overlay:set_size(1024, 768)
    self._overlay:set_pos(0, 0)
    self._overlay:set_style_bg_color(0x000000, 0)
    self._overlay:set_style_bg_opa(128, 0)
    self._overlay:set_style_border_width(0, 0)
    self._overlay:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    -- 创建对话框容器
    self._dialog = lv.obj_create(self._overlay)
    self._dialog:set_size(DEFAULT_WIDTH, dialog_height)
    self._dialog:center()
    self._dialog:set_style_bg_color(0x2D2D2D, 0)
    self._dialog:set_style_radius(8, 0)
    self._dialog:set_style_border_width(1, 0)
    self._dialog:set_style_border_color(0x555555, 0)
    self._dialog:set_style_shadow_width(20, 0)
    self._dialog:set_style_shadow_color(0x000000, 0)
    self._dialog:set_style_shadow_opa(150, 0)
    self._dialog:set_style_text_color(0xFFFFFF, 0)
    self._dialog:set_style_pad_all(0, 0)
    self._dialog:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self._dialog:clear_layout()
    
    -- 创建标题栏
    self:_create_title_bar()
    
    -- 创建路径选择区
    self:_create_path_area()
    
    -- 创建文件列表区（用于打开模式）
    if self._mode == "open" then
        self:_create_file_list()
        self:_refresh_file_list()
    end
    
    -- 创建文件名输入区
    self:_create_input_area()
    
    -- 创建按钮区
    self:_create_button_area()
    
    return self
end

-- 创建标题栏
function FileDialog:_create_title_bar()
    local title_bar = lv.obj_create(self._dialog)
    title_bar:set_pos(0, 0)
    title_bar:set_size(DEFAULT_WIDTH, 40)
    title_bar:set_style_bg_color(0x3D3D3D, 0)
    title_bar:set_style_radius(8, 0)
    title_bar:set_style_border_width(0, 0)
    title_bar:set_style_pad_all(0, 0)
    title_bar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    title_bar:clear_layout()
    
    -- 标题文本
    local title_label = lv.label_create(title_bar)
    title_label:set_text(self._title)
    title_label:set_style_text_color(0xFFFFFF, 0)
    title_label:align(lv.ALIGN_LEFT_MID, 15, 0)
    
    -- 关闭按钮
    local close_btn = lv.obj_create(title_bar)
    close_btn:set_size(28, 28)
    close_btn:align(lv.ALIGN_RIGHT_MID, -6, 0)
    close_btn:set_style_bg_color(0x555555, 0)
    close_btn:set_style_radius(4, 0)
    close_btn:set_style_border_width(0, 0)
    close_btn:set_style_pad_all(0, 0)
    close_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local close_label = lv.label_create(close_btn)
    close_label:set_text("X")
    close_label:set_style_text_color(0xFFFFFF, 0)
    close_label:center()
    
    local this = self
    close_btn:add_event_cb(function(e)
        this:close()
    end, lv.EVENT_CLICKED, nil)
end

-- 创建路径选择区
function FileDialog:_create_path_area()
    local content_y = 50
    
    -- 路径标签
    local path_label = lv.label_create(self._dialog)
    path_label:set_text("路径:")
    path_label:set_style_text_color(0xCCCCCC, 0)
    path_label:set_pos(20, content_y + 6)
    
    -- 路径显示容器
    local path_container = lv.obj_create(self._dialog)
    path_container:set_pos(70, content_y)
    path_container:set_size(DEFAULT_WIDTH - 90, 32)
    path_container:set_style_bg_color(0x404040, 0)
    path_container:set_style_radius(4, 0)
    path_container:set_style_border_width(1, 0)
    path_container:set_style_border_color(0x555555, 0)
    path_container:set_style_pad_all(0, 0)
    path_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    path_container:clear_layout()
    
    -- 路径显示标签
    self._path_label = lv.label_create(path_container)
    self._path_label:set_text(self._current_path .. "/")
    self._path_label:set_style_text_color(0xFFFFFF, 0)
    self._path_label:align(lv.ALIGN_LEFT_MID, 10, 0)
    
    -- 浏览按钮
    local browse_btn = lv.obj_create(path_container)
    browse_btn:set_size(40, 26)
    browse_btn:align(lv.ALIGN_RIGHT_MID, -3, 0)
    browse_btn:set_style_bg_color(0x007ACC, 0)
    browse_btn:set_style_radius(4, 0)
    browse_btn:set_style_border_width(0, 0)
    browse_btn:set_style_pad_all(0, 0)
    browse_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local browse_label = lv.label_create(browse_btn)
    browse_label:set_text("...")
    browse_label:set_style_text_color(0xFFFFFF, 0)
    browse_label:center()
    
    local this = self
    browse_btn:add_event_cb(function(e)
        this:_show_path_selector()
    end, lv.EVENT_CLICKED, nil)
end

-- 创建文件列表（打开模式）
function FileDialog:_create_file_list()
    local list_y = 92
    local list_height = 160
    
    -- 文件列表标签
    local list_label = lv.label_create(self._dialog)
    list_label:set_text("文件列表:")
    list_label:set_style_text_color(0xCCCCCC, 0)
    list_label:set_pos(20, list_y)
    
    -- 文件列表容器
    self._file_list_container = lv.obj_create(self._dialog)
    self._file_list_container:set_pos(20, list_y + 22)
    self._file_list_container:set_size(DEFAULT_WIDTH - 40, list_height)
    self._file_list_container:set_style_bg_color(0x353535, 0)
    self._file_list_container:set_style_radius(4, 0)
    self._file_list_container:set_style_border_width(1, 0)
    self._file_list_container:set_style_border_color(0x555555, 0)
    self._file_list_container:set_style_pad_all(5, 0)
    self._file_list_container:add_flag(lv.OBJ_FLAG_SCROLLABLE)
    self._file_list_container:clear_layout()
    
    -- 文件项列表
    self._file_items = {}
end

-- 刷新文件列表
function FileDialog:_refresh_file_list()
    if not self._file_list_container then return end
    
    -- 清除现有项
    for _, item in ipairs(self._file_items or {}) do
        if item.container then
            item.container:delete()
        end
    end
    self._file_items = {}
    
    -- 扫描目录
    local files = self:_scan_directory(self._current_path)
    
    local item_height = 30
    local item_y = 0
    local this = self
    
    for i, file in ipairs(files) do
        local item = lv.obj_create(self._file_list_container)
        item:set_pos(0, item_y)
        item:set_size(DEFAULT_WIDTH - 55, item_height)
        item:set_style_bg_color(0x454545, 0)
        item:set_style_radius(4, 0)
        item:set_style_border_width(0, 0)
        item:set_style_pad_left(10, 0)
        item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        item:clear_layout()
        
        local label = lv.label_create(item)
        label:set_text(file.name)
        label:set_style_text_color(0xFFFFFF, 0)
        label:align(lv.ALIGN_LEFT_MID, 0, 0)
        
        -- 点击选择文件
        local filename = file.name
        item:add_event_cb(function(e)
            this:_select_file(filename)
        end, lv.EVENT_CLICKED, nil)
        
        table.insert(self._file_items, {
            container = item,
            filename = file.name
        })
        
        item_y = item_y + item_height + 4
    end
    
    -- 如果没有文件，显示提示
    if #files == 0 then
        local empty_label = lv.label_create(self._file_list_container)
        empty_label:set_text("目录下没有 .json 文件")
        empty_label:set_style_text_color(0x888888, 0)
        empty_label:center()
    end
end

-- 扫描目录获取文件列表
function FileDialog:_scan_directory(path)
    local files = {}
    
    -- 确保目录存在
    os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '"')
    
    -- 使用 dir 命令扫描文件
    local handle = io.popen('dir /b "' .. path .. '\\*.json" 2>nul')
    if handle then
        for line in handle:lines() do
            if line and #line > 0 then
                table.insert(files, {
                    name = line,
                    is_dir = false
                })
            end
        end
        handle:close()
    end
    
    return files
end

-- 选择文件
function FileDialog:_select_file(filename)
    if self._textarea then
        self._textarea:set_text(filename)
    end
end

-- 创建文件名输入区
function FileDialog:_create_input_area()
    -- 根据模式计算 Y 位置
    -- open模式: 92 + 22 + 160 + 10 = 284
    -- save模式: 50 + 42 = 92
    local content_y = self._mode == "open" and 284 or 92
    
    -- 文件名标签
    local filename_label = lv.label_create(self._dialog)
    filename_label:set_text("文件名:")
    filename_label:set_style_text_color(0xCCCCCC, 0)
    filename_label:set_pos(20, content_y + 6)
    
    -- 文件名输入框
    self._textarea = lv.textarea_create(self._dialog)
    self._textarea:set_pos(85, content_y)
    self._textarea:set_size(DEFAULT_WIDTH - 105, 32)
    self._textarea:set_style_bg_color(0x404040, 0)
    self._textarea:set_style_radius(4, 0)
    self._textarea:set_style_border_width(1, 0)
    self._textarea:set_style_border_color(0x555555, 0)
    self._textarea:set_style_text_color(0xFFFFFF, 0)
    self._textarea:set_one_line(true)
    self._textarea:set_text(self._default_filename)
    self._textarea:set_placeholder_text("输入文件名...")
    self._textarea:set_style_pad_top(6, 0)
    self._textarea:set_style_pad_left(8, 0)
    
    -- 只在保存模式显示提示
    if self._mode == "save" then
        content_y = content_y + 40
        local hint_label = lv.label_create(self._dialog)
        hint_label:set_text("文件保存为 JSON 格式")
        hint_label:set_style_text_color(0x888888, 0)
        hint_label:set_pos(20, content_y)
    end
end

-- 创建按钮区
function FileDialog:_create_button_area()
    -- 根据模式计算按钮 Y 位置
    -- open模式: 文件名输入区在 284，高度32，间距10，按钮在 326
    -- save模式: 文件名输入区在 92，高度32，提示在132，按钮在 dialog_height - 55
    local btn_y
    if self._mode == "open" then
        btn_y = 284 + 32 + 10  -- 文件名输入区 + 高度 + 间距 = 326
    else
        btn_y = self._dialog_height - 55
    end
    
    -- 取消按钮
    local cancel_btn = lv.obj_create(self._dialog)
    cancel_btn:set_size(90, 36)
    cancel_btn:set_pos(DEFAULT_WIDTH - 200, btn_y)
    cancel_btn:set_style_bg_color(0x555555, 0)
    cancel_btn:set_style_radius(6, 0)
    cancel_btn:set_style_border_width(0, 0)
    cancel_btn:set_style_pad_all(0, 0)
    cancel_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local cancel_label = lv.label_create(cancel_btn)
    cancel_label:set_text("取消")
    cancel_label:set_style_text_color(0xFFFFFF, 0)
    cancel_label:center()
    
    local this = self
    cancel_btn:add_event_cb(function(e)
        this:close()
    end, lv.EVENT_CLICKED, nil)
    
    -- 确认按钮
    local confirm_btn = lv.obj_create(self._dialog)
    confirm_btn:set_size(90, 36)
    confirm_btn:set_pos(DEFAULT_WIDTH - 100, btn_y)
    confirm_btn:set_style_bg_color(0x007ACC, 0)
    confirm_btn:set_style_radius(6, 0)
    confirm_btn:set_style_border_width(0, 0)
    confirm_btn:set_style_pad_all(0, 0)
    confirm_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    
    local confirm_label = lv.label_create(confirm_btn)
    confirm_label:set_text(self._mode == "save" and "保存" or "打开")
    confirm_label:set_style_text_color(0xFFFFFF, 0)
    confirm_label:center()
    
    confirm_btn:add_event_cb(function(e)
        this:_on_confirm()
    end, lv.EVENT_CLICKED, nil)
end

-- 显示路径选择器
function FileDialog:_show_path_selector()
    -- 创建简单的路径选择弹窗
    local popup = lv.obj_create(self._dialog)
    popup:set_size(280, 180)
    popup:center()
    popup:set_style_bg_color(0x3D3D3D, 0)
    popup:set_style_radius(8, 0)
    popup:set_style_border_width(1, 0)
    popup:set_style_border_color(0x666666, 0)
    popup:set_style_shadow_width(10, 0)
    popup:set_style_shadow_color(0x000000, 0)
    popup:set_style_shadow_opa(150, 0)
    popup:set_style_pad_all(15, 0)
    popup:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    popup:clear_layout()
    
    -- 标题
    local title = lv.label_create(popup)
    title:set_text("选择路径")
    title:set_style_text_color(0xFFFFFF, 0)
    title:set_pos(0, 0)
    
    -- 预定义路径列表
    local paths = {
        { name = "projects (默认)", path = "projects" },
        { name = "当前目录 (.)", path = "." },
        { name = "output", path = "output" },
    }
    
    local this = self
    local item_y = 30
    
    for _, p in ipairs(paths) do
        local item = lv.obj_create(popup)
        item:set_pos(0, item_y)
        item:set_size(250, 32)
        item:set_style_bg_color(0x505050, 0)
        item:set_style_radius(4, 0)
        item:set_style_border_width(0, 0)
        item:set_style_pad_left(10, 0)
        item:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        item:clear_layout()
        
        local label = lv.label_create(item)
        label:set_text(p.name)
        label:set_style_text_color(0xFFFFFF, 0)
        label:align(lv.ALIGN_LEFT_MID, 0, 0)
        
        local path_value = p.path
        item:add_event_cb(function(e)
            this._current_path = path_value
            this._path_label:set_text(path_value .. "/")
            if this._mode == "open" and this._file_list_container then
                this:_refresh_file_list()
            end
            popup:delete()
        end, lv.EVENT_CLICKED, nil)
        
        item_y = item_y + 38
    end
end

-- 确认操作
function FileDialog:_on_confirm()
    local filename = self._textarea:get_text()
    if filename and #filename > 0 then
        -- 确保文件名有 .json 扩展名
        if not filename:match("%.json$") then
            filename = filename .. ".json"
        end
        
        local full_path = self._current_path .. "/" .. filename
        
        self._callback(full_path, filename)
        self:close()
    end
end

-- 关闭对话框
function FileDialog:close()
    if self._overlay then
        self._overlay:delete()
        self._overlay = nil
        self._dialog = nil
        self._textarea = nil
        self._path_label = nil
        self._file_list_container = nil
        self._file_items = {}
    end
end

-- 获取文件名
function FileDialog:get_filename()
    if self._textarea then
        return self._textarea:get_text()
    end
    return ""
end

-- 设置文件名
function FileDialog:set_filename(filename)
    if self._textarea then
        self._textarea:set_text(filename or "")
    end
end

return FileDialog
