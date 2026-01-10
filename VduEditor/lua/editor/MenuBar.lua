-- MenuBar.lua
-- Ribbon 风格菜单栏组件
local lv = require("lvgl")

local MenuBar = {}
MenuBar.__index = MenuBar

MenuBar.__widget_meta = {
    id = "menu_bar",
    name = "Menu Bar (Ribbon)",
    description = "Ribbon 风格编辑器菜单栏",
    schema_version = "1.0",
    version = "2.0",
}

-- 获取应用程序目录
local APP_DIR = _G.APP_DIR or ""

-- LVGL 文件系统前缀（与 lv_conf.h 中的 LV_FS_WIN32_LETTER 对应）
local FS_PREFIX = "D:"

-- 辅助函数：构建完整路径（用于 LVGL 图片加载）
local function build_path(relative_path)
    if APP_DIR and APP_DIR ~= "" then
        -- 将相对路径转换为绝对路径，并添加 LVGL 文件系统前缀
        local path = APP_DIR .. relative_path:gsub("/", "\\")
        return FS_PREFIX .. path
    end
    return FS_PREFIX .. relative_path
end

-- 颜色定义
MenuBar.COLORS = {
    ribbon_bg = 0x2D2D2D,           -- Ribbon 背景色
    tab_bg = 0x252525,              -- 标签栏背景色
    tab_active = 0x3D3D3D,          -- 活动标签背景
    tab_hover = 0x383838,           -- 悬停标签背景
    panel_bg = 0x333333,            -- 面板背景色
    panel_border = 0x454545,        -- 面板边框色
    btn_bg = 0x3D3D3D,              -- 按钮背景
    btn_hover = 0x4D4D4D,           -- 按钮悬停
    btn_pressed = 0x505050,         -- 按钮按下
    text_primary = 0xFFFFFF,        -- 主要文字颜色
    text_secondary = 0xAAAAAA,      -- 次要文字颜色
    separator = 0x454545,           -- 分隔线颜色
    accent = 0x0078D4,              -- 强调色（蓝色）
}

-- 图标目录（相对于应用程序目录）
MenuBar.ICON_DIR = "icons/ribbon/"

-- Ribbon 标签页定义
MenuBar.RIBBON_TABS = {
    {
        id = "home",
        label = "主页",
        groups = {
            {
                id = "file",
                label = "文件",
                buttons = {
                    { id = "new", label = "新建", icon = "new.png", size = "large", shortcut = "Ctrl+N" },
                    { id = "open", label = "打开", icon = "open.png", size = "large", shortcut = "Ctrl+O" },
                    { id = "save", label = "保存", icon = "save.png", size = "large", shortcut = "Ctrl+S" },
                    { id = "save_as", label = "另存为", icon = "save_as.png", size = "small" },
                }
            },
            {
                id = "clipboard",
                label = "剪贴板",
                buttons = {
                    { id = "paste", label = "粘贴", icon = "paste.png", size = "large", shortcut = "Ctrl+V" },
                    { id = "cut", label = "剪切", icon = "cut.png", size = "small", shortcut = "Ctrl+X" },
                    { id = "copy", label = "复制", icon = "copy.png", size = "small", shortcut = "Ctrl+C" },
                    { id = "delete", label = "删除", icon = "delete.png", size = "small", shortcut = "Del" },
                }
            },
            {
                id = "history",
                label = "历史",
                buttons = {
                    { id = "undo", label = "撤销", icon = "undo.png", size = "large", shortcut = "Ctrl+Z" },
                    { id = "redo", label = "重做", icon = "redo.png", size = "large", shortcut = "Ctrl+Y" },
                }
            },
        }
    },
    {
        id = "align",
        label = "对齐",
        groups = {
            {
                id = "horizontal",
                label = "水平对齐",
                buttons = {
                    { id = "align_left", label = "左对齐", icon = "align_left.png", size = "medium" },
                    { id = "align_center", label = "居中", icon = "align_center.png", size = "medium" },
                    { id = "align_right", label = "右对齐", icon = "align_right.png", size = "medium" },
                }
            },
            {
                id = "vertical",
                label = "垂直对齐",
                buttons = {
                    { id = "align_top", label = "顶部", icon = "align_top.png", size = "medium" },
                    { id = "align_middle", label = "居中", icon = "align_middle.png", size = "medium" },
                    { id = "align_bottom", label = "底部", icon = "align_bottom.png", size = "medium" },
                }
            },
            {
                id = "distribute",
                label = "分布",
                buttons = {
                    { id = "distribute_h", label = "水平分布", icon = "distribute_h.png", size = "large" },
                    { id = "distribute_v", label = "垂直分布", icon = "distribute_v.png", size = "large" },
                }
            },
        }
    },
    {
        id = "view",
        label = "视图",
        groups = {
            {
                id = "zoom",
                label = "缩放",
                buttons = {
                    { id = "zoom_in", label = "放大", icon = "zoom_in.png", size = "medium", shortcut = "Ctrl++" },
                    { id = "zoom_out", label = "缩小", icon = "zoom_out.png", size = "medium", shortcut = "Ctrl+-" },
                    { id = "zoom_reset", label = "重置", icon = "zoom_reset.png", size = "medium", shortcut = "Ctrl+0" },
                }
            },
            {
                id = "display",
                label = "显示",
                buttons = {
                    { id = "show_grid", label = "网格", icon = "grid.png", size = "medium", toggle = true },
                    { id = "snap_to_grid", label = "对齐网格", icon = "snap.png", size = "medium", toggle = true },
                }
            },
        }
    },
}

