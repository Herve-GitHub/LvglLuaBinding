print("进入")
local lvgl = require("lvgl")
local DataManager = require("datamanager")
print("lvgl type:", type(lvgl))

-- 启动网络服务（由 DataManager 内部管理，但需要手动调用一次）
-- DataManager 的 init 方法中会调用 lvgl.start_network_service
-- 但为了确保网络服务启动，可以显式调用
lvgl.start_network_service(100)
-- 初始化 DataManager（会自动设置回调并启动连接）
DataManager.init()
-- 创建界面
local scr = lvgl.scr_act()

-- 创建按钮
local btn = lvgl.btn_create(scr)
btn:set_size(200, 100)
btn:set_pos(200, 200)

local btn_text = lvgl.label_create(btn)
btn_text:set_text("42")
btn_text:set_style_text_font(24)

-- 创建用于显示数值的标签
local g_label = lvgl.label_create(scr)
g_label:set_text("等待数据...")
g_label:set_style_text_font(24)
g_label:set_size(200, 100)
g_label:set_pos(600, 200)
g_label:set_style_bg_opa(lvgl.OPA_COVER, 0)
g_label:set_style_bg_color(0x4CAF50, 0)
print("标签1创建成功:", type(g_label))

local g_label2 = lvgl.label_create(scr)
g_label2:set_text("等待数据...")
g_label2:set_style_text_font(24)
g_label2:set_size(200, 100)
g_label2:set_pos(600, 400)
g_label2:set_style_bg_opa(lvgl.OPA_COVER, 0)
g_label2:set_style_bg_color(0x4CAF50, 0)
print("标签2创建成功:", type(g_label2))

local g_label3 = lvgl.label_create(scr)
g_label3:set_text("等待数据...")
g_label3:set_style_text_font(24)
g_label3:set_size(200, 100)
g_label3:set_pos(200, 400)
g_label3:set_style_bg_opa(lvgl.OPA_COVER, 0)
g_label3:set_style_bg_color(0x4CAF50, 0)
print("标签3创建成功:", type(g_label3))

-- 注册标签到 DataManager
DataManager.register_label("THmeter.AirRoomTemp1", g_label)
DataManager.register_label("THmeter.AirRoomTemp2", g_label2)
DataManager.register_label("THmeter.AirRoomTemp3", g_label3)

-- 测试标签是否能正常更新（通过 DataManager 读取）
print("测试标签更新...")
-- 直接设置标签文本进行测试
g_label:set_text("测试123")
g_label2:set_text("测试456")
g_label3:set_text("测试789")
print("标签测试完成")

-- 按钮点击事件：写入数据
btn:add_event_cb(function(event_code)
    if event_code == lvgl.EVENT_CLICKED then
        print("按钮被点击！正在写入...")
        local success = DataManager.write("Device1.E", "42")
        if success then
            print("✅ 写入成功")
        else
            print("❌ 写入失败")
        end
    end
end, lvgl.EVENT_CLICKED)

-- 设置外部回调（用于打印接收到的数据，可选）
DataManager.set_external_callback({
    on_connect = function(connected)
        print("📡 WebSocket 连接状态:", connected)
    end,
    on_data = function(device_id, value, status)
        -- 打印接收到的数据
        print("📡 收到数据:", device_id, "=", value, "(status:", status, ")")
        -- 注意：DataManager 已经自动更新了标签，这里只需要做额外处理
        -- 如果需要额外逻辑，可以在这里添加
    end,
    on_error = function(err)
        print("⚠️ WebSocket 错误:", err)
    end
})

-- 初始化 DataManager（会自动设置回调并启动连接）
DataManager.init()

print("开始连接 WebSocket")
lvgl.connect("ws://192.168.0.80:8085/ws/", 3000)
print("连接函数调用完成")

-- 可选：启动轮询（如果需要自动定时读取）
-- DataManager.poll_enabled = true
-- DataManager.start_polling()