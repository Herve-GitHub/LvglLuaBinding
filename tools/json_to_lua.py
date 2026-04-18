#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
json_to_lua.py — 独立的 JSON 工程文件 → Lua 脚本编译器
Standalone JSON project-file → Lua script compiler.

用法 / Usage:
    python tools/json_to_lua.py  project.json  [output.lua]

若不提供输出路径，则在与输入文件相同目录下生成同名 .lua 文件。
If no output path is given the .lua file is written next to the JSON file.

该脚本与 VduEditor/lua/editor/ProjectCompiler.lua 的逻辑完全一致，
因此生成的 Lua 脚本可直接在 VduSimulator 或目标硬件上运行。

This script mirrors the logic of VduEditor/lua/editor/ProjectCompiler.lua
so the generated Lua runs in VduSimulator or on target hardware unchanged.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime
from typing import Any

# ---------------------------------------------------------------------------
# Widget-type → Lua module path mapping  (mirrors WIDGET_TYPE_TO_MODULE)
# ---------------------------------------------------------------------------
WIDGET_TYPE_TO_MODULE: dict[str, str] = {
    "custom_button": "widgets.button",
    "label":         "widgets.label",
    "button":        "widgets.new_button",
    "valve":         "widgets.valve",
    "trend_chart":   "widgets.trend_chart",
    "status_bar":    "widgets.status_bar",
    "switch":        "widgets.switch",
    "image":         "widgets.image",
    "PopupButton":   "widgets.PopupButton",
    "checkbox":      "widgets.checkbox",
    "dropdown":      "widgets.dropdown",
    "slider":        "widgets.slider",
    "new_label":     "widgets.new_label",
}

# Supported event names per widget type  (mirrors WIDGET_EVENTS)
WIDGET_EVENTS: dict[str, list[str]] = {
    "custom_button": ["clicked", "single_clicked", "double_clicked"],
    "button":        ["clicked", "single_clicked", "double_clicked"],
    "valve":         ["angle_changed", "toggled"],
    "trend_chart":   ["updated"],
    "status_bar":    ["updated", "time_tick"],
    "switch":        ["changed"],
    "checkbox":      ["changed"],
    "dropdown":      ["changed"],
    "slider":        ["changed"],
}

# Default parameter signatures for auto-wrapped handlers
EVENT_DEFAULT_PARAMS: dict[str, str] = {
    "clicked":        "self",
    "single_clicked": "self",
    "double_clicked": "self",
    "angle_changed":  "self, angle",
    "toggled":        "self, is_open",
    "updated":        "self, value",
    "time_tick":      "self, time_str",
    "changed":        "self",
}

# Action modules always imported in generated scripts.
# NOTE: "SitwchAction" is the actual filename in the repository
# (VduEditor/lua/actions/SitwchAction.lua) – the "Sitwch" spelling
# is intentional to match that existing file.
ACTION_MODULES: list[str] = [
    "actions.page_navigation",
    "editor.DataAction",
    "actions.LabelAction",
    "actions.SitwchAction",
]

# Properties that hold CSS-style colour strings (#RRGGBB)
COLOR_PROPERTIES: set[str] = {
    "bg_color", "color", "handle_color", "border_color",
    "text_color", "line_color", "fill_color",
    "bg_color_off", "bg_color_on",
}


# ---------------------------------------------------------------------------
# Utility helpers
# ---------------------------------------------------------------------------

def _escape_string(s: str) -> str:
    """Escape a string for embedding in a Lua double-quoted literal."""
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", "\\n")
    s = s.replace("\r", "\\r")
    s = s.replace("\t", "\\t")
    return s


def _make_valid_var_name(name: str) -> str | None:
    """Convert *name* to a legal Lua variable name, or return None."""
    if not name:
        return None
    valid = re.sub(r"[^\w]", "_", name, flags=re.ASCII)
    if re.match(r"^\d", valid):
        valid = "_" + valid
    if not valid or valid == "_":
        return None
    return valid


def _number_to_color_string(value: Any) -> str:
    """Convert an integer colour (e.g. 0x1E1E1E) to "#RRGGBB"."""
    if isinstance(value, int):
        return "#{:06X}".format(value & 0xFFFFFF)
    return str(value)


