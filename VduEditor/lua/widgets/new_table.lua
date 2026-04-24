local lvgl = require("lvgl")
local json = require("editor.json")
local DataTable = {}

DataTable.__widget_meta = {
    id = "data_table",
    name = "Data Table",
    description = "SCADA实时数据表格",
    schema_version = "1.0",
    version = "1.0",
    properties = {
        { name = "instance_name", type = "string", default = "", label = "实例名称" },
        { name = "x", type = "number", default = 0, label = "X坐标" },
        { name = "y", type = "number", default = 0, label = "Y坐标" },
        { name = "width", type = "number", default = 600, label = "宽度" },
        { name = "height", type = "number", default = 400, label = "高度" },

        { name = "rows_per_page", type = "number", default = 6, label = "每页条数" },
        { name = "col1_width", type = "number", default = 180 },
        { name = "col2_width", type = "number", default = 160 },
        { name = "col3_width", type = "number", default = 100 },
        { name = "col4_width", type = "number", default = 100 },

        { name = "header1", type = "string", default = "设备ID" },
        { name = "header2", type = "string", default = "时间" },
        { name = "header3", type = "string", default = "状态" },
        { name = "header4", type = "string", default = "数值" },

        { name = "api_server", type = "string", default = "192.168.0.73", label = "服务器IP" },
        { name = "api_token", type = "string", default = "scadaToken", label = "Token" },
        { name = "refresh_sec", type = "number", default = 5 },
        { name = "border_color", type = "color", default = "#dddddd" },

        -- 【和你图表完全一致】
        { name = "design_mode", type = "boolean", default = true, label = "设计模式" },
    },
}

local function parse_color(c)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
        return tonumber(c:sub(2), 16)
    end
    return 0xdddddd
end

-- 假数据（设计模式用）
local function get_fake_table_data()
    return {
        { "Dev_001", "2025-12-30 10:00", "正常", "55" },
        { "Dev_002", "2025-12-30 10:00", "正常", "72" },
        { "Dev_003", "2025-12-30 10:00", "报警", "0" },
        { "Dev_004", "2025-12-30 10:00", "正常", "91" },
        { "Dev_005", "2025-12-30 10:00", "正常", "68" },
        { "Dev_006", "2025-12-30 10:00", "离线", "0" },
    }
end

-- 接口拉取数据
local function load_data_from_api(server, token)
    if not server or not token or not lvgl.get_real_data then return {} end
    local success, resp = lvgl.get_real_data(server, token, 1, 100)
    if not success or not resp then return {} end

    local ok, data = pcall(json.decode, resp)
    if not ok or not data or data.code ~= "200" or not data.data or not data.data.list then
        return {}
    end

    local result = {}
    for _, item in ipairs(data.data.list) do
        table.insert(result, {
            item.id or "---",
            tostring(item.timestamp or ""),
            item.status or "---",
            tostring(item.val or "0")
        })
    end
    return result
end

-- 本地ID筛选
local function filter_data(origin, id)
    if not id or id == "" then return origin end
    local res = {}
    for _, row in ipairs(origin) do
        if row[1] == id then
            table.insert(res, row)
        end
    end
    return res
end

