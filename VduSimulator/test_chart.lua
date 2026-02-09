-- 直接测试 chart 功能
local lv = require("lvgl")

-- Get active screen
local scr = lv.scr_act()
scr:set_style_bg_color(0x1E1E6B, 0)  -- Dark blue background

-- 创建 chart
local chart = lv.chart_create(scr)
chart:set_pos(50, 50)
chart:set_size(700, 300)

-- 设置 chart 属性
print("Setting chart type to LINE (1)...")
chart:set_type(1)  -- LV_CHART_TYPE_LINE = 1

print("Setting point count to 20...")
chart:set_point_count(20)  -- 使用少量点便于测试

print("Setting update mode to SHIFT (1)...")
chart:set_update_mode(1)  -- LV_CHART_UPDATE_MODE_SHIFT = 1

print("Setting range 0-100...")
chart:set_range(0, 0, 100)  -- axis=0 (PRIMARY_Y), y轴范围 0-100

-- 添加数据系列
print("Adding series with color 0x2196F3, axis=0...")
local series = chart:add_series(0x2196F3, 0)  -- Blue color, Y axis = 0
print("Series created:", series)

if series then
    -- 添加初始数据
    print("Setting 20 values...")
    for i = 1, 20 do
        local value = math.random(20, 80)
        print(string.format("  [%d] = %d", i, value))
        chart:set_next_value(series, value)
    end
else
    print("ERROR: series is nil!")
end

-- 创建一个 label 显示状态
local label = lv.label_create(scr)
label:set_text("Chart Test - 20 points")
label:set_pos(50, 10)
label:set_style_text_color(0xFFFFFF, 0)

-- 刷新 chart
print("Refreshing chart...")
chart:refresh()

print("Chart test complete! Check if chart is visible.")
