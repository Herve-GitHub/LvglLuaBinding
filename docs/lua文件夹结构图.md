# Lua 文件夹结构图

本文档描述项目中所有 `lua` 目录的文件结构与各文件的用途，便于学习和二次开发。

---

## 一、VduEditor/lua —— 组态编辑器 Lua 层

VduEditor 是可视化组态编辑器，其 Lua 层承担全部 UI 渲染与业务逻辑。

```
VduEditor/lua/
│
├── general.lua                     # 通用工具库（print_r 深打印、路径辅助等）
├── print_widget_meta.lua           # 调试脚本：解析并打印控件的 __widget_meta 信息
│
├── demo_button.lua                 # 示例：创建自定义按钮控件
├── demo_trend_chart.lua            # 示例：创建趋势折线图控件
├── demo_valve.lua                  # 示例：创建阀门图示控件
├── demo_valve_control.lua          # 示例：阀门控件交互控制
│
├── editor/                         # 编辑器核心模块
│   ├── main_editor.lua             # 【入口】整合菜单栏、画布、左侧面板与右侧属性面板
│   │
│   ├── MenuBar.lua                 # Ribbon 风格菜单栏（文件/编辑/视图/运行等菜单）
│   ├── LeftPanel.lua               # 左侧面板（工具箱 Tab + 图页列表 Tab）
│   ├── CanvasArea.lua              # 设计画布（支持拖拽移动、框选多选控件）
│   ├── CanvasList.lua              # 多图页管理窗口（新建/切换/删除图页）
│   │
│   ├── PropertyArea.lua            # 右侧属性面板（汇总以下子编辑模块）
│   ├── PropertyPageEditor.lua      # 图页属性编辑（背景色、尺寸等页级属性）
│   ├── PropertyWidgetEditor.lua    # 控件属性编辑（位置、大小、文本等控件属性）
│   ├── PropertyGlobalEditor.lua    # 全局组件属性编辑（状态栏等非画布组件）
│   ├── PropertyDataEditor.lua      # 数据绑定操作面板（数据点读写、下拉选择）
│   ├── PropertyEvent.lua           # 事件数据结构定义（事件表格式约定）
│   ├── PropertyEventEditor.lua     # 事件绑定编辑（事件下拉 + 多行代码编辑 + 保存）
│   ├── PropertyInputs.lua          # 属性面板通用输入控件（文本框、色值框等）
│   │
│   ├── ProjectManager.lua          # 工程管理器（保存/加载 JSON 工程文件）
│   ├── ProjectCompiler.lua         # 工程编译器（JSON 工程 → 可运行 Lua 脚本）
│   ├── DataBindingManager.lua      # 数据绑定管理器（数据点与控件属性的关联维护）
│   │
│   ├── ColorDialog.lua             # 颜色选择对话框（十六进制 / RGB 输入）
│   ├── FileDialog.lua              # 文件浏览对话框（打开/保存文件路径选择）
│   ├── clipboard.lua               # 剪贴板辅助模块（读写系统剪贴板文本）
│   ├── icons.lua                   # Font Awesome 图标 Unicode 常量定义
│   ├── json.lua                    # 轻量 JSON 编解码库
│   └── savelua.lua                 # Lua 脚本序列化工具（将数据表写成 Lua 源码）
│
├── widgets/                        # 可复用 UI 控件库
│   ├── button.lua                  # 自定义按钮控件（含 __widget_meta 元数据）
│   ├── checkbox.lua                # 复选框控件
│   ├── dropdown.lua                # 下拉列表控件
│   ├── label.lua                   # 标签/文本控件
│   ├── slider.lua                  # 滑动条控件
│   ├── status_bar.lua              # 状态栏控件（底部固定信息栏）
│   ├── trend_chart.lua             # 趋势折线图控件（支持自动刷新与多数据系列）
│   └── valve.lua                   # 阀门图示控件（开/关状态动画）
│
├── actions/                        # 动作函数模块（编译后运行时使用）
│   └── page_navigation.lua         # 图页跳转动作（供按钮等控件绑定）
│
└── test_lua/                       # 测试脚本
    └── websocket.lua               # WebSocket 连接测试脚本
```