-- 尺寸定义
MenuBar.SIZES = {
    tab_height = 28,                -- 标签栏高度
    ribbon_height = 100,            -- Ribbon 内容区高度
    total_height = 128,             -- 总高度
    large_btn_width = 54,           -- 大按钮宽度
    large_btn_height = 66,          -- 大按钮高度
    medium_btn_width = 82,          -- 中按钮宽度（增加到82以容纳"对齐网格"等文字）
    medium_btn_height = 24,         -- 中按钮高度（减少到24）
    small_btn_width = 80,           -- 小按钮宽度（增加到80）
    small_btn_height = 22,          -- 小按钮高度
    group_padding = 8,              -- 组内边距
    group_spacing = 12,             -- 组间距
    icon_size_large = 32,           -- 大图标尺寸
    icon_size_medium = 16,          -- 中图标尺寸（减少到16）
    icon_size_small = 16,           -- 小图标尺寸
}

-- 图标缓存
local icon_cache = {}

-- 构造函数
function MenuBar.new(parent, props)
    props = props or {}
    local self = setmetatable({}, MenuBar)
    
    -- 保存父元素引用
    self._parent = parent
    
    -- 属性
    self.props = {
        x = props.x or 0,
        y = props.y or 0,
        width = props.width or 1024,
        height = MenuBar.SIZES.total_height,
    }
    
    -- 状态管理（用于切换按钮）
    self._states = {
        show_grid = true,
        snap_to_grid = true,
        show_toolbox = true,
        show_properties = false,
        show_canvas_list = true,
    }
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 当前活动标签
    self._active_tab_id = "home"
    
    -- UI 元素引用
    self._tab_buttons = {}
    self._ribbon_panels = {}
    self._toggle_buttons = {}
    
    -- 记录上次屏幕宽度
    self._last_screen_width = self.props.width
    
    -- 创建主容器
    self:_create_main_container()
    
    -- 创建标签栏
    self:_create_tab_bar()
    
    -- 创建 Ribbon 内容区
    self:_create_ribbon_content()
    
    -- 显示默认标签页
    self:_switch_tab("home")
    
    -- 设置窗口大小变化检测
    self:_setup_resize_timer()
    
    return self
end

