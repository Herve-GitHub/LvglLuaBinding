local lvgl = require("lvgl")
local config = require("lua.widgets.config")

-- 1. 创建图片控件（不设置任何宽高 = 开启自适应）
local img = lvgl.image_create(lvgl.scr_act())

-- 2. 设置图片路径
img:set_src("C:\\Test\\LUATEST2\\ahu3.png")

-- 3. 强制让图片加载并获取真实尺寸（核心修复）
local w = img:get_width()
local h = img:get_height()