### 关键数据流（编辑器工作流程）

```
main_editor.lua
  ├── 创建 MenuBar      → 文件操作 (ProjectManager) / 编译 (ProjectCompiler)
  ├── 创建 LeftPanel    → 工具箱（widgets/ 列表）+ CanvasList（图页切换）
  ├── 创建 CanvasArea   → 拖拽控件、框选、触发属性面板刷新
  └── 创建 PropertyArea
        ├── PropertyPageEditor    ← 选中"图页"时激活
        ├── PropertyWidgetEditor  ← 选中"控件"时激活
        ├── PropertyGlobalEditor  ← 选中"全局组件"时激活
        ├── PropertyDataEditor    ← 数据绑定 Tab
        └── PropertyEventEditor   ← 事件绑定 Tab
```

---

## 二、VduSimulator/lua —— 模拟运行器 Lua 层

VduSimulator 是编译结果的运行环境，负责加载并运行由编辑器导出的工程脚本。
其 `lua/` 结构与 VduEditor 大体相同，但新增了运行时相关文件，并去除了纯编辑器功能。

```
VduSimulator/lua/
│
├── general.lua                     # 通用工具库（与 VduEditor 共用同一份逻辑）
├── print_widget_meta.lua           # 调试脚本：打印控件元数据
│
├── project.lua                     # 【示例工程】由编辑器编译生成的可运行 Lua 脚本
├── project20260116.lua             # 历史版本示例工程（2026-01-16 生成）
│
├── demo_button.lua                 # 示例：按钮控件演示
├── demo_trend_chart.lua            # 示例：趋势图控件演示
├── demo_valve.lua                  # 示例：阀门控件演示
├── demo_valve_control.lua          # 示例：阀门控制交互演示
│
├── editor/                         # 编辑器模块（与 VduEditor 同步）
│   ├── main_editor.lua             # 主编辑器入口
│   ├── MenuBar.lua                 # 菜单栏
│   ├── LeftPanel.lua               # 左侧面板
│   ├── CanvasArea.lua              # 设计画布
│   ├── CanvasList.lua              # 图页管理
│   ├── PropertyArea.lua            # 属性面板
│   ├── PropertyPageEditor.lua      # 图页属性编辑
│   ├── PropertyWidgetEditor.lua    # 控件属性编辑
│   ├── PropertyGlobalEditor.lua    # 全局组件属性编辑
│   ├── PropertyEventEditor.lua     # 事件绑定编辑
│   ├── PropertyInputs.lua          # 属性输入控件
│   ├── ProjectManager.lua          # 工程管理器
│   ├── ProjectCompiler.lua         # 工程编译器
│   ├── tools_box.lua               # 浮动工具箱（悬浮在画布上，支持拖拽与折叠）
│   ├── ColorDialog.lua             # 颜色选择对话框
│   ├── FileDialog.lua              # 文件对话框
│   ├── clipboard.lua               # 剪贴板辅助
│   ├── icons.lua                   # 图标常量
│   └── json.lua                    # JSON 编解码库
│
├── widgets/                        # 可复用 UI 控件库
│   ├── button.lua                  # 按钮控件
│   ├── checkbox.lua                # 复选框控件
│   ├── label.lua                   # 标签控件
│   ├── status_bar.lua              # 状态栏控件
│   ├── trend_chart.lua             # 趋势图控件
│   └── valve.lua                   # 阀门图示控件
│
└── actions/                        # 动作模块
    └── page_navigation.lua         # 图页跳转动作
```

> **VduEditor vs VduSimulator 的 lua/ 差异**
> | 文件 | VduEditor | VduSimulator | 说明 |
> |------|-----------|--------------|------|
> | `editor/tools_box.lua` | ✗ | ✓ | 模拟器独有浮动工具箱 |
> | `editor/DataBindingManager.lua` | ✓ | ✗ | 编辑器独有数据绑定管理器 |
> | `editor/PropertyEvent.lua` | ✓ | ✗ | 编辑器独有事件数据结构 |
> | `editor/savelua.lua` | ✓ | ✗ | 编辑器独有 Lua 序列化工具 |
> | `widgets/dropdown.lua` | ✓ | ✗ | 编辑器独有下拉控件 |
> | `widgets/slider.lua` | ✓ | ✗ | 编辑器独有滑动条控件 |
> | `project.lua` / `project*.lua` | ✗ | ✓ | 模拟器独有：编译输出的工程脚本 |

