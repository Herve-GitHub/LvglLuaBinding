-- Lua中使用
local lvgl = require("lvgl")
local img = lvgl.image_create(lvgl.scr_act())
img:set_src("C:\\Test\\LUATEST2\\ahu3.png")  -- 对应这个C函数
img:set_rotation(90)
img:set_scale(100)
img:set_scale_x(200)
img:set_scale_y(300)