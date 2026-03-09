-- PropertyArea.lua
-- 右侧属性面板：固定在右侧，不可拖拽和关闭
local lv = require("lvgl")

-- 引入子模块
local PropertyPageEditor = require("editor.PropertyPageEditor")
local PropertyWidgetEditor = require("editor.PropertyWidgetEditor")
local PropertyGlobalEditor = require("editor.PropertyGlobalEditor")
local PropertyDataEditor = require("editor.PropertyDataEditor")
local PropertyEvent = require("editor.PropertyEvent")

local PropertyArea = {}
PropertyArea.__index = PropertyArea

PropertyArea.__widget_meta = {
    id = "property_area",
    name = "属性窗口",
    description = "右侧固定属性面板，包含属性、数据和事件操作",
    schema_version = "1.0",
    version = "1.0",
}

-- 标签页类型常量
local TAB_TYPE = {
    PROPERTY = 1,
    DATA = 2,
    EVENT = 3
}

-- 模块状态
local selectedItems = {}
local selectedPage = nil
local selectedPageIndex = 0
local selectedGlobal = nil
local currentTab = TAB_TYPE.PROPERTY

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
        tab_height = props.tab_height or 36,
        item_height = props.item_height or 32,
        bg_color = props.bg_color or 0x2D2D2D,
        title_bg_color = props.title_bg_color or 0x3D3D3D,
        tab_bg_color = props.tab_bg_color or 0x3D3D3D,
        tab_active_color = props.tab_active_color or 0x4A90E2,
        border_color = props.border_color or 0x555555,
        text_color = props.text_color or 0xFFFFFF,
        text_inactive_color = props.text_inactive_color or 0xAAAAAA,
    }
    
    -- 保存父元素引用
    self._parent = parent
    
    -- 事件监听器
    self._event_listeners = {}
    
    -- 创建主容器
    self:_create_main_container()
    
    -- 创建标题栏
    self:_create_title_bar()
    
    -- 创建标签页切换栏
    self:_create_tab_bar()
    
    -- 创建内容区域
    self:_create_content_area()
    
    -- 初始化显示属性页面
    self:_switch_tab(TAB_TYPE.PROPERTY)
    
    return self
end

-- 创建主容器
function PropertyArea:_create_main_container()
    self.container = lv.obj_create(self._parent)
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
    self.title_label:set_text("工具面板")
    self.title_label:set_style_text_color(self.props.text_color, 0)
    self.title_label:align(lv.ALIGN_LEFT_MID, 10, 0)
end