---

## 三、LvglLuaBinding/lua —— Lua 5.5 解释器源码

这是 Lua 5.5 官方源码，作为 C 静态库编译进 LvglLuaBinding.dll，**无需修改**。

```
LvglLuaBinding/lua/
│
├── lua.h / luaconf.h / lualib.h    # 公开 C API 头文件（嵌入 Lua 的主要接口）
├── lauxlib.h / lauxlib.c           # 辅助库（luaL_* 系列接口）
├── lprefix.h / llimits.h           # 平台与限制定义
│
├── ── 虚拟机核心 ──
├── lvm.c / lvm.h                   # Lua 虚拟机（字节码执行）
├── lopcodes.c / lopcodes.h         # 操作码定义
├── lopnames.h                      # 操作码名称（调试用）
├── ljumptab.h                      # 跳转表优化（computed goto）
│
├── ── 编译前端 ──
├── llex.c / llex.h                 # 词法分析器
├── lparser.c / lparser.h           # 语法分析器（生成 AST）
├── lcode.c / lcode.h               # 代码生成器（AST → 字节码）
│
├── ── 运行时状态 ──
├── lstate.c / lstate.h             # Lua 状态机（lua_State 结构）
├── lobject.c / lobject.h           # 基础值类型（TValue、Table、String 等）
├── lstring.c / lstring.h           # 字符串驻留（interned strings）
├── ltable.c / ltable.h             # Table 数据结构（哈希 + 数组）
├── lfunc.c / lfunc.h               # 函数/闭包/上值
├── ltm.c / ltm.h                   # 元方法（metamethods）
├── lgc.c / lgc.h                   # 增量式垃圾回收器
├── lmem.c / lmem.h                 # 内存管理
│
├── ── 序列化 ──
├── ldump.c                         # 将函数原型序列化为二进制 chunk
├── lundump.c / lundump.h           # 反序列化（加载预编译 .luac）
├── lzio.c / lzio.h                 # 通用缓冲 I/O（供 llex 等使用）
│
├── ── 调试 ──
├── ldebug.c / ldebug.h             # 调试接口（行号、变量名查询等）
├── ldo.c / ldo.h                   # 受保护调用与错误处理（pcall/xpcall）
├── lctype.c / lctype.h             # 字符分类（兼容非标准 C locale）
│
├── ── 标准库 ──
├── linit.c                         # 标准库注册入口（luaL_openlibs）
├── lbaselib.c                      # 基础库（print, tostring, error 等）
├── lcorolib.c                      # 协程库（coroutine.*）
├── ldblib.c                        # 调试库（debug.*）
├── liolib.c                        # I/O 库（io.*）
├── lmathlib.c                      # 数学库（math.*）
├── loadlib.c                       # 包加载库（require, package.*）
├── loslib.c                        # 操作系统库（os.*）
├── lstrlib.c                       # 字符串库（string.*）
├── ltablib.c                       # 表库（table.*）
├── lutf8lib.c                      # UTF-8 库（utf8.*）
│
├── ltests.c / ltests.h             # 内部测试辅助（仅 Debug 构建使用）
└── lua.c                           # 独立 Lua 解释器入口（命令行 lua.exe）
```

---

## 四、控件开发快速上手

参考现有控件 `widgets/button.lua`，新增控件只需三步：

1. **在 `widgets/` 下新建 `my_widget.lua`**，导出 `__widget_meta` 和 `new(parent, props)` 函数。
2. **在 `editor/ProjectCompiler.lua` 的 `WIDGET_TYPE_TO_MODULE` 表中注册**新控件的类型 ID 与模块路径。
3. **运行 `print_widget_meta.lua`** 验证元数据格式是否正确。

> 详细规范请参阅 [`VduSimulator/docs/Lua控件设计规范.md`](../VduSimulator/docs/Lua控件设计规范.md)
