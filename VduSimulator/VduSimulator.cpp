// VduSimulator.cpp : VDU模拟主程序
//

#include <Windows.h>
#include <iostream>
#include <string>

// Lua 绑定
extern "C" {
#include "lvgl_lua_bindings.h"
}

// 窗口尺寸
static const int WINDOW_WIDTH = 1024;
static const int WINDOW_HEIGHT = 768;

// 默认脚本路径
static const char* DEFAULT_SCRIPT_PATH = "lua\\editor\\main_editor.lua";

// 默认 Lua 搜索路径（模板，使用绝对路径）
static const char* DEFAULT_LUA_PATH_TEMPLATE = 
    "%slua\\editor\\?.lua;"
    "%slua\\editor\\?\\init.lua;"
    "%slua\\sim\\?.lua;"
    "%slua\\sim\\?\\init.lua;"
    "%slua\\?.lua;"
    "%slua\\?\\init.lua;"
    "%slua\\actions\\?.lua";

// 默认字体路径（黑体）
static const char* DEFAULT_FONT_PATH = "fonts\\simhei.ttf";
static const int DEFAULT_FONT_SIZE = 14;

// Lua 状态机
static lua_State* g_L = nullptr;

// 全局 TTF 字体
static lv_font_t* g_chinese_font = nullptr;

// 全局可执行文件目录
static std::string g_exe_directory;

/**
 * @brief 将窗口居中显示在屏幕上
 * @param hwnd 窗口句柄
 */
