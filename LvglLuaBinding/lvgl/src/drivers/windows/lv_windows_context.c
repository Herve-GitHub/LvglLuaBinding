/**
 * @file lv_windows_context.c
 *
 */

 /*********************
  *      INCLUDES
  *********************/

#include "lv_windows_context.h"
#if LV_USE_WINDOWS

#ifdef __GNUC__
#pragma GCC diagnostic ignored "-Wcast-function-type"
#endif

#include "lv_windows_display.h"
#include "lv_windows_input_private.h"
#include "../../osal/lv_os_private.h"

  /*********************
   *      DEFINES
   *********************/

   /**********************
    *      TYPEDEFS
    **********************/

    /**********************
     *  STATIC PROTOTYPES
     **********************/

static uint32_t lv_windows_tick_count_callback(void);

static void lv_windows_delay_callback(uint32_t ms);

static void lv_windows_check_display_existence_timer_callback(
    lv_timer_t* timer);

static bool lv_windows_window_message_callback_nolock(
    HWND hWnd,
    UINT uMsg,
    WPARAM wParam,
    LPARAM lParam,
    LRESULT* plResult);

static LRESULT CALLBACK lv_windows_window_message_callback(
    HWND   hWnd,
    UINT   uMsg,
    WPARAM wParam,
    LPARAM lParam);

static void lv_windows_resize_display(lv_windows_window_context_t* context, int32_t width, int32_t height);

/**********************
 *  STATIC VARIABLES
 **********************/

 /**********************
  *      MACROS
  **********************/

  /**********************
   *   GLOBAL FUNCTIONS
   **********************/

void lv_windows_platform_init(void)
{
    lv_tick_set_cb(lv_windows_tick_count_callback);

    lv_delay_set_cb(lv_windows_delay_callback);

    lv_timer_create(
        lv_windows_check_display_existence_timer_callback,
        200,
        NULL);

    // Try to ensure the default group exists.
    {
        lv_group_t* default_group = lv_group_get_default();
        if (!default_group) {
            default_group = lv_group_create();
            if (default_group) {
                lv_group_set_default(default_group);
            }
        }
    }

    WNDCLASSEXW window_class;
    lv_memzero(&window_class, sizeof(WNDCLASSEXW));
    window_class.cbSize = sizeof(WNDCLASSEXW);
    window_class.style = 0;
    window_class.lpfnWndProc = lv_windows_window_message_callback;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = NULL;
    window_class.hIcon = NULL;
    window_class.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
    window_class.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    window_class.lpszMenuName = NULL;
    window_class.lpszClassName = L"LVGL.Window";
    window_class.hIconSm = NULL;
    LV_ASSERT(RegisterClassExW(&window_class));
}

lv_windows_window_context_t* lv_windows_get_window_context(
    HWND window_handle)
{
    return (lv_windows_window_context_t*)(
        GetPropW(window_handle, L"LVGL.Window.Context"));
}

/**********************
 *   STATIC FUNCTIONS
 **********************/

static uint32_t lv_windows_tick_count_callback(void)
{
    LARGE_INTEGER Frequency;
    if (QueryPerformanceFrequency(&Frequency)) {
        LARGE_INTEGER PerformanceCount;
        if (QueryPerformanceCounter(&PerformanceCount)) {
            return (uint32_t)(PerformanceCount.QuadPart * 1000 / Frequency.QuadPart);
        }
    }

    return (uint32_t)GetTickCount64();
}

static void lv_windows_delay_callback(uint32_t ms)
{
    HANDLE timer_handle = CreateWaitableTimerExW(
        NULL,
        NULL,
        CREATE_WAITABLE_TIMER_MANUAL_RESET |
        CREATE_WAITABLE_TIMER_HIGH_RESOLUTION,
        TIMER_ALL_ACCESS);
    if (timer_handle) {
        LARGE_INTEGER due_time;
        due_time.QuadPart = -((int64_t)ms) * 1000 * 10;
        SetWaitableTimer(timer_handle, &due_time, 0, NULL, NULL, FALSE);
        WaitForSingleObject(timer_handle, INFINITE);

        CloseHandle(timer_handle);
    }
}

static void lv_windows_check_display_existence_timer_callback(
    lv_timer_t* timer)
{
    LV_UNUSED(timer);
    if (!lv_display_get_next(NULL)) {
        // Don't use lv_deinit() due to it will cause exception when parallel
        // rendering is enabled.
        exit(0);
    }
}