function DataTable.new(parent, props)
    props = props or {}
    local self = {}

    -- ====================== 属性初始化（和图表完全一样） ======================
    self.props = {}
    for _, p in ipairs(DataTable.__widget_meta.properties) do
        if props[p.name] ~= nil then
            self.props[p.name] = props[p.name]
        else
            self.props[p.name] = p.default
        end
    end

    self._parent = parent
    self.timer = nil
    self.origin_data = {}    -- 原始数据
    self.all_data = {}       -- 显示数据
    self.current_page = 1
    self.filter_id = ""
    local rows_pp = self.props.rows_per_page

    -- ====================== 主容器 ======================
    self.container = lvgl.obj_create(parent)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_style_bg_opa(0, 0)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(parse_color(self.props.border_color), 0)
    self.container:remove_flag(lvgl.OBJ_FLAG_SCROLLABLE)

    -- ====================== 顶部 ID 查询栏 ======================
    self.query_bar = lvgl.obj_create(self.container)
    self.query_bar:set_size(lvgl.pct(100), 40)
    self.query_bar:set_pos(0, 0)
    self.query_bar:set_style_bg_opa(0, 0)
    self.query_bar:set_flex_flow(2)
    self.query_bar:set_flex_align(1, 2, 2)
    self.query_bar:remove_flag(lvgl.OBJ_FLAG_SCROLLABLE)

    local lab = lvgl.label_create(self.query_bar)
    lab:set_text("ID:")

    self.input_id = lvgl.textarea_create(self.query_bar)
    self.input_id:set_size(200, 32)
    self.input_id:set_placeholder_text("输入设备ID")
    self.input_id:remove_flag(lvgl.OBJ_FLAG_SCROLLABLE)



    
    -- 全局创建一个键盘（整个页面共用）
    local keyboard = lvgl.keyboard_create(scr)
    keyboard:add_flag(lvgl.OBJ_FLAG_HIDDEN) -- 默认隐藏


    -- 绑定键盘到 ID 输入框
self.input_id:add_event_cb(function(code)
    if code == lvgl.EVENT_CLICKED then
        -- 点输入框 → 弹出键盘并绑定
        keyboard:keyboard_set_textarea(self.input_id)
        keyboard:remove_flag(lvgl.OBJ_FLAG_HIDDEN)
    end
end, 0)

