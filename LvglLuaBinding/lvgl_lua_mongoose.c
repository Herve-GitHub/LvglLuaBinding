

// 解决Windows头文件冲突
#define WIN32_LEAN_AND_MEAN
#define _WINSOCKAPI_
#include <windows.h>

#include "lvgl_lua_bindings_internal.h"
#include <cJSON.h>
#include <string.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>

// ===== 跨平台线程同步 =====
#ifdef _WIN32
// Windows平台使用CRITICAL_SECTION
typedef CRITICAL_SECTION lv_mutex_t;
#define MUTEX_INIT(m) InitializeCriticalSection(&m)
#define MUTEX_LOCK(m) EnterCriticalSection(&m)
#define MUTEX_UNLOCK(m) LeaveCriticalSection(&m)
#define MUTEX_DESTROY(m) DeleteCriticalSection(&m)
#define SLEEP_MS(ms) Sleep(ms)
#else
#include <pthread.h>
#include <unistd.h>  // for usleep
typedef pthread_mutex_t lv_mutex_t;
#define MUTEX_INIT(m) pthread_mutex_init(&m, NULL)
#define MUTEX_LOCK(m) pthread_mutex_lock(&m)
#define MUTEX_UNLOCK(m) pthread_mutex_unlock(&m)
#define MUTEX_DESTROY(m) pthread_mutex_destroy(&m)
#define SLEEP_MS(ms) usleep((ms) * 1000)
#endif

// ===== Mongoose 库头文件 =====
#include "mongoose.h"

// ===== 全局变量定义（修复重复定义问题）=====
static struct mg_mgr mgr;                  // WebSocket 管理器
static struct mg_mgr sync_mgr;             // 同步HTTP查询管理器
static struct mg_connection* ws_conn = NULL;
static int is_connected = 0;
static int connection_initialized = 0;
static int sync_mgr_initialized = 0;
static lv_mutex_t ws_mutex;  // 统一的互斥锁                   // 统一的互斥锁（修复重复定义）

// ===== 重连相关配置 =====
static int max_reconnect_attempts = 5;
static int reconnect_attempts = 0;
static time_t last_reconnect_time = 0;
static char saved_url[256] = "";

// ===== 连接状态结构体 =====
typedef struct {
    int connecting;      // 正在连接
    int last_error;      // 最后错误码
    char error_msg[256]; // 错误信息
    time_t connect_time; // 连接开始时间
    int timeout_ms;      // 连接超时时间
} WSConnectionState;

static WSConnectionState ws_state = { 0 };

// ===== Lua回调函数结构体 =====
typedef struct {
    int lua_connect_callback_ref;    // 连接状态回调
    int lua_message_callback_ref;    // 消息接收回调
    int lua_error_callback_ref;      // 错误回调
    lua_State* L;
} LuaWebSocketCallbacks;

static LuaWebSocketCallbacks ws_callbacks = { 0 };

// ===== 修改：同步查询数据结构（使用堆分配）=====
typedef struct {
    bool completed;
    int status_code;
    char response_json[4096];
    lv_timer_t* timeout_timer;
    struct mg_connection* conn;  // 保存连接指针
} SyncQueryData;


static SyncQueryData sync_ctx = { 0 };


// ===== 函数声明 =====
static void ws_event_handler(struct mg_connection* c, int ev, void* ev_data, void* fn_data);
static void network_timer_cb(lv_timer_t* timer);
/*static void sync_query_handler(struct mg_connection* c, int ev, void* ev_data, void* fn_data);
static void sync_query_timeout_cb(lv_timer_t* timer);
static char* build_history_json(const char* ids_json, int count, int period,
    const char* start_time, const char* end_time,
    const char* agg_type);
static void init_sync_network_manager(void);
static void try_reconnect(void);*/
static void try_reconnect(void);



// ===== 同步查询超时回调 =====
static void sync_query_timeout_cb(lv_timer_t* timer) {
    SyncQueryData* ctx = (SyncQueryData*)lv_timer_get_user_data(timer);
    if (!ctx) return;

    if (!ctx->completed) {
        printf("[SYNC_QUERY] Timeout reached - forcing completion\n");
        ctx->completed = true;
        ctx->status_code = -2;  // -2 表示超时
        snprintf(ctx->response_json, sizeof(ctx->response_json), "Timeout waiting for response");
    }
    else {
        printf("[SYNC_QUERY] Timeout triggered but already completed, ignoring\n");
    }

    // 释放定时器
    lv_timer_del(timer);
}

// ===== 同步查询事件处理器 =====
static void sync_query_handler(struct mg_connection* c, int ev, void* ev_data, void* fn_data) {
   

    if (ev == MG_EV_HTTP_MSG) {
        struct mg_http_message* hm = (struct mg_http_message*)ev_data;

        sync_ctx.status_code = mg_http_status(hm);

        printf("[SYNC_HANDLER] Response status: %d, body len: %d\n",
            sync_ctx.status_code, (int)hm->body.len);

        // 复制响应体
        if (hm->body.len > 0 && hm->body.buf) {
            size_t copy_len = hm->body.len;
            if (copy_len > sizeof(sync_ctx.response_json) - 1) {
                copy_len = sizeof(sync_ctx.response_json) - 1;
            }
            memcpy(sync_ctx.response_json, hm->body.buf, copy_len);
            sync_ctx.response_json[copy_len] = '\0';
        }
        else {
            sync_ctx.response_json[0] = '\0';
        }

        // 标记请求完成
        sync_ctx.completed = true;

        printf("[SYNC_HANDLER] Marked completed: %s\n", sync_ctx.response_json);

        // 主动关闭连接
        c->is_closing = 1;
    }
    else if (ev == MG_EV_ERROR) {
        const char* error_msg = (const char*)ev_data;
        printf("[SYNC_HANDLER] Error: %s\n", error_msg ? error_msg : "unknown");

        sync_ctx.status_code = -1;
        snprintf(sync_ctx.response_json, sizeof(sync_ctx.response_json),
            "Network error: %s", error_msg ? error_msg : "unknown");
        sync_ctx.completed = true;
    }
    else if (ev == MG_EV_CLOSE) {
        printf("[SYNC_HANDLER] Connection closed\n");
        sync_ctx.conn = NULL;
    }
}