static HDC lv_windows_create_frame_buffer(
    HWND window_handle,
    LONG width,
    LONG height,
    UINT32** pixel_buffer,
    SIZE_T* pixel_buffer_size)
{
    HDC frame_buffer_dc_handle = NULL;

    LV_ASSERT_NULL(pixel_buffer);
    LV_ASSERT_NULL(pixel_buffer_size);

    HDC window_dc_handle = GetDC(window_handle);
    if (window_dc_handle) {
        frame_buffer_dc_handle = CreateCompatibleDC(window_dc_handle);
        ReleaseDC(window_handle, window_dc_handle);
    }

    if (frame_buffer_dc_handle) {
#if (LV_COLOR_DEPTH == 32) || (LV_COLOR_DEPTH == 24)
        BITMAPINFO bitmap_info = { 0 };
#elif (LV_COLOR_DEPTH == 16)
        typedef struct _BITMAPINFO_16BPP {
            BITMAPINFOHEADER bmiHeader;
            DWORD bmiColorMask[3];
        } BITMAPINFO_16BPP;

        BITMAPINFO_16BPP bitmap_info = { 0 };
#else
#error [lv_windows] Unsupported LV_COLOR_DEPTH.
#endif

        bitmap_info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bitmap_info.bmiHeader.biWidth = width;
        bitmap_info.bmiHeader.biHeight = -height;
        bitmap_info.bmiHeader.biPlanes = 1;
        bitmap_info.bmiHeader.biBitCount = lv_color_format_get_bpp(
            LV_COLOR_FORMAT_NATIVE);
#if (LV_COLOR_DEPTH == 32) || (LV_COLOR_DEPTH == 24)
        bitmap_info.bmiHeader.biCompression = BI_RGB;
#elif (LV_COLOR_DEPTH == 16)
        bitmap_info.bmiHeader.biCompression = BI_BITFIELDS;
        bitmap_info.bmiColorMask[0] = 0xF800;
        bitmap_info.bmiColorMask[1] = 0x07E0;
        bitmap_info.bmiColorMask[2] = 0x001F;
#else
#error [lv_windows] Unsupported LV_COLOR_DEPTH.
#endif

        HBITMAP hBitmap = CreateDIBSection(
            frame_buffer_dc_handle,
            (PBITMAPINFO)(&bitmap_info),
            DIB_RGB_COLORS,
            (void**)pixel_buffer,
            NULL,
            0);
        if (hBitmap) {
            *pixel_buffer_size = width * height;
            *pixel_buffer_size *= lv_color_format_get_size(
                LV_COLOR_FORMAT_NATIVE);

            DeleteObject(SelectObject(frame_buffer_dc_handle, hBitmap));
            DeleteObject(hBitmap);
        }
        else {
            DeleteDC(frame_buffer_dc_handle);
            frame_buffer_dc_handle = NULL;
        }
    }

    return frame_buffer_dc_handle;
}

// 修复：禁用定时器重建缓冲区，避免黑屏
static void lv_windows_display_timer_callback(lv_timer_t* timer)
{
    // 缓冲区重建已移至WM_SIZE消息处理中，此回调仅用于刷新
    lv_windows_window_context_t* context = lv_timer_get_user_data(timer);
    LV_ASSERT_NULL(context);

    // 只处理显示刷新，不重建缓冲区
    if (context->display_device_object) {
        lv_refr_now(context->display_device_object);
    }
}

// 新增：安全的显示大小调整函数
static void lv_windows_resize_display(lv_windows_window_context_t* context, int32_t width, int32_t height)
{
    if (!context || !context->display_device_object) return;

    // 防止无效尺寸
    if (width <= 0) width = 1;
    if (height <= 0) height = 1;

    // 保存当前活动屏幕对象
    lv_obj_t* active_screen = lv_display_get_screen_active(context->display_device_object);

    // 更新显示分辨率
    lv_display_set_resolution(context->display_device_object, width, height);

    // 重建帧缓冲区
    if (context->display_framebuffer_context_handle) {
        context->display_framebuffer_base = NULL;
        context->display_framebuffer_size = 0;
        DeleteDC(context->display_framebuffer_context_handle);
        context->display_framebuffer_context_handle = NULL;
    }

    HWND window_handle = lv_windows_get_display_window_handle(context->display_device_object);
    if (window_handle) {
        context->display_framebuffer_context_handle = lv_windows_create_frame_buffer(
            window_handle,
            width,
            height,
            &context->display_framebuffer_base,
            &context->display_framebuffer_size);

        if (context->display_framebuffer_context_handle) {
            lv_display_set_buffers(
                context->display_device_object,
                context->display_framebuffer_base,
                NULL,
                (uint32_t)context->display_framebuffer_size,
                LV_DISPLAY_RENDER_MODE_DIRECT);
        }
    }

    // 强制刷新显示
    if (active_screen) {
        lv_obj_invalidate(active_screen);
        lv_refr_now(context->display_device_object);
    }
}

