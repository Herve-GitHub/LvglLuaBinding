**Lua 控件规范**

目的：为基于 Lua 的控件（位于 `lua/widgets/`）定义一套统一的元数据与实例 API 规范，方便上位机编辑器识别、展示与编辑控件实例的属性。

一、模块导出要求
- 每个控件文件（例如 `lua/widgets/my_widget.lua`）应返回一个表示类/构造器的表（table）。
- 模块应导出以下两个可选/推荐的顶层项：
  - `__widget_meta`（必需）：描述控件类型、属性以及编辑器所需信息的元数据表。
  - `new(parent, props)`（必需）：构造函数，创建并返回控件实例对象。

二、`__widget_meta` 结构（示例）
```
__widget_meta = {
  id = "button",                -- 唯一类型标识（编辑器内部使用）
  name = "Button",              -- 可读名称（显示在列表/面板）
  description = "Simple button",
  icon = "button.png",          -- 可选：编辑器显示的小图标文件名
  schema_version = "1.0",
  version = "1.0",
  properties = {
    { name = "label", type = "string", default = "Button", label = "文本" },
    { name = "x", type = "number", default = 0, min = 0, max = 1024, label = "X" },
    { name = "y", type = "number", default = 0, min = 0, max = 1024, label = "Y" },
    { name = "width", type = "number", default = 100, min = 1, max = 2048, label = "宽度" },
    { name = "height", type = "number", default = 40, min = 1, max = 2048, label = "高度" },
    { name = "bg_color", type = "color", default = "#FFFFFF", label = "背景色" },
    { name = "enabled", type = "boolean", default = true, label = "启用" },
    { name = "mode", type = "enum", default = "normal", options = {"normal","toggle"}, label = "模式" },
  }
}
```

字段说明：
- `id`：字符串，控件类型唯一标识（用于序列化和编辑器内部判断）。
- `name`：用于展示的可读名称。
- `description`：简短说明。
- `icon`：相对图标路径或文件名（由编辑器映射/查找）。
- `schema_version`: Lua控件___widget_meta接口版本
- `version`:控件版本
- `properties`：数组，每个元素为属性说明表：
  - `name`（必需）：属性键名，实例读写时使用。
  - `type`（必需）：属性类型，常用值：`string`、`number`、`boolean`、`enum`、`color`、`position`、`size`、`reference`。
  - `default`（可选）：默认值。
  - `label`（可选）：在编辑器显示的字段标签（支持国际化）。
  - `min`/`max`（仅对 number 有效）：数值范围。
  - `options`（仅对 enum 有效）：枚举可选值数组。
  - `read_only`（布尔，可选）：是否只读。

三、实例对象 API 约定
构造函数 `new(parent, props)` 必须返回一个实例表（object），编辑器可以通过该实例进行运行时属性读写。实例应实现下列方法之一或多项：
- `get_property(name)` -> value
- `set_property(name, value)` -> boolean (是否成功)
- `get_properties()` -> table（当前属性表，键值对）
- `apply_properties(props_table)` -> boolean（批量应用）
- `to_state()` -> table（序列化当前运行时状态，供编辑器保存）

约定说明：
- 编辑器通过 `__widget_meta.properties` 知道应该展示哪些字段以及字段类型。运行时会调用 `get_property`/`set_property` 来同步显示与修改。
- 控件也可以只提供 `get_properties` / `apply_properties` 的实现，编辑器将以此为主进行批量读取/写入。

四、序列化与反序列化
- 模块应支持把实例状态序列化为一个简单的 Lua 表（`to_state`），并能够通过 `new(parent, state)` 或单独的 `from_state(parent, state)` 恢复。

五、事件与回调（可选）
- 若控件希望将事件暴露给编辑器（例如 “clicked”），可以在 `__widget_meta` 中声明 `events = {"clicked","value_changed"}`，并在实例上提供 `on(event_name, callback)` 注册函数，编辑器可订阅以便做交互预览。

六、示例：Button 元数据
```
__widget_meta = {
  id = "button",
  name = "Button",
  schema_version = "1.0",
  description = "Clickable button",
  properties = {
    {name="label", type="string", default="Button", label="文本"},
    {name="x", type="number", default=0},
    {name="y", type="number", default=0},
    {name="width", type="number", default=120},
    {name="height", type="number", default=40},
    {name="bg_color", type="color", default="#007acc"},
    {name="enabled", type="boolean", default=true},
  },
  events = {"clicked"}
}
```

示例代码见 `lua/widgets/widget_template.lua` 与 `lua/widgets/button_example.lua`。
