local lv = require("lvgl")

-- 使用找到的正确常量
local chart = lv.chart_create(lv.scr_act())
chart:set_size(300, 200)
--chart:set_type(lv.CHART_TYPE_LINE)
chart:set_point_count(5)



local series = chart:add_series(0xFF0000, lv.CHART_AXIS_PRIMARY_Y)
chart:set_range(lv.CHART_AXIS_PRIMARY_Y, 0, 100)

for i = 1, 5 do
    chart:set_next_value(series, i * 20)
end