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

        { name = "api_server", type = "string", default = "", label = "服务器IP" },
        { name = "api_token", type = "string", default = "scadaToken", label = "Token" },
        { name = "refresh_sec", type = "number", default = 5 },
        { name = "border_color", type = "color", default = "#dddddd" },
    },
}

local function parse_color(c)
    if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
        return tonumber(c:sub(2), 16)
    end
    return 0xdddddd
end

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
    print("[表格] 加载成功：" .. #result .. " 条")
    return result
end

function DataTable.new(parent, state)
    if not parent then return nil end
    state = state or {}

    local self = {}
    self.props = {}
    for _, p in ipairs(DataTable.__widget_meta.properties) do
        self.props[p.name] = state[p.name] ~= nil and state[p.name] or p.default
    end

    self.current_page = 1
    self.all_data = {}
    local rows_pp = self.props.rows_per_page

    -- 主容器
    self.container = lvgl.obj_create(parent)
    self.container:set_size(self.props.width, self.props.height)
    self.container:set_pos(self.props.x, self.props.y)
    self.container:set_style_border_width(1, 0)
    self.container:set_style_border_color(parse_color(self.props.border_color), 0)
    self.container:remove_flag(lvgl.OBJ_FLAG_SCROLLABLE)

    -- ====================== 【表格：占大部分区域】 ======================
    self.table = lvgl.table_create(self.container)
    self.table:set_size(lvgl.pct(100), lvgl.pct(85))  -- 高度 85%
    self.table:set_pos(0, 0)                          -- 贴顶部
    self.table:set_col_cnt(4)
    self.table:set_row_cnt(rows_pp + 1)

    local ws = {self.props.col1_width, self.props.col2_width, self.props.col3_width, self.props.col4_width}
    local hs = {self.props.header1, self.props.header2, self.props.header3, self.props.header4}
    for i=1,4 do
        self.table:set_column_width(i-1, ws[i])
        self.table:set_cell_value(0, i-1, hs[i])
    end

    -- ====================== 【分页栏：固定在最底部】 ======================
    self.page_cont = lvgl.obj_create(self.container)
    self.page_cont:set_size(lvgl.pct(100), 40)        -- 固定高度 40
    self.page_cont:set_pos(0, self.props.height - 85) -- 强制贴底部
    self.page_cont:set_style_bg_opa(0, 0)
    self.page_cont:set_flex_flow(2)
    self.page_cont:set_flex_align(2, 2, 2)
    self.page_cont:remove_flag(lvgl.OBJ_FLAG_SCROLLABLE)

    -- 页码显示
    local function update_page_label()
        local total = math.ceil(#self.all_data / rows_pp)
        total = total < 1 and 1 or total
        self.page_lbl:set_text(self.current_page .. " / " .. total)
    end

    -- 刷新表格内容
    local function update_table()
        for r=1, rows_pp do
            for c=0,3 do
                self.table:set_cell_value(r, c, "")
            end
        end

        local from = (self.current_page-1)*rows_pp + 1
        local to = math.min(from + rows_pp -1, #self.all_data)
        local r = 1
        for i=from, to do
            local d = self.all_data[i]
            if d then
                self.table:set_cell_value(r, 0, d[1] or "")
                self.table:set_cell_value(r, 1, d[2] or "")
                self.table:set_cell_value(r, 2, d[3] or "")
                self.table:set_cell_value(r, 3, d[4] or "")
                r = r+1
            end
        end
        update_page_label()
    end

    -- 跳转页码
    local function goto_page(p)
        local total = math.ceil(#self.all_data / rows_pp)
        total = total < 1 and 1 or total
        self.current_page = math.max(1, math.min(p, total))
        update_table()
    end

    -- 创建按钮
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
    self.page_lbl = lvgl.label_create(self.page_cont)
    create_btn("下页", function() goto_page(self.current_page+1) end)
    create_btn("末页", function() goto_page(math.ceil(#self.all_data/rows_pp)) end)

    -- 刷新后保持当前页
    local function refresh()
        local old_page = self.current_page
        self.all_data = load_data_from_api(self.props.api_server, self.props.api_token)
        goto_page(old_page)
    end

    lvgl.start_network_service()
    refresh()
    lvgl.timer_create(refresh, self.props.refresh_sec*1000)

    function self:get_property(name) return self.props[name] end
    function self:set_property(name, value)
        self.props[name] = value
        if name == "api_server" or name == "api_token" then refresh() end
    end
    function self:get_properties() return self.props end
    function self:apply_properties(props) for k,v in pairs(props) do self:set_property(k,v) end end
    function self:to_state() return self.props end

    return self
end

return DataTable