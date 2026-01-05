// VduEditor.cpp : VDU组态编辑器主程序
//

#include <Windows.h>
#include <iostream>
#include <string>

// Lua headers (C style)
extern "C" {
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
}

// LVGL headers
#include <lvgl/lvgl.h>

// Lua bindings
extern "C" {
#include "lvgl_lua_bindings.h"
}

// Window dimensions
static const int WINDOW_WIDTH = 1024;
static const int WINDOW_HEIGHT = 768;

// Default script path
static const char* DEFAULT_SCRIPT_PATH = "D:\\CodePro\\lvgl_git\\lv_port_pc_visual_studio\\VduEditor\\lua\\editor\\main_editor.lua";

// Default Lua search path
static const char* DEFAULT_LUA_PATH = "D:\\CodePro\\lvgl_git\\lv_port_pc_visual_studio\\VduEditor\\lua\\editor\\?.lua;"
                                       "D:\\CodePro\\lvgl_git\\lv_port_pc_visual_studio\\VduEditor\\lua\\editor\\?\\init.lua;"
                                       "D:\\CodePro\\lvgl_git\\lv_port_pc_visual_studio\\VduEditor\\lua\\?.lua;"
                                       "D:\\CodePro\\lvgl_git\\lv_port_pc_visual_studio\\VduEditor\\lua\\?\\init.lua;";

// Default font path (黑体)
static const char* DEFAULT_FONT_PATH = "D:\\CodePro\\lvgl_git\\lv_port_pc_visual_studio\\VduEditor\\fonts\\simhei.ttf";
static const int DEFAULT_FONT_SIZE = 14;

// Lua state
static lua_State* g_L = nullptr;

// Global TTF font
static lv_font_t* g_chinese_font = nullptr;

/**
 * @brief Get the pre-loaded Chinese font (called from lvgl_lua_bindings.c)
 * @return Pointer to the Chinese font, or NULL if not loaded
 */
extern "C" lv_font_t* get_chinese_font(void)
{
    return g_chinese_font;
}

/**
 * @brief Initialize Chinese font using TinyTTF
 * @return true if successful
 */
static bool init_chinese_font()
{
#if LV_USE_TINY_TTF
    // Check if font file exists
    FILE* f = nullptr;
    if (fopen_s(&f, DEFAULT_FONT_PATH, "rb") != 0 || !f) {
        std::cerr << "Font file not found: " << DEFAULT_FONT_PATH << std::endl;
        std::cerr << "Please copy simhei.ttf to the fonts directory." << std::endl;
        return false;
    }
    fclose(f);

    // Create TTF font
    g_chinese_font = lv_tiny_ttf_create_file(DEFAULT_FONT_PATH, DEFAULT_FONT_SIZE);
    if (!g_chinese_font) {
        std::cerr << "Failed to create TTF font from: " << DEFAULT_FONT_PATH << std::endl;
        return false;
    }

    // Set as default theme font
    lv_display_t* disp = lv_display_get_default();
    if (disp) {
        lv_theme_t* theme = lv_display_get_theme(disp);
        if (theme) {
            // Apply font to the active screen
            lv_obj_t* scr = lv_screen_active();
            if (scr) {
                lv_obj_set_style_text_font(scr, g_chinese_font, 0);
            }
        }
    }

    std::cout << "Chinese font loaded: " << DEFAULT_FONT_PATH << " (size: " << DEFAULT_FONT_SIZE << ")" << std::endl;
    return true;
#else
    std::cerr << "TinyTTF is not enabled. Please set LV_USE_TINY_TTF to 1 in lv_conf.h" << std::endl;
    return false;
#endif
}

/**
 * @brief Cleanup Chinese font
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
 * @brief Set Lua module search path
 * @param L Lua state
 * @param lua_path The Lua path to set
 */
static void set_lua_path(lua_State* L, const char* lua_path)
{
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path");
    const char* cur_path = lua_tostring(L, -1);
    
    // Combine new path with existing path
    std::string new_path = std::string(lua_path) + ";" + (cur_path ? cur_path : "");
    
    lua_pop(L, 1);  // Pop old path
    lua_pushstring(L, new_path.c_str());
    lua_setfield(L, -2, "path");
    lua_pop(L, 1);  // Pop package table
    
    std::cout << "Lua package.path set to: " << new_path << std::endl;
}