static void lv_windows_display_driver_flush_callback(
    lv_display_t* display,
    const lv_area_t* area,
    uint8_t* px_map)
{
    LV_UNUSED(area);
    LV_UNUSED(px_map);

    HWND window_handle = lv_windows_get_display_window_handle(display);
    if (!window_handle) {
        lv_display_flush_ready(display);
        return;
    }

    lv_windows_window_context_t* context = lv_windows_get_window_context(
        window_handle);
    if (!context) {
        lv_display_flush_ready(display);
        return;
    }

    if (lv_display_flush_is_last(display)) {
        HDC hdc = GetDC(window_handle);
        if (hdc && context->display_framebuffer_context_handle) {
            SetStretchBltMode(hdc, HALFTONE);

            RECT client_rect;
            GetClientRect(window_handle, &client_rect);

            int32_t draw_width = client_rect.right - client_rect.left;
            int32_t draw_height = client_rect.bottom - client_rect.top;

            int32_t fb_width = lv_display_get_horizontal_resolution(display);
            int32_t fb_height = lv_display_get_vertical_resolution(display);

            if (draw_width > 0 && draw_height > 0 && fb_width > 0 && fb_height > 0) {
                StretchBlt(
                    hdc,
                    client_rect.left,
                    client_rect.top,
                    draw_width,
                    draw_height,
                    context->display_framebuffer_context_handle,
                    0,
                    0,
                    fb_width,
                    fb_height,
                    SRCCOPY);
            }

            ReleaseDC(window_handle, hdc);
        }
    }

    lv_display_flush_ready(display);
}

static UINT lv_windows_get_dpi_for_window(HWND window_handle)
{
    UINT result = (UINT)(-1);

    HMODULE module_handle = LoadLibraryW(L"SHCore.dll");
    if (module_handle) {
        typedef enum MONITOR_DPI_TYPE_PRIVATE {
            MDT_EFFECTIVE_DPI = 0,
            MDT_ANGULAR_DPI = 1,
            MDT_RAW_DPI = 2,
            MDT_DEFAULT = MDT_EFFECTIVE_DPI
        } MONITOR_DPI_TYPE_PRIVATE;

        typedef HRESULT(WINAPI* function_type)(
            HMONITOR, MONITOR_DPI_TYPE_PRIVATE, UINT*, UINT*);

        function_type function = (function_type)(
            GetProcAddress(module_handle, "GetDpiForMonitor"));
        if (function) {
            HMONITOR MonitorHandle = MonitorFromWindow(
                window_handle,
                MONITOR_DEFAULTTONEAREST);

            UINT dpiX = 0;
            UINT dpiY = 0;
            if (SUCCEEDED(function(
                MonitorHandle,
                MDT_EFFECTIVE_DPI,
                &dpiX,
                &dpiY))) {
                result = dpiX;
            }
        }

        FreeLibrary(module_handle);
    }

    if (result == (UINT)(-1)) {
        HDC hWindowDC = GetDC(window_handle);
        if (hWindowDC) {
            result = GetDeviceCaps(hWindowDC, LOGPIXELSX);
            ReleaseDC(window_handle, hWindowDC);
        }
    }

    if (result == (UINT)(-1)) {
        result = USER_DEFAULT_SCREEN_DPI;
    }

    return result;
}

static BOOL lv_windows_register_touch_window(
    HWND window_handle,
    ULONG flags)
{
    HMODULE module_handle = GetModuleHandleW(L"user32.dll");
    if (!module_handle) {
        return FALSE;
    }

    typedef BOOL(WINAPI* function_type)(HWND, ULONG);

    function_type function = (function_type)(
        GetProcAddress(module_handle, "RegisterTouchWindow"));
    if (!function) {
        return FALSE;
    }

    return function(window_handle, flags);
}

