-- 测试正确的token传递方式
print("=== 测试正确的token传递 ===")

-- 启动网络
lvgl.start_network_service()

-- 等待网络初始化
local t = os.clock()
while (os.clock() - t) * 1000 < 300 do end

print("开始查询...")

-- 正确的参数顺序
local ok, result = lvgl.query_sync(
    "192.168.0.99",                    -- server_url
    "scadaToken",                      -- token (直接传递，不需要key-value对)
    '["THmeter.AirRoomTemp1"]',        -- ids_json
    100,                                 -- count (数字)
    60,                                -- period (数字)
    "2026-01-06 13:11:00",            -- start_time
    "2026-01-07 13:11:00",            -- end_time
    "LAST"                             -- agg_type
)

print("结果状态:", ok)
print("响应内容:", result)

if ok then
    -- 解析JSON响应
    local code = result:match('"code":"([^"]+)"')
    if code == "200" then
        print("✅ 查询成功!")
        
        -- 提取数据
        local data = result:match('"data":%s*(%[.*%])')
        if data then
            print("数据:", data)
        end
    else
        print("❌ 业务错误，code:", code)
    end
else
    print("❌ 查询失败:", result)
end

print("\n=== 测试结束 ===")