# VduEditor JSON → Lua 编译器 / JSON-to-Lua Compiler

这个目录包含了将 JSON 格式的 HMI 组态文件编译为 LVGL Lua 脚本的独立工具。

This directory contains standalone tools for compiling JSON-format HMI project files
into LVGL Lua scripts that run in VduSimulator or on target hardware.

---

## 快速开始 / Quick Start

```bash
# 编译一个 JSON 工程文件  /  Compile a JSON project file
python tools/json_to_lua.py  my_project.json

# 指定输出路径  /  Specify an output path
python tools/json_to_lua.py  my_project.json  VduSimulator/projects/my_project.lua
```

只需要 **Python 3.7+**，无其他依赖。  
Only **Python 3.7+** is required – no external dependencies.

---

## 工作流程 / Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. 创建 / 编辑 JSON 组态文件                                        │
│     Create / edit a JSON project file                                │
│     • 使用任意文本编辑器（VS Code, Notepad++, …）                   │
│     • 或使用 Web 可视化编辑器（未来计划）                           │
│     • 或直接用 VduEditor GUI 保存为 JSON                            │
└──────────────────────────┬──────────────────────────────────────────┘
                           │  project.json
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. 运行编译器  /  Run the compiler                                  │
│     python tools/json_to_lua.py  project.json                       │
└──────────────────────────┬──────────────────────────────────────────┘
                           │  project.lua
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. 部署 Lua 脚本  /  Deploy the Lua script                          │
│     • 放入 VduSimulator/projects/  进行本机测试                     │
│     • 或直接部署到嵌入式设备                                        │
│     Copy to VduSimulator/projects/ for local testing,               │
│     or deploy directly to embedded hardware                         │
└─────────────────────────────────────────────────────────────────────┘
```

---

## JSON 工程文件格式 / JSON Project Format

完整 JSON Schema 见 [`schema/project_schema.json`](schema/project_schema.json)。  
Full JSON Schema is in [`schema/project_schema.json`](schema/project_schema.json).

示例见 [`examples/demo_hmi.json`](examples/demo_hmi.json)。  
An annotated example is in [`examples/demo_hmi.json`](examples/demo_hmi.json).

### 顶层结构 / Top-level structure

```jsonc
{
  "version": "1.0",            // 工程格式版本
  "current_page_index": 1,     // 启动时显示的图页（1-based）
  "settings": { … },           // 编辑器设置（可选）
  "status_bar": { … },         // 状态栏（可选）
  "pages": [ … ]               // 图页列表（至少 1 个）
}
```

### 图页 / Page

```jsonc
{
  "id":       "page_1",        // 唯一标识符
  "name":     "主页",           // 显示名称
  "width":    1024,            // 画布宽度（px）
  "height":   600,             // 画布高度（px）
  "bg_color": "#1E1E2E",       // 背景颜色 (#RRGGBB)
  "widgets":  [ … ]            // 控件列表
}
```

### 控件 / Widget

```jsonc
{
  "type":        "custom_button",          // 控件类型
  "module_path": "widgets.button",         // Lua 模块（可选，有默认值）
  "props": {
    "instance_name": "btn_ok",             // Lua 变量名（留空自动生成）
    "x": 100,  "y": 200,                   // 位置（px）
    "width": 120,  "height": 40,           // 尺寸（px）
    "label": "确认",                        // 文本
    "bg_color": "#007ACC",                 // 背景色
    "color":    "#FFFFFF",                 // 文字色
    "on_clicked_handler": "function(self)\n    print('clicked')\nend"
  }
}
```

### 支持的控件类型 / Supported Widget Types

| `type` 值              | Lua 模块               | 说明                      |
|------------------------|------------------------|---------------------------|
| `custom_button`        | `widgets.button`       | 按钮（支持数据绑定）        |
| `button`               | `widgets.new_button`   | 简单按钮                  |
| `label`                | `widgets.label`        | 标签                      |
| `new_label`            | `widgets.new_label`    | 增强标签                  |
| `valve`                | `widgets.valve`        | 阀门旋转控件              |
| `trend_chart`          | `widgets.trend_chart`  | 折线/趋势图               |
| `switch`               | `widgets.switch`       | 开关                      |
| `checkbox`             | `widgets.checkbox`     | 复选框                    |
| `dropdown`             | `widgets.dropdown`     | 下拉列表                  |
| `slider`               | `widgets.slider`       | 滑块                      |
| `image`                | `widgets.image`        | 图像                      |
| `PopupButton`          | `widgets.PopupButton`  | 弹出按钮                  |
| `status_bar`           | `widgets.status_bar`   | 状态栏（嵌入页面中）       |

### 事件处理 / Event Handlers

每个控件的事件处理器通过 `on_<event>_handler` 属性指定 Lua 代码。  
支持两种格式：

```jsonc
// 完整函数定义（推荐）
"on_clicked_handler": "function(self)\n    print('clicked')\nend"

// 仅函数体（编译器自动补全 function(self) … end 包装）
"on_clicked_handler": "print('clicked')"
```

各控件事件名称：

| 控件类型             | 事件名称                              |
|----------------------|---------------------------------------|
| `custom_button` / `button` | `clicked`, `single_clicked`, `double_clicked` |
| `valve`              | `angle_changed`, `toggled`            |
| `trend_chart`        | `updated`                             |
| `status_bar`         | `updated`, `time_tick`                |
| `switch` / `checkbox` / `dropdown` / `slider` | `changed` |

### 数据绑定 / Data Binding

控件通过 `bind_point` 和 `websocket_url` 属性绑定到网关数据点：

```jsonc
{
  "type": "custom_button",
  "props": {
    "bind_point":    "Device1.tag0001",
    "websocket_url": "ws://192.168.0.100:8085/ws/",
    "event_action":  "写入绑定数据点",
    "custom_value":  "1"
  }
}
```

`event_action` 可选值：
- `写入绑定数据点` — 点击时向数据点写入 `custom_value`
- `读取绑定数据点` — 启动时读取数据点当前值
- `读写数据点`     — 同时注册读写

---

## 命令行参数 / CLI Arguments

```
usage: json_to_lua.py [-h] input [output]

positional arguments:
  input   输入 JSON 文件路径 / Input JSON file path
  output  输出 Lua 文件路径（可选）/ Output Lua file path (optional)
```

---

## 与 VduEditor 的关系 / Relationship to VduEditor

`json_to_lua.py` 与 `VduEditor/lua/editor/ProjectCompiler.lua` 的输出格式完全兼容：  
- 均生成带有 `PageManager`、控件模块引用和动作模块引用的 Lua 脚本  
- `json_to_lua.py` 可在无 Windows 图形环境的情况下（CI / Linux / macOS）独立运行  
- 用 VduEditor GUI 设计好界面、保存 JSON 后，可用本工具在命令行批量编译

`json_to_lua.py` produces output fully compatible with `VduEditor/lua/editor/ProjectCompiler.lua`:
- Both generate Lua scripts with the same `PageManager`, widget-module requires, and action-module requires
- `json_to_lua.py` runs standalone without a graphical environment (CI / Linux / macOS)
- Design in VduEditor GUI → save JSON → compile with this tool in a build pipeline