-- 键盘取消/确定事件
keyboard:add_event_cb(function(code)
    if code == lvgl.EVENT_CANCEL or code == lvgl.EVENT_READY then
        keyboard:add_flag(lvgl.OBJ_FLAG_HIDDEN)
    end
end, 0)




    local btn_search = lvgl.btn_create(self.query_bar)
    btn_search:set_size(70, 32)
    local lab_s = lvgl.label_create(btn_search)
    lab_s:set_text("查询")
    lab_s:center()

    local btn_clear = lvgl.btn_create(self.query_bar)
    btn_clear:set_size(70, 32)
    local lab_c = lvgl.label_create(btn_clear)
    lab_c:set_text("清空")
    lab_c:center()

    -- ====================== 表格 ======================
    self.table = lvgl.table_create(self.container)
    self.table:set_size(lvgl.pct(100), lvgl.pct(75))
    self.table:set_pos(0, 40)
    self.table:set_col_cnt(4)
    self.table:set_row_cnt(rows_pp + 1)

    local ws = {self.props.col1_width, self.props.col2_width, self.props.col3_width, self.props.col4_width}
    local hs = {self.props.header1, self.props.header2, self.props.header3, self.props.header4}
    for i=1,4 do
        self.table:set_column_width(i-1, ws[i])
        self.table:set_cell_value(0, i-1, hs[i])
    end

    -- ====================== 分页栏 ======================
    self.page_cont = lvgl.obj_create(self.container)
    self.page_cont:set_size(lvgl.pct(100), 40)
    self.page_cont:set_pos(0, self.props.height - 85)
    self.page_cont:set_style_bg_opa(0, 0)
    self.page_cont:set_flex_flow(2)
    self.page_cont:set_flex_align(2, 2, 2)
    self.page_cont:remove_flag(lvgl.OBJ_FLAG_SCROLLABLE)

    -- 页码
    self.page_lbl = lvgl.label_create(self.page_cont)
    self.page_lbl:set_text("1 / 1")

    -- ====================== 核心函数 ======================
    local function update_page_label()
        local total = math.ceil(#self.all_data / rows_pp)
        total = total < 1 and 1 or total
        self.page_lbl:set_text(self.current_page .. " / " .. total)
    end

    local function update_table()
        for r=1, rows_pp do
            for c=0,3 do self.table:set_cell_value(r, c, "") end
        end
        local total = #self.all_data
        if total == 0 then return end

        local from = (self.current_page-1)*rows_pp + 1
        local to = math.min(from + rows_pp -1, total)
        local r = 1
        for i=from, to do
            local d = self.all_data[i]
            self.table:set_cell_value(r, 0, d[1])
            self.table:set_cell_value(r, 1, d[2])
            self.table:set_cell_value(r, 2, d[3])
            self.table:set_cell_value(r, 3, d[4])
            r = r+1
        end
        update_page_label()
    end

    local function goto_page(p)
        local total = math.ceil(#self.all_data / rows_pp)
        total = total < 1 and 1 or total
        self.current_page = math.max(1, math.min(p, total))
        update_table()
    end

    -- 分页按钮
    local function create_btn(txt, cb)
        local b = lvgl.btn_create(self.page_cont)
        b:set_size(55,32)
        local l = lvgl.label_create(b)
        l:set_text(txt)
        l:center()
        b:add_event_cb(cb, 2)
    end
    create_btn("首页", function() goto_page(1) end)
    create_btn("上页", function() goto_page(self.current_page-1) end)
    create_btn("下页", function() goto_page(self.current_page+1) end)
    create_btn("末页", function() goto_page(math.ceil(#self.all_data/rows_pp)) end)

    -- ====================== 刷新逻辑（仅运行模式执行） ======================
    local function refresh_full()
        if self.props.design_mode then return end  -- 设计模式直接返回！

        self.origin_data = load_data_from_api(self.props.api_server, self.props.api_token)
        self.all_data = filter_data(self.origin_data, self.filter_id)
        goto_page(1)
    end

    -- 查询 / 清空
    local function do_search()
        self.filter_id = self.input_id:get_text() or ""
        self.all_data = filter_data(self.origin_data, self.filter_id)
        goto_page(1)
    end
    local function do_clear()
        self.input_id:set_text("")
        self.filter_id = ""
        self.all_data = filter_data(self.origin_data, "")
        goto_page(1)
    end

    btn_search:add_event_cb(do_search, 2)
    btn_clear:add_event_cb(do_clear, 2)

    -- ====================== 启动/停止（和图表完全一样） ======================
    function self:start()
        if self.timer then return end
        if self.props.design_mode then return end  -- 设计模式不启动定时器

        lvgl.start_network_service()
        refresh_full()
        self.timer = lvgl.timer_create(refresh_full, self.props.refresh_sec * 1000)
    end

    function self:stop()
        if self.timer then
            lvgl.timer_delete(self.timer)
            self.timer = nil
        end
    end

    -- ====================== 属性方法 ======================
    function self:get_property(name)
        return self.props[name]
    end

    function self:set_property(name, value)
        self.props[name] = value

        if name == "x" or name == "y" then
            self.container:set_pos(self.props.x, self.props.y)
        elseif name == "width" or name == "height" then
            self.container:set_size(self.props.width, self.props.height)
            self.table:set_size(lvgl.pct(100), lvgl.pct(75))
        elseif name == "api_server" or name == "api_token" then
            refresh_full()
        elseif name == "design_mode" then
            -- 设计模式切换
            self:stop()
            if value then
                -- 设计模式：假数据
                self.origin_data = get_fake_table_data()
                self.all_data = filter_data(self.origin_data, self.filter_id)
                goto_page(1)
            else
                self:start()
            end
        end
        return true
    end

    function self:get_properties()
        local out = {}
        for k,v in pairs(self.props) do out[k] = v end
        return out
    end

    function self:apply_properties(props_table)
        for k,v in pairs(props_table) do
            self:set_property(k,v)
        end
        return true
    end

    function self:to_state()
        return self:get_properties()
    end

    function self:get_container()
        return self.container
    end

    -- ====================== 初始化 ======================
    if self.props.design_mode then
        -- 设计模式：假数据，不启动定时器
        self.origin_data = get_fake_table_data()
        self.all_data = filter_data(self.origin_data, "")
        goto_page(1)
    else
        -- 运行模式：启动
        self:start()
    end

    return self
end

return DataTable