#include <unistd.h>
#include <stdio.h>
#ifdef _WIN32
#include <windows.h>
#endif
#include "lv_lua.h"

int main(int argc, char **argv) {
    // 设置控制台编码为UTF-8
#ifdef _WIN32
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);
#endif
    
    char *lua_script = NULL;
    // 判断参数传入文件
    if (argc < 2) {
        printf("Usage: %s <lua_script>\n", argv[0]);
        return 1;
    }
    
    lua_script = argv[1];

    // 1. 初始化图形系统
    if (vdu_sys_init(1024, 768, "simhei.ttf", 16) != 0) {
        return -1;
    }

    // 2. 运行 Lua 脚本
    printf("Loading %s...\n", lua_script);
    if (vdu_lua_run(lua_script) != 0) {
        vdu_sys_shutdown();
        return -1;
    }

    // 3. 主循环
    while(1) {
        vdu_sys_poll();
        usleep(5000);
    }

    // 4. 清理资源
    vdu_sys_shutdown();
    return 0;
}