-- 创建标签页切换栏（三个标签）
function PropertyArea:_create_tab_bar()
    local tab_y = self.props.title_height
    
    self.tab_bar = lv.obj_create(self.container)
    self.tab_bar:set_pos(0, tab_y)
    self.tab_bar:set_size(self.props.width, self.props.tab_height)
    self.tab_bar:set_style_bg_color(self.props.tab_bg_color, 0)
    self.tab_bar:set_style_radius(0, 0)
    self.tab_bar:set_style_border_width(0, 1)
    self.tab_bar:set_style_border_color(self.props.border_color, 0)
    self.tab_bar:set_style_pad_all(0, 0)
    self.tab_bar:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
    self.tab_bar:clear_layout()
    
    -- 创建三个标签按钮，宽度平均分配（使用math.floor确保整数）
    local tab_width = math.floor(self.props.width / 3)
    local remainder = self.props.width - tab_width * 3
    
    -- 属性标签
    self.tab_property = lv.btn_create(self.tab_bar)
    self.tab_property:set_size(tab_width, self.props.tab_height)
    self.tab_property:set_pos(0, 0)
    self.tab_property:set_style_bg_color(self.props.tab_active_color, 0)
    self.tab_property:set_style_radius(0, 0)
    self.tab_property:set_style_border_width(0, 0)
    self.tab_property:set_style_text_color(self.props.text_color, 0)
    
    local tab_property_label = lv.label_create(self.tab_property)
    tab_property_label:set_text("属性")
    tab_property_label:center()
    
    -- 数据标签
    self.tab_data = lv.btn_create(self.tab_bar)
    self.tab_data:set_size(tab_width, self.props.tab_height)
    self.tab_data:set_pos(tab_width, 0)
    self.tab_data:set_style_bg_color(self.props.tab_bg_color, 0)
    self.tab_data:set_style_radius(0, 0)
    self.tab_data:set_style_border_width(0, 0)
    self.tab_data:set_style_text_color(self.props.text_inactive_color, 0)
    
    local tab_data_label = lv.label_create(self.tab_data)
    tab_data_label:set_text("数据")
    tab_data_label:center()
    
    -- 事件标签（最后一个标签可能会稍宽一些，以补偿余数）
    self.tab_event = lv.btn_create(self.tab_bar)
    self.tab_event:set_size(tab_width + remainder, self.props.tab_height)
    self.tab_event:set_pos(tab_width * 2, 0)
    self.tab_event:set_style_bg_color(self.props.tab_bg_color, 0)
    self.tab_event:set_style_radius(0, 0)
    self.tab_event:set_style_border_width(0, 0)
    self.tab_event:set_style_text_color(self.props.text_inactive_color, 0)
    
    local tab_event_label = lv.label_create(self.tab_event)
    tab_event_label:set_text("事件")
    tab_event_label:center()
    
    -- 事件处理
    self.tab_property:add_event_cb(function()
        self:_switch_tab(TAB_TYPE.PROPERTY)
    end, lv.EVENT_CLICKED, nil)
    
    self.tab_data:add_event_cb(function()
        self:_switch_tab(TAB_TYPE.DATA)
    end, lv.EVENT_CLICKED, nil)
    
    self.tab_event:add_event_cb(function()
        self:_switch_tab(TAB_TYPE.EVENT)
    end, lv.EVENT_CLICKED, nil)
end

-- 切换标签页
function PropertyArea:_switch_tab(tab_type)
    if currentTab == tab_type then
        return
    end
    
    currentTab = tab_type
    
    -- 更新所有标签样式
    -- 先全部设置为非活动状态
    self.tab_property:set_style_bg_color(self.props.tab_bg_color, 0)
    self.tab_property:set_style_text_color(self.props.text_inactive_color, 0)
    self.tab_data:set_style_bg_color(self.props.tab_bg_color, 0)
    self.tab_data:set_style_text_color(self.props.text_inactive_color, 0)
    self.tab_event:set_style_bg_color(self.props.tab_bg_color, 0)
    self.tab_event:set_style_text_color(self.props.text_inactive_color, 0)
    
    -- 根据选中的标签设置活动样式
    if tab_type == TAB_TYPE.PROPERTY then
        self.tab_property:set_style_bg_color(self.props.tab_active_color, 0)
        self.tab_property:set_style_text_color(self.props.text_color, 0)
        self.title_label:set_text("属性")
        self:_refresh_current_selection()
    elseif tab_type == TAB_TYPE.DATA then
        self.tab_data:set_style_bg_color(self.props.tab_active_color, 0)
        self.tab_data:set_style_text_color(self.props.text_color, 0)
        self.title_label:set_text("数据")
        self:_show_data_page()
    else -- EVENT
        self.tab_event:set_style_bg_color(self.props.tab_active_color, 0)
        self.tab_event:set_style_text_color(self.props.text_color, 0)
        self.title_label:set_text("事件")
        self:_show_event_page()
    end
    
    self:_emit("tab_changed", tab_type)
end

