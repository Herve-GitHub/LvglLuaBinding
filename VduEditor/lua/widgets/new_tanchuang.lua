--new_tangchuang 
--通过get_id找到对应的bind_point来写入自定义的值

local lv = require("lvgl")
local gen = require("general")


local new_tangchuang = {}

new_tangchuang._widget_meta = {
	 id = "custom_tangchuang",
	 name = "Custom tangchuang",
	 description= "自定义输入值弹窗",
	 schema_version = "1.0",
	 version = "1.0",
	 properties = {
	       {name = "instance_name", type = "string", default = "",label = "实例名称"，description= "用于编译时的变量名，留空则自动生成"},
		   {name = "label", type = "string = ", default = "OK",label = "文本" },
		   {name = "x", type = "number", default = "100", label = "X"},
		   {name = "y", type = "number", default = "100", label = "Y"},
		   {name = "width", type = "number", default= "80", label = "宽度"},
		   {name = "height", type = "number", default = "60", label = "高度"},
           { name = "color", type = "color", default = "#ffffff", label = "文本颜色" },
           { name = "font_size", type = "number", default = 16, label = "字体大小" },
           { name = "alignment", type = "string", default = "center", label = "对齐方式" },
           { name = "bg_color", type = "color", default = "#007acc", label = "背景色" },
           { name = "enabled", type = "boolean", default = true, label = "启用" },
           { name = "design_mode", type = "boolean", default = true, label = "设计模式" },

	 
	 
	 
	 
	 
	 
	 }


	 function apply_styles( self )
	 --容器背景颜色
	   local bg_color = parse_color(self.props.color or "#007acc")
	   if self.contain = self.contain.set_style_bg_color then 
	       if self.props.enabled then 
		       self.contain: set_style_bg_color(bg_color,0)
		   else
		      self.contain:set_style_bg_color(0x888888,0)
			end
		end


	--内置的标签文本背景 =
	self.label : set_style_bg_color(bg_color)

		
		
			
	-- body
end






	 function tangchuang.tangchuang(parent , state)
	     state = state or {}
		 local self = {}
		 self.props = {}
		 --初始化属性
		 for _, p in ipairs(Button.__widget_meta.properties) do 
		     if state[p.name] ~= nil then 
			    self.props[p.name] = state[p.name]
			 else
			    self.props[p.name] = p.default
			end
		end

		self.contain = lv.obj_create(parent)
		self.contain : set_size(self.props.width, self.props.height)
		self.contain : set_pos(self.props.x, self.props.y)

		self.label = lv.label_create(contain)
		self.label : set_text(self.props.label)
		self.label : top()

		self.textview =lv.textview_create(contain)
		self.textview : set_pos(self.props.width, self.props.height-20)

		self.btn = lv.button_create(contain)
	    self.btn : set_pos(self.props.width-30, self.props.height-30)
		self.btn : set_text("确认")
		self.btn : bottom()

		self.btn2 = lv.button_create(contain)
		self.btn2 : set_text("取消")
		self.btn : set_pos(self.props.width, self.props.height-30)


		apply_styles(self)

		self._callbacks = {}
		 -- body


		 --get_contain:获取容器对象
		 
		 function self.get_contain(self)
		   return self.contain
	-- body
         end
		 --获取属性的值
		 function self.get_property( self,name  )
		  return self.props[name]
	-- body
end

    ---设置属性的值

	function self.set_property( self,value,name  )
	-- body
end


       


end

  






}