static void center_window(HWND hwnd)
{
    if (!hwnd) return;

    // 获取窗口当前大小
    RECT window_rect;
    GetWindowRect(hwnd, &window_rect);
    int window_width = window_rect.right - window_rect.left;
    int window_height = window_rect.bottom - window_rect.top;

    // 获取屏幕工作区大小（排除任务栏）
    RECT work_area;
    SystemParametersInfo(SPI_GETWORKAREA, 0, &work_area, 0);
    int screen_width = work_area.right - work_area.left;
    int screen_height = work_area.bottom - work_area.top;

    // 计算居中位置
    int x = work_area.left + (screen_width - window_width) / 2;
    int y = work_area.top + (screen_height - window_height) / 2;

    // 设置窗口位置
    SetWindowPos(hwnd, NULL, x, y, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
}

/**
 * @brief 获取当前可执行文件所在目录
 * @return 以反斜杠结尾的目录路径，失败时返回空字符串
 */
static std::string get_exe_directory()
{
    char path[MAX_PATH];
    DWORD len = GetModuleFileNameA(NULL, path, MAX_PATH);
    if (len == 0 || len >= MAX_PATH) {
        return "";
    }

    // 查找最后一个反斜杠并截断
    std::string dir(path);
    size_t pos = dir.find_last_of("\\/");
    if (pos != std::string::npos) {
        dir = dir.substr(0, pos + 1);  // 保留反斜杠
    }
    return dir;
}

/**
 * @brief 构建完整路径（基于可执行文件目录）
 * @param relative_path 相对路径
 * @return 完整绝对路径
 */
static std::string build_full_path(const char* relative_path)
{
    return g_exe_directory + relative_path;
}

/**
 * @brief 使用 TinyTTF 初始化中文字体
 * @return 成功返回 true
 */
static bool init_chinese_font()
{
#if LV_USE_TINY_TTF
    // 获取可执行文件目录并构建完整字体路径
    std::string full_font_path = build_full_path(DEFAULT_FONT_PATH);

    std::cout << "Executable directory: " << g_exe_directory << std::endl;
    std::cout << "Font path: " << full_font_path << std::endl;

    // 检查字体文件是否存在
    FILE* f = nullptr;
    if (fopen_s(&f, full_font_path.c_str(), "rb") != 0 || !f) {
        std::cerr << "Font file not found: " << full_font_path << std::endl;
        std::cerr << "Please copy simhei.ttf to the fonts directory." << std::endl;
        return false;
    }
    fclose(f);

    // 创建 TTF 字体，禁用字距调整
    // 注意：对于中文字体，应禁用字距调整以避免字符间距问题
    g_chinese_font = lv_tiny_ttf_create_file_ex(
        full_font_path.c_str(),
        DEFAULT_FONT_SIZE,
        LV_FONT_KERNING_NONE,  // 禁用中文字体的字距调整
        LV_TINY_TTF_CACHE_GLYPH_CNT
    );
    if (!g_chinese_font) {
        std::cerr << "Failed to create TTF font from: " << full_font_path << std::endl;
        return false;
    }
    // 设置为当前 TTF 字体
    set_current_ttf_font(g_chinese_font);
    // 设置为默认主题字体
    lv_display_t* disp = lv_display_get_default();
    if (disp) {
        lv_theme_t* theme = lv_display_get_theme(disp);
        if (theme) {
            // 将字体应用到当前活动屏幕
            lv_obj_t* scr = lv_screen_active();
            if (scr) {
                lv_obj_set_style_text_font(scr, g_chinese_font, 0);
            }
        }
    }

    std::cout << "Chinese font loaded: " << full_font_path << " (size: " << DEFAULT_FONT_SIZE << ", kerning: disabled)" << std::endl;
    return true;
#else
    std::cerr << "TinyTTF is not enabled. Please set LV_USE_TINY_TTF to 1 in lv_conf.h" << std::endl;
    return false;
#endif
}

/**
 * @brief 清理中文字体资源
 */
static void cleanup_chinese_font()
{
#if LV_USE_TINY_TTF
    if (g_chinese_font) {
        lv_tiny_ttf_destroy(g_chinese_font);
        g_chinese_font = nullptr;
    }
#endif
}

/**
 * @brief 设置 Lua 模块搜索路径（使用绝对路径）
 * @param L Lua 状态机
 */
static void set_lua_path(lua_State* L)
{
    // 构建使用绝对路径的 Lua 搜索路径
    char lua_path[4096];
    snprintf(lua_path, sizeof(lua_path), DEFAULT_LUA_PATH_TEMPLATE,
        g_exe_directory.c_str(),
        g_exe_directory.c_str(),
        g_exe_directory.c_str(),
        g_exe_directory.c_str(),
        g_exe_directory.c_str(),
        g_exe_directory.c_str(),
        g_exe_directory.c_str());

    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path");
    const char* cur_path = lua_tostring(L, -1);

    // 将新路径与现有路径合并
    std::string new_path = std::string(lua_path) + ";" + (cur_path ? cur_path : "");

    lua_pop(L, 1);  // 弹出旧路径
    lua_pushstring(L, new_path.c_str());
    lua_setfield(L, -2, "path");
    lua_pop(L, 1);  // 弹出 package 表

    std::cout << "Lua package.path set to: " << new_path << std::endl;
}

/**
 * @brief 设置全局变量 APP_DIR 供 Lua 使用
 * @param L Lua 状态机
 */
static void set_lua_app_dir(lua_State* L)
{
    // 设置 APP_DIR 全局变量，供 Lua 脚本使用
    lua_pushstring(L, g_exe_directory.c_str());
    lua_setglobal(L, "APP_DIR");
    
    std::cout << "Lua APP_DIR set to: " << g_exe_directory << std::endl;
}

/**
 * @brief 初始化 Lua 状态机并注册 LVGL 绑定
 * @return 成功返回 true
 */
static bool init_lua()
{
    g_L = luaL_newstate();
    if (!g_L) {
        std::cerr << "Failed to create Lua state" << std::endl;
        return false;
    }

    // 打开标准库
    luaL_openlibs(g_L);

    // 设置 Lua 模块搜索路径（使用绝对路径）
    set_lua_path(g_L);
    
    // 设置 APP_DIR 全局变量
    set_lua_app_dir(g_L);

    // 注册 LVGL 绑定
    lvgl_lua_register(g_L);

    return true;
}

/**
 * @brief 加载并执行 Lua 脚本
 * @param script_path Lua 脚本路径（相对路径将转换为绝对路径）
 * @return 成功返回 true
 */
static bool load_lua_script(const char* script_path)
{
    if (!g_L || !script_path) {
        return false;
    }

    // 构建完整脚本路径
    std::string full_script_path = build_full_path(script_path);

    // 检查文件是否存在
    FILE* f = nullptr;
    if (fopen_s(&f, full_script_path.c_str(), "r") != 0 || !f) {
        std::cerr << "Script file not found: " << full_script_path << std::endl;
        return false;
    }
    fclose(f);

    std::cout << "Loading script: " << full_script_path << std::endl;

    // 加载并执行脚本
    int result = luaL_dofile(g_L, full_script_path.c_str());
    if (result != LUA_OK) {
        const char* error = lua_tostring(g_L, -1);
        std::cerr << "Lua error: " << (error ? error : "unknown error") << std::endl;
        lua_pop(g_L, 1);
        return false;
    }

    return true;
}

/**
 * @brief 清理 Lua 状态机资源
 */
static void cleanup_lua()
{
    if (g_L) {
        lua_close(g_L);
        g_L = nullptr;
    }
}

/**
 * @brief 主函数
 */
int main(int argc, char* argv[])
{
    // 将控制台设置为 UTF-8 以支持中文输出
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);

    std::cout << "VduSimulator - LVGL Lua Configuration Editor" << std::endl;
    std::cout << "Window size: " << WINDOW_WIDTH << "x" << WINDOW_HEIGHT << std::endl;

    // 获取可执行文件目录（在程序启动时获取一次）
    g_exe_directory = get_exe_directory();
    if (g_exe_directory.empty()) {
        std::cerr << "Failed to get executable directory" << std::endl;
        return -1;
    }
    std::cout << "Application directory: " << g_exe_directory << std::endl;

    // 确定脚本路径
    const char* script_path = DEFAULT_SCRIPT_PATH;
    if (argc > 1) {
        script_path = argv[1];
        std::cout << "Using command line script: " << script_path << std::endl;
    }
    else {
        std::cout << "Using default script: " << script_path << std::endl;
    }

    // 初始化 LVGL
    lv_init();

    // 创建显示
    int32_t zoom_level = 100;
    bool allow_dpi_override = false;
    bool simulator_mode = false;

    lv_display_t* display = lv_windows_create_display(
        L"VduSimulator",
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        zoom_level,
        allow_dpi_override,
        simulator_mode);

    if (!display) {
        std::cerr << "Failed to create display" << std::endl;
        return -1;
    }

    // 获取窗口句柄并设置图标
    HWND window_handle = lv_windows_get_display_window_handle(display);
    if (!window_handle) {
        std::cerr << "Failed to get window handle" << std::endl;
        return -1;
    }

    // 将窗口居中显示
    center_window(window_handle);

    // 创建 输入设备
    lv_indev_t* pointer_indev = lv_windows_acquire_pointer_indev(display);
    if (!pointer_indev) {
        std::cerr << "Failed to create pointer input device" << std::endl;
        return -1;
    }

    lv_indev_t* keypad_indev = lv_windows_acquire_keypad_indev(display);
    if (!keypad_indev) {
        std::cerr << "Failed to create keypad input device" << std::endl;
        return -1;
    }

    lv_indev_t* encoder_indev = lv_windows_acquire_encoder_indev(display);
    if (!encoder_indev) {
        std::cerr << "Failed to create encoder input device" << std::endl;
        return -1;
    }

    // 运行几个定时器周期，让 LVGL 完全初始化显示
    for (int i = 0; i < 10; i++) {
        lv_timer_handler();
        Sleep(10);
    }

    std::cout << "LVGL display initialized successfully" << std::endl;

    // 初始化中文字体（在 Lua 脚本执行之前）
    if (!init_chinese_font()) {
        std::cerr << "Warning: Chinese font not loaded, Chinese text may not display correctly" << std::endl;
    }

    // 初始化 Lua
    if (!init_lua()) {
        std::cerr << "Failed to initialize Lua" << std::endl;
        cleanup_chinese_font();
        return -1;
    }

    // 加载并执行 Lua 脚本
    if (!load_lua_script(script_path)) {
        std::cerr << "Failed to load Lua script, showing default demo" << std::endl;

        // 如果脚本加载失败，创建一个简单的演示界面
        lv_obj_t* scr = lv_screen_active();
        lv_obj_set_style_bg_color(scr, lv_color_hex(0x2D3436), 0);

        lv_obj_t* label = lv_label_create(scr);
        lv_label_set_text(label, "VduSimulator - Script load failed\nCheck console for errors");
        lv_obj_set_style_text_color(label, lv_color_hex(0xFFFFFF), 0);
        if (g_chinese_font) {
            lv_obj_set_style_text_font(label, g_chinese_font, 0);
        }
        lv_obj_align(label, LV_ALIGN_CENTER, 0, 0);
    }

    std::cout << "Starting main loop..." << std::endl;

    // 主循环
    while (1) {
        uint32_t time_till_next = lv_timer_handler();
        // 处理 LV_NO_TIMER_READY 的情况，避免等待过长时间
        // LV_NO_TIMER_READY = 0xFFFFFFFF，表示没有定时器准备好
        if (time_till_next == LV_NO_TIMER_READY) {
            time_till_next = LV_DEF_REFR_PERIOD;  // 使用默认刷新周期（通常是 33ms）
        }
        lv_delay_ms(time_till_next);
    }

    // 清理资源（在此示例中永远不会执行到这里）
    cleanup_lua();
    cleanup_chinese_font();

    return 0;
}
