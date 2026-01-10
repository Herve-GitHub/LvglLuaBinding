-- icons.lua
-- 图标常量定义
-- 使用方法：
-- 1. 下载 Font Awesome Free 字体：https://fontawesome.com/download
-- 2. 将 fa-solid-900.ttf 或 fa-regular-400.ttf 放到 fonts 目录
-- 3. 在 main_editor.lua 中加载图标字体

local Icons = {}

-- ========== Font Awesome 6 Free (Solid) 图标 Unicode 编码 ==========
-- 下载地址: https://fontawesome.com/download
-- 使用文件: webfonts/fa-solid-900.ttf

Icons.FA = {
    -- 文件操作
    file = "\u{f15b}",              -- 文件
    file_lines = "\u{f15c}",        -- 文件（带行）
    folder = "\u{f07b}",            -- 文件夹
    folder_open = "\u{f07c}",       -- 打开的文件夹
    floppy_disk = "\u{f0c7}",       -- 保存（软盘）
    download = "\u{f019}",          -- 下载
    upload = "\u{f093}",            -- 上传
    file_export = "\u{f56e}",       -- 导出
    file_import = "\u{f56f}",       -- 导入
    
    -- 编辑操作
    scissors = "\u{f0c4}",          -- 剪切
    copy = "\u{f0c5}",              -- 复制
    paste = "\u{f0ea}",             -- 粘贴
    trash = "\u{f1f8}",             -- 删除
    trash_can = "\u{f2ed}",         -- 删除（垃圾桶）
    eraser = "\u{f12d}",            -- 橡皮擦
    pen = "\u{f304}",               -- 笔
    pencil = "\u{f303}",            -- 铅笔
    
    -- 历史操作
    rotate_left = "\u{f2ea}",       -- 撤销（逆时针）
    rotate_right = "\u{f2f9}",      -- 重做（顺时针）
    arrow_rotate_left = "\u{f0e2}", -- 撤销箭头
    arrow_rotate_right = "\u{f01e}",-- 重做箭头
    clock_rotate_left = "\u{f1da}", -- 历史
    
    -- 对齐操作
    align_left = "\u{f036}",        -- 左对齐
    align_center = "\u{f037}",      -- 居中对齐
    align_right = "\u{f038}",       -- 右对齐
    align_justify = "\u{f039}",     -- 两端对齐
    
    -- 垂直对齐（使用箭头表示）
    arrow_up = "\u{f062}",          -- 向上
    arrow_down = "\u{f063}",        -- 向下
    arrows_up_down = "\u{f07d}",    -- 上下箭头
    arrows_left_right = "\u{f07e}", -- 左右箭头
    up_down_left_right = "\u{f0b2}",-- 四向箭头
    
    -- 缩放
    magnifying_glass_plus = "\u{f00e}",  -- 放大
    magnifying_glass_minus = "\u{f010}", -- 缩小
    magnifying_glass = "\u{f002}",       -- 搜索
    expand = "\u{f065}",            -- 展开
    compress = "\u{f066}",          -- 压缩
    maximize = "\u{f31e}",          -- 最大化
    minimize = "\u{f2d1}",          -- 最小化
    
    -- 视图/显示
    eye = "\u{f06e}",               -- 显示
    eye_slash = "\u{f070}",         -- 隐藏
    grid = "\u{e011}",              -- 网格（FA6 新增）
    border_all = "\u{f84c}",        -- 边框全部
    table_cells = "\u{f00a}",       -- 表格
    layer_group = "\u{f5fd}",       -- 图层
    
    -- 面板/窗口
    window_maximize = "\u{f2d0}",   -- 窗口最大化
    window_minimize = "\u{f2d1}",   -- 窗口最小化
    window_restore = "\u{f2d2}",    -- 窗口还原
    bars = "\u{f0c9}",              -- 菜单（三横线）
    sliders = "\u{f1de}",           -- 滑块/设置
    gear = "\u{f013}",              -- 齿轮/设置
    cog = "\u{f013}",               -- 齿轮（同上）
    wrench = "\u{f0ad}",            -- 扳手
    toolbox = "\u{f552}",           -- 工具箱
    
    -- 通用图标
    plus = "\u{f067}",              -- 加号
    minus = "\u{f068}",             -- 减号
    xmark = "\u{f00d}",             -- X 关闭
    check = "\u{f00c}",             -- 对勾
    circle = "\u{f111}",            -- 圆形
    square = "\u{f0c8}",            -- 方形
    home = "\u{f015}",              -- 主页
    image = "\u{f03e}",             -- 图片
    images = "\u{f302}",            -- 多图片
    
    -- 箭头
    chevron_left = "\u{f053}",      -- 左箭头
    chevron_right = "\u{f054}",     -- 右箭头
    chevron_up = "\u{f077}",        -- 上箭头
    chevron_down = "\u{f078}",      -- 下箭头
    angle_left = "\u{f104}",        -- 左尖角
    angle_right = "\u{f105}",       -- 右尖角
    angle_up = "\u{f106}",          -- 上尖角
    angle_down = "\u{f107}",        -- 下尖角
    
    -- 其他
    question = "\u{f128}",          -- 问号
    info = "\u{f129}",              -- 信息
    exclamation = "\u{f12a}",       -- 感叹号
    bell = "\u{f0f3}",              -- 铃铛
    bookmark = "\u{f02e}",          -- 书签
    star = "\u{f005}",              -- 星星
    heart = "\u{f004}",             -- 心形
    user = "\u{f007}",              -- 用户
    users = "\u{f0c0}",             -- 多用户
    lock = "\u{f023}",              -- 锁
    unlock = "\u{f09c}",            -- 解锁
    print = "\u{f02f}",             -- 打印
    share = "\u{f064}",             -- 分享
    link = "\u{f0c1}",              -- 链接
    palette = "\u{f53f}",           -- 调色板
    fill_drip = "\u{f576}",         -- 填充
}

