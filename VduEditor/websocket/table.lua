local lv = require("lvgl")

-- 数据准备
local all_data = {}
for i = 1, 50 do
    all_data[i] = {"用户" .. i, tostring(20 + i % 20), "城市" .. (i % 10 + 1)}
end

local rows_per_page = 6
local current_page = 1
local total_pages = math.ceil(#all_data / rows_per_page)

-- 创建主容器
local main_cont = lv.obj_create(lv.scr_act())
main_cont:set_size(400, 380)
main_cont:align(lv.ALIGN_CENTER, 0, 0)
main_cont:set_style_border_width(1, 0)
main_cont:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 创建表格
local table = lv.table_create(main_cont)
table:set_size(380, 300)
table:align(lv.ALIGN_TOP_MID, 0, 10)
table:set_col_cnt(3)
table:set_row_cnt(rows_per_page + 1)

-- 设置列宽
table:set_column_width(0, 150)
table:set_column_width(1, 100)
table:set_column_width(2, 150)

-- 设置表头
table:set_cell_value(0, 0, "姓名")
table:set_cell_value(0, 1, "年龄")
table:set_cell_value(0, 2, "城市")

-- 页码按钮容器
local page_cont = lv.obj_create(main_cont)
page_cont:set_size(380, 30)
page_cont:align(lv.ALIGN_BOTTOM_MID, 0, -10)
page_cont:set_style_bg_opa(lv.OPA_TRANSP, 0)
page_cont:set_flex_flow(lv.FLEX_FLOW_ROW)
page_cont:set_flex_align(lv.FLEX_ALIGN_CENTER, lv.FLEX_ALIGN_CENTER, lv.FLEX_ALIGN_CENTER)
page_cont:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

-- 存储按钮对象的全局变量
local first_btn, prev_btn, page_info, next_btn, last_btn

-- 跳转到指定页的函数
function go_to_page(page)
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end
    current_page = page
    update_table_content()
    update_page_buttons()
end

-- 更新表格内容
function update_table_content()
    local start_idx = (current_page - 1) * rows_per_page + 1
    local end_idx = math.min(start_idx + rows_per_page - 1, #all_data)
    
    -- 清空数据行
    for row = 1, rows_per_page do
        for col = 0, 2 do
            table:set_cell_value(row, col, "")
        end
    end
    
    -- 填充新数据
    local data_row = 1
    for i = start_idx, end_idx do
        table:set_cell_value(data_row, 0, all_data[i][1])
        table:set_cell_value(data_row, 1, all_data[i][2])
        table:set_cell_value(data_row, 2, all_data[i][3])
        data_row = data_row + 1
    end
    
    table:invalidate()
end

-- 更新页码按钮状态（简化版，不设置禁用状态）
function update_page_buttons()
    if page_info then
        page_info:set_text(current_page .. " / " .. total_pages)
    end
end

-- 创建按钮（只创建一次）
first_btn = lv.btn_create(page_cont)
first_btn:set_size(50, 35)
local first_label = lv.label_create(first_btn)
first_label:set_text("首页")
first_label:center()
first_btn:add_event_cb(function() 
    if current_page > 1 then
        go_to_page(1) 
    end
end, lv.EVENT_CLICKED, nil)

prev_btn = lv.btn_create(page_cont)
prev_btn:set_size(50, 35)
local prev_label = lv.label_create(prev_btn)
prev_label:set_text("〈")
prev_label:center()
prev_btn:add_event_cb(function() 
    if current_page > 1 then
        go_to_page(current_page - 1) 
    end
end, lv.EVENT_CLICKED, nil)

page_info = lv.label_create(page_cont)
page_info:set_text("1 / " .. total_pages)
-- 移除有问题的字体设置，使用默认字体
-- page_info:set_style_text_font(lv.font_montserrat_16, 0)  -- 这行导致错误
page_info:set_style_pad_left(10, 0)
page_info:set_style_pad_right(10, 0)

next_btn = lv.btn_create(page_cont)
next_btn:set_size(50, 35)
local next_label = lv.label_create(next_btn)
next_label:set_text("〉")
next_label:center()
next_btn:add_event_cb(function() 
    if current_page < total_pages then
        go_to_page(current_page + 1) 
    end
end, lv.EVENT_CLICKED, nil)

last_btn = lv.btn_create(page_cont)
last_btn:set_size(50, 35)
local last_label = lv.label_create(last_btn)
last_label:set_text("末页")
last_label:center()
last_btn:add_event_cb(function() 
    if current_page < total_pages then
        go_to_page(total_pages) 
    end
end, lv.EVENT_CLICKED, nil)

-- 初始化
update_table_content()
update_page_buttons()

print("分页表格已创建，总数据：" .. #all_data .. "条，共" .. total_pages .. "页")
print("提示：表格支持分页浏览，使用下方按钮切换页面")