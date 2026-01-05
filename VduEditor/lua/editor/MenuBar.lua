-- MenuBar.lua
-- 菜单栏组件：包含文件、编辑、对齐、视图菜单
local lv = require("lvgl")

local MenuBar = {}
MenuBar.__index = MenuBar

MenuBar.__widget_meta = {
    id = "menu_bar",
    name = "Menu Bar",
    description = "编辑器菜单栏",
    schema_version = "1.0",
    version = "1.0",
}

-- 菜单项定义
MenuBar.MENU_ITEMS = {
    file = {
        label = "文件",
        items = {
            { id = "new", label = "新建", shortcut = "Ctrl+N" },
            { id = "open", label = "打开", shortcut = "Ctrl+O" },
            { id = "save", label = "保存", shortcut = "Ctrl+S" },
            { id = "save_as", label = "另存为", shortcut = "" },
            { id = "separator" },
            { id = "export", label = "导出", shortcut = "" },
            { id = "separator" },
            { id = "exit", label = "退出", shortcut = "Alt+F4" },
        }
    },
    edit = {
        label = "编辑",
        items = {
            { id = "undo", label = "撤销", shortcut = "Ctrl+Z" },
            { id = "redo", label = "重做", shortcut = "Ctrl+Y" },
            { id = "separator" },
            { id = "cut", label = "剪切", shortcut = "Ctrl+X" },
            { id = "copy", label = "复制", shortcut = "Ctrl+C" },
            { id = "paste", label = "粘贴", shortcut = "Ctrl+V" },
            { id = "delete", label = "删除", shortcut = "Del" },
            { id = "separator" },
            { id = "select_all", label = "全选", shortcut = "Ctrl+A" },
        }
    },
    align = {
        label = "对齐",
        items = {
            { id = "align_left", label = "左对齐", shortcut = "" },
            { id = "align_center", label = "水平居中", shortcut = "" },
            { id = "align_right", label = "右对齐", shortcut = "" },
            { id = "separator" },
            { id = "align_top", label = "顶部对齐", shortcut = "" },
            { id = "align_middle", label = "垂直居中", shortcut = "" },
            { id = "align_bottom", label = "底部对齐", shortcut = "" },
            { id = "separator" },
            { id = "distribute_h", label = "水平分布", shortcut = "" },
            { id = "distribute_v", label = "垂直分布", shortcut = "" },
        }
    },
    view = {
        label = "视图",
        items = {
            { id = "zoom_in", label = "放大", shortcut = "Ctrl++" },
            { id = "zoom_out", label = "缩小", shortcut = "Ctrl+-" },
            { id = "zoom_reset", label = "重置缩放", shortcut = "Ctrl+0" },
            { id = "separator" },
            { id = "show_grid", label = "显示网格", shortcut = "" },
            { id = "snap_to_grid", label = "对齐到网格", shortcut = "" },
            { id = "separator" },
            { id = "show_toolbox", label = "显示工具箱", shortcut = "" },
            { id = "show_properties", label = "属性面板", shortcut = "" },
            { id = "show_canvas_list", label = "图页列表", shortcut = "" },
        }
    },
}

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
        height = props.height or 36,
        bg_color = props.bg_color or 0x2D2D2D,
        text_color = props.text_color or 0xFFFFFF,
        hover_color = props.hover_color or 0x3D3D3D,
    }
    
    -- 动态菜单项标签（用于切换显示）
    self._dynamic_labels = {
        show_grid = { on = "隐藏网格", off = "显示网格" },
        snap_to_grid = { on = "取消对齐到网格", off = "对齐到网格" },
        show_toolbox = { on = "隐藏工具箱", off = "显示工具箱" },
        show_properties = { on = "隐藏属性窗口", off = "属性窗口" },
        show_canvas_list = { on = "隐藏图页列表", off = "图页列表" },
    }
    
    -- 动态状态
    self._states = {
        show_grid = true,         -- 默认显示网格
        snap_to_grid = true,      -- 默认对齐到网格
        show_toolbox = true,      -- 默认显示工具箱
        show_properties = false,  -- 默认属性窗口隐藏
        show_canvas_list = true,  -- 默认显示图页列表
    }
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 当前打开的下拉菜单
    self._open_dropdown = nil
    self._open_menu_key = nil
    
    -- 创建菜单栏容器
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_radius(0, 0)
    self.container:set_style_border_width(0, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:set_style_text_color(self.props.text_color, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    -- 清除默认布局
    self.container:clear_layout()
    
    -- 菜单按钮存储
    self._menu_buttons = {}
    
    -- 创建菜单项
    local x_offset = 10
    local menu_order = { "file", "edit", "align", "view" }
    
    for _, menu_key in ipairs(menu_order) do
        local menu_def = MenuBar.MENU_ITEMS[menu_key]
        local btn_info = self:_create_menu_button(menu_key, menu_def.label, x_offset)
        self._menu_buttons[menu_key] = btn_info
        x_offset = x_offset + btn_info.width + 8
    end
    
    return self
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
                print("[MenuBar] 事件回调错误:", err)
            end
        end
    end
end

-- 关闭所有下拉菜单
function MenuBar:close_all_dropdowns()
    if self._open_dropdown then
        self._open_dropdown:delete()
        self._open_dropdown = nil
        self._open_menu_key = nil
    end
end

-- 创建菜单按钮
function MenuBar:_create_menu_button(menu_key, label, x_offset)
    local btn_width = 65
    local btn_height = self.props.height - 6
    
    local btn = lv.obj_create(self.container)
    btn:set_pos(x_offset, 3)
    btn:set_size(btn_width, btn_height)
    btn:set_style_bg_color(self.props.bg_color, 0)
    btn:set_style_radius(4, 0)
    btn:set_style_border_width(0, 0)
    btn:set_style_pad_all(0, 0)
    btn:set_style_text_color(self.props.text_color, 0)
    btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    btn:clear_layout()
    
    local lbl = lv.label_create(btn)
    lbl:set_text(label)
    lbl:set_style_text_color(self.props.text_color, 0)
    lbl:center()
    
    -- 点击事件：显示下拉菜单
    local this = self
    local key = menu_key
    btn:add_event_cb(function(e)
        print("[MenuBar] 点击菜单: " .. key)
        this:_toggle_dropdown(key, btn)
    end, lv.EVENT_CLICKED, nil)
    
    return { btn = btn, label = lbl, width = btn_width, x = x_offset }
end

-- 获取菜单项的显示标签（支持动态标签）
function MenuBar:_get_item_label(item_id, default_label)
    local dynamic = self._dynamic_labels[item_id]
    if dynamic then
        local state = self._states[item_id]
        return state and dynamic.on or dynamic.off
    end
    return default_label
end

-- 切换下拉菜单显示
function MenuBar:_toggle_dropdown(menu_key, btn)
    print("[MenuBar] _toggle_dropdown called: " .. menu_key)
    
    -- 如果点击的是当前已打开的菜单，则关闭
    if self._open_dropdown and self._open_menu_key == menu_key then
        print("[MenuBar] 关闭当前菜单")
        self:close_all_dropdowns()
        return
    end
    
    -- 关闭之前打开的菜单
    self:close_all_dropdowns()
    
    -- 创建下拉菜单
    local scr = lv.scr_act()
    local menu_def = MenuBar.MENU_ITEMS[menu_key]
    
    if not menu_def then
        print("[MenuBar] 菜单定义不存在: " .. menu_key)
        return
    end
    
    -- 计算位置（在按钮下方）
    local btn_x = btn:get_x()
    local dropdown_x = self.props.x + btn_x
    local dropdown_y = self.props.y + self.props.height
    
    print("[MenuBar] 创建下拉菜单 @ (" .. dropdown_x .. ", " .. dropdown_y .. ")")
    
    -- 创建下拉面板（在屏幕上创建，确保在最上层）
    local dropdown = lv.obj_create(scr)
    dropdown:set_pos(dropdown_x, dropdown_y)
    dropdown:set_style_bg_color(0x3D3D3D, 0)
    dropdown:set_style_radius(4, 0)
    dropdown:set_style_border_width(1, 0)
    dropdown:set_style_border_color(0x555555, 0)
    dropdown:set_style_pad_all(0, 0)
    dropdown:set_style_text_color(0xFFFFFF, 0)
    dropdown:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    dropdown:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    -- 清除默认布局
    dropdown:clear_layout()
    
    self._open_dropdown = dropdown
    self._open_menu_key = menu_key
    
    -- 计算尺寸
    local item_height = 32
    local separator_height = 10
    local max_width = 220
    local total_height = 10  -- 初始 padding
    
    for _, item in ipairs(menu_def.items) do
        if item.id == "separator" then
            total_height = total_height + separator_height
        else
            total_height = total_height + item_height
        end
    end
    
    dropdown:set_size(max_width, total_height)
    print("[MenuBar] 下拉菜单尺寸: " .. max_width .. "x" .. total_height)
    
    -- 创建菜单项
    local y_offset = 5
    local this = self
    
    for _, item in ipairs(menu_def.items) do
        if item.id == "separator" then
            -- 分隔线
            local sep = lv.obj_create(dropdown)
            sep:set_pos(5, y_offset + 3)
            sep:set_size(max_width - 10, 2)
            sep:set_style_bg_color(0x555555, 0)
            sep:set_style_radius(0, 0)
            sep:set_style_border_width(0, 0)
            sep:remove_flag(lv.OBJ_FLAG_CLICKABLE)
            sep:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            y_offset = y_offset + separator_height
        else
            -- 菜单项（使用 obj）
            local item_btn = lv.obj_create(dropdown)
            item_btn:set_pos(2, y_offset)
            item_btn:set_size(max_width - 4, item_height)
            item_btn:set_style_bg_color(0x3D3D3D, 0)
            item_btn:set_style_radius(2, 0)
            item_btn:set_style_border_width(0, 0)
            item_btn:set_style_pad_all(0, 0)
            item_btn:set_style_text_color(0xFFFFFF, 0)
            item_btn:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
            item_btn:clear_layout()
            
            -- 获取动态标签
            local display_label = self:_get_item_label(item.id, item.label)
            
            -- 标签
            local item_lbl = lv.label_create(item_btn)
            item_lbl:set_text(display_label)
            item_lbl:set_style_text_color(0xFFFFFF, 0)
            item_lbl:align(lv.ALIGN_LEFT_MID, 10, 0)
            
            -- 快捷键（如果有）
            if item.shortcut and #item.shortcut > 0 then
                local shortcut_lbl = lv.label_create(item_btn)
                shortcut_lbl:set_text(item.shortcut)
                shortcut_lbl:align(lv.ALIGN_RIGHT_MID, -10, 0)
                shortcut_lbl:set_style_text_color(0xAAAAAA, 0)
            end
            
            -- 点击事件
            local item_id = item.id
            local key = menu_key
            item_btn:add_event_cb(function(e)
                print("[MenuBar] 点击菜单项: " .. key .. " -> " .. item_id)
                this:close_all_dropdowns()
                this:_emit("menu_action", key, item_id)
            end, lv.EVENT_CLICKED, nil)
            
            y_offset = y_offset + item_height
        end
    end
    
    print("[MenuBar] 下拉菜单创建完成，项目数: " .. #menu_def.items)
end

-- 设置状态（用于更新动态菜单项）
function MenuBar:set_state(state_key, value)
    if self._states[state_key] ~= nil then
        self._states[state_key] = value
        print("[MenuBar] 状态更新: " .. state_key .. " = " .. tostring(value))
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
        print("[MenuBar] 状态切换: " .. state_key .. " = " .. tostring(self._states[state_key]))
        return self._states[state_key]
    end
    return nil
end

-- 获取容器
function MenuBar:get_container()
    return self.container
end

-- 获取高度
function MenuBar:get_height()
    return self.props.height
end

return MenuBar