-- ========== Material Design Icons 图标 Unicode 编码 ==========
-- 下载地址: https://github.com/google/material-design-icons/raw/master/font/MaterialIcons-Regular.ttf
-- 或: https://github.com/Templarian/MaterialDesign-Webfont

Icons.MDI = {
    -- 文件操作
    file = "\u{e24d}",
    folder = "\u{e2c7}",
    save = "\u{e161}",
    save_as = "\u{eb60}",
    
    -- 编辑
    cut = "\u{e14e}",
    copy = "\u{e14d}",
    paste = "\u{e14f}",
    delete = "\u{e872}",
    undo = "\u{e166}",
    redo = "\u{e15a}",
    
    -- 对齐
    format_align_left = "\u{e236}",
    format_align_center = "\u{e234}",
    format_align_right = "\u{e237}",
    vertical_align_top = "\u{e25e}",
    vertical_align_center = "\u{e25d}",
    vertical_align_bottom = "\u{e258}",
    
    -- 缩放
    zoom_in = "\u{e8ff}",
    zoom_out = "\u{e900}",
    zoom_out_map = "\u{e56b}",
    
    -- 视图
    grid_on = "\u{e3ec}",
    grid_off = "\u{e3eb}",
    view_module = "\u{e8f3}",
    view_list = "\u{e8ef}",
    
    -- 其他
    settings = "\u{e8b8}",
    home = "\u{e88a}",
    add = "\u{e145}",
    remove = "\u{e15b}",
    close = "\u{e5cd}",
    check = "\u{e5ca}",
    image = "\u{e3f4}",
}

-- ========== 简单 ASCII 图标（备用方案，无需额外字体）==========
Icons.ASCII = {
    -- 文件操作
    new = "[+]",
    open = "[O]",
    save = "[S]",
    save_as = "[A]",
    
    -- 编辑
    cut = "[X]",
    copy = "[C]",
    paste = "[V]",
    delete = "[D]",
    undo = "[<]",
    redo = "[>]",
    
    -- 对齐
    align_left = "[|<",
    align_center = "[|]",
    align_right = ">|]",
    align_top = "[-]",
    align_middle = "[=]",
    align_bottom = "[_]",
    
    -- 分布
    distribute_h = "<->",
    distribute_v = "^v^",
    
    -- 缩放
    zoom_in = "[+]",
    zoom_out = "[-]",
    zoom_reset = "[1]",
    
    -- 视图
    grid = "[#]",
    snap = "[.]",
    
    -- 面板
    toolbox = "[T]",
    properties = "[P]",
    pages = "[L]",
    
    -- 导出
    export = "[E]",
    export_image = "[I]",
}

-- ========== 中文简写图标（当前使用，兼容 SimHei）==========
Icons.CN = {
    -- 文件操作
    new = "新",
    open = "开",
    save = "存",
    save_as = "另",
    
    -- 编辑
    cut = "剪",
    copy = "复",
    paste = "贴",
    delete = "删",
    undo = "撤",
    redo = "重",
    
    -- 对齐
    align_left = "左",
    align_center = "中",
    align_right = "右",
    align_top = "上",
    align_middle = "央",
    align_bottom = "下",
    
    -- 分布
    distribute_h = "横",
    distribute_v = "竖",
    
    -- 缩放
    zoom_in = "+",
    zoom_out = "-",
    zoom_reset = "1:1",
    
    -- 视图
    grid = "#",
    snap = "齐",
    
    -- 面板
    toolbox = "工",
    properties = "属",
    pages = "页",
    
    -- 导出
    export = "导",
    export_image = "图",
}

-- 当前使用的图标集（默认使用中文简写）
Icons.current = Icons.CN

-- 切换图标集
function Icons.use(icon_set)
    if icon_set == "fa" or icon_set == "fontawesome" then
        Icons.current = Icons.FA
    elseif icon_set == "mdi" or icon_set == "material" then
        Icons.current = Icons.MDI
    elseif icon_set == "ascii" then
        Icons.current = Icons.ASCII
    elseif icon_set == "cn" or icon_set == "chinese" then
        Icons.current = Icons.CN
    end
end

-- 获取图标
function Icons.get(name)
    return Icons.current[name] or "?"
end

return Icons