// ===== 构建历史查询JSON =====
static char* build_history_json(const char* ids_json, int count, int period,
    const char* start_time, const char* end_time,
    const char* agg_type) {
    if (!ids_json) return NULL;

    // 动态计算缓冲区大小，避免固定1024的限制
    size_t base_len = strlen(ids_json) + strlen(agg_type) + 100;
    size_t time_len = (start_time ? strlen(start_time) : 0) + (end_time ? strlen(end_time) : 0);
    char* json_body = (char*)malloc(base_len + time_len);

    if (!json_body) return NULL;

    if (strlen(start_time) > 0 && strlen(end_time) > 0) {
        snprintf(json_body, base_len + time_len,
            "{\"ids\":%s,\"count\":%d,\"period\":%d,"
            "\"startTime\":\"%s\",\"endTime\":\"%s\","
            "\"aggType\":\"%s\"}",
            ids_json, count, period, start_time, end_time, agg_type);
    }
    else {
        snprintf(json_body, base_len + time_len,
            "{\"ids\":%s,\"count\":%d,\"period\":%d,"
            "\"aggType\":\"%s\"}",
            ids_json, count, period, agg_type);
    }

    return json_body;
}

// ===== 初始化同步网络管理器 =====
static void init_sync_network_manager(void) {
    if (!sync_mgr_initialized) {
        printf("[SYNC_NET] Initializing sync network manager\n");
        mg_mgr_init(&sync_mgr);
        sync_mgr_initialized = 1;
        printf("[SYNC_NET] Sync network manager initialized\n");
    }
}

// ===== 同步查询历史数据 =====
static int lua_query_history_sync(lua_State* L) {
    const char* server_url = luaL_checkstring(L, 1);
    const char* token = luaL_checkstring(L, 2);
    const char* ids_json = luaL_checkstring(L, 3);

    int count = luaL_optinteger(L, 4, 100);
    int period = luaL_optinteger(L, 5, 60);
    const char* start_time = luaL_optstring(L, 6, "");
    const char* end_time = luaL_optstring(L, 7, "");
    const char* agg_type = luaL_optstring(L, 8, "LAST");

    printf("\n[HISTORY_SYNC] Querying history data...\n");
    printf("  Server: %s\n", server_url);
    printf("  IDs: %s\n", ids_json);

    // 重置全局上下文
    memset(&sync_ctx, 0, sizeof(SyncQueryData));

    // 确保同步管理器已初始化
    init_sync_network_manager();

    // 构建JSON请求体
    char* json_body = build_history_json(ids_json, count, period, start_time, end_time, agg_type);
    if (!json_body) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Failed to build JSON");
        return 2;
    }

    // 构建请求URL
    char url[512];
    snprintf(url, sizeof(url), "http://%s/scada/aggQueryHistory", server_url);

    printf("[HISTORY_SYNC] URL: %s\n", url);

    // 创建HTTP连接
    struct mg_connection* conn = mg_http_connect(&sync_mgr, url, sync_query_handler, NULL);
    if (!conn) {
        free(json_body);
        lua_pushboolean(L, false);
        lua_pushstring(L, "Failed to create connection");
        return 2;
    }
    sync_ctx.conn = conn;

    // 发送HTTP请求
    mg_printf(conn,
        "POST /scada/aggQueryHistory HTTP/1.1\r\n"
        "Host: %s\r\n"
        "Content-Type: application/json\r\n"
        "Authorization: %s\r\n"
        "Content-Length: %d\r\n"
        "Connection: close\r\n"
        "\r\n"
        "%s",
        server_url,
        token,
        (int)strlen(json_body),
        json_body
    );

    free(json_body);

    printf("[HISTORY_SYNC] Request sent, waiting for response...\n");

    // 设置超时定时器（5秒）
    lv_timer_t* timeout_timer = lv_timer_create(sync_query_timeout_cb, 5000, &sync_ctx);

    // 等待响应
    int timeout_ms = 5000;
    int poll_interval = 10;
    int max_polls = timeout_ms / poll_interval;
    int poll_count = 0;

    while (!sync_ctx.completed && poll_count < max_polls) {
        // 处理网络事件
        mg_mgr_poll(&sync_mgr, 0);

        // 处理LVGL定时器和任务
        lv_tick_inc(poll_interval);
        lv_timer_handler();

        poll_count++;
        SLEEP_MS(poll_interval);
    }

    // 删除超时定时器
    lv_timer_del(timeout_timer);

    printf("[HISTORY_SYNC] Loop finished: poll_count=%d, completed=%d, status=%d\n",
        poll_count, sync_ctx.completed, sync_ctx.status_code);

    // 判断业务是否成功
    bool business_success = false;
    const char* result_msg = sync_ctx.response_json;

    if (sync_ctx.completed) {
        if (sync_ctx.status_code == 200) {
            // HTTP状态200，检查业务状态
            if (strstr(sync_ctx.response_json, "\"code\":\"200\"") != NULL) {
                printf("[HISTORY_SYNC] SUCCESS: Business code 200\n");
                business_success = true;
            }
            else if (strstr(sync_ctx.response_json, "\"code\":\"401\"") != NULL) {
                printf("[HISTORY_SYNC] ERROR: Token invalid\n");
                business_success = false;
            }
            else if (strstr(sync_ctx.response_json, "\"code\"") != NULL) {
                printf("[HISTORY_SYNC] ERROR: Business error in response\n");
                business_success = false;
            }
            else {
                printf("[HISTORY_SYNC] WARNING: No business code in response\n");
                business_success = true;
            }
        }
        else {
            printf("[HISTORY_SYNC] ERROR: HTTP status %d\n", sync_ctx.status_code);
            business_success = false;
        }
    }
    else {
        printf("[HISTORY_SYNC] ERROR: Timeout\n");
        business_success = false;
        result_msg = "Request timeout (5000ms)";
    }

    // 返回结果
    lua_pushboolean(L, business_success);
    lua_pushstring(L, result_msg);

    // 清理连接
    if (sync_ctx.conn) {
        mg_close_conn(sync_ctx.conn);
        sync_ctx.conn = NULL;
    }

    // 最后处理剩余的网络事件
    for (int i = 0; i < 10; i++) {
        mg_mgr_poll(&sync_mgr, 1);
        SLEEP_MS(1);
    }

    return 2;
}

