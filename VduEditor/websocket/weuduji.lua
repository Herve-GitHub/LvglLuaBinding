local scr = lvgl.scr_act()

-- 创建温度计（已经包含完整的刻度和样式）
--[[local wendu = lvgl.create_wendu(scr)
wendu:set_size(50, 180)
wendu:set_pos(50, 50)]]--
local time = lvgl.create_time_label(scr)
time:set_pos(200,200)