#include "lvgl_lua_bindings_internal.h"
// 存储LVGL对象的引用
typedef struct {
    lv_obj_t* obj;
} LuaLVGLObject;

static int lua_create_picture(lua_State* L) {
    const char* image_path = luaL_checkstring(L, 1);
    int x = luaL_optinteger(L, 2, 0);
    int y = luaL_optinteger(L, 3, 0);

    lv_obj_t* img = lv_image_create(lv_scr_act());
    lv_image_set_src(img, image_path);
    lv_obj_set_pos(img, x, y);

    // ===== 新增：禁用滚动 =====
    lv_obj_set_scrollbar_mode(img, LV_SCROLLBAR_MODE_OFF);
    lv_obj_clear_flag(img, LV_OBJ_FLAG_SCROLLABLE);

    LuaLVGLObject* udata = (LuaLVGLObject*)lua_newuserdata(L, sizeof(LuaLVGLObject));
    udata->obj = img;
    return 1;
}
// 创建普通容器（可以嵌套）
// ===== 创建GIF动画 =====
static int lua_create_gif(lua_State* L) {
    const char* gif_path = luaL_checkstring(L, 1);
    int x = luaL_optinteger(L, 2, 0);
    int y = luaL_optinteger(L, 3, 0);
    int width = luaL_optinteger(L, 4, 0);    // 0表示使用GIF原始大小
    int height = luaL_optinteger(L, 5, 0);   // 0表示使用GIF原始大小

    // 父容器（可选）
    lv_obj_t* parent = lv_scr_act();
    if (lua_gettop(L) >= 6 && lua_isuserdata(L, 6)) {
        LuaLVGLObject* parent_udata = (LuaLVGLObject*)lua_touserdata(L, 6);
        if (parent_udata && parent_udata->obj) {
            parent = parent_udata->obj;
        }
    }

    printf("LUA: Creating GIF at (%d, %d): %s\n", x, y, gif_path);

    // 创建GIF对象
    lv_obj_t* gif = lv_gif_create(parent);

    // 设置GIF源
    lv_gif_set_src(gif, gif_path);

    // 设置位置
    lv_obj_set_pos(gif, x, y);

    // 如果指定了大小，则设置大小
    if (width > 0 && height > 0) {
        lv_obj_set_size(gif, width, height);
    }

    // 禁用滚动
    lv_obj_set_scrollbar_mode(gif, LV_SCROLLBAR_MODE_OFF);
    lv_obj_clear_flag(gif, LV_OBJ_FLAG_SCROLLABLE);

    // 返回用户数据
    LuaLVGLObject* udata = (LuaLVGLObject*)lua_newuserdata(L, sizeof(LuaLVGLObject));
    udata->obj = gif;
    return 1;
}

// ===== 新增：禁用对象滚动 =====
static int lua_disable_scroll(lua_State* L) {
    LuaLVGLObject* udata = (LuaLVGLObject*)lua_touserdata(L, 1);

    if (udata && udata->obj) {
        lv_obj_set_scrollbar_mode(udata->obj, LV_SCROLLBAR_MODE_OFF);
        lv_obj_clear_flag(udata->obj, LV_OBJ_FLAG_SCROLLABLE);
        lv_obj_set_scroll_dir(udata->obj, LV_DIR_NONE);
        printf("LUA: Disabled scrolling for object\n");
    }

    return 0;
}

// ===== 新增：隐藏组件 =====
static int lua_hide_object(lua_State* L) {
    LuaLVGLObject* udata = (LuaLVGLObject*)lua_touserdata(L, 1);

    if (udata && udata->obj) {
        // 添加隐藏标志
        lv_obj_add_flag(udata->obj, LV_OBJ_FLAG_HIDDEN);
        printf("LUA: Object hidden\n");
    }
    else {
        lua_pushstring(L, "Invalid object");
        lua_error(L);
    }

    return 0;
}

// ===== 新增：显示组件 =====
static int lua_show_object(lua_State* L) {
    LuaLVGLObject* udata = (LuaLVGLObject*)lua_touserdata(L, 1);

    if (udata && udata->obj) {
        // 移除隐藏标志
        lv_obj_clear_flag(udata->obj, LV_OBJ_FLAG_HIDDEN);
        printf("LUA: Object shown\n");
    }
    else {
        lua_pushstring(L, "Invalid object");
        lua_error(L);
    }

    return 0;
}

// ===== 新增：切换组件显示/隐藏状态 =====
static int lua_toggle_object(lua_State* L) {
    LuaLVGLObject* udata = (LuaLVGLObject*)lua_touserdata(L, 1);

    if (udata && udata->obj) {
        if (lv_obj_has_flag(udata->obj, LV_OBJ_FLAG_HIDDEN)) {
            lv_obj_clear_flag(udata->obj, LV_OBJ_FLAG_HIDDEN);
            printf("LUA: Object shown (toggled)\n");
        }
        else {
            lv_obj_add_flag(udata->obj, LV_OBJ_FLAG_HIDDEN);
            printf("LUA: Object hidden (toggled)\n");
        }
    }
    else {
        lua_pushstring(L, "Invalid object");
        lua_error(L);
    }

    return 0;
}
// ========== Chart Methods Table ==========
static const luaL_Reg lv_picture_methods[] = {
    {"create_picture", lua_create_picture},
    {"create_gif", lua_create_gif},
    {"disable_scroll", lua_disable_scroll},
    {"hide_object", lua_hide_object},
    {"show_object", lua_show_object},
    {"toggle_object", lua_toggle_object},
   
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_picture_methods(void) {
    return lv_picture_methods;
}