// ===== WebSocket事件处理器 =====
static void ws_event_handler(struct mg_connection* c, int ev, void* ev_data, void* fn_data) {
    MUTEX_LOCK(ws_mutex);

    if (ev == MG_EV_OPEN) {
        ws_state.connecting = 1;
    }
    else if (ev == MG_EV_WS_OPEN) {
        printf("[WS_EVENT] WebSocket connected!\n");
        is_connected = 1;
        ws_conn = c;
        ws_state.connecting = 0;
        ws_state.last_error = 0;
        reconnect_attempts = 0; // 重置重连计数

        // 调用Lua连接回调
        if (ws_callbacks.lua_connect_callback_ref && ws_callbacks.L) {
            lua_State* L = ws_callbacks.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_connect_callback_ref);
            lua_pushboolean(L, true);
            lua_pushstring(L, "connected");

            if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
                const char* err = lua_tostring(L, -1);
                printf("[WS_EVENT] Lua callback error: %s\n", err);
                lua_pop(L, 1);
            }
        }
    }
    else if (ev == MG_EV_WS_MSG) {
        struct mg_ws_message* wm = (struct mg_ws_message*)ev_data;
        const char* json_data = (const char*)wm->data.buf;

        // 打印原始消息（调试用，可根据需要注释）
        printf("[WS_EVENT] Received WS message: %.*s\n", (int)wm->data.len, json_data);

        // 解析JSON数据
        cJSON* root = cJSON_Parse(json_data);

        if (root) {
            cJSON* code = cJSON_GetObjectItemCaseSensitive(root, "code");
            cJSON* data = cJSON_GetObjectItemCaseSensitive(root, "data");
            cJSON* id = cJSON_GetObjectItemCaseSensitive(root, "id");
            cJSON* val = cJSON_GetObjectItemCaseSensitive(root, "val");
            cJSON* status = cJSON_GetObjectItemCaseSensitive(root, "status");

            // ✅ 修复1：兼容多种合法JSON格式，避免数据丢失
            // 场景1：直接包含id/val的基础格式（写操作响应/单条数据）
            if (cJSON_IsString(id) && cJSON_IsString(val)) {
                if (ws_callbacks.lua_message_callback_ref && ws_callbacks.L) {
                    lua_State* L = ws_callbacks.L;
                    lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_message_callback_ref);
                    lua_pushstring(L, id->valuestring);
                    lua_pushstring(L, val->valuestring);
                    lua_pushstring(L, status && cJSON_IsString(status) ? status->valuestring : "Good");

                    if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
                        const char* err = lua_tostring(L, -1);
                        printf("[WS_EVENT] Lua callback error: %s\n", err);
                        lua_pop(L, 1);
                    }
                }
            }
            // 场景2：data为数组的批量数据格式（读操作响应）
            else if (cJSON_IsArray(data)) {
                int count = cJSON_GetArraySize(data);
                // 处理设备数据数组
                for (int i = 0; i < count; i++) {
                    cJSON* item = cJSON_GetArrayItem(data, i);
                    if (item) {
                        cJSON* item_id = cJSON_GetObjectItemCaseSensitive(item, "id");
                        cJSON* item_val = cJSON_GetObjectItemCaseSensitive(item, "val");
                        cJSON* item_status = cJSON_GetObjectItemCaseSensitive(item, "status");

                        if (cJSON_IsString(item_id) && cJSON_IsString(item_val)) {
                            if (ws_callbacks.lua_message_callback_ref && ws_callbacks.L) {
                                lua_State* L = ws_callbacks.L;
                                lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_message_callback_ref);
                                lua_pushstring(L, item_id->valuestring);
                                lua_pushstring(L, item_val->valuestring);
                                lua_pushstring(L, item_status && cJSON_IsString(item_status) ? item_status->valuestring : "Good");

                                if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
                                    const char* err = lua_tostring(L, -1);
                                    printf("[WS_EVENT] Lua callback error: %s\n", err);
                                    lua_pop(L, 1);
                                }
                            }
                        }
                        else {
                            printf("[WS_EVENT] Invalid item format at index %d: missing id/val or non-string type\n", i);
                        }
                    }
                }
            }
            // 场景3：其他合法格式（打印日志，便于调试）
            else {
                printf("[WS_EVENT] Unhandled valid JSON format (no id/val or array data): %s\n", json_data);
            }

            cJSON_Delete(root);
        }
        else {
            // ✅ 修复2：JSON解析失败时，保持3个参数格式，避免Lua回调参数不匹配报错
            printf("[WS_EVENT] JSON parse failed, raw data: %.*s\n", (int)wm->data.len, (const char*)wm->data.buf);
            if (ws_callbacks.lua_message_callback_ref && ws_callbacks.L) {
                lua_State* L = ws_callbacks.L;
                lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_message_callback_ref);
                // 保持3个参数格式：原始数据、空值、错误状态
                lua_pushlstring(L, (const char*)wm->data.buf, wm->data.len);
                lua_pushstring(L, "");
                lua_pushstring(L, "JSON Parse Error");

                if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
                    const char* err = lua_tostring(L, -1);
                    printf("[WS_EVENT] Lua callback error: %s\n", err);
                    lua_pop(L, 1);
                }
            }
        }
    }
    else if (ev == MG_EV_ERROR) {
        const char* error_msg = (const char*)ev_data;
        printf("[WS_EVENT] Error: %s\n", error_msg ? error_msg : "unknown");

        is_connected = 0;
        ws_conn = NULL;
        ws_state.connecting = 0;
        ws_state.last_error = -1;

        if (error_msg) {
            snprintf(ws_state.error_msg, sizeof(ws_state.error_msg), "%s", error_msg);
        }

        // 调用Lua错误回调
        if (ws_callbacks.lua_error_callback_ref && ws_callbacks.L) {
            lua_State* L = ws_callbacks.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_error_callback_ref);
            lua_pushstring(L, error_msg ? error_msg : "unknown error");

            if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                const char* err = lua_tostring(L, -1);
                printf("[WS_EVENT] Lua error callback error: %s\n", err);
                lua_pop(L, 1);
            }
        }

        // 触发重连
        try_reconnect();
    }
    else if (ev == MG_EV_CLOSE) {
        printf("[WS_EVENT] Connection closed\n");

        is_connected = 0;
        ws_conn = NULL;
        ws_state.connecting = 0;

        // 调用Lua断开连接回调
        if (ws_callbacks.lua_connect_callback_ref && ws_callbacks.L) {
            lua_State* L = ws_callbacks.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_connect_callback_ref);
            lua_pushboolean(L, false);
            lua_pushstring(L, "disconnected");

            if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
                const char* err = lua_tostring(L, -1);
                printf("[WS_EVENT] Lua callback error: %s\n", err);
                lua_pop(L, 1);
            }
        }

        // 触发重连
        try_reconnect();
    }

    MUTEX_UNLOCK(ws_mutex);
}
// ===== WebSocket事件处理器 =====
/*static void ws_event_handler(struct mg_connection* c, int ev, void* ev_data, void* fn_data) {
    MUTEX_LOCK(ws_mutex);

    if (ev == MG_EV_OPEN) {
        ws_state.connecting = 1;
    }
    else if (ev == MG_EV_WS_OPEN) {
        printf("[WS_EVENT] WebSocket connected!\n");
        is_connected = 1;
        ws_conn = c;
        ws_state.connecting = 0;
        ws_state.last_error = 0;
        reconnect_attempts = 0; // 重置重连计数

        // 调用Lua连接回调
        if (ws_callbacks.lua_connect_callback_ref && ws_callbacks.L) {
            lua_State* L = ws_callbacks.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_connect_callback_ref);
            lua_pushboolean(L, true);
            lua_pushstring(L, "connected");

            if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
                const char* err = lua_tostring(L, -1);
                printf("[WS_EVENT] Lua callback error: %s\n", err);
                lua_pop(L, 1);
            }
        }
    }
    else if (ev == MG_EV_WS_MSG) {
        struct mg_ws_message* wm = (struct mg_ws_message*)ev_data;

        // 解析JSON数据
        const char* json_data = (const char*)wm->data.buf;
        cJSON* root = cJSON_Parse(json_data);

        if (root) {
            cJSON* code = cJSON_GetObjectItemCaseSensitive(root, "code");
            cJSON* data = cJSON_GetObjectItemCaseSensitive(root, "data");

            if (cJSON_IsNumber(code) && code->valueint == 200 && cJSON_IsArray(data)) {
                int count = cJSON_GetArraySize(data);

                // 处理设备数据数组
                for (int i = 0; i < count; i++) {
                    cJSON* item = cJSON_GetArrayItem(data, i);
                    if (item) {
                        cJSON* id = cJSON_GetObjectItemCaseSensitive(item, "id");
                        cJSON* val = cJSON_GetObjectItemCaseSensitive(item, "val");
                        cJSON* status = cJSON_GetObjectItemCaseSensitive(item, "status");

                        if (cJSON_IsString(id) && cJSON_IsString(val)) {
                            // 调用Lua消息回调
                            if (ws_callbacks.lua_message_callback_ref && ws_callbacks.L) {
                                lua_State* L = ws_callbacks.L;
                                lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_message_callback_ref);

                                lua_pushstring(L, id->valuestring);
                                lua_pushstring(L, val->valuestring);
                                lua_pushstring(L, status && cJSON_IsString(status) ? status->valuestring : "Unknown");

                                if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
                                    const char* err = lua_tostring(L, -1);
                                    printf("[WS_EVENT] Lua callback error: %s\n", err);
                                    lua_pop(L, 1);
                                }
                            }
                        }
                    }
                }
            }
            else if (cJSON_IsString(data)) {
                // 处理设备写操作响应
                cJSON* id = cJSON_GetObjectItemCaseSensitive(root, "id");
                cJSON* val = cJSON_GetObjectItemCaseSensitive(root, "val");

                if (cJSON_IsString(id) && cJSON_IsString(val)) {
                    // 调用Lua消息回调
                    if (ws_callbacks.lua_message_callback_ref && ws_callbacks.L) {
                        lua_State* L = ws_callbacks.L;
                        lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_message_callback_ref);

                        lua_pushstring(L, id->valuestring);
                        lua_pushstring(L, val->valuestring);
                        lua_pushstring(L, "Write Success");

                        if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
                            const char* err = lua_tostring(L, -1);
                            printf("[WS_EVENT] Lua callback error: %s\n", err);
                            lua_pop(L, 1);
                        }
                    }
                }
            }

            cJSON_Delete(root);
        }
        else {
            // JSON解析失败，传递原始消息
            if (ws_callbacks.lua_message_callback_ref && ws_callbacks.L) {
                lua_State* L = ws_callbacks.L;
                lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_message_callback_ref);
                lua_pushlstring(L, (const char*)wm->data.buf, wm->data.len);

                if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                    const char* err = lua_tostring(L, -1);
                    printf("[WS_EVENT] Lua callback error: %s\n", err);
                    lua_pop(L, 1);
                }
            }
        }
    }
    else if (ev == MG_EV_ERROR) {
        const char* error_msg = (const char*)ev_data;
        printf("[WS_EVENT] Error: %s\n", error_msg ? error_msg : "unknown");

        is_connected = 0;
        ws_conn = NULL;
        ws_state.connecting = 0;
        ws_state.last_error = -1;

        if (error_msg) {
            snprintf(ws_state.error_msg, sizeof(ws_state.error_msg), "%s", error_msg);
        }

        // 调用Lua错误回调
        if (ws_callbacks.lua_error_callback_ref && ws_callbacks.L) {
            lua_State* L = ws_callbacks.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_error_callback_ref);
            lua_pushstring(L, error_msg ? error_msg : "unknown error");

            if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                const char* err = lua_tostring(L, -1);
                printf("[WS_EVENT] Lua error callback error: %s\n", err);
                lua_pop(L, 1);
            }
        }

        // 触发重连
        try_reconnect();
    }
    else if (ev == MG_EV_CLOSE) {
        printf("[WS_EVENT] Connection closed\n");

        is_connected = 0;
        ws_conn = NULL;
        ws_state.connecting = 0;

        // 调用Lua断开连接回调
        if (ws_callbacks.lua_connect_callback_ref && ws_callbacks.L) {
            lua_State* L = ws_callbacks.L;
            lua_rawgeti(L, LUA_REGISTRYINDEX, ws_callbacks.lua_connect_callback_ref);
            lua_pushboolean(L, false);
            lua_pushstring(L, "disconnected");

            if (lua_pcall(L, 2, 0, 0) != LUA_OK) {
                const char* err = lua_tostring(L, -1);
                printf("[WS_EVENT] Lua callback error: %s\n", err);
                lua_pop(L, 1);
            }
        }

        // 触发重连
        try_reconnect();
    }

    MUTEX_UNLOCK(ws_mutex);
}*/

