print("进入")
local lvgl = require("lvgl")
print("lvgl type:", type(lvgl))

-- 引入DataManager（核心修改）
local DataManager = require("editor.DataManager")

-- 全局引用 label，以便在回调中使用
local g_label = nil

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

-- 设置DataManager的外部回调（关键：保留你的自定义逻辑）
DataManager.set_external_callback({
    -- 连接状态回调
    on_connect = function(connected)
        if connected then
            print("连接成功，开始读取数据...")
            DataManager.read("THmeter.AirRoomTemp1")  -- 请求读取
        else
            if g_label then
                g_label:set_text("连接断开")
            end
        end
    end,
    -- 数据接收回调
    on_data = function(device_id, value, status)
        print("📡 Received:", device_id, "=", value, "(status:", status, ")")
        if g_label then
            g_label:set_text(value)
        end
    end,
    -- 错误回调
    on_error = function(err)
        print("⚠️ WebSocket error:", err)
        if g_label then
            g_label:set_text("错误:" .. tostring(err))
        end
    end
})

-- ✅ 为按钮添加点击事件回调
btn:add_event_cb(function(event_code)
    if event_code == lvgl.EVENT_CLICKED then
        print("按钮被点击！正在写入...")
        
        -- 改用DataManager写入（核心修改）
        DataManager.write("Device1.E", "42")
        print("✅ 写入请求已发送")
    end
end, lvgl.EVENT_CLICKED)

print("开始连接 WebSocket")
-- DataManager.init() 会自动启动网络服务，无需手动调用
lvgl.connect("ws://192.168.0.80:8085/ws/", 3000)