def _color_to_hex_string(value: Any) -> str:
    """Return a Lua-style hex colour literal (0xRRGGBB)."""
    if isinstance(value, int):
        return "0x{:06X}".format(value & 0xFFFFFF)
    if isinstance(value, str):
        m = re.match(r"^#([0-9a-fA-F]{6})$", value)
        if m:
            return "0x" + m.group(1).upper()
        return value
    return "0x1E1E1E"


def _preprocess_color_props(props: dict) -> dict:
    """In-place: convert integer colours in *props* to "#RRGGBB" strings."""
    for key in COLOR_PROPERTIES:
        if key in props and isinstance(props[key], int):
            props[key] = _number_to_color_string(props[key])
    return props


def _value_to_lua(value: Any, indent: str = "") -> str:
    """Recursively serialise a Python value as a Lua literal."""
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return '"' + _escape_string(value) + '"'
    if isinstance(value, (list, tuple)):
        items = [_value_to_lua(v, indent + "    ") for v in value]
        return "{ " + ", ".join(items) + " }"
    if isinstance(value, dict):
        new_indent = indent + "    "
        parts: list[str] = []
        for k, v in value.items():
            if re.match(r"^[A-Za-z_]\w*$", str(k)):
                key_str = str(k)
            else:
                key_str = "[" + _value_to_lua(k) + "]"
            parts.append(new_indent + key_str + " = " + _value_to_lua(v, new_indent))
        if not parts:
            return "{}"
        return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
    return '"' + _escape_string(str(value)) + '"'


def _is_complete_function(code: str) -> bool:
    """Return True if *code* looks like a complete Lua function definition."""
    stripped = code.strip()
    return stripped.startswith("function(") and stripped.endswith("end")


def _find_websocket_url(project_data: dict) -> tuple[str, int]:
    """Scan all widgets for a websocket_url; return (url, timeout)."""
    url = ""
    timeout = 3000
    for page in project_data.get("pages", []):
        for widget in page.get("widgets", []):
            props = widget.get("props", {})
            if props.get("websocket_url"):
                url = props["websocket_url"]
    return url, timeout


# ---------------------------------------------------------------------------
# Code generation helpers
# ---------------------------------------------------------------------------

def _generate_widget_code(
    widget: dict,
    index: int,
    page_var: str,
    used_names: dict[str, bool],
) -> tuple[str, str, str]:
    """
    Generate Lua for a single widget.

    Returns ``(lua_code, module_path, var_name)``.
    """
    lines: list[str] = []
    widget_type  = widget.get("type", "custom_button")
    module_path  = widget.get("module_path") or WIDGET_TYPE_TO_MODULE.get(widget_type, "widgets.button")
    props        = dict(widget.get("props") or {})

    # Always disable design mode in compiled output
    props["design_mode"] = False

    _preprocess_color_props(props)

    # Determine Lua variable name
    instance_name = props.get("instance_name", "")
    var_name      = _make_valid_var_name(instance_name)
    if not var_name:
        var_name = "widget_" + str(index)
    elif var_name in used_names:
        var_name = var_name + "_" + str(index)
    used_names[var_name] = True

    props_str = _value_to_lua(props, "    ")
    module_var = module_path.replace(".", "_")

    comment = "控件 {}: {}".format(index, widget_type)
    if instance_name:
        comment += " ({})".format(instance_name)

    lines.append("    -- " + comment)
    lines.append(
        "    local {} = {}.new({}, {})".format(var_name, module_var, page_var, props_str)
    )
    lines.append("")

    # Event handlers
    events = WIDGET_EVENTS.get(widget_type, ["clicked", "single_clicked", "double_clicked"])
    for event_name in events:
        handler_prop = "on_{}_handler".format(event_name)
        handler_code = props.get(handler_prop, "")
        if not handler_code:
            continue

        lines.append("    -- {} 事件处理".format(event_name))
        if _is_complete_function(handler_code):
            lines.append('    {}:on("{}", {})'.format(var_name, event_name, handler_code))
        else:
            params = EVENT_DEFAULT_PARAMS.get(event_name, "self")
            lines.append('    {}:on("{}", function({})'.format(var_name, event_name, params))
            for line in handler_code.splitlines():
                lines.append("        " + line)
            lines.append("    end)")
        lines.append("")

    return "\n".join(lines), module_path, var_name


