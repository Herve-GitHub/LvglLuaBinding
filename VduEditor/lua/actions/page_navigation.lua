-- page_navigation.lua
-- 图页跳转动作函数模块
-- 此模块定义了可用于按钮等控件的图页跳转函数
-- 用于编译后的运行时环境

local PageNavigation = {}

-- 模块元数据
PageNavigation.__action_meta = {
    id = "page_navigation",
    name = "图页跳转",
    description = "提供图页导航相关的动作函数",
    version = "1.0",
}

-- 可用的动作列表（供属性编辑器读取）
PageNavigation.available_actions = {
    {
        id = "goto_page",
        name = "跳转到指定图页",
        description = "跳转到指定索引的图页",
        params = {
            { name = "page_index", type = "number", label = "图页索引", default = 1 },
        },
    },
    {
        id = "goto_page_by_name",
        name = "按名称跳转图页",
        description = "跳转到指定名称的图页",
        params = {
            { name = "page_name", type = "string", label = "图页名称", default = "" },
        },
    },
    {
        id = "goto_next_page",
        name = "下一页",
        description = "跳转到下一个图页",
        params = {},
    },
    {
        id = "goto_prev_page",
        name = "上一页",
        description = "跳转到上一个图页",
        params = {},
    },
    {
        id = "goto_first_page",
        name = "第一页",
        description = "跳转到第一个图页",
        params = {},
    },
    {
        id = "goto_last_page",
        name = "最后一页",
        description = "跳转到最后一个图页",
        params = {},
    },
}

-- 获取 PageManager（运行时由编译器生成）
local function get_page_manager()
    if _G.PageManager then
        return _G.PageManager
    end
    return nil
end

-- 跳转到指定索引的图页
-- @param page_index: 图页索引（从1开始）
function PageNavigation.goto_page(page_index)
    local pm = get_page_manager()
    if not pm then
        print("[PageNavigation] 错误: 无法获取 PageManager")
        return false
    end
    
    local page_count = pm.get_page_count and pm.get_page_count() or #pm.pages
    if page_index < 1 or page_index > page_count then
        print("[PageNavigation] 错误: 无效的图页索引 " .. tostring(page_index) .. "，有效范围: 1-" .. page_count)
        return false
    end
    
    if pm.goto_page then
        pm.goto_page(page_index)
    elseif pm.select_page then
        pm.select_page(page_index)
    end
    print("[PageNavigation] 跳转到图页 " .. page_index)
    return true
end

-- 按名称跳转到图页
-- @param page_name: 图页名称
function PageNavigation.goto_page_by_name(page_name)
    local pm = get_page_manager()
    if not pm then
        print("[PageNavigation] 错误: 无法获取 PageManager")
        return false
    end
    
    local pages = pm.pages or {}
    for i, page in ipairs(pages) do
        if page.name == page_name then
            if pm.goto_page then
                pm.goto_page(i)
            elseif pm.select_page then
                pm.select_page(i)
            end
            print("[PageNavigation] 跳转到图页 '" .. page_name .. "' (索引: " .. i .. ")")
            return true
        end
    end
    
    print("[PageNavigation] 错误: 找不到名为 '" .. page_name .. "' 的图页")
    return false
end

-- 跳转到下一页
function PageNavigation.goto_next_page()
    local pm = get_page_manager()
    if not pm then
        print("[PageNavigation] 错误: 无法获取 PageManager")
        return false
    end
    
    local current_index = pm.current_index or 0
    local page_count = pm.get_page_count and pm.get_page_count() or #pm.pages
    
    if current_index < page_count then
        local next_index = current_index + 1
        if pm.goto_page then
            pm.goto_page(next_index)
        elseif pm.select_page then
            pm.select_page(next_index)
        end
        print("[PageNavigation] 跳转到下一页: " .. next_index)
        return true
    else
        print("[PageNavigation] 已经是最后一页")
        return false
    end
end

-- 跳转到上一页
function PageNavigation.goto_prev_page()
    local pm = get_page_manager()
    if not pm then
        print("[PageNavigation] 错误: 无法获取 PageManager")
        return false
    end
    
    local current_index = pm.current_index or 0
    
    if current_index > 1 then
        local prev_index = current_index - 1
        if pm.goto_page then
            pm.goto_page(prev_index)
        elseif pm.select_page then
            pm.select_page(prev_index)
        end
        print("[PageNavigation] 跳转到上一页: " .. prev_index)
        return true
    else
        print("[PageNavigation] 已经是第一页")
        return false
    end
end

-- 跳转到第一页
function PageNavigation.goto_first_page()
    local pm = get_page_manager()
    if not pm then
        print("[PageNavigation] 错误: 无法获取 PageManager")
        return false
    end
    
    if pm.goto_page then
        pm.goto_page(1)
    elseif pm.select_page then
        pm.select_page(1)
    end
    print("[PageNavigation] 跳转到第一页")
    return true
end

-- 跳转到最后一页
function PageNavigation.goto_last_page()
    local pm = get_page_manager()
    if not pm then
        print("[PageNavigation] 错误: 无法获取 PageManager")
        return false
    end
    
    local page_count = pm.get_page_count and pm.get_page_count() or #pm.pages
    if pm.goto_page then
        pm.goto_page(page_count)
    elseif pm.select_page then
        pm.select_page(page_count)
    end
    print("[PageNavigation] 跳转到最后一页: " .. page_count)
    return true
end

-- 获取当前页面索引
function PageNavigation.get_current_page_index()
    local pm = get_page_manager()
    if not pm then
        return 0
    end
    return pm.current_index or 0
end

-- 获取总页数
function PageNavigation.get_page_count()
    local pm = get_page_manager()
    if not pm then
        return 0
    end
    return pm.get_page_count and pm.get_page_count() or #pm.pages
end

-- 创建动作回调函数（用于绑定到控件事件）
-- @param action_id: 动作ID
-- @param params: 动作参数表
-- @return: 可直接调用的回调函数
function PageNavigation.create_action_callback(action_id, params)
    params = params or {}
    
    if action_id == "goto_page" then
        local page_index = params.page_index or 1
        return function()
            PageNavigation.goto_page(page_index)
        end
    elseif action_id == "goto_page_by_name" then
        local page_name = params.page_name or ""
        return function()
            PageNavigation.goto_page_by_name(page_name)
        end
    elseif action_id == "goto_next_page" then
        return function()
            PageNavigation.goto_next_page()
        end
    elseif action_id == "goto_prev_page" then
        return function()
            PageNavigation.goto_prev_page()
        end
    elseif action_id == "goto_first_page" then
        return function()
            PageNavigation.goto_first_page()
        end
    elseif action_id == "goto_last_page" then
        return function()
            PageNavigation.goto_last_page()
        end
    end
    
    -- 未知动作，返回空函数
    print("[PageNavigation] 警告: 未知动作 " .. tostring(action_id))
    return function() end
end

return PageNavigation
