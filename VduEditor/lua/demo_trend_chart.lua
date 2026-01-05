local lv = require("lvgl")
local TrendChart = require("lua.widgets.trend_chart")

-- Get active screen
local scr = lv.scr_act()

-- Create TrendChart using new API
local chart = TrendChart.new(scr, {
    x = 50, y = 50, width = 700, height = 300,
    point_count = 300, update_interval = 1000, range_min = 0, range_max = 100, auto_update = true
})

-- Create a label
local label = lv.label_create(scr)
label:set_text("趋势图演示 (300 点, 1秒刷新)")
label:set_pos(50, 10)

-- 演示：注册更新事件，以便当有新值时同时更新其它 UI
chart:on("updated", function(_, value)
    -- 这里只演示打印，编辑器可以监听该事件以实现更多功能
    print("TrendChart updated value:", value)
end)

-- Keep reference to prevent GC
_G.chart = chart
