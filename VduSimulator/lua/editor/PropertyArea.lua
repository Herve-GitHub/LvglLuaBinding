-- PropertyArea.lua
-- 右侧属性面板：固定在右侧，不可拖拽和关闭
local lv = require("lvgl")

-- 引入子模块
local PropertyPageEditor = require("editor.PropertyPageEditor")
local PropertyWidgetEditor = require("editor.PropertyWidgetEditor")
local PropertyGlobalEditor = require("editor.PropertyGlobalEditor")

local PropertyArea = {}
PropertyArea.__index = PropertyArea

PropertyArea.__widget_meta = {
    id = "property_area",
    name = "属性窗口",
    description = "右侧固定属性面板",
    schema_version = "1.0",
    version = "1.0",
}

-- 模块状态
local selectedItems = {}
local selectedPage = nil
local selectedPageIndex = 0
local selectedGlobal = nil  -- 当前选中的全局组件

-- 构造函数
function PropertyArea.new(parent, props)
    props = props or {}
    local self = setmetatable({}, PropertyArea)
    
    -- 属性
    self.props = {
        x = props.x or 800,
        y = props.y or 0,
        width = props.width or 280,
        height = props.height or 600,
        title_height = props.title_height or 32,
        item_height = props.item_height or 32,
        bg_color = props.bg_color or 0x2D2D2D,
        title_bg_color = props.title_bg_color or 0x3D3D3D,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
    }
    
    -- 保存父元素引用
    self._parent = parent
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 创建主容器（固定面板样式）
    self.container = lv.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_color(self.props.bg_color, 0)
    self.container:set_style_radius(0, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(self.props.border_color, 0)
    self.container:set_style_text_color(self.props.text_color, 0)
    self.container:set_style_pad_all(0, 0)
    self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.container:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.container:clear_layout()
    
    -- 创建标题栏
    self:_create_title_bar()
    
    -- 创建内容区域
    self:_create_content_area()
    
    return self
end

-- 创建标题栏
function PropertyArea:_create_title_bar()
    self.title_bar = lv.obj_create(self.container)
    self.title_bar:set_pos(0, 0)
    self.title_bar:set_size(self.props.width, self.props.title_height)
    self.title_bar:set_style_bg_color(self.props.title_bg_color, 0)
    self.title_bar:set_style_radius(0, 0)
    self.title_bar:set_style_border_width(0, 0)
    self.title_bar:set_style_text_color(self.props.text_color, 0)
    self.title_bar:set_style_pad_all(0, 0)
    self.title_bar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.title_bar:clear_layout()
    
    -- 标题文本
    self.title_label = lv.label_create(self.title_bar)
    self.title_label:set_text("属性")
    self.title_label:set_style_text_color(self.props.text_color, 0)
    self.title_label:align(lv.ALIGN_LEFT_MID, 10, 0)
end

-- 创建内容区域
function PropertyArea:_create_content_area()
    local content_height = self.props.height - self.props.title_height
    
    self.content = lv.obj_create(self.container)
    self.content:set_pos(0, self.props.title_height)
    self.content:set_size(self.props.width, content_height)
    self.content:set_style_bg_opa(0, 0)
    self.content:set_style_border_width(0, 0)
    self.content:set_style_text_color(self.props.text_color, 0)
    self.content:set_style_pad_all(5, 0)
    self.content:set_style_pad_right(10, 0)
    -- 禁用滚动
    self.content:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.content:remove_flag(lv.OBJ_FLAG_GESTURE_BUBBLE)
    self.content:clear_layout()
end

-- 事件订阅
function PropertyArea:on(event_name, callback)
    if not self._event_listeners[event_name] then
        self._event_listeners[event_name] = {}
    end
    table.insert(self._event_listeners[event_name], callback)
end

-- 触发事件
function PropertyArea:_emit(event_name, ...)
    local listeners = self._event_listeners[event_name]
    if listeners then
        for _, cb in ipairs(listeners) do
            local ok, err = pcall(cb, self, ...)
            if not ok then
                print("[属性窗口] 事件回调错误:", err)
            end
        end
    end
end

-- 清空内容区域
function PropertyArea:_clear_content_area()
    local child_count = self.content:get_child_count()
    for i = child_count - 1, 0, -1 do
        local child = self.content:get_child(i)
        if child then
            child:delete()
        end
    end
end

-- 设置高度
function PropertyArea:set_height(height)
    if height and height > 0 then
        self.props.height = height
        self.container:set_height(height)
        self.content:set_height(height - self.props.title_height)
    end
end

-- 设置位置
function PropertyArea:set_pos(x, y)
    self.props.x = x
    self.props.y = y
    self.container:set_pos(x, y)
end

-- 获取位置
function PropertyArea:get_pos()
    return self.props.x, self.props.y
end

-- 获取容器
function PropertyArea:get_container()
    return self.container
end

-- 获取宽度
function PropertyArea:get_width()
    return self.props.width
end

-- 是否可见
function PropertyArea:is_visible()
    return true
end

-- 选中控件时调用
function PropertyArea:onSelectedItem(item)
    -- 清除图页选中状态
    selectedPage = nil
    selectedPageIndex = 0
    -- 清除全局组件选中状态
    selectedGlobal = nil
    
    if item == nil then
        print("[属性窗口] 取消选中控件")
        selectedItems = {}
        self:_clear_content_area()
        return
    end
    
    if type(item) == "table" and item.instance then
        selectedItems = { item }
        PropertyWidgetEditor.display_properties(self, item)
    elseif type(item) == "table" then
        selectedItems = item
        if #item > 0 then
            print("[属性窗口] 多个控件已选中，共 " .. #item .. " 个，显示第一个")
            PropertyWidgetEditor.display_properties(self, item[1])
        end
    end
end

-- 选中图页时调用
function PropertyArea:onSelectedPage(page_data, page_index, page_meta)
    -- 清除控件选中状态
    selectedItems = {}
    -- 清除全局组件选中状态
    selectedGlobal = nil
    
    if page_data == nil then
        print("[属性窗口] 取消选中图页")
        selectedPage = nil
        selectedPageIndex = 0
        self:_clear_content_area()
        return
    end
    
    selectedPage = page_data
    selectedPageIndex = page_index
    
    print("[属性窗口] 选中图页: " .. page_data.name)
    PropertyPageEditor.display_properties(self, page_data, page_index, page_meta)
end

-- 选中全局组件时调用（如状态栏）
function PropertyArea:onSelectedGlobal(global_entry)
    -- 清除控件选中状态
    selectedItems = {}
    -- 清除图页选中状态
    selectedPage = nil
    selectedPageIndex = 0
    
    if global_entry == nil then
        print("[属性窗口] 取消选中全局组件")
        selectedGlobal = nil
        self:_clear_content_area()
        return
    end
    
    selectedGlobal = global_entry
    
    local name = "未知"
    if global_entry.module and global_entry.module.__widget_meta then
        name = global_entry.module.__widget_meta.name or global_entry.module.__widget_meta.id
    end
    print("[属性窗口] 选中全局组件: " .. name)
    PropertyGlobalEditor.display_properties(self, global_entry)
end

-- 获取当前选中的全局组件
function PropertyArea:get_selected_global()
    return selectedGlobal
end

return PropertyArea