// ===== 网络定时器回调 =====
/*static void network_timer_cb(lv_timer_t* timer) {
    // 处理WebSocket事件
    if (connection_initialized) {
        mg_mgr_poll(&mgr, 10);
    }

    // 处理同步查询事件
    if (sync_mgr_initialized) {
        mg_mgr_poll(&sync_mgr, 10);
    }
}*/

static void network_timer_cb(lv_timer_t* timer) {
    // 改为非阻塞 poll（超时 0ms），避免阻塞 LVGL 定时器
    if (connection_initialized) {
        mg_mgr_poll(&mgr, 0); // ✅ 非阻塞，及时处理心跳事件
    }
    if (sync_mgr_initialized) {
        mg_mgr_poll(&sync_mgr, 0);
    }
    // 补充 LVGL 心跳更新（确保 UI 不卡顿）
    lv_tick_inc(50); // 定时器间隔 50ms，对应 tick 增量
}

// ===== Lua绑定：WebSocket连接 =====
static int lua_ws_connect(lua_State* L) {
    const char* url = luaL_checkstring(L, 1);
    int timeout_ms = luaL_optinteger(L, 2, 5000);

    printf("[WS_CONNECT] Attempting to connect to: %s\n", url);

    MUTEX_LOCK(ws_mutex);

    // 保存URL
    strncpy(saved_url, url, sizeof(saved_url) - 1);
    saved_url[sizeof(saved_url) - 1] = '\0';

    // 如果已有连接，先关闭
    if (ws_conn) {
        printf("[WS_CONNECT] Closing existing connection\n");
        mg_close_conn(ws_conn);
        ws_conn = NULL;
        is_connected = 0;
    }

    // 检查是否初始化
    if (!connection_initialized) {
        printf("[WS_CONNECT] ERROR: Network service not started!\n");
        printf("[WS_CONNECT] Call lvgl.start_network_service() first\n");
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
        return 1;
    }

    // 重置状态
    memset(&ws_state, 0, sizeof(WSConnectionState));
    ws_state.timeout_ms = timeout_ms;
    ws_state.connect_time = time(NULL);
    ws_state.connecting = 1;

    // 创建WebSocket连接
    struct mg_connection* conn = mg_ws_connect(&mgr, url, ws_event_handler, NULL, NULL);

    if (conn) {
        printf("[WS_CONNECT] SUCCESS: Connection object created\n");
        ws_conn = conn;
        ws_state.connecting = 1;
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, true);
    }
    else {
        printf("[WS_CONNECT] FAILED: Could not create connection\n");
        ws_state.last_error = -1;
        snprintf(ws_state.error_msg, sizeof(ws_state.error_msg),
            "Failed to create connection");
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
    }

    return 1;
}