static BOOL lv_windows_enable_child_window_dpi_message(
    HWND WindowHandle)
{
    OSVERSIONINFOEXW os_version_info_ex = { 0 };
    os_version_info_ex.dwOSVersionInfoSize = sizeof(OSVERSIONINFOEXW);
    os_version_info_ex.dwMajorVersion = 10;
    os_version_info_ex.dwMinorVersion = 0;
    os_version_info_ex.dwBuildNumber = 14986;
    if (!VerifyVersionInfoW(
        &os_version_info_ex,
        VER_MAJORVERSION | VER_MINORVERSION | VER_BUILDNUMBER,
        VerSetConditionMask(
            VerSetConditionMask(
                VerSetConditionMask(
                    0,
                    VER_MAJORVERSION,
                    VER_GREATER_EQUAL),
                VER_MINORVERSION,
                VER_GREATER_EQUAL),
            VER_BUILDNUMBER,
            VER_LESS))) {
        return FALSE;
    }

    HMODULE module_handle = GetModuleHandleW(L"user32.dll");
    if (!module_handle) {
        return FALSE;
    }

    typedef BOOL(WINAPI* function_type)(HWND, BOOL);

    function_type function = (function_type)(
        GetProcAddress(module_handle, "EnableChildWindowDpiMessage"));
    if (!function) {
        return FALSE;
    }

    return function(WindowHandle, TRUE);
}