-- 刷新当前选中的内容（属性页面）
function PropertyArea:_refresh_current_selection()
    self:_clear_content_area()
    
    if #selectedItems > 0 then
       PropertyWidgetEditor.display_properties(self, selectedItems[1])
    elseif selectedPage then
        PropertyPageEditor.display_properties(self, selectedPage, selectedPageIndex)
    elseif selectedGlobal then
        PropertyGlobalEditor.display_properties(self, selectedGlobal)
    else
        local placeholder = lv.label_create(self.content)
        placeholder:set_text("请选择一个控件或图页\n查看其属性")
        placeholder:set_style_text_color(self.props.text_inactive_color, 0)
        placeholder:set_long_mode(lv.LABEL_LONG_WRAP)
        placeholder:set_width(self.props.width - 20)
        placeholder:align(lv.ALIGN_TOP_MID, 0, 20)
    end
end

-- 显示数据页面
function PropertyArea:_show_data_page()
    self:_clear_content_area()
    
    if PropertyDataEditor and PropertyDataEditor.display then
        PropertyDataEditor.display(self)
    else
        local placeholder = lv.label_create(self.content)
        placeholder:set_text("数据操作页面\n\n此功能正在开发中...")
        placeholder:set_style_text_color(self.props.text_color, 0)
        placeholder:set_long_mode(lv.LABEL_LONG_WRAP)
        placeholder:set_width(self.props.width - 20)
        placeholder:align(lv.ALIGN_TOP_MID, 0, 20)
    end
end

-- 显示事件页面
function PropertyArea:_show_event_page()
    self:_clear_content_area()
    
    if #selectedItems > 0 then
        -- 如果有选中的控件，显示事件编辑器
        if PropertyEvent and PropertyEvent.display then
            local meta = selectedItems[1].meta or {}
            PropertyEvent.create_events_table(self, 10, selectedItems[1], meta)
        else
            local placeholder = lv.label_create(self.content)
            placeholder:set_text("事件绑定页面\n\n正在开发中...")
            placeholder:set_style_text_color(self.props.text_color, 0)
            placeholder:set_long_mode(lv.LABEL_LONG_WRAP)
            placeholder:set_width(self.props.width - 20)
            placeholder:align(lv.ALIGN_TOP_MID, 0, 50)
        end
    else
        -- 如果没有选中控件，显示提示
        local placeholder = lv.label_create(self.content)
        placeholder:set_text("请先选择一个控件\n\n然后在事件页面配置该控件的事件绑定")
        placeholder:set_style_text_color(self.props.text_inactive_color, 0)
        placeholder:set_long_mode(lv.LABEL_LONG_WRAP)
        placeholder:set_width(self.props.width - 20)
        placeholder:align(lv.ALIGN_TOP_MID, 0, 50)
    end
end

-- 创建内容区域
function PropertyArea:_create_content_area()
    local content_y = self.props.title_height + self.props.tab_height
    local content_height = self.props.height - self.props.title_height - self.props.tab_height
    
    self.content = lv.obj_create(self.container)
    self.content:set_pos(0, content_y)
    self.content:set_size(self.props.width, content_height)
    self.content:set_style_bg_opa(0, 0)
    self.content:set_style_border_width(0, 0)
    self.content:set_style_text_color(self.props.text_color, 0)
    self.content:set_style_pad_all(5, 0)
    self.content:set_style_pad_right(10, 0)
    self.content:add_flag(lv.OBJ_FLAG_SCROLLABLE)
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
    if not self.content then
        return
    end
    
    local child = self.content:get_child(0)
    while child do
        child:delete()
        child = self.content:get_child(0)
    end
end

-- 设置高度
function PropertyArea:set_height(height)
    if height and height > 0 then
        self.props.height = height
        self.container:set_height(height)
        
        local content_y = self.props.title_height + self.props.tab_height
        local content_height = height - self.props.title_height - self.props.tab_height
        self.content:set_pos(0, content_y)
        self.content:set_height(content_height)
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

-- 获取当前标签页
function PropertyArea:get_current_tab()
    return currentTab
end

-- 切换到属性标签页
function PropertyArea:switch_to_property_tab()
    self:_switch_tab(TAB_TYPE.PROPERTY)
end

-- 切换到数据标签页
function PropertyArea:switch_to_data_tab()
    self:_switch_tab(TAB_TYPE.DATA)