// ===== Lua绑定：WebSocket发送消息 =====
static int lua_ws_send(lua_State* L) {
    size_t len = 0;
    const char* message = luaL_checklstring(L, 1, &len);

    MUTEX_LOCK(ws_mutex);

    if (ws_conn && is_connected) {
        // 发送WebSocket消息
        int bytes_sent = mg_ws_send(ws_conn, message, len, WEBSOCKET_OP_TEXT);

        if (bytes_sent > 0) {
            printf("Sent message: %s (%d bytes)\n", message, bytes_sent);
            lua_pushboolean(L, true);
            lua_pushinteger(L, bytes_sent);
            MUTEX_UNLOCK(ws_mutex);
            return 2;
        }
        else {
            printf("Send failed (returned %d)\n", bytes_sent);
            lua_pushboolean(L, false);
            lua_pushstring(L, "send failed");
            MUTEX_UNLOCK(ws_mutex);
            return 2;
        }
    }
    else {
        printf("Send failed: WebSocket not connected\n");
        lua_pushboolean(L, false);
        lua_pushstring(L, "not connected");
        MUTEX_UNLOCK(ws_mutex);
        return 2;
    }
}

// ===== Lua绑定：设置WebSocket回调 =====
static int lua_ws_set_callbacks(lua_State* L) {
    MUTEX_LOCK(ws_mutex);

    // 释放旧的回调引用
    if (ws_callbacks.lua_connect_callback_ref) {
        luaL_unref(L, LUA_REGISTRYINDEX, ws_callbacks.lua_connect_callback_ref);
        ws_callbacks.lua_connect_callback_ref = 0;
    }
    if (ws_callbacks.lua_message_callback_ref) {
        luaL_unref(L, LUA_REGISTRYINDEX, ws_callbacks.lua_message_callback_ref);
        ws_callbacks.lua_message_callback_ref = 0;
    }
    if (ws_callbacks.lua_error_callback_ref) {
        luaL_unref(L, LUA_REGISTRYINDEX, ws_callbacks.lua_error_callback_ref);
        ws_callbacks.lua_error_callback_ref = 0;
    }

    ws_callbacks.L = L;

    // 设置新的回调
    if (lua_isfunction(L, 1)) {
        lua_pushvalue(L, 1);
        ws_callbacks.lua_connect_callback_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }
    if (lua_isfunction(L, 2)) {
        lua_pushvalue(L, 2);
        ws_callbacks.lua_message_callback_ref = luaL_ref(L, LUA_REGISTRYINDEX);
        printf("[WS] Message callback set (new format: device_id, value, status)\n");
    }
    if (lua_isfunction(L, 3)) {
        lua_pushvalue(L, 3);
        ws_callbacks.lua_error_callback_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    MUTEX_UNLOCK(ws_mutex);
    return 0;
}

// ===== Lua绑定：获取WebSocket状态 =====
/*static int lua_ws_get_status(lua_State* L) {
    MUTEX_LOCK(ws_mutex);

    lua_newtable(L);

    lua_pushboolean(L, is_connected);
    lua_setfield(L, -2, "connected");

    lua_pushboolean(L, ws_conn != NULL);
    lua_setfield(L, -2, "has_connection");

    lua_pushinteger(L, ws_state.last_error);
    lua_setfield(L, -2, "last_error");

    lua_pushstring(L, ws_state.error_msg);
    lua_setfield(L, -2, "error_msg");

    MUTEX_UNLOCK(ws_mutex);
    return 1;
}
*/
// ===== Lua绑定：断开WebSocket连接 =====
static int lua_ws_disconnect(lua_State* L) {
    MUTEX_LOCK(ws_mutex);

    if (ws_conn) {
        mg_close_conn(ws_conn);
        ws_conn = NULL;
        is_connected = 0;
        saved_url[0] = '\0'; // 清空保存的URL，停止重连
        printf("WebSocket disconnected\n");
    }

    MUTEX_UNLOCK(ws_mutex);
    return 0;
}

static int lua_start_network_service(lua_State* L) {
    printf("lua_start_network_service Enter\n");

    static lv_timer_t* network_timer = NULL;
    static int mutex_inited = 0;

    // 初始化互斥锁（只执行一次）
    if (!mutex_inited) {
        MUTEX_INIT(ws_mutex);
        mutex_inited = 1;
    }

    MUTEX_LOCK(ws_mutex);

    // 如果网络服务已经运行，直接返回 true（而不是 false）
    if (network_timer != NULL) {
        printf("[NETWORK] Network service already running\n");
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, true);  // 改为返回 true
        return 1;
    }

    // 初始化 WebSocket 管理器
    if (!connection_initialized) {
        printf("[NETWORK] Initializing WebSocket manager...\n");
        mg_mgr_init(&mgr);
        connection_initialized = 1;
        printf("[NETWORK] WebSocket manager initialized\n");
    }

    // 初始化同步查询管理器
    if (!sync_mgr_initialized) {
        printf("[NETWORK] Initializing sync manager...\n");
        mg_mgr_init(&sync_mgr);
        sync_mgr_initialized = 1;
    }

    // 创建网络定时器
    printf("[NETWORK] Creating network timer...\n");
    network_timer = lv_timer_create(network_timer_cb, 50, NULL);
    if (network_timer) {
        lv_timer_set_repeat_count(network_timer, -1);
        printf("[NETWORK] Network timer created successfully\n");
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, true);
    }
    else {
        printf("[NETWORK] Failed to create network timer\n");
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
        lua_pushstring(L, "Failed to create timer");
        return 2;
    }

    printf("lua_start_network_service Exit\n");
    return 1;
}
// ===== 尝试重连 =====
/*static void try_reconnect(void) {
    MUTEX_LOCK(ws_mutex);

    // 如果已连接或有连接对象，不需要重连
    if (is_connected || ws_conn) {
        MUTEX_UNLOCK(ws_mutex);
        return;
    }

    // 检查重连次数限制
    if (reconnect_attempts >= max_reconnect_attempts) {
        time_t now = time(NULL);
        // 如果超过1分钟，重置重连计数
        if (now - last_reconnect_time > 60) {
            reconnect_attempts = 0;
        }
        else {
            MUTEX_UNLOCK(ws_mutex);
            return;
        }
    }

    // 检查是否有保存的URL
    if (strlen(saved_url) == 0) {
        MUTEX_UNLOCK(ws_mutex);
        return;
    }

    // 检查重连间隔
    time_t now = time(NULL);
    if (now - ws_state.connect_time < 2) {
        MUTEX_UNLOCK(ws_mutex);
        return;
    }

    printf("Attempting to reconnect to %s (attempt %d/%d)\n",
        saved_url, reconnect_attempts + 1, max_reconnect_attempts);

    // 创建新连接
    struct mg_connection* conn = mg_ws_connect(&mgr, saved_url, ws_event_handler, NULL, NULL);
    if (conn) {
        ws_conn = conn;
        ws_state.connecting = 1;
        ws_state.connect_time = now;
        ws_state.last_error = 0;
        ws_state.error_msg[0] = '\0';
        reconnect_attempts++;
        last_reconnect_time = now;
        printf("Reconnection attempt started\n");
    }
    else {
        printf("Reconnection attempt failed\n");
        reconnect_attempts++;
        last_reconnect_time = now;
    }

    MUTEX_UNLOCK(ws_mutex);
}
*/