static bool lv_windows_window_message_callback_nolock(
    HWND hWnd,
    UINT uMsg,
    WPARAM wParam,
    LPARAM lParam,
    LRESULT* plResult)
{
    switch (uMsg) {
    case WM_CREATE: {
        lv_windows_create_display_data_t* data =
            (lv_windows_create_display_data_t*)(
                ((LPCREATESTRUCTW)(lParam))->lpCreateParams);
        if (!data) {
            return -1;
        }

        lv_windows_window_context_t* context =
            (lv_windows_window_context_t*)(HeapAlloc(
                GetProcessHeap(),
                HEAP_ZERO_MEMORY,
                sizeof(lv_windows_window_context_t)));
        if (!context) {
            return -1;
        }

        if (!SetPropW(hWnd, L"LVGL.Window.Context", (HANDLE)(context))) {
            HeapFree(GetProcessHeap(), 0, context);
            return -1;
        }

        context->window_dpi = lv_windows_get_dpi_for_window(hWnd);
        context->zoom_level = data->zoom_level;
        context->allow_dpi_override = data->allow_dpi_override;
        context->simulator_mode = data->simulator_mode;

        // 获取窗口客户区大小
        RECT client_rect;
        GetClientRect(hWnd, &client_rect);
        int32_t init_width = client_rect.right - client_rect.left;
        int32_t init_height = client_rect.bottom - client_rect.top;

        if (init_width <= 0) init_width = 800;
        if (init_height <= 0) init_height = 600;

        // 创建显示设备（使用实际窗口大小）
        context->display_device_object = lv_display_create(init_width, init_height);
        if (!context->display_device_object) {
            RemovePropW(hWnd, L"LVGL.Window.Context");
            HeapFree(GetProcessHeap(), 0, context);
            return -1;
        }

        lv_display_set_flush_cb(
            context->display_device_object,
            lv_windows_display_driver_flush_callback);
        lv_display_set_driver_data(
            context->display_device_object,
            hWnd);

        if (!context->allow_dpi_override) {
            lv_display_set_dpi(
                context->display_device_object,
                context->window_dpi);
        }

        // 立即创建帧缓冲区
        context->display_framebuffer_context_handle = lv_windows_create_frame_buffer(
            hWnd,
            init_width,
            init_height,
            &context->display_framebuffer_base,
            &context->display_framebuffer_size);

        if (context->display_framebuffer_context_handle) {
            lv_display_set_buffers(
                context->display_device_object,
                context->display_framebuffer_base,
                NULL,
                (uint32_t)context->display_framebuffer_size,
                LV_DISPLAY_RENDER_MODE_DIRECT);
        }

        // 创建定时器（用于定期刷新）
        context->display_timer_object = lv_timer_create(
            lv_windows_display_timer_callback,
            LV_DEF_REFR_PERIOD,
            context);

        lv_windows_register_touch_window(hWnd, 0);
        lv_windows_enable_child_window_dpi_message(hWnd);

        // 初始刷新
        lv_refr_now(context->display_device_object);

        break;
    }
    case WM_SIZE: {
        if (wParam != SIZE_MINIMIZED) {
            lv_windows_window_context_t* context = (lv_windows_window_context_t*)(
                lv_windows_get_window_context(hWnd));
            if (context && context->display_device_object) {
                int32_t new_width = LOWORD(lParam);
                int32_t new_height = HIWORD(lParam);

                if (new_width > 0 && new_height > 0) {
                    // 直接调整显示大小，不依赖定时器
                    lv_windows_resize_display(context, new_width, new_height);

                    // 重置指针位置
                    if (context->pointer.point.x >= new_width) {
                        context->pointer.point.x = new_width > 0 ? new_width - 1 : 0;
                    }
                    if (context->pointer.point.y >= new_height) {
                        context->pointer.point.y = new_height > 0 ? new_height - 1 : 0;
                    }
                }
            }
        }
        break;
    }
    case WM_PAINT: {
        lv_windows_window_context_t* context = (lv_windows_window_context_t*)(
            lv_windows_get_window_context(hWnd));
        if (context && context->display_framebuffer_context_handle) {
            PAINTSTRUCT ps;
            HDC hdc = BeginPaint(hWnd, &ps);
            if (hdc) {
                SetStretchBltMode(hdc, HALFTONE);

                RECT client_rect;
                GetClientRect(hWnd, &client_rect);

                int32_t fb_width = lv_display_get_horizontal_resolution(context->display_device_object);
                int32_t fb_height = lv_display_get_vertical_resolution(context->display_device_object);

                if (fb_width > 0 && fb_height > 0) {
                    StretchBlt(
                        hdc,
                        client_rect.left,
                        client_rect.top,
                        client_rect.right - client_rect.left,
                        client_rect.bottom - client_rect.top,
                        context->display_framebuffer_context_handle,
                        0,
                        0,
                        fb_width,
                        fb_height,
                        SRCCOPY);
                }

                EndPaint(hWnd, &ps);
            }

            *plResult = 0;
            return true;
        }
        break;
    }
    case WM_ERASEBKGND: {
        // 返回TRUE防止背景擦除（减少闪烁）
        return TRUE;
    }
    case WM_DPICHANGED: {
        lv_windows_window_context_t* context = (lv_windows_window_context_t*)(
            lv_windows_get_window_context(hWnd));
        if (context) {
            context->window_dpi = HIWORD(wParam);

            if (!context->allow_dpi_override) {
                lv_display_set_dpi(
                    context->display_device_object,
                    context->window_dpi);
            }

            LPRECT suggested_rect = (LPRECT)lParam;

            SetWindowPos(
                hWnd,
                NULL,
                suggested_rect->left,
                suggested_rect->top,
                suggested_rect->right - suggested_rect->left,
                suggested_rect->bottom - suggested_rect->top,
                SWP_NOZORDER | SWP_NOACTIVATE);
        }
        break;
    }
    case WM_DESTROY: {
        lv_windows_window_context_t* context = (lv_windows_window_context_t*)(
            RemovePropW(hWnd, L"LVGL.Window.Context"));
        if (context) {
            if (context->display_timer_object) {
                lv_timer_delete(context->display_timer_object);
            }

            lv_display_t* display_device_object =
                context->display_device_object;
            context->display_device_object = NULL;

            if (display_device_object) {
                lv_display_delete(display_device_object);
            }

            if (context->display_framebuffer_context_handle) {
                DeleteDC(context->display_framebuffer_context_handle);
            }

            HeapFree(GetProcessHeap(), 0, context);
        }

        PostQuitMessage(0);
        break;
    }
    default: {
        lv_windows_window_context_t* context = (lv_windows_window_context_t*)(
            lv_windows_get_window_context(hWnd));
        if (context) {
            if (context->pointer.indev &&
                lv_windows_pointer_device_window_message_handler(
                    hWnd,
                    uMsg,
                    wParam,
                    lParam,
                    plResult)) {
                return true;
            }
            else if (context->keypad.indev &&
                lv_windows_keypad_device_window_message_handler(
                    hWnd,
                    uMsg,
                    wParam,
                    lParam,
                    plResult)) {
                return true;
            }
            else if (context->encoder.indev &&
                lv_windows_encoder_device_window_message_handler(
                    hWnd,
                    uMsg,
                    wParam,
                    lParam,
                    plResult)) {
                return true;
            }
        }
        return false;
    }
    }

    *plResult = 0;
    return true;
}

static LRESULT CALLBACK lv_windows_window_message_callback(
    HWND hWnd,
    UINT uMsg,
    WPARAM wParam,
    LPARAM lParam)
{
    lv_lock();

    LRESULT lResult = 0;
    bool Handled = lv_windows_window_message_callback_nolock(
        hWnd,
        uMsg,
        wParam,
        lParam,
        &lResult);

    lv_unlock();

    return Handled ? lResult : DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

#endif // LV_USE_WINDOWS
