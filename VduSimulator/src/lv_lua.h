#ifndef LV_LUA_H
#define LV_LUA_H

// 初始化图形系统 (LVGL + SDL + 字体 + 输入设备)
// 返回 0 表示成功，非 0 表示失败
int vdu_sys_init(int width, int height, const char* font_path, int font_size);

// 运行一次 LVGL 的任务调度 (lv_timer_handler)
void vdu_sys_poll(void);

// 初始化 Lua 虚拟机，注册 LVGL 库，并运行指定脚本
// 返回 0 表示成功，非 0 表示失败
int vdu_lua_run(const char *script_path);

// 关闭 Lua 虚拟机
void vdu_lua_close(void);

// 清理资源 (可选)
void vdu_sys_shutdown(void);

#endif