-- 加载图标图片
function MenuBar:_load_icon(icon_name, size)
    if not icon_name then return nil end
	
	-- 检查缓存
	local cache_key = icon_name .. "_" .. tostring(size)
	if icon_cache[cache_key] then
		return icon_cache[cache_key]
	end
	
	-- 构建图标完整路径
	local icon_path = build_path(MenuBar.ICON_DIR .. icon_name)
	
	-- 尝试加载图标
	local ok, result = pcall(function()
		return lv.image_create(nil)  -- 创建临时图像检测
	end)
	
	-- 返回图标路径（LVGL 会自动加载）
	icon_cache[cache_key] = icon_path
	return icon_path
end

-- 创建图标控件
function MenuBar:_create_icon(parent, icon_name, size)
    if not icon_name then return nil end
    
    local icon_path = build_path(MenuBar.ICON_DIR .. icon_name)
    
    -- 创建图像控件
    local ok, img = pcall(function()
        local i = lv.image_create(parent)
        if i then
            i:set_src(icon_path)
            -- 设置图片大小并使用 STRETCH 模式自动缩放图片以适应指定尺寸
            if size then
                i:set_size(size, size)
                -- 使用 IMAGE_ALIGN_STRETCH 让图片拉伸填充到指定大小
                -- 如果常量存在则使用，否则使用备选方案
                if lv.IMAGE_ALIGN_STRETCH then
                    i:set_inner_align(lv.IMAGE_ALIGN_STRETCH)
                elseif lv.IMAGE_ALIGN_CONTAIN then
                    -- CONTAIN 保持宽高比，图片会完整显示在区域内
                    i:set_inner_align(lv.IMAGE_ALIGN_CONTAIN)
                end
            end
        end
        return i
    end)
    
    if ok and img then
        return img
    else
        -- 如果图片加载失败，创建一个占位标签
        print("[MenuBar] 图标加载失败: " .. icon_path)
        local placeholder = lv.label_create(parent)
        placeholder:set_text("?")
        placeholder:set_style_text_color(MenuBar.COLORS.text_secondary, 0)
        return placeholder
    end
end

