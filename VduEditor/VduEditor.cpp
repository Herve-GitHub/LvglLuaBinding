// VduEditor.cpp : VDU组态编辑器主程序
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

// 默认 Lua 搜索路径
static const char* DEFAULT_LUA_PATH = "lua\\editor\\?.lua;"
"lua\\editor\\?\\init.lua;"
"lua\\?.lua;"
"lua\\?\\init.lua;"
"lau\\actions\\?.lua";

// 默认字体路径（黑体）
static const char* DEFAULT_FONT_PATH = "fonts\\simhei.ttf";
static const int DEFAULT_FONT_SIZE = 14;

// Lua 状态机
static lua_State* g_L = nullptr;

// 全局 TTF 字体
static lv_font_t* g_chinese_font = nullptr;

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
 * @brief 使用 TinyTTF 初始化中文字体
 * @return 成功返回 true
 */
static bool init_chinese_font()
{
#if LV_USE_TINY_TTF
    // 获取可执行文件目录并构建完整字体路径
    std::string exe_dir = get_exe_directory();
    std::string full_font_path = exe_dir + DEFAULT_FONT_PATH;
    
    std::cout << "Executable directory: " << exe_dir << std::endl;
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
 * @brief 设置 Lua 模块搜索路径
 * @param L Lua 状态机
 * @param lua_path 要设置的 Lua 路径
 */
static void set_lua_path(lua_State* L, const char* lua_path)
{
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

    // 设置 Lua 模块搜索路径
    set_lua_path(g_L, DEFAULT_LUA_PATH);

    // 注册 LVGL 绑定
    lvgl_lua_register(g_L);

    return true;
}

/**
 * @brief 加载并执行 Lua 脚本
 * @param script_path Lua 脚本路径
 * @return 成功返回 true
 */
static bool load_lua_script(const char* script_path)
{
    if (!g_L || !script_path) {
        return false;
    }

    // 检查文件是否存在
    FILE* f = nullptr;
    if (fopen_s(&f, script_path, "r") != 0 || !f) {
        std::cerr << "Script file not found: " << script_path << std::endl;
        return false;
    }
    fclose(f);

    std::cout << "Loading script: " << script_path << std::endl;

    // 加载并执行脚本
    int result = luaL_dofile(g_L, script_path);
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

    std::cout << "VduEditor - LVGL Lua Configuration Editor" << std::endl;
    std::cout << "Window size: " << WINDOW_WIDTH << "x" << WINDOW_HEIGHT << std::endl;

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
    bool simulator_mode = true;
    
    lv_display_t* display = lv_windows_create_display(
        L"VduEditor",
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

    // 创建输入设备
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
        lv_label_set_text(label, "VduEditor - Script load failed\nCheck console for errors");
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
        lv_delay_ms(time_till_next);
    }

    // 清理资源（在此示例中永远不会执行到这里）
    cleanup_lua();
    cleanup_chinese_font();

    return 0;
}
