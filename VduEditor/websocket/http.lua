-- 启动网络服务
lvgl.start_network_service()

local server = "192.168.1.230"
local token = "scadaToken"

-- 使用调试版本查看详细请求信息
local success, response = lvgl.get_real_data(server, token, 2, 6)
