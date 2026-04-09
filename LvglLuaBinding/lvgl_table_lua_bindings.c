/**
 * @file lvgl_table_lua_bindings.c
 * @brief LVGL Table Lua bindings
 *
 * 这个文件提供了LVGL表格控件的Lua绑定，支持以下功能：
 * - 设置表格行列数
 * - 设置单元格内容、样式、对齐方式
 * - 设置列宽、行高
 * - 单元格控制标志（合并、对齐等）
 * - 单元格用户数据存储
 * - 单元格选中功能
 */

#include "lvgl_lua_bindings_internal.h"

 // ============================================
 // 基础方法
 // ============================================

 /**
  * 设置表格行数
  * Lua调用: table:set_row_cnt(row_cnt)
  * @param row_cnt 行数（0-65535）
  */
static int l_table_set_row_cnt(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t row = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_table_set_row_count(obj, row);  // 使用正确的API
    return 0;
}

/**
 * 设置表格列数
 * Lua调用: table:set_col_cnt(col_cnt)
 * @param col_cnt 列数（0-65535）
 */
static int l_table_set_col_cnt(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t col = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_table_set_column_count(obj, col);  // 使用正确的API
    return 0;
}

/**
 * 设置单元格文本值（支持格式化）
 * Lua调用: table:set_cell_value(row, col, txt)
 *         table:set_cell_value_fmt(row, col, fmt, ...)  -- 格式化版本
 * @param row 行索引（0开始）
 * @param col 列索引（0开始）
 * @param txt 文本内容
 */
static int l_table_set_cell_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t row = (uint32_t)luaL_checkinteger(L, 2);
    uint32_t col = (uint32_t)luaL_checkinteger(L, 3);
    const char* txt = luaL_checkstring(L, 4);
    if (obj && txt) {
        lv_table_set_cell_value(obj, row, col, txt);
    }
    return 0;
}

/**
 * 设置单元格格式化文本（类似printf）
 * Lua调用: table:set_cell_value_fmt(row, col, "Value: %d", 100)
 */
 /**
  * 设置单元格格式化文本（类似printf）
  * Lua调用: table:set_cell_value_fmt(row, col, fmt, ...)
  */
  // 注意：函数名后面必须有三个点 ... 表示可变参数
static int l_table_set_cell_value_fmt(lua_State* L, ...) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t row = (uint32_t)luaL_checkinteger(L, 2);
    uint32_t col = (uint32_t)luaL_checkinteger(L, 3);
    const char* fmt = luaL_checkstring(L, 4);

    if (obj && fmt) {
        // 获取格式化参数
        char buffer[512];
        va_list args;
        va_start(args, fmt);  // 现在可以使用了
        vsnprintf(buffer, sizeof(buffer), fmt, args);
        va_end(args);
        lv_table_set_cell_value(obj, row, col, buffer);
    }
    return 0;
}

/**
 * 获取单元格文本值
 * Lua调用: local text = table:get_cell_value(row, col)
 * @return 单元格文本内容
 */
static int l_table_get_cell_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t row = (uint32_t)luaL_checkinteger(L, 2);
    uint32_t col = (uint32_t)luaL_checkinteger(L, 3);

    if (obj) {
        const char* txt = lv_table_get_cell_value(obj, row, col);
        lua_pushstring(L, txt ? txt : "");
        return 1;
    }
    lua_pushstring(L, "");
    return 1;
}

// ============================================
// 行列操作
// ============================================

/**
 * 获取表格行数
 * Lua调用: local rows = table:get_row_count()
 * @return 行数
 */
static int l_table_get_row_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) {
        uint32_t count = lv_table_get_row_count(obj);
        lua_pushinteger(L, count);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

/**
 * 获取表格列数
 * Lua调用: local cols = table:get_column_count()
 * @return 列数
 */
static int l_table_get_column_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) {
        uint32_t count = lv_table_get_column_count(obj);
        lua_pushinteger(L, count);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

// ============================================
// 列宽设置
// ============================================

/**
 * 设置指定列的宽度
 * Lua调用: table:set_column_width(col_id, width)
 * @param col_id 列索引
 * @param width 宽度（像素）
 */
static int l_table_set_column_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t col_id = (uint32_t)luaL_checkinteger(L, 2);
    int32_t width = (int32_t)luaL_checkinteger(L, 3);
    if (obj) {
        lv_table_set_column_width(obj, col_id, width);
    }
    return 0;
}

/**
 * 获取指定列的宽度
 * Lua调用: local width = table:get_column_width(col_id)
 * @return 列宽（像素）
 */
