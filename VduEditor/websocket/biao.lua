local scr = lvgl.scr_act()

-- 背景
local bg = lvgl.obj_create(scr)
bg:set_size(480, 480)
bg:set_style_bg_color(0x1a1a2e, 0)
bg:center()

-- 圆形表盘底
local dial = lvgl.obj_create(bg)
dial:set_size(300, 300)
dial:center()
dial:set_style_radius(150, 0)
dial:set_style_bg_color(0x16213e, 255)
dial:set_style_border_width(3, 0)
dial:set_style_border_color(0x0f3460, 0)

-- 表盘标题
local title = lvgl.label_create(dial)
title:set_text("仪表盘")
title:set_style_text_color(0xffffff, 255)
title:align(lvgl.ALIGN_TOP_MID, 0, 100)

-- 进度圆环
local arc_val = lvgl.arc_create(dial)
arc_val:set_size(260, 260)
arc_val:center()
arc_val:arc_set_style_arc_width(6)
arc_val:arc_set_style_arc_color(0xffd700)
arc_val:arc_set_angles(135, 135)

-- 中心数值（大号）
local label = lvgl.label_create(dial)
label:set_text("0")
label:set_style_text_color(0xffffff, 255)
label:align(lvgl.ALIGN_CENTER, 0, 30)

-- 数值单位（在数值下方）
local unit_label = lvgl.label_create(dial)
unit_label:set_text("百分比 %")
unit_label:set_style_text_color(0xcccccc, 255)
unit_label:align(lvgl.ALIGN_CENTER, 0, 45)



-- 动画
local val = 0
local dir = 1

lvgl.timer_create(function()
    val = val + dir
    if val >= 100 then dir = -1 end
    if val <= 0 then dir = 1 end

    local angle = math.floor(135 + val * 2.7)
    arc_val:arc_set_angles(135, angle)
    label:set_text(tostring(val))
end, 40)

print("✅ 完美运行！")
