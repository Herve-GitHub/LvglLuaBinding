local lvgl = require("lvgl")
local config = require("lua.widgets.config")



-- 辅助函数：构建完整路径（用于 LVGL 图片加载）
local function build_path(relative_path)
    if APP_DIR and APP_DIR ~= "" then
        local path = APP_DIR .. relative_path:gsub("/", "\\")
        return path  -- 🔥 这里绝对不能加 FS_PREFIX
    end
    return FS_PREFIX .. relative_path
end


-- 1. 创建图片控件（不设置任何宽高 = 开启自适应）
local img = lvgl.image_create(lvgl.scr_act())

-- 2. 设置图片路径
img:set_src("/image/ahu3.png")

-- 3. 强制让图片加载并获取真实尺寸（核心修复）
local w = img:get_width()
local h = img:get_height()


