-- 存储所有标签的表格
local g_labels = {}

-- 启动网络服务
lvgl.start_network_service(100)
lvgl.connect("ws://192.168.1.230:8085/ws/", 3000)

-- 创建界面
local scr = lvgl.scr_act()

-- 定义要显示的数据点
local data_points = {
    {id = "暖通空调.AirRoomTemp1", name = "空调房温度1", x = 20, y = 20},
    {id = "暖通空调.AirRoomTemp2", name = "空调房温度2", x = 20, y = 80},
    {id = "暖通空调.AirRoomTemp3", name = "空调房温度3", x = 20, y = 140},
    {id = "暖通空调.CoilTemp", name = "盘管温度", x = 20, y = 200},
    {id = "暖通空调.DRoomTemp", name = "配电室温度", x = 20, y = 260}
}

-- 创建用于显示各个数据点的标签
for i, point in ipairs(data_points) do
    -- 创建容器面板
    local panel = lvgl.obj_create(scr)
    panel:set_size(250, 50)
    panel:set_pos(point.x, point.y)
    panel:set_style_bg_opa(lvgl.OPA_COVER, 0)
    panel:set_style_bg_color(0x2C3E50, 0)  -- 深色背景
    panel:set_style_border_width(1, 0)
    panel:set_style_border_color(0xECF0F1, 0)
    panel:set_style_radius(5, 0)
    
    -- 创建名称标签
    local name_label = lvgl.label_create(panel)
    name_label:set_text(point.name .. ":")
    name_label:set_style_text_font(18)
    name_label:set_pos(10, 12)
    name_label:set_style_text_color(0xECF0F1, 0)
    
    -- 创建数值标签
    local value_label = lvgl.label_create(panel)
    value_label:set_text("等待数据...")
    value_label:set_style_text_font(20)
    value_label:set_pos(120, 10)
    value_label:set_style_text_color(0x4CAF50, 0)
    
    -- 存储标签信息
    g_labels[point.id] = {
        value_label = value_label,
        name = point.name
    }
end

-- 创建状态显示标签（可选）
local status_label = lvgl.label_create(scr)
status_label:set_text("状态: 等待连接...")
status_label:set_style_text_font(16)
status_label:set_pos(20, 340)
status_label:set_size(300, 30)
status_label:set_style_text_color(0xFFC107, 0)

-- 设置回调函数
lvgl.set_callbacks(
    -- 🔥🔥🔥 只有这里被我改成【批量一次读取】🔥🔥🔥
    function(connected)
        if connected then
            status_label:set_text("状态: 已连接，订阅完成...")
            
            -- ✅ 批量一次发送所有标签，只发1条指令
            local ids = {}
            for id, _ in pairs(g_labels) do
                table.insert(ids, id)
            end
            lvgl.read(table.unpack(ids))  -- 一次订阅全部
        else
            status_label:set_text("状态: 连接断开")
            for _, label_info in pairs(g_labels) do
                label_info.value_label:set_text("---")
            end
        end
    end,

    -- 数据接收回调（完全不用改）
    function(device_id, value, status)
        print("Received:", device_id, "=", value, "(status:", status, ")")
        
        -- 更新对应的标签
        if g_labels[device_id] then
            if status == "Good" then
                g_labels[device_id].value_label:set_text(value)
                g_labels[device_id].value_label:set_style_text_color(0x4CAF50, 0)
            else
                g_labels[device_id].value_label:set_text("错误")
                g_labels[device_id].value_label:set_style_text_color(0xFF5252, 0)
            end
        end
        
        status_label:set_text(string.format("状态: 最后更新 %s = %s", device_id, value))
    end
)