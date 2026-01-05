local lv = require("lvgl")
local Valve = require("lua.widgets.valve")
local Button = require("lua.widgets.button")

local scr = lv.scr_act()

-- 创建标题
local title = lv.label_create(scr)
title:set_text("阀门控制演示")
title:align(lv.ALIGN_TOP_MID, 0, 20)

-- 创建三个阀门
local v1 = Valve.new(scr, { x = 100, y = 100, title = "Valve 1" })
local v2 = Valve.new(scr, { x = 300, y = 100, title = "Valve 2" })
local v3 = Valve.new(scr, { x = 500, y = 100, size = 120, handle_color = "#2196F3", label = "V3" })

-- 添加标签说明
local function add_label(parent, text, y_offset)
    local l = lv.label_create(parent)
    l:set_text(text)
    l:align(lv.ALIGN_BOTTOM_MID, 0, y_offset)
end

-- 简单的标签添加方式（直接在屏幕上定位）
local l1 = lv.label_create(scr) l1:set_text("阀门 1") l1:align_to(v1.container, lv.ALIGN_OUT_BOTTOM_MID, 0, 10)
local l2 = lv.label_create(scr) l2:set_text("阀门 2") l2:align_to(v2.container, lv.ALIGN_OUT_BOTTOM_MID, 0, 10)
local l3 = lv.label_create(scr) l3:set_text("阀门 3") l3:align_to(v3.container, lv.ALIGN_OUT_BOTTOM_MID, 0, 10)

-- 创建控制按钮
local btn_open_all = Button.new(scr, { x = 50, y = 300, width = 150, height = 50, label = "一键全开", bg_color = "#4CAF50" })
local btn_close_all = Button.new(scr, { x = 250, y = 300, width = 150, height = 50, label = "一键全关", bg_color = "#F44336" })
local text_valve_range = lv.slider_create(scr)
text_valve_range:set_pos(450, 300)

-- 绑定事件
btn_open_all:on("clicked", function()
    print("执行：一键全开")
    Valve.open_all()
end)

btn_close_all:on("clicked", function()
    print("执行：一键全关")
    Valve.close_all()
end)

-- 监听阀门状态变化（可选）
v1:on("toggled", function(self, is_open) print("V1 状态: " .. (is_open and "开" or "关")) end)
v2:on("toggled", function(self, is_open) print("V2 状态: " .. (is_open and "开" or "关")) end)
v3:on("toggled", function(self, is_open) print("V3 状态: " .. (is_open and "开" or "关")) end)

print("阀门演示已加载。点击阀门可单独操作（带确认），点击下方按钮可批量操作。")