end

-- 切换到事件标签页
function PropertyArea:switch_to_event_tab()
    self:_switch_tab(TAB_TYPE.EVENT)
end

-- 选中控件时调用
function PropertyArea:onSelectedItem(item)
    selectedPage = nil
    selectedPageIndex = 0
    selectedGlobal = nil
    
    if item == nil then
        print("[属性窗口] 取消选中控件")
        selectedItems = {}
        if currentTab == TAB_TYPE.PROPERTY then
            self:_refresh_current_selection()
        elseif currentTab == TAB_TYPE.DATA then
            self:_show_data_page()
        else
            self:_show_event_page()
        end
        return
    end
    
    if type(item) == "table" and item.instance then
        selectedItems = { item }
        if currentTab == TAB_TYPE.PROPERTY then
            self:_refresh_current_selection()
        elseif currentTab == TAB_TYPE.DATA then
            self:_show_data_page()
        else
            self:_show_event_page()
        end
    elseif type(item) == "table" then
        selectedItems = item
        if #item > 0 then
            print("[属性窗口] 多个控件已选中，共 " .. #item .. " 个")
            if currentTab == TAB_TYPE.PROPERTY then
                self:_refresh_current_selection()
            elseif currentTab == TAB_TYPE.DATA then
                self:_show_data_page()
            else
                self:_show_event_page()
            end
        end
    end
end

-- 选中图页时调用
function PropertyArea:onSelectedPage(page_data, page_index, page_meta)
    selectedItems = {}
    selectedGlobal = nil
    
    if page_data == nil then
        print("[属性窗口] 取消选中图页")
        selectedPage = nil
        selectedPageIndex = 0
        if currentTab == TAB_TYPE.PROPERTY then
            self:_refresh_current_selection()
        elseif currentTab == TAB_TYPE.DATA then
            self:_show_data_page()
        else
            self:_show_event_page()
        end
        return
    end
    
    selectedPage = page_data
    selectedPageIndex = page_index
    
    print("[属性窗口] 选中图页: " .. page_data.name)
    if currentTab == TAB_TYPE.PROPERTY then
        self:_refresh_current_selection()
    elseif currentTab == TAB_TYPE.DATA then
        self:_show_data_page()
    else
        self:_show_event_page()
    end
end

-- 选中全局组件时调用
-- 显示事件页面
function PropertyArea:_show_event_page()
    self:_clear_content_area()
    
    if #selectedItems > 0 then
        -- 如果有选中的控件，显示事件编辑器
        if PropertyEvent and PropertyEvent.display then
            PropertyEvent.display(self)  -- 调用 display 方法，传入 property_area 实例
        else
            local placeholder = lv.label_create(self.content)
            placeholder:set_text("事件绑定页面\n\n正在开发中...")
            placeholder:set_style_text_color(self.props.text_color, 0)
            placeholder:set_long_mode(lv.LABEL_LONG_WRAP)
            placeholder:set_width(self.props.width - 20)
            placeholder:align(lv.ALIGN_TOP_MID, 0, 50)
        end
    else
        -- 如果没有选中控件，显示提示
        local placeholder = lv.label_create(self.content)
        placeholder:set_text("请先选择一个控件\n\n然后在事件页面配置该控件的事件绑定")
        placeholder:set_style_text_color(self.props.text_inactive_color, 0)
        placeholder:set_long_mode(lv.LABEL_LONG_WRAP)
        placeholder:set_width(self.props.width - 20)
        placeholder:align(lv.ALIGN_TOP_MID, 0, 50)
    end
end
-- 获取当前选中的全局组件
function PropertyArea:get_selected_global()
    return selectedGlobal
end

-- 获取当前选中的控件
function PropertyArea:get_selected_items()
    return selectedItems
end

-- 获取当前选中的图页
function PropertyArea:get_selected_page()
    return selectedPage, selectedPageIndex
end

return PropertyArea