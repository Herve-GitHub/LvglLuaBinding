lvgl.start_network_service()

local server = "192.168.1.230"
local token = "scadaToken"

-- 1. 获取标签树
local ok, json = lvgl.get_tags_tree(server, token)

-- 2. 解析成 Lua 表
local tag_list = lvgl.parse_tags_tree(json)

-- 3. 提取所有点位 ID → 存入 data_points
local data_points = {}
for i, tag in ipairs(tag_list) do
    table.insert(data_points, tag.id)  -- 只保存 id
end

-- 4. 固定的 websocket 地址（你给的原样）
local websocket_urls = {
    "ws://192.168.0.100:8085/ws",
    "ws://192.168.0.60:8085/ws",
    "ws://192.168.0.99:8085/ws",
    "ws://localhost:8085/ws",
    "ws://192.168.0.16:8085/ws/",
    "ws://192.168.0.80:8085/ws/",
    "ws://192.168.1.230:8085/ws/"
}

-- 5. 组合成最终JSON结构
local result = {
    data_points = data_points,
    websocket_urls = websocket_urls
}

-- 6. 保存到 data_editor_config.json 文件（直接覆盖！）
local json = require("json")
local json_str = json.encode(result, {indent = true}) -- 格式化输出

local f = io.open("data_editor_config.json", "w")
f:write(json_str)
f:close()

-- 7. 打印提示
print("\n✅ 成功保存到 data_editor_config.json")
print("📌 数据点数量：", #result.data_points)