static void try_reconnect(void) {
    MUTEX_LOCK(ws_mutex);

    if (is_connected || ws_conn) {
        MUTEX_UNLOCK(ws_mutex);
        return;
    }

    // ✅ 增加退避策略：重连间隔随次数递增（2s → 4s → 8s → ...）
    int reconnect_delay = 2 * (1 << reconnect_attempts);
    if (reconnect_delay > 30) reconnect_delay = 30; // 最大 30 秒

    time_t now = time(NULL);
    if (now - last_reconnect_time < reconnect_delay) {
        MUTEX_UNLOCK(ws_mutex);
        return;
    }

    if (reconnect_attempts >= max_reconnect_attempts) {
        if (now - last_reconnect_time > 60) {
            reconnect_attempts = 0;
        }
        else {
            MUTEX_UNLOCK(ws_mutex);
            return;
        }
    }

    if (strlen(saved_url) == 0) {
        MUTEX_UNLOCK(ws_mutex);
        return;
    }

    printf("Attempting to reconnect to %s (attempt %d/%d, delay %ds)\n",
        saved_url, reconnect_attempts + 1, max_reconnect_attempts, reconnect_delay);

    struct mg_connection* conn = mg_ws_connect(&mgr, saved_url, ws_event_handler, NULL, NULL);
    if (conn) {
        ws_conn = conn;
        ws_state.connecting = 1;
        ws_state.connect_time = now;
        reconnect_attempts++;
        last_reconnect_time = now;
        printf("Reconnection attempt started\n");
    }
    else {
        reconnect_attempts++;
        last_reconnect_time = now;
        printf("Reconnection attempt failed\n");
    }

    MUTEX_UNLOCK(ws_mutex);
}


// ===== Lua绑定：WebSocket写单个值 =====
static int lua_ws_write_value(lua_State* L) {
    const char* point_id = luaL_checkstring(L, 1);
    const char* value = luaL_checkstring(L, 2);

    MUTEX_LOCK(ws_mutex);

    if (!ws_conn || !is_connected) {
        printf("[WS_WRITE] Error: WebSocket not connected\n");
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
        lua_pushstring(L, "WebSocket not connected");
        return 2;
    }

    // 构建写操作消息
    char message[256];
    snprintf(message, sizeof(message),
        "{\"type\":\"write\",\"id\":\"%s\",\"val\":\"%s\"}",
        point_id, value);

    // 发送消息
    int bytes_sent = mg_ws_send(ws_conn, message, strlen(message), WEBSOCKET_OP_TEXT);

    MUTEX_UNLOCK(ws_mutex);

    if (bytes_sent > 0) {
        printf("[WS_WRITE] Write command sent: %s = %s (%d bytes)\n",
            point_id, value, bytes_sent);
        lua_pushboolean(L, true);
        lua_pushinteger(L, bytes_sent);
        return 2;
    }
    else {
        printf("[WS_WRITE] Failed to send write command\n");
        lua_pushboolean(L, false);
        lua_pushstring(L, "send failed");
        return 2;
    }
}

