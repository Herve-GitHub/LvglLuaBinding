local lv = require("lvgl")
local Button = require("lua.widgets.button")

-- 获取当前活动屏幕
local scr = lv.scr_act()

-- 使用新的 Button.new(parent, props) 接口
local btn1 = Button.new(scr, { x = 100, y = 100, width = 200, height = 60, label = "点击我" ,design_mode = false})
local btn2 = Button.new(scr, { x = 100, y = 200, width = 200, height = 60, label = "重置" ,design_mode = false})

-- 注册点击事件（使用规范化的 on(event, cb)）
btn1:on("single_clicked", function(self)
    print("按钮1被点击了！")
    self:set_property("label", "已点击")
    self:set_property("bg_color", "#E91E63") -- 变为粉色
end)

btn1:on("double_clicked", function(self)
    print("按钮1被双击了！")
    self:set_property("label", "已双击")
    self:set_property("bg_color", "#4CAF50") -- 变为绿色
end)

btn2:on("clicked", function(self)
    print("重置按钮被点击！")
    btn1:set_property("label", "点击我")
    btn1:set_property("bg_color", "#2196F3") -- 变为蓝色
end)

print("Button 演示已加载（使用新 API）")
