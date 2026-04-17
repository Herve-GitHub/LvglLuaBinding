-- Admin.lua  环境配置查看页面（项目标准格式）
local lv = require("lvgl")

local Admin = {}

Admin.__widget_meta = {
    id = "admin_config_page",
    name = "环境配置页面",
    description = "查看当前 install_config.lua 配置",
    schema_version = "1.0",
    version = "1.0",
}

local function parse_color(c)
    if type(c) == "string" and c:find("^#") then
        return tonumber(c:sub(2), 16)
    end
    return c or 0xffffff
end

-- 读取 install_config.lua
local function load_install_config()
    local ok, config = pcall(require, "install_config")
    if ok and type(config) == "table" then
        print("[Admin] 成功加载 install_config 模块")
        return config
    end

    print("[Admin] 加载配置失败，使用默认配置")
    return {
        remote_host = "",
        remote_user = "",
        remote_path = "",
        password = "",
        verbose = true,
        compile_before_install = true
    }
end

-- 读取图片路径（widgets.config.lua）
local function load_widgets_config()
    local ok, config = pcall(require, "widgets.config")
    if ok and type(config) == "table" then
        print("[Admin] 成功加载 widgets.config 模块")
        return config
    end

    print("[Admin] 加载 widgets.config 失败")
    return {
        image_path = ""
    }
end

-- 创建配置页面
function Admin.show_config_page(parent)
    parent = parent or lv.scr_act()

    -- 弹窗
    local modal = lv.obj_create(parent)
    modal:set_size(550, 450)
    modal:align(lv.ALIGN_CENTER, 0, 0)
    modal:set_style_bg_color(0x2E2E2E, 0)
    modal:set_style_radius(8, 0)
    modal:set_style_border_color(0x555555, 0)
    modal:set_style_border_width(2, 0)
    modal:set_style_pad_all(20, 0)
    modal:remove_flag(lv.OBJ_FLAG_SCROLLABLE)

    -- 标题
    local title = lv.label_create(modal)
    title:set_text("当前环境配置")
    title:set_style_text_color(0xFFD700, 0)
    title:align(lv.ALIGN_TOP_MID, 0, 10)

    -- 滚动区域
    local scroll = lv.obj_create(modal)
    scroll:set_size(500, 280)
    scroll:set_pos(25, 60)
    scroll:set_style_bg_color(0x252525, 0)
    scroll:set_style_radius(6, 0)
    scroll:set_style_pad_all(15, 0)
    scroll:add_flag(lv.OBJ_FLAG_SCROLLABLE)

    local cfg = load_install_config()
    local widget_cfg = load_widgets_config()
    local y = 10
    local line_h = 35

    local function add_line(label, value)
        local lab = lv.label_create(scroll)
        lab:set_text(label)
        lab:set_style_text_color(0xaaaaaa, 0)
        lab:set_pos(10, y)

        local val = lv.label_create(scroll)
        local show = value == "" and "未配置" or value

        if label == "密码：" then
            show = value ~= "" and "********" or "未配置"
        end

        val:set_text(show)
        val:set_style_text_color(0xffffff, 0)
        val:set_pos(160, y)

        y = y + line_h
    end

    -- 配置项（已删除本地路径）
    add_line("远程主机：", cfg.remote_host)
    add_line("用户名：", cfg.remote_user)
    add_line("远程路径：", cfg.remote_path)
    add_line("密码：", cfg.password)
    add_line("图片资源路径：", widget_cfg.image_path) -- 只保留这个
    add_line("详细日志：", cfg.verbose and "开启" or "关闭")
    add_line("安装前编译：", cfg.compile_before_install and "开启" or "关闭")

    -- 确定按钮
    local btn_ok = lv.btn_create(modal)
    btn_ok:set_size(160, 45)
    btn_ok:set_pos(195, 370)
    btn_ok:set_style_bg_color(0x0078D4, 0)

    local lab_ok = lv.label_create(btn_ok)
    lab_ok:set_text("确定")
    lab_ok:align(lv.ALIGN_CENTER, 0, 0)

    -- 跳转回编辑器
    btn_ok:add_event_cb(function()
        lvgl.loadfile("lua/editor/main_editor.lua")
    end, lv.EVENT_CLICKED)
end

-- 自动打开
Admin.show_config_page(lv.scr_act())

return Admin