static int l_table_get_column_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t col_id = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) {
        int32_t width = lv_table_get_column_width(obj, col_id);
        lua_pushinteger(L, width);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

/**
 * 设置所有列等宽（平均分配父容器宽度）
 * Lua调用: table:set_equal_column_widths(col_count)
 * @param col_count 列数
 */
static int l_table_set_equal_column_widths(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t col_count = (uint32_t)luaL_checkinteger(L, 2);

    if (obj && lv_obj_get_parent(obj)) {
        lv_obj_t* parent = lv_obj_get_parent(obj);
        int32_t parent_width = lv_obj_get_width(parent);
        int32_t col_width = parent_width / col_count;

        for (uint32_t col = 0; col < col_count; col++) {
            lv_table_set_column_width(obj, col, col_width);
        }
    }
    return 0;
}

// ============================================
// 单元格控制标志（用于合并单元格、对齐等）
// ============================================

/**
 * 添加单元格控制标志
 * Lua调用: table:add_cell_ctrl(row, col, ctrl)
 * @param ctrl 控制标志，可以是：
 *   - lv.TABLE_CELL_CTRL_MERGE_RIGHT  -- 向右合并单元格
 *   - lv.TABLE_CELL_CTRL_MERGE_DOWN   -- 向下合并单元格
 *   - lv.TABLE_CELL_CTRL_TEXT_CENTER  -- 文本居中
 *   - lv.TABLE_CELL_CTRL_TEXT_RIGHT   -- 文本右对齐
 *   - lv.TABLE_CELL_CTRL_CUSTOM_1     -- 自定义标志1
 *   - lv.TABLE_CELL_CTRL_CUSTOM_2     -- 自定义标志2
 *   - lv.TABLE_CELL_CTRL_CUSTOM_3     -- 自定义标志3
 *   - lv.TABLE_CELL_CTRL_CUSTOM_4     -- 自定义标志4
 */

/**
 * 清除单元格控制标志
 * Lua调用: table:clear_cell_ctrl(row, col, ctrl)
 */
static int l_table_clear_cell_ctrl(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t row = (uint32_t)luaL_checkinteger(L, 2);
    uint32_t col = (uint32_t)luaL_checkinteger(L, 3);
    lv_table_cell_ctrl_t ctrl = (lv_table_cell_ctrl_t)luaL_checkinteger(L, 4);

    if (obj) {
        lv_table_clear_cell_ctrl(obj, row, col, ctrl);
    }
    return 0;
}

/**
 * 检查单元格是否有指定控制标志
 * Lua调用: local has = table:has_cell_ctrl(row, col, ctrl)
 * @return boolean 是否有该标志
 */
static int l_table_has_cell_ctrl(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t row = (uint32_t)luaL_checkinteger(L, 2);
    uint32_t col = (uint32_t)luaL_checkinteger(L, 3);
    lv_table_cell_ctrl_t ctrl = (lv_table_cell_ctrl_t)luaL_checkinteger(L, 4);

    if (obj) {
        bool has = lv_table_has_cell_ctrl(obj, row, col, ctrl);
        lua_pushboolean(L, has);
        return 1;
    }
    lua_pushboolean(L, false);
    return 1;
}

// ============================================
// 单元格用户数据
// ============================================

/**
 * 设置单元格用户数据（存储任意指针数据）
 * Lua调用: table:set_cell_user_data(row, col, user_data)
 * @param user_data 用户数据（lightuserdata）
 * 注意：用于存储自定义数据指针，Lua中通常用lightuserdata
 */
static int l_table_set_cell_user_data(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint16_t row = (uint16_t)luaL_checkinteger(L, 2);
    uint16_t col = (uint16_t)luaL_checkinteger(L, 3);
    void* user_data = lua_touserdata(L, 4);  // lightuserdata

    if (obj) {
        lv_table_set_cell_user_data(obj, row, col, user_data);
    }
    return 0;
}

/**
 * 获取单元格用户数据
 * Lua调用: local data = table:get_cell_user_data(row, col)
 * @return lightuserdata 用户数据
 */
static int l_table_get_cell_user_data(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint16_t row = (uint16_t)luaL_checkinteger(L, 2);
    uint16_t col = (uint16_t)luaL_checkinteger(L, 3);

    if (obj) {
        void* user_data = lv_table_get_cell_user_data(obj, row, col);
        lua_pushlightuserdata(L, user_data);
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

// ============================================
// 单元格选中功能
// ============================================

/**
 * 设置选中的单元格
 * Lua调用: table:set_selected_cell(row, col)
 * 功能：高亮显示选中的单元格
 */
static int l_table_set_selected_cell(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint16_t row = (uint16_t)luaL_checkinteger(L, 2);
    uint16_t col = (uint16_t)luaL_checkinteger(L, 3);

    if (obj) {
        lv_table_set_selected_cell(obj, row, col);
    }
    return 0;
}

/**
 * 获取选中的单元格
 * Lua调用: local row, col = table:get_selected_cell()
 * @return row, col 选中的行列索引
 */
static int l_table_get_selected_cell(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);

    if (obj) {
        uint32_t row = 0, col = 0;
        lv_table_get_selected_cell(obj, &row, &col);
        lua_pushinteger(L, row);
        lua_pushinteger(L, col);
        return 2;
    }
    lua_pushinteger(L, 0);
    lua_pushinteger(L, 0);
    return 2;
}

// ============================================
// 布局辅助方法
// ============================================

/**
 * 设置表格铺满父容器
 * Lua调用: table:set_full_size()
 * 功能：自动设置表格大小为父容器的宽高
 */
static int l_table_set_full_size(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_get_parent(obj)) {
        lv_obj_t* parent = lv_obj_get_parent(obj);
        int32_t parent_width = lv_obj_get_width(parent);
        int32_t parent_height = lv_obj_get_height(parent);
        lv_obj_set_size(obj, parent_width, parent_height);
    }
    return 0;
}

/**
 * 获取父容器宽度
 * Lua调用: local width = table:get_parent_width()
 */
static int l_table_get_parent_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_get_parent(obj)) {
        lv_obj_t* parent = lv_obj_get_parent(obj);
        int32_t width = lv_obj_get_width(parent);
        lua_pushinteger(L, width);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

/**
 * 获取父容器高度
 * Lua调用: local height = table:get_parent_height()
 */
static int l_table_get_parent_height(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_get_parent(obj)) {
        lv_obj_t* parent = lv_obj_get_parent(obj);
        int32_t height = lv_obj_get_height(parent);
        lua_pushinteger(L, height);
        return 1;
    }
    lua_pushinteger(L, 0);
    return 1;
}