// ===== Lua绑定：WebSocket批量写值 =====
static int lua_ws_write_multiple(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);

    MUTEX_LOCK(ws_mutex);

    if (!ws_conn || !is_connected) {
        printf("[WS_WRITE] Error: WebSocket not connected\n");
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
        lua_pushstring(L, "WebSocket not connected");
        return 2;
    }

    // 构建JSON消息
    char message[1024];
    strcpy(message, "{\"type\":\"write_batch\",\"data\":[");

    bool first = true;
    lua_pushnil(L);

    while (lua_next(L, 1) != 0) {
        const char* point_id = lua_tostring(L, -2);
        const char* value = lua_tostring(L, -1);

        if (point_id && value) {
            if (!first) {
                strcat(message, ",");
            }

            char entry[128];
            snprintf(entry, sizeof(entry), "{\"id\":\"%s\",\"val\":\"%s\"}", point_id, value);
            strcat(message, entry);

            first = false;
        }

        lua_pop(L, 1);
    }

    strcat(message, "]}");

    // 发送消息
    int bytes_sent = mg_ws_send(ws_conn, message, strlen(message), WEBSOCKET_OP_TEXT);

    MUTEX_UNLOCK(ws_mutex);

    if (bytes_sent > 0) {
        printf("[WS_WRITE] Batch write sent: %d bytes\n", bytes_sent);
        lua_pushboolean(L, true);
        lua_pushinteger(L, bytes_sent);
        return 2;
    }
    else {
        printf("[WS_WRITE] Failed to send batch write\n");
        lua_pushboolean(L, false);
        lua_pushstring(L, "send failed");
        return 2;
    }
}

static int lua_ws_read_values(lua_State* L) {
    int n = lua_gettop(L);

    MUTEX_LOCK(ws_mutex);

    if (!ws_conn || !is_connected) {
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
        lua_pushstring(L, "WebSocket not connected");
        return 2;
    }

    // 使用动态分配代替固定计算
    size_t buffer_size = 256;  // 初始大小
    char* message = (char*)malloc(buffer_size);
    if (!message) {
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
        lua_pushstring(L, "内存分配失败");
        return 2;
    }

    size_t pos = snprintf(message, buffer_size, "{\"type\":\"read\",\"ids\":[");

    // 处理table参数
    if (n == 1 && lua_istable(L, 1)) {
        lua_pushnil(L);
        bool first = true;

        while (lua_next(L, 1) != 0) {
            if (lua_isstring(L, -1)) {
                const char* point_id = lua_tostring(L, -1);

                if (!first) {
                    // 添加逗号
                    while (pos + 1 >= buffer_size) {
                        buffer_size *= 2;
                        char* new_msg = (char*)realloc(message, buffer_size);
                        if (!new_msg) {
                            free(message);
                            MUTEX_UNLOCK(ws_mutex);
                            lua_pushboolean(L, false);
                            lua_pushstring(L, "内存分配失败");
                            return 2;
                        }
                        message = new_msg;
                    }
                    message[pos++] = ',';
                    message[pos] = '\0';
                }

                // 计算需要的空间（包括转义）
                size_t needed = 3; // 引号和可能的转义
                for (const char* c = point_id; *c; c++) {
                    if (*c == '"' || *c == '\\') needed += 2;
                    else needed += 1;
                }

                // 确保空间足够
                while (pos + needed + 1 >= buffer_size) {
                    buffer_size *= 2;
                    char* new_msg = (char*)realloc(message, buffer_size);
                    if (!new_msg) {
                        free(message);
                        MUTEX_UNLOCK(ws_mutex);
                        lua_pushboolean(L, false);
                        lua_pushstring(L, "内存分配失败");
                        return 2;
                    }
                    message = new_msg;
                }

                // 添加带转义的ID
                message[pos++] = '"';
                for (const char* c = point_id; *c; c++) {
                    if (*c == '"' || *c == '\\') {
                        message[pos++] = '\\';
                    }
                    message[pos++] = *c;
                }
                message[pos++] = '"';
                message[pos] = '\0';

                first = false;
            }
            lua_pop(L, 1);
        }
    }
    else {
        // 处理多个参数
        for (int i = 1; i <= n; i++) {
            const char* point_id = luaL_checkstring(L, i);

            if (i > 1) {
                while (pos + 1 >= buffer_size) {
                    buffer_size *= 2;
                    char* new_msg = (char*)realloc(message, buffer_size);
                    if (!new_msg) {
                        free(message);
                        MUTEX_UNLOCK(ws_mutex);
                        lua_pushboolean(L, false);
                        lua_pushstring(L, "内存分配失败");
                        return 2;
                    }
                    message = new_msg;
                }
                message[pos++] = ',';
                message[pos] = '\0';
            }

            // 计算需要的空间
            size_t needed = 3;
            for (const char* c = point_id; *c; c++) {
                if (*c == '"' || *c == '\\') needed += 2;
                else needed += 1;
            }

            while (pos + needed + 1 >= buffer_size) {
                buffer_size *= 2;
                char* new_msg = (char*)realloc(message, buffer_size);
                if (!new_msg) {
                    free(message);
                    MUTEX_UNLOCK(ws_mutex);
                    lua_pushboolean(L, false);
                    lua_pushstring(L, "内存分配失败");
                    return 2;
                }
                message = new_msg;
            }

            // 添加带转义的ID
            message[pos++] = '"';
            for (const char* c = point_id; *c; c++) {
                if (*c == '"' || *c == '\\') {
                    message[pos++] = '\\';
                }
                message[pos++] = *c;
            }
            message[pos++] = '"';
            message[pos] = '\0';
        }
    }

    // 添加结尾
    while (pos + 2 >= buffer_size) {
        buffer_size *= 2;
        char* new_msg = (char*)realloc(message, buffer_size);
        if (!new_msg) {
            free(message);
            MUTEX_UNLOCK(ws_mutex);
            lua_pushboolean(L, false);
            lua_pushstring(L, "内存分配失败");
            return 2;
        }
        message = new_msg;
    }

    strcat(message, "]}");

    // 发送消息
    int bytes_sent = mg_ws_send(ws_conn, message, strlen(message), WEBSOCKET_OP_TEXT);
    free(message);

    MUTEX_UNLOCK(ws_mutex);

    if (bytes_sent > 0) {
        lua_pushboolean(L, true);
        lua_pushinteger(L, bytes_sent);
        return 2;
    }
    else {
        lua_pushboolean(L, false);
        lua_pushstring(L, "send failed");
        return 2;
    }
}
// ===== Lua绑定：发送原始JSON =====
static int lua_ws_send_raw(lua_State* L) {
    const char* json_str = luaL_checkstring(L, 1);

    MUTEX_LOCK(ws_mutex);

    if (!ws_conn || !is_connected) {
        MUTEX_UNLOCK(ws_mutex);
        lua_pushboolean(L, false);
        lua_pushstring(L, "WebSocket not connected");
        return 2;
    }

    int bytes_sent = mg_ws_send(ws_conn, json_str, strlen(json_str), WEBSOCKET_OP_TEXT);

    MUTEX_UNLOCK(ws_mutex);

    if (bytes_sent > 0) {
        lua_pushboolean(L, true);
        lua_pushinteger(L, bytes_sent);
        return 2;
    }
    else {
        lua_pushboolean(L, false);
        lua_pushstring(L, "send failed");
        return 2;
    }
}




