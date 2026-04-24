-- 1. 先启动网络
lvgl.start_network_service()

-- 2. 准备参数
local ip_port = "192.168.0.68"
local token = "scadaToken"
local ids = '["Device2.tag0001","Device2.tag0002"]'
local startTime = "2026-04-14 13:12:31"
local endTime = "2026-04-21 13:12:31"
local count = 100

-- 3. 调用历史数据查询
local ok, json = lvgl.query_sync(
    ip_port,
    token,
    ids,
    startTime,
    endTime,
    count
)

-- 4. 结果
print("查询成功:", ok)
print("返回数据:", json)