def _generate_page_code(
    page: dict,
    page_index: int,
) -> tuple[str, dict[str, bool], list[str]]:
    """
    Generate Lua for a whole page.

    Returns ``(lua_code, required_modules, widget_var_names)``.
    """
    lines:            list[str]       = []
    required_modules: dict[str, bool] = {}
    widget_vars:      list[str]       = []
    used_names:       dict[str, bool] = {}

    page_width    = page.get("width", 800)
    page_height   = page.get("height", 600)
    page_bg_color = _color_to_hex_string(page.get("bg_color", 0x1E1E1E))
    page_var      = "page_{}".format(page_index)

    lines.append("-- ========== 图页 {}: {} ==========".format(
        page_index, page.get("name", "未命名")))
    lines.append("-- 图页尺寸: {}x{}".format(page_width, page_height))
    lines.append("-- 背景颜色: {}".format(page_bg_color))
    lines.append("local function create_{}(parent)".format(page_var))
    lines.append("    -- 创建图页容器")
    lines.append("    local container = lv.obj_create(parent)")
    lines.append("    container:set_pos(0, 0)")
    lines.append("    container:set_size({}, {})".format(page_width, page_height))
    lines.append("    container:set_style_bg_color({}, 0)".format(page_bg_color))
    lines.append("    container:set_style_border_width(0, 0)")
    lines.append("    container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)")
    lines.append("    container:clear_layout()")
    lines.append("")

    for i, widget in enumerate(page.get("widgets", []), start=1):
        code, module_path, var_name = _generate_widget_code(widget, i, "container", used_names)
        lines.append(code)
        required_modules[module_path] = True
        widget_vars.append(var_name)

    lines.append("    return container")
    lines.append("end")
    lines.append("")

    return "\n".join(lines), required_modules, widget_vars


# ---------------------------------------------------------------------------
# Main compiler
# ---------------------------------------------------------------------------