/**
 * @brief Initialize Lua state and register LVGL bindings
 * @return true if successful
 */
static bool init_lua()
{
    g_L = luaL_newstate();
    if (!g_L) {
        std::cerr << "Failed to create Lua state" << std::endl;
        return false;
    }

    // Open standard libraries
    luaL_openlibs(g_L);

    // Set Lua module search path
    set_lua_path(g_L, DEFAULT_LUA_PATH);

    // Register LVGL bindings
    lvgl_lua_register(g_L);

    return true;
}

/**
 * @brief Load and execute a Lua script
 * @param script_path Path to the Lua script
 * @return true if successful
 */
static bool load_lua_script(const char* script_path)
{
    if (!g_L || !script_path) {
        return false;
    }

    // Check if file exists
    FILE* f = nullptr;
    if (fopen_s(&f, script_path, "r") != 0 || !f) {
        std::cerr << "Script file not found: " << script_path << std::endl;
        return false;
    }
    fclose(f);

    std::cout << "Loading script: " << script_path << std::endl;

    // Load and execute the script
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
 * @brief Cleanup Lua state
 */
static void cleanup_lua()
{
    if (g_L) {
        lua_close(g_L);
        g_L = nullptr;
    }
}

/**
 * @brief Main function
 */
int main(int argc, char* argv[])
{
    // Set console to UTF-8 for Chinese output
    SetConsoleCP(CP_UTF8);
    SetConsoleOutputCP(CP_UTF8);

    std::cout << "VduEditor - LVGL Lua Configuration Editor" << std::endl;
    std::cout << "Window size: " << WINDOW_WIDTH << "x" << WINDOW_HEIGHT << std::endl;

    // Determine script path
    const char* script_path = DEFAULT_SCRIPT_PATH;
    if (argc > 1) {
        script_path = argv[1];
        std::cout << "Using command line script: " << script_path << std::endl;
    }
    else {
        std::cout << "Using default script: " << script_path << std::endl;
    }

    // Initialize LVGL
    lv_init();

    // Create display
    int32_t zoom_level = 100;
    bool allow_dpi_override = false;
    bool simulator_mode = true;
    
    lv_display_t* display = lv_windows_create_display(
        L"LVGL Lua Demo",
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        zoom_level,
        allow_dpi_override,
        simulator_mode);

    if (!display) {
        std::cerr << "Failed to create display" << std::endl;
        return -1;
    }

    // Get window handle and set icon
    HWND window_handle = lv_windows_get_display_window_handle(display);
    if (!window_handle) {
        std::cerr << "Failed to get window handle" << std::endl;
        return -1;
    }

    // Create input devices
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

    // Run a few timer cycles to let LVGL fully initialize the display
    for (int i = 0; i < 10; i++) {
        lv_timer_handler();
        Sleep(10);
    }

    std::cout << "LVGL display initialized successfully" << std::endl;

    // Initialize Chinese font (before Lua script execution)
    if (!init_chinese_font()) {
        std::cerr << "Warning: Chinese font not loaded, Chinese text may not display correctly" << std::endl;
    }

    // Initialize Lua
    if (!init_lua()) {
        std::cerr << "Failed to initialize Lua" << std::endl;
        cleanup_chinese_font();
        return -1;
    }

    // Load and execute the Lua script
    if (!load_lua_script(script_path)) {
        std::cerr << "Failed to load Lua script, showing default demo" << std::endl;
        
        // Create a simple demo UI if script fails
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

    // Main loop
    while (1) {
        uint32_t time_till_next = lv_timer_handler();
        lv_delay_ms(time_till_next);
    }

    // Cleanup (never reached in this example)
    cleanup_lua();
    cleanup_chinese_font();

    return 0;
}

// 运行程序: Ctrl + F5 或调试 >"开始执行(不调试)"菜单
// 调试程序: F5 或调试 >"开始调试"菜单
