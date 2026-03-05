print("进入")
local lvgl = require("lvgl")
print("lvgl type:", type(lvgl))

-- 全局引用 label，以便在回调中使用
local g_label = nil

-- 启动网络服务
lvgl.start_network_service(100)

-- 创建界面
local scr = lvgl.scr_act()

local btn = lvgl.btn_create(scr)
btn:set_size(200, 100)
btn:set_pos(200, 200)

local btn_text = lvgl.label_create(btn)
btn_text:set_text("42")
btn_text:set_style_text_font(24)

-- 创建用于显示数值的标签
g_label = lvgl.label_create(scr)
g_label:set_text("等待数据...")
g_label:set_style_text_font(24)
g_label:set_size(200, 100)
g_label:set_pos(600, 200)
g_label:set_style_bg_opa(lvgl.OPA_COVER, 0)  -- 完全不透明
g_label:set_style_bg_color(0x4CAF50, 0)     -- 绿色背景


-- ✅ 为按钮添加点击事件回调
btn:add_event_cb(function(event_code)
    if event_code == lvgl.EVENT_CLICKED then
        print("按钮被点击！正在写入...")
        
        -- 执行写操作：Device2.tag0001 = "42"
        local success = lvgl.write("Device1.E", "42")
        
        if success then
            print("✅ 写入成功")
        else
            print("❌ 写入失败")
        end
    end
end, lvgl.EVENT_CLICKED)







lvgl.set_callbacks(
    -- 连接状态回调
    function(connected)
        if connected then
         
            lvgl.read("Device1.E")  -- 请求读取
        else
            
            if g_label then
                g_label:set_text("连接断开")
            end
        end
    end,

    -- 数据接收回调（关键！）
    function(device_id, value, status)
        print("📡 Received:", device_id, "=", value, "(status:", status, ")")
       
                g_label:set_text(value)
            
    end,

    -- 错误回调
    function(err)
        print("⚠️ WebSocket error:", err)
        if g_label then
            g_label:set_text("错误:" .. tostring(err))
        end
    end
)

print("开始连接 WebSocket")
lvgl.connect("ws://192.168.0.99:8085/ws/", 3000)