将lua 5.5 和lvgl 9.4.0 代码编译到项目lvglluabinding项目中，作为动态链接库使用
在windows下，如果需要导出lvgl的其他函数，请编辑LvglLuaBinding.def
编译环境VS2026

---

## JSON 组态工作流 / JSON-based HMI Configuration Workflow

为了降低组态颗粒度、提升用户友好性，项目提供了一套**基于 JSON 的组态流程**，
无需手动编写 Lua 即可完成 HMI 界面配置，配置结果自动编译为可在 LVGL 平台运行的 Lua 脚本。

To lower configuration granularity and improve user-friendliness, the project provides a
**JSON-based configuration workflow**. HMI screens can be configured without writing Lua by hand;
the configuration is compiled automatically into a Lua script that runs on any LVGL platform.

### 流程概述 / Workflow Overview

```
┌──────────────────────────────────────┐
│  1. 编写 / 编辑 JSON 工程文件         │
│     Write / edit a JSON project file │
│     (任意文本编辑器或 VduEditor GUI)  │
└───────────────┬──────────────────────┘
                │ project.json
                ▼
┌──────────────────────────────────────┐
│  2. 运行独立编译器                    │
│     Run the standalone compiler      │
│  python tools/json_to_lua.py         │
│          project.json                │
└───────────────┬──────────────────────┘
                │ project.lua
                ▼
┌──────────────────────────────────────┐
│  3. 部署运行                          │
│     Deploy & run                     │
│  VduSimulator 测试 / 嵌入式设备部署  │
└──────────────────────────────────────┘
```

### 相关文件 / Key Files

| 路径 | 说明 |
|------|------|
| `tools/json_to_lua.py` | 独立 Python 编译器（仅需 Python 3.7+，无额外依赖） |
| `tools/README.md` | 编译器使用文档与 JSON 格式说明 |
| `tools/schema/project_schema.json` | JSON Schema（可在 VS Code 等编辑器中启用智能提示） |
| `tools/examples/demo_hmi.json` | 示例 HMI 工程（3 个图页：主页、趋势图、阀门控制） |
| `VduEditor/projects/*.json` | VduEditor 保存的工程文件（可直接用编译器编译） |

### 快速体验 / Quick Demo

```bash
# 编译示例工程
python tools/json_to_lua.py tools/examples/demo_hmi.json

# 将生成的 demo_hmi.lua 复制到模拟器
copy tools\examples\demo_hmi.lua VduSimulator\projects\

# 在 VduSimulator 中运行（修改 VduSimulator/src/main.cpp 的脚本路径后重新编译）
```





-----------------------------------------------------------------------------------------------------------------------------------

项目路径改成了C:（由于电脑没有D盘）

增加了网络库

实现了与网关的数据通信：lvgl\_lua\_mongoose.c

实现了webscoket连接后与数据点的读写功能，通过http获取网关的事实数据

可以通过VduEditor/websocket下的两个lua进行测试（通过修改VduEditor.cpp里面的默认脚本路径测试）

在PropertyArea.lua里面与属性并列添加了数据（PropertyDataEditor）操作页面

