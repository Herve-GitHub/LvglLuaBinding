local lv = require("lvgl")

-- 数据
local all_data = {}
for i = 1, 50 do
    local hour = i - 1
    local time_str = string.format("2026-01-%02d %02d:11:00", math.floor(hour/24)+1, hour%24)
    all_data[i] = {"用户" .. i, tostring(20 + i % 20), "城市" .. (i % 10 + 1), time_str}
end

local filtered_data = all_data
local rows_per_page = 6
local current_page = 1
local total_pages = math.ceil(#filtered_data / rows_per_page)

-- ===================== 【顶层大容器】包裹所有内容 =====================
local root_cont = lv.obj_create(lv.scr_act())
root_cont:set_size(640, 480)
root_cont:align(lv.ALIGN_CENTER, 0, 0)
root_cont:set_style_border_width(1, 0)
root_cont:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- ===================== 【筛选栏】独立放在顶部 =====================
local filter_cont = lv.obj_create(root_cont)
filter_cont:set_size(600, 50)
filter_cont:align(lv.ALIGN_TOP_MID, 0, 15)
filter_cont:set_flex_flow(lv.FLEX_FLOW_ROW)
filter_cont:set_flex_align(lv.FLEX_ALIGN_SPACE_EVENLY, lv.FLEX_ALIGN_CENTER, lv.FLEX_ALIGN_CENTER)
filter_cont:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 开始时间
local start_lab = lv.label_create(filter_cont)
start_lab:set_text("开始时间")

local start_input = lv.textarea_create(filter_cont)
start_input:set_size(160, 32)
start_input:set_text("2026-01-01 00:00:00")
start_input:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 结束时间
local end_lab = lv.label_create(filter_cont)
end_lab:set_text("结束时间")

local end_input = lv.textarea_create(filter_cont)
end_input:set_size(160, 32)
end_input:set_text("2026-01-05 23:59:59")
end_input:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 查询按钮
local query_btn = lv.btn_create(filter_cont)
query_btn:set_size(70, 32)
local q_lab = lv.label_create(query_btn)
q_lab:set_text("查询")
q_lab:center()

-- 重置按钮
local reset_btn = lv.btn_create(filter_cont)
reset_btn:set_size(70, 32)
local r_lab = lv.label_create(reset_btn)
r_lab:set_text("重置")
r_lab:center()

-- ===================== 【表格】 =====================
local table = lv.table_create(root_cont)
table:set_size(500, 300)
table:align(lv.ALIGN_TOP_MID, 0, 90)
table:set_col_cnt(3)
table:set_row_cnt(rows_per_page + 1)

table:set_column_width(0, 150)
table:set_column_width(1, 100)
table:set_column_width(2, 230)

table:set_cell_value(0, 0, "姓名")
table:set_cell_value(0, 1, "年龄")
table:set_cell_value(0, 2, "城市")

-- ===================== 【分页栏】 =====================
local page_cont = lv.obj_create(root_cont)
page_cont:set_size(500, 40)
page_cont:align(lv.ALIGN_BOTTOM_MID, 0, -15)
page_cont:set_style_bg_opa(lv.OPA_TRANSP, 0)
page_cont:set_flex_flow(lv.FLEX_FLOW_ROW)
page_cont:set_flex_align(lv.FLEX_ALIGN_CENTER, lv.FLEX_ALIGN_CENTER, lv.FLEX_ALIGN_CENTER)
page_cont:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 时间转换
local function time_to_timestamp(str)
    local y, m, d, h, mi, s = str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    return os.time({year = y, month = m, day = d, hour = h, min = mi, sec = s})
end

-- 查询
local function do_query()
    local start_str = start_input:get_text()
    local end_str = end_input:get_text()
    local start_ts = time_to_timestamp(start_str)
    local end_ts = time_to_timestamp(end_str)

    filtered_data = {}
    for _, v in ipairs(all_data) do
        local data_ts = time_to_timestamp(v[4])
        if data_ts >= start_ts and data_ts <= end_ts then
            table.insert(filtered_data, v)
        end
    end

    current_page = 1
    total_pages = math.ceil(#filtered_data / rows_per_page)
    update_table_content()
    update_page_buttons()
end

-- 重置
local function do_reset()
    filtered_data = all_data
    current_page = 1
    total_pages = math.ceil(#filtered_data / rows_per_page)
    start_input:set_text("2026-01-01 00:00:00")
    end_input:set_text("2026-01-05 23:59:59")
    update_table_content()
    update_page_buttons()
end

local function go_to_page(page)
    current_page = math.max(1, math.min(page, total_pages))
    update_table_content()
    update_page_buttons()
end

function update_table_content()
    local st = (current_page - 1) * rows_per_page + 1
    local ed = math.min(st + rows_per_page - 1, #filtered_data)

    for r = 1, rows_per_page do
        for c = 0, 2 do
            table:set_cell_value(r, c, "")
        end
    end

    local i = 1
    for idx = st, ed do
        table:set_cell_value(i, 0, filtered_data[idx][1])
        table:set_cell_value(i, 1, filtered_data[idx][2])
        table:set_cell_value(i, 2, filtered_data[idx][3])
        i = i + 1
    end
end

function update_page_buttons()
    page_info:set_text(current_page .. " / " .. total_pages)
end

local function make_btn(txt, cb)
    local b = lv.btn_create(page_cont)
    b:set_size(60, 32)
    local l = lv.label_create(b)
    l:set_text(txt)
    l:center()
    b:add_event_cb(cb, lv.EVENT_CLICKED, nil)
    return b
end

first_btn = make_btn("首页", function() go_to_page(1) end)
prev_btn = make_btn("上页", function() go_to_page(current_page - 1) end)

page_info = lv.label_create(page_cont)
page_info:set_style_pad_left(10)
page_info:set_style_pad_right(10)

next_btn = make_btn("下页", function() go_to_page(current_page + 1) end)
last_btn = make_btn("末页", function() go_to_page(total_pages) end)

-- 绑定事件
query_btn:add_event_cb(do_query, lv.EVENT_CLICKED, nil)
reset_btn:add_event_cb(do_reset, lv.EVENT_CLICKED, nil)

-- 初始化
update_table_content()
update_page_buttons()