// ===== 获取实时数据（HTTP接口）- 修复token传递 =====
static int lua_get_real_data(lua_State* L) {
    const char* server_url = luaL_checkstring(L, 1);  // IP:PORT
    const char* token = luaL_checkstring(L, 2);       // token = "scadaToken"
    int page = luaL_optinteger(L, 3, 1);               // 当前页，默认1
    int size = luaL_optinteger(L, 4, 15);              // 每页数量，默认15

    printf("\n[REAL_DATA] Querying real-time data...\n");
    printf("  Server: %s\n", server_url);
    printf("  Page: %d, Size: %d\n", page, size);
    printf("  Token: %s\n", token);

    // 重置全局上下文
    memset(&sync_ctx, 0, sizeof(SyncQueryData));

    // 确保同步管理器已初始化
    init_sync_network_manager();

    // 构建JSON请求体
    char json_body[256];
    snprintf(json_body, sizeof(json_body),
        "{\"page\":%d,\"size\":%d}", page, size);

    // 构建请求URL
    char url[512];
    snprintf(url, sizeof(url), "http://%s/scada/getRealData", server_url);

    // 提取Host（去掉可能的http://前缀）
    char host[256];
    const char* host_start = server_url;
    if (strstr(server_url, "http://") == server_url) {
        host_start = server_url + 7;
    }

    // 复制host，去掉路径部分（如果有）
    const char* path_start = strchr(host_start, '/');
    if (path_start) {
        size_t host_len = path_start - host_start;
        snprintf(host, sizeof(host), "%.*s", (int)host_len, host_start);
    }
    else {
        snprintf(host, sizeof(host), "%s", host_start);
    }

    printf("[REAL_DATA] URL: %s\n", url);
    printf("[REAL_DATA] Host: %s\n", host);
    printf("[REAL_DATA] Request body: %s\n", json_body);

    // 创建HTTP连接
    struct mg_connection* conn = mg_http_connect(&sync_mgr, url, sync_query_handler, NULL);
    if (!conn) {
        lua_pushboolean(L, false);
        lua_pushstring(L, "Failed to create connection");
        return 2;
    }
    sync_ctx.conn = conn;

    // 发送HTTP POST请求
    mg_printf(conn,
        "POST /scada/getRealData HTTP/1.1\r\n"
        "Host: %s\r\n"
        "Content-Type: application/json\r\n"
        "token: %s\r\n"           // 直接使用token作为header名
        "Content-Length: %d\r\n"
        "Connection: close\r\n"
        "\r\n"
        "%s",
        host,                      // 使用提取的host
        token,                     // 直接使用scadaToken
        (int)strlen(json_body),
        json_body
    );

  

    // 设置超时定时器（5秒）
    lv_timer_t* timeout_timer = lv_timer_create(sync_query_timeout_cb, 5000, &sync_ctx);

    // 等待响应
    int timeout_ms = 5000;
    int poll_interval = 10;
    int max_polls = timeout_ms / poll_interval;
    int poll_count = 0;

    while (!sync_ctx.completed && poll_count < max_polls) {
        mg_mgr_poll(&sync_mgr, 0);
        lv_tick_inc(poll_interval);
        lv_timer_handler();
        poll_count++;
        SLEEP_MS(poll_interval);
    }

    lv_timer_del(timeout_timer);

    printf("[REAL_DATA] Loop finished: poll_count=%d, completed=%d, status=%d\n",
        poll_count, sync_ctx.completed, sync_ctx.status_code);

    // 判断业务是否成功
    bool business_success = false;
    const char* result_msg = sync_ctx.response_json;

    if (sync_ctx.completed) {
        if (sync_ctx.status_code == 200) {
            printf("[REAL_DATA] SUCCESS: HTTP 200 OK\n");
            business_success = true;
        }
        else {
            printf("[REAL_DATA] ERROR: HTTP status %d\n", sync_ctx.status_code);
            business_success = false;

            // 根据状态码提供具体错误信息
            if (sync_ctx.status_code == 401) {
                result_msg = "Token invalid or missing (status 401)";
            }
            else if (sync_ctx.status_code == 404) {
                result_msg = "API path not found: /scada/getRealData";
            }
            else if (sync_ctx.status_code == 400) {
                result_msg = "Bad request - check page/size parameters";
            }
            else {
                result_msg = sync_ctx.response_json;
            }
        }
    }
    else {
        printf("[REAL_DATA] ERROR: Timeout\n");
        business_success = false;
        result_msg = "Request timeout (5000ms)";
    }

    // 返回结果
    lua_pushboolean(L, business_success);
    lua_pushstring(L, result_msg);

    // 清理连接
    if (sync_ctx.conn) {
        mg_close_conn(sync_ctx.conn);
        sync_ctx.conn = NULL;
    }

    // 处理剩余网络事件
    for (int i = 0; i < 10; i++) {
        mg_mgr_poll(&sync_mgr, 1);
        SLEEP_MS(1);
    }

    return 2;
}


// ===== WebSocket 方法注册 =====
static const luaL_Reg lv_mongoose_methods[] = {
    {"connect", lua_ws_connect},
    {"send", lua_ws_send},
    {"send_raw", lua_ws_send_raw},
    {"disconnect", lua_ws_disconnect},
    {"set_callbacks", lua_ws_set_callbacks},
   // {"get_status", lua_ws_get_status},
    {"write", lua_ws_write_value},
    {"write_batch", lua_ws_write_multiple},
    {"read", lua_ws_read_values},
    {"read_multiple", lua_ws_read_values}, // 别名
    {"query_sync", lua_query_history_sync},
    {"get_real_data", lua_get_real_data},  // 新增实时数据接口
    {"start_network_service", lua_start_network_service},
    {NULL, NULL}
};

// ===== 获取方法列表 =====
const luaL_Reg* lvgl_get_mongoose_methods(void) {
    return lv_mongoose_methods;
}