def compile_project(project_data: dict) -> str:
    """
    Compile a project dict (parsed from JSON) into a Lua script string.

    Mirrors ``ProjectCompiler:compile()`` in ProjectCompiler.lua.
    """
    lines: list[str] = []

    has_status_bar = bool(
        project_data.get("status_bar") and project_data["status_bar"].get("enabled")
    )

    websocket_url, websocket_timeout = _find_websocket_url(project_data)

    # ---- Header ----
    lines += [
        "-- ==============================================",
        "-- 自动生成的Lua脚本",
        "-- 由 json_to_lua.py 编译生成",
        "-- 生成时间: " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "-- 工程版本: " + str(project_data.get("version", "1.0")),
        "-- ==============================================",
        "",
    ]

    # ---- Network service ----
    lines.append("-- 启动网络服务")
    lines.append("lvgl.start_network_service(3000)")
    if websocket_url:
        lines.append('lvgl.connect("{}", {})'.format(
            _escape_string(websocket_url), websocket_timeout))
    else:
        lines.append('lvgl.connect("", 3000)')
    lines.append("")

    # ---- Collect all required widget modules ----
    all_required_modules: dict[str, bool] = {}
    for page in project_data.get("pages", []):
        for widget in page.get("widgets", []):
            wtype = widget.get("type", "custom_button")
            mpath = widget.get("module_path") or WIDGET_TYPE_TO_MODULE.get(wtype, "widgets.button")
            all_required_modules[mpath] = True

    if has_status_bar:
        all_required_modules["widgets.status_bar"] = True

    # ---- Require statements ----
    lines.append("-- 引用 LVGL")
    lines.append('local lv = require("lvgl")')
    lines.append("")

    lines.append("-- 引用控件模块")
    for mpath in sorted(all_required_modules):
        var = mpath.replace(".", "_")
        lines.append('local {} = require("{}")'.format(var, mpath))
    lines.append("")

    lines.append("-- 引用动作模块")
    for mpath in ACTION_MODULES:
        var = mpath.replace(".", "_")
        lines.append('local {} = require("{}")'.format(var, mpath))
    lines.append("")

    # ---- Screen setup ----
    lines += [
        "-- 获取活动屏幕",
        "local scr = lv.scr_act()",
        "scr:set_style_bg_color(0x1E1E1E, 0)",
        "scr:remove_flag(lv.OBJ_FLAG_SCROLLABLE)",
        "scr:clear_layout()",
        "",
        "-- 获取屏幕尺寸",
        "local scr_width = scr:get_width()",
        "local scr_height = scr:get_height()",
        "",
    ]

    # ---- Status bar ----
    if has_status_bar:
        sb             = project_data["status_bar"]
        sb_height      = 28
        sb_position    = sb.get("position", "bottom")
        sb_lamp_status = sb.get("lamp_status", "#00FF00")
        sb_lamp_text   = sb.get("lamp_text", "CH1")
        sb_bg_color    = sb.get("bg_color", "#252526")
        sb_text_color  = sb.get("text_color", "#CCCCCC")
        sb_show_time   = "true" if sb.get("show_time", True) else "false"
        sb_lamp_size   = sb.get("lamp_size", 14)

        lines += [
            "-- ========== 状态栏 ==========",
            "local status_bar = nil",
            "local STATUS_BAR_HEIGHT = {}".format(sb_height),
            "",
            "local function create_status_bar()",
            "    local sb_y = scr_height - STATUS_BAR_HEIGHT",
            "    status_bar = widgets_status_bar.new(scr, {",
            "        x = 0,",
            "        y = sb_y,",
            "        width = scr_width,",
            "        height = STATUS_BAR_HEIGHT,",
            '        position = "{}",'.format(sb_position),
            '        lamp_status = "{}",'.format(sb_lamp_status),
            '        lamp_text = "{}",'.format(_escape_string(sb_lamp_text)),
            '        bg_color = "{}",'.format(sb_bg_color),
            '        text_color = "{}",'.format(sb_text_color),
            "        show_time = {},".format(sb_show_time),
            "        lamp_size = {},".format(sb_lamp_size),
            "        design_mode = false,",
            "    })",
            "    status_bar:start()",
            "    return status_bar",
            "end",
            "",
        ]

    # ---- Pages ----
    page_functions: list[str] = []
    for i, page in enumerate(project_data.get("pages", []), start=1):
        page_code, _modules, _vars = _generate_page_code(page, i)
        lines.append(page_code)
        page_functions.append("create_page_{}".format(i))

    # ---- PageManager ----
    lines += [
        "-- ========== 图页管理（预创建模式） ==========",
        "local PageManager = {}",
        "PageManager.pages = {}        -- 图页信息",
        "PageManager.containers = {}   -- 预创建的图页容器",
        "PageManager.current_index = 0",
        "",
        "-- 注册图页创建函数",
    ]
    for i, func_name in enumerate(page_functions, start=1):
        page_name = ""
        pages = project_data.get("pages", [])
        if i <= len(pages):
            page_name = pages[i - 1].get("name", "图页 {}".format(i))
        lines.append(
            'PageManager.pages[{}] = {{ name = "{}", create = {} }}'.format(
                i, _escape_string(page_name), func_name
            )
        )
    lines.append("")

    lines += [
        "-- 预创建所有图页（启动时调用）",
        "function PageManager.init()",
        '    print("[PageManager] 预创建所有图页...")',
        "    for i, page_info in ipairs(PageManager.pages) do",
        "        if page_info.create then",
        "            local container = page_info.create(scr)",
        "            -- 默认隐藏所有图页",
        "            container:add_flag(lv.OBJ_FLAG_HIDDEN)",
        "            PageManager.containers[i] = container",
        '            print("[PageManager] 图页 " .. i .. " 已创建: " .. page_info.name)',
        "        end",
        "    end",
        '    print("[PageManager] 所有图页创建完成，共 " .. #PageManager.containers .. " 个")',
        "end",
        "",
        "-- 获取图页数量",
        "function PageManager.get_page_count()",
        "    return #PageManager.pages",
        "end",
        "",
        "-- 获取当前选中的图页",
        "function PageManager.get_selected_page()",
        "    if PageManager.current_index > 0 then",
        "        return PageManager.pages[PageManager.current_index], PageManager.current_index",
        "    end",
        "    return nil, 0",
        "end",
        "",
        "-- 获取所有图页",
        "function PageManager.get_pages()",
        "    return PageManager.pages",
        "end",
        "",
        "-- 选择图页（与 goto_page 相同）",
        "function PageManager.select_page(index)",
        "    return PageManager.goto_page(index)",
        "end",
        "",
        "-- 切换图页（显示/隐藏模式，不销毁图页）",
        "function PageManager.goto_page(index)",
        "    if index < 1 or index > #PageManager.pages then",
        '        print("[PageManager] 无效的图页索引: " .. tostring(index))',
        "        return false",
        "    end",
        "",
        "    -- 隐藏当前图页",
        "    if PageManager.current_index > 0 and PageManager.containers[PageManager.current_index] then",
        "        PageManager.containers[PageManager.current_index]:add_flag(lv.OBJ_FLAG_HIDDEN)",
        "    end",
        "",
        "    -- 显示目标图页",
        "    if PageManager.containers[index] then",
        "        PageManager.containers[index]:remove_flag(lv.OBJ_FLAG_HIDDEN)",
        "        PageManager.current_index = index",
        '        print("[PageManager] 切换到图页 " .. index .. ": " .. PageManager.pages[index].name)',
        "        return true",
        "    end",
        "",
        "    return false",
        "end",
        "",
        "-- 获取指定图页的容器",
        "function PageManager.get_page_container(index)",
        "    return PageManager.containers[index]",
        "end",
        "",
        "-- 获取当前图页的容器",
        "function PageManager.get_current_container()",
        "    return PageManager.containers[PageManager.current_index]",
        "end",
        "",
        "-- 导出图页管理器到全局",
        "_G.PageManager = PageManager",
        "",
        "-- 创建模拟编辑器接口（供 actions 模块使用）",
        "_G.Editor = {",
        "    get_canvas_list = function()",
        "        return PageManager",
        "    end,",
    ]
    if has_status_bar:
        lines += [
            "    get_status_bar = function()",
            "        return status_bar",
            "    end,",
        ]
    lines += [
        "}",
        "",
    ]

    # ---- Startup ----
    start_page = project_data.get("current_page_index", 1) or 1
    lines += [
        "-- ========== 启动 ==========",
        'print("=== 组态程序启动 ===")',
        'print("图页数量: " .. #PageManager.pages)',
        "",
    ]

    if has_status_bar:
        lines += ["-- 创建状态栏", "create_status_bar()", ""]

    lines += [
        "-- 预创建所有图页",
        "PageManager.init()",
        "",
        "-- 显示初始图页",
        "PageManager.goto_page({})".format(start_page),
        "",
        'print("=== 组态程序已就绪 ===")',
        "",
    ]

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="将 VduEditor JSON 工程文件编译为 Lua 脚本 / "
                    "Compile a VduEditor JSON project file into a Lua script.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("input",  help="输入 JSON 文件路径 / Input JSON file path")
    parser.add_argument("output", nargs="?", help="输出 Lua 文件路径 / Output Lua file path (optional)")
    args = parser.parse_args()

    in_path  = args.input
    out_path = args.output

    if out_path is None:
        base, _ = os.path.splitext(in_path)
        out_path = base + ".lua"

    # Read JSON
    try:
        with open(in_path, "r", encoding="utf-8-sig") as fh:
            project_data = json.load(fh)
    except FileNotFoundError:
        print("错误: 找不到文件 / Error: file not found: {}".format(in_path), file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print("错误: JSON 解析失败 / Error: JSON parse error: {}".format(exc), file=sys.stderr)
        return 1

    # Compile
    try:
        lua_code = compile_project(project_data)
    except Exception as exc:  # pragma: no cover
        print("错误: 编译失败 / Error: compilation failed: {}".format(exc), file=sys.stderr)
        return 1

    # Write Lua
    try:
        with open(out_path, "w", encoding="utf-8") as fh:
            fh.write(lua_code)
    except OSError as exc:
        print("错误: 无法写入文件 / Error: cannot write file: {}".format(exc), file=sys.stderr)
        return 1

    print("编译完成 / Compiled: {} → {}".format(in_path, out_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