/**
 * 设置表格内部边框（单元格间距）
 * Lua调用: table:set_inner_border_width(width)
 * @param width 边框宽度（像素）
 */
static int l_table_set_inner_border_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint16_t border_width = (uint16_t)luaL_checkinteger(L, 2);

    if (obj) {
        lv_obj_set_style_pad_all(obj, border_width, 0);
        lv_obj_set_style_border_width(obj, 1, 0);
        lv_obj_set_style_border_color(obj, lv_color_hex(0xCCCCCC), 0);
    }
    return 0;
}

/**
 * 设置表格边框可见性
 * Lua调用: table:show_borders(show)
 * @param show true显示边框，false隐藏边框
 */
static int l_table_show_borders(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool show = lua_toboolean(L, 2);

    if (obj) {
        if (show) {
            lv_obj_set_style_border_width(obj, 1, 0);
            lv_obj_set_style_border_color(obj, lv_color_hex(0x999999), 0);
        }
        else {
            lv_obj_set_style_border_width(obj, 0, 0);
        }
    }
    return 0;
}


// ============================================
// 方法注册表
// ============================================

static const luaL_Reg lv_table_methods[] = {
    // 基础方法
    {"set_row_cnt", l_table_set_row_cnt},
    {"set_col_cnt", l_table_set_col_cnt},
    {"set_cell_value", l_table_set_cell_value},
    {"set_cell_value_fmt", l_table_set_cell_value_fmt},
    {"get_cell_value", l_table_get_cell_value},

    // 行列操作
    {"get_row_count", l_table_get_row_count},
    {"get_column_count", l_table_get_column_count},

    // 列宽操作
    {"set_column_width", l_table_set_column_width},
    {"get_column_width", l_table_get_column_width},
    {"set_equal_column_widths", l_table_set_equal_column_widths},

    {"clear_cell_ctrl", l_table_clear_cell_ctrl},
    {"has_cell_ctrl", l_table_has_cell_ctrl},

    // 用户数据
    {"set_cell_user_data", l_table_set_cell_user_data},
    {"get_cell_user_data", l_table_get_cell_user_data},

    // 选中功能
    {"set_selected_cell", l_table_set_selected_cell},
    {"get_selected_cell", l_table_get_selected_cell},

    // 布局辅助
    {"set_full_size", l_table_set_full_size},
    {"get_parent_width", l_table_get_parent_width},
    {"get_parent_height", l_table_get_parent_height},
    {"set_inner_border_width", l_table_set_inner_border_width},
    {"show_borders", l_table_show_borders},

    {NULL, NULL}
};

const luaL_Reg* lvgl_get_table_methods(void) {
    return lv_table_methods;
}
