local lv = require("lvgl")

-- 使用找到的正确常量
local chart = lv.chart_create(lv.scr_act())
chart:set_size(300, 200)
chart:set_point_count(2)
chart:set_type(lv.CHART_TYPE_LINE)





chart:set_range(lv.CHART_AXIS_PRIMARY_Y, 0, 100)

local series = chart:add_series(0xFF0000, lv.CHART_AXIS_PRIMARY_Y)

for i = 1, 10 do
    chart:set_next_value(series, i * 10)
end






--[[local lv = require("lvgl")

local chart = lv.chart_create(lv.scr_act())
chart:set_size(300, 200)
chart:set_point_count(10)

-- 你绑定里有的！必须用这个设置折线模式！
chart:set_type(lv.CHART_TYPE_LINE)

-- 设置范围
chart:set_range(lv.CHART_AXIS_PRIMARY_Y, 0, 100)

-- 加系列
local series = chart:add_series(0xFF0000, lv.CHART_AXIS_PRIMARY_Y)

-- 填数据
for i = 1, 10 do
    chart:set_next_value(series, i * 10)
end

-- 刷新
--chart:refresh(chart)]]--