-- 创建主容器
function MenuBar:_create_main_container()
    self.container = lv.obj_create(self._parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(MenuBar.COLORS.ribbon_bg, 0)
    self.container:set_style_radius(0, 0)
    self.container:set_style_border_width(0, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:clear_layout()
end

-- 创建标签栏
function MenuBar:_create_tab_bar()
    self._tab_bar = lv.obj_create(self.container)
    self._tab_bar:set_pos(0, 0)
    self._tab_bar:set_size(self.props.width, MenuBar.SIZES.tab_height)
    self._tab_bar:set_style_bg_color(MenuBar.COLORS.tab_bg, 0)
    self._tab_bar:set_style_radius(0, 0)
    self._tab_bar:set_style_border_width(0, 0)
    self._tab_bar:set_style_pad_left(10, 0)
    self._tab_bar:set_style_pad_top(2, 0)
    self._tab_bar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self._tab_bar:clear_layout()
    
    -- 创建底部分隔线
    local separator = lv.obj_create(self.container)
    separator:set_pos(0, MenuBar.SIZES.tab_height - 1)
    separator:set_size(self.props.width, 1)
    separator:set_style_bg_color(MenuBar.COLORS.panel_border, 0)
    separator:set_style_radius(0, 0)
    separator:set_style_border_width(0, 0)
    separator:remove_flag(lv.OBJ_FLAG_CLICKABLE)
    separator:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self._tab_separator = separator
    
    -- 创建标签按钮
    local x_offset = 0
    for _, tab in ipairs(MenuBar.RIBBON_TABS) do
        local tab_btn = self:_create_tab_button(tab, x_offset)
        self._tab_buttons[tab.id] = tab_btn
        x_offset = x_offset + tab_btn.width + 2
    end
end

-- 创建单个标签按钮
function MenuBar:_create_tab_button(tab, x_offset)
    local btn_width = 60
    local btn_height = MenuBar.SIZES.tab_height - 4
    
    local btn = lv.obj_create(self._tab_bar)
    btn:set_pos(x_offset, 0)
    btn:set_size(btn_width, btn_height)
    btn:set_style_bg_color(MenuBar.COLORS.tab_bg, 0)
    btn:set_style_bg_opa(0, 0)
    btn:set_style_radius(4, 0)
    btn:set_style_radius(0, lv.PART_MAIN + lv.STATE_DEFAULT)
    btn:set_style_border_width(0, 0)
    btn:set_style_pad_all(0, 0)
    btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    btn:clear_layout()
    
    local lbl = lv.label_create(btn)
    lbl:set_text(tab.label)
    lbl:set_style_text_color(MenuBar.COLORS.text_primary, 0)
    lbl:center()
    
    -- 点击事件
    local this = self
    local tab_id = tab.id
    btn:add_event_cb(function(e)
        this:_switch_tab(tab_id)
    end, lv.EVENT_CLICKED, nil)
    
    return { btn = btn, label = lbl, width = btn_width, tab_id = tab.id }
end

-- 创建 Ribbon 内容区
function MenuBar:_create_ribbon_content()
    self._ribbon_area = lv.obj_create(self.container)
    self._ribbon_area:set_pos(0, MenuBar.SIZES.tab_height)
    self._ribbon_area:set_size(self.props.width, MenuBar.SIZES.ribbon_height)
    self._ribbon_area:set_style_bg_color(MenuBar.COLORS.ribbon_bg, 0)
    self._ribbon_area:set_style_radius(0, 0)
    self._ribbon_area:set_style_border_width(0, 0)
    self._ribbon_area:set_style_pad_all(0, 0)
    self._ribbon_area:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self._ribbon_area:clear_layout()
    
    -- 为每个标签创建内容面板
    for _, tab in ipairs(MenuBar.RIBBON_TABS) do
        local panel = self:_create_tab_panel(tab)
        self._ribbon_panels[tab.id] = panel
        -- 初始隐藏
        panel:add_flag(lv.OBJ_FLAG_HIDDEN)
    end
end

-- 创建标签页面板
function MenuBar:_create_tab_panel(tab)
    local panel = lv.obj_create(self._ribbon_area)
    panel:set_pos(0, 0)
    panel:set_size(self.props.width, MenuBar.SIZES.ribbon_height)
    panel:set_style_bg_opa(0, 0)
    panel:set_style_border_width(0, 0)
    panel:set_style_pad_left(10, 0)
    panel:set_style_pad_top(6, 0)
    panel:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    panel:clear_layout()
    
    -- 创建分组
    local x_offset = 0
    for _, group in ipairs(tab.groups) do
        local group_width = self:_create_group(panel, group, x_offset)
        x_offset = x_offset + group_width + MenuBar.SIZES.group_spacing
        
        -- 创建分隔线（除了最后一个组）
        if group ~= tab.groups[#tab.groups] then
            local sep = lv.obj_create(panel)
            sep:set_pos(x_offset - 6, 4)
            sep:set_size(1, MenuBar.SIZES.ribbon_height - 20)
            sep:set_style_bg_color(MenuBar.COLORS.separator, 0)
            sep:set_style_radius(0, 0)
            sep:set_style_border_width(0, 0)
            sep:remove_flag(lv.OBJ_FLAG_CLICKABLE)
            sep:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
        end
    end
    
    return panel
end

-- 创建分组
function MenuBar:_create_group(parent, group, x_offset)
    local group_container = lv.obj_create(parent)
    group_container:set_pos(x_offset, 0)
    group_container:set_style_bg_opa(0, 0)
    group_container:set_style_border_width(0, 0)
    group_container:set_style_pad_all(0, 0)
    group_container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    group_container:clear_layout()
    
    -- 创建按钮
    local btn_x = 0
    local btn_y = 0
    local small_count = 0
    local max_width = 0
    local row_height = 0
    
    -- 计算中/小按钮的行高（包含间距）
    local medium_row_height = MenuBar.SIZES.medium_btn_height + 4
    local small_row_height = MenuBar.SIZES.small_btn_height + 2
    
    for _, btn_def in ipairs(group.buttons) do
        local btn_info
        
        if btn_def.size == "large" then
            -- 大按钮
            btn_info = self:_create_large_button(group_container, btn_def, btn_x, 0)
            btn_x = btn_x + MenuBar.SIZES.large_btn_width + 4
            row_height = MenuBar.SIZES.large_btn_height
        elseif btn_def.size == "medium" then
            -- 中按钮（3行布局）
            local row = small_count % 3
            btn_info = self:_create_medium_button(group_container, btn_def, btn_x, row * medium_row_height)
            small_count = small_count + 1
            if small_count % 3 == 0 then
                btn_x = btn_x + MenuBar.SIZES.medium_btn_width + 4
            end
            row_height = math.max(row_height, 3 * medium_row_height)
        else
            -- 小按钮（3行布局）
            local row = small_count % 3
            btn_info = self:_create_small_button(group_container, btn_def, btn_x, row * small_row_height)
            small_count = small_count + 1
            if small_count % 3 == 0 then
                btn_x = btn_x + MenuBar.SIZES.small_btn_width + 4
            end
            row_height = math.max(row_height, 3 * small_row_height)
        end
        
        max_width = math.max(max_width, btn_x)
    end
    
    -- 处理未满3个的小/中按钮列
    if small_count > 0 and small_count % 3 ~= 0 then
        -- 根据最后使用的按钮类型确定宽度
        max_width = btn_x + MenuBar.SIZES.medium_btn_width + 4
    end
    
    -- 设置组容器大小（高度需要包含组标签的空间）
    local group_width = max_width + MenuBar.SIZES.group_padding
    local group_height = MenuBar.SIZES.ribbon_height - 6  -- 减少顶部padding的影响
    group_container:set_size(group_width, group_height)
    
    -- 创建组标签（底部）
    local group_label = lv.label_create(group_container)
    group_label:set_text(group.label)
    group_label:set_style_text_color(MenuBar.COLORS.text_secondary, 0)
    group_label:align(lv.ALIGN_BOTTOM_MID, 0, -2)
    
    return group_width
end

-- 创建大按钮
function MenuBar:_create_large_button(parent, btn_def, x, y)
    local btn = lv.obj_create(parent)
    btn:set_pos(x, y)
    btn:set_size(MenuBar.SIZES.large_btn_width, MenuBar.SIZES.large_btn_height)
    btn:set_style_bg_color(MenuBar.COLORS.btn_bg, 0)
    btn:set_style_bg_opa(0, 0)
    btn:set_style_radius(4, 0)
    btn:set_style_border_width(0, 0)
    btn:set_style_pad_all(2, 0)
    btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    btn:clear_layout()
    
    -- 图标（图片）
    local icon_obj = nil
    if btn_def.icon then
        icon_obj = self:_create_icon(btn, btn_def.icon, MenuBar.SIZES.icon_size_large)
        if icon_obj then
            icon_obj:align(lv.ALIGN_TOP_MID, 0, 4)
        end
    end
    
    -- 标签
    local text_lbl = lv.label_create(btn)
    text_lbl:set_text(btn_def.label)
    text_lbl:set_style_text_color(MenuBar.COLORS.text_primary, 0)
    text_lbl:align(lv.ALIGN_BOTTOM_MID, 0, -4)
    
    -- 切换按钮状态指示
    if btn_def.toggle and self._states[btn_def.id] then
        btn:set_style_bg_opa(255, 0)
        btn:set_style_bg_color(MenuBar.COLORS.accent, 0)
    end
    
    -- 绑定事件
    self:_bind_button_event(btn, btn_def)
    
    -- 保存切换按钮引用
    if btn_def.toggle then
        self._toggle_buttons[btn_def.id] = { btn = btn, def = btn_def }
    end
    
    return { btn = btn, icon = icon_obj, label = text_lbl }
end

-- 创建中按钮
function MenuBar:_create_medium_button(parent, btn_def, x, y)
    local btn = lv.obj_create(parent)
    btn:set_pos(x, y)
    btn:set_size(MenuBar.SIZES.medium_btn_width, MenuBar.SIZES.medium_btn_height)
    btn:set_style_bg_color(MenuBar.COLORS.btn_bg, 0)
    btn:set_style_bg_opa(0, 0)
    btn:set_style_radius(3, 0)
    btn:set_style_border_width(0, 0)
    btn:set_style_pad_all(2, 0)
    btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    btn:clear_layout()
    
    -- 图标（图片，左侧）
    local icon_obj = nil
    if btn_def.icon then
        icon_obj = self:_create_icon(btn, btn_def.icon, MenuBar.SIZES.icon_size_medium)
        if icon_obj then
            icon_obj:align(lv.ALIGN_LEFT_MID, 2, 0)
        end
    end
    
    -- 标签（右侧）
    local text_lbl = lv.label_create(btn)
    text_lbl:set_text(btn_def.label)
    text_lbl:set_style_text_color(MenuBar.COLORS.text_primary, 0)
    text_lbl:align(lv.ALIGN_LEFT_MID, MenuBar.SIZES.icon_size_medium + 6, 0)
    
    -- 切换按钮状态指示
    if btn_def.toggle and self._states[btn_def.id] then
        btn:set_style_bg_opa(255, 0)
        btn:set_style_bg_color(MenuBar.COLORS.accent, 0)
    end
    
    -- 绑定事件
    self:_bind_button_event(btn, btn_def)
    
    -- 保存切换按钮引用
    if btn_def.toggle then
        self._toggle_buttons[btn_def.id] = { btn = btn, def = btn_def }
    end
    
    return { btn = btn, icon = icon_obj, label = text_lbl }
end

-- 创建小按钮
function MenuBar:_create_small_button(parent, btn_def, x, y)
    local btn = lv.obj_create(parent)
    btn:set_pos(x, y)
    btn:set_size(MenuBar.SIZES.small_btn_width, MenuBar.SIZES.small_btn_height)
    btn:set_style_bg_color(MenuBar.COLORS.btn_bg, 0)
    btn:set_style_bg_opa(0, 0)
    btn:set_style_radius(2, 0)
    btn:set_style_border_width(0, 0)
    btn:set_style_pad_all(2, 0)
    btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    btn:clear_layout()
    
    -- 图标（图片，左侧）
    local icon_obj = nil
    if btn_def.icon then
        icon_obj = self:_create_icon(btn, btn_def.icon, MenuBar.SIZES.icon_size_small)
        if icon_obj then
            icon_obj:align(lv.ALIGN_LEFT_MID, 2, 0)
        end
    end
    
    -- 标签
    local text_lbl = lv.label_create(btn)
    text_lbl:set_text(btn_def.label)
    text_lbl:set_style_text_color(MenuBar.COLORS.text_primary, 0)
    text_lbl:align(lv.ALIGN_LEFT_MID, MenuBar.SIZES.icon_size_small + 4, 0)
    
    -- 切换按钮状态指示
    if btn_def.toggle and self._states[btn_def.id] then
        btn:set_style_bg_opa(255, 0)
        btn:set_style_bg_color(MenuBar.COLORS.accent, 0)
    end
    
    -- 绑定事件
    self:_bind_button_event(btn, btn_def)
    
    -- 保存切换按钮引用
    if btn_def.toggle then
        self._toggle_buttons[btn_def.id] = { btn = btn, def = btn_def }
    end
    
    return { btn = btn, icon = icon_obj, label = text_lbl }
end

-- 绑定按钮事件
function MenuBar:_bind_button_event(btn, btn_def)
    local this = self
    local btn_id = btn_def.id
    local is_toggle = btn_def.toggle
    
    btn:add_event_cb(function(e)
        print("[Ribbon] 点击按钮: " .. btn_id)
        
        if is_toggle then
            -- 切换状态
            this:toggle_state(btn_id)
            this:_update_toggle_button(btn_id)
        end
        
        -- 触发菜单动作事件
        this:_emit("menu_action", nil, btn_id)
    end, lv.EVENT_CLICKED, nil)
end

-- 更新切换按钮视觉状态
function MenuBar:_update_toggle_button(btn_id)
    local btn_info = self._toggle_buttons[btn_id]
    if btn_info then
        local state = self._states[btn_id]
        if state then
            btn_info.btn:set_style_bg_opa(255, 0)
            btn_info.btn:set_style_bg_color(MenuBar.COLORS.accent, 0)
        else
            btn_info.btn:set_style_bg_opa(0, 0)
        end
    end
end

-- 切换标签页
function MenuBar:_switch_tab(tab_id)
    -- 更新标签按钮状态
    for id, tab_btn in pairs(self._tab_buttons) do
        if id == tab_id then
            tab_btn.btn:set_style_bg_opa(255, 0)
            tab_btn.btn:set_style_bg_color(MenuBar.COLORS.tab_active, 0)
        else
            tab_btn.btn:set_style_bg_opa(0, 0)
        end
    end
    
    -- 显示/隐藏面板
    for id, panel in pairs(self._ribbon_panels) do
        if id == tab_id then
            panel:remove_flag(lv.OBJ_FLAG_HIDDEN)
        else
            panel:add_flag(lv.OBJ_FLAG_HIDDEN)
        end
    end
    
    self._active_tab_id = tab_id
    print("[Ribbon] 切换到标签: " .. tab_id)
end

-- 设置窗口大小变化定时器
function MenuBar:_setup_resize_timer()
    local this = self
    self._resize_timer = lv.timer_create(function(timer)
        this:_check_screen_resize()
    end, 200)
end

-- 检查屏幕大小变化
function MenuBar:_check_screen_resize()
    local scr = lv.scr_act()
    if scr and scr.get_width then
        local ok, new_width = pcall(function() return scr:get_width() end)
        if ok and type(new_width) == "number" and new_width > 0 then
            if new_width ~= self._last_screen_width then
                self._last_screen_width = new_width
                self:set_width(new_width)
            end
        end
    end
end

-- 设置宽度
function MenuBar:set_width(width)
    if width and width > 0 then
        self.props.width = width
        self.container:set_width(width)
        self._tab_bar:set_width(width)
        self._ribbon_area:set_width(width)
        
        -- 更新分隔线宽度
        if self._tab_separator then
            self._tab_separator:set_width(width)
        end
        
        for _, panel in pairs(self._ribbon_panels) do
            panel:set_width(width)
        end
    end
end

-- 事件订阅
function MenuBar:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function MenuBar:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[Ribbon] 事件回调错误:", err)
            end
        end
    end
end

-- 设置状态
function MenuBar:set_state(state_key, value)
    if self._states[state_key] ~= nil then
        self._states[state_key] = value
        self:_update_toggle_button(state_key)
    end
end

-- 获取状态
function MenuBar:get_state(state_key)
    return self._states[state_key]
end

-- 切换状态
function MenuBar:toggle_state(state_key)
    if self._states[state_key] ~= nil then
        self._states[state_key] = not self._states[state_key]
        return self._states[state_key]
    end
    return nil
end

-- 关闭所有下拉菜单（保持兼容性）
function MenuBar:close_all_dropdowns()
    -- Ribbon 风格没有下拉菜单，保留此方法以兼容旧代码
end

-- 获取容器
function MenuBar:get_container()
    return self.container
end

-- 获取高度
function MenuBar:get_height()
    return self.props.height
end

-- 销毁
function MenuBar:destroy()
    if self._resize_timer then
        lv.timer_delete(self._resize_timer)
        self._resize_timer = nil
    end
    if self.container then
        self.container:delete()
        self.container = nil
    end
end

return MenuBar
