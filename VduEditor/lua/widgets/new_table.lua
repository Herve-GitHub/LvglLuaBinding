local lv = require("lvgl")
local DataTable = {}

DataTable.__widget_meta = {
  id = "data_table",
  name = "Data Table",
  description = "分页表格组件，支持设置数据和样式",
  schema_version = "1.0",
  version = "1.0",
  properties = {
    -- 实例名称
    { name = "instance_name", type = "string", default = "", label = "实例名称" },
    
    -- 位置和尺寸
    { name = "x", type = "number", default = 0, label = "X坐标" },
    { name = "y", type = "number", default = 0, label = "Y坐标" },
    { name = "width", type = "number", default = 400, label = "宽度" },
    { name = "height", type = "number", default = 380, label = "高度" },
    
    -- 表格配置
    { name = "col_count", type = "number", default = 4, label = "列数", min = 1, max = 10 },
    { name = "rows_per_page", type = "number", default = 6, label = "每页行数", min = 1, max = 20 },
    
    -- 列宽设置（最多10列）
    { name = "col1_width", type = "number", default = 100, label = "列1宽度" },
    { name = "col2_width", type = "number", default = 100, label = "列2宽度" },
    { name = "col3_width", type = "number", default = 100, label = "列3宽度" },
    { name = "col4_width", type = "number", default = 100, label = "列4宽度" },
    { name = "col5_width", type = "number", default = 100, label = "列5宽度" },
    { name = "col6_width", type = "number", default = 100, label = "列6宽度" },
    
    -- 表头文字（最多10列）
    { name = "header1", type = "string", default = "列1", label = "表头1" },
    { name = "header2", type = "string", default = "列2", label = "表头2" },
    { name = "header3", type = "string", default = "列3", label = "表头3" },
    { name = "header4", type = "string", default = "列4", label = "表头4" },
    { name = "header5", type = "string", default = "列5", label = "表头5" },
    { name = "header6", type = "string", default = "列6", label = "表头6" },

    -- 数据源
    { name = "data_source", type = "string", default = "", label = "数据源",
      description = "支持两种格式：1) A1,B1,C1;A2,B2,C2 2) A1,B1,C1,A2,B2,C2 (自动按列数分组)" },
    
    -- 样式
    { name = "border_color", type = "color", default = "#dddddd", label = "边框颜色" },
  },
}

-- 辅助函数：解析颜色
local function parse_color(c)
  if type(c) == "string" and c:match("^#%x%x%x%x%x%x$") then
    return tonumber(c:sub(2), 16)
  elseif type(c) == "number" then
    return c
  end
  return 0x000000
end

-- 辅助函数：解析数据源字符串（支持两种格式）
local function parse_data_source(str, col_count)
  if not str or str == "" then
    return {}
  end
  
  local data = {}
  
  -- 检查是否包含分号（明确的行分隔符）
  if string.find(str, ";") then
    -- 格式1: 使用分号分隔行
    for row_str in string.gmatch(str, "[^;]+") do
      local row = {}
      local col_idx = 1
      for col_str in string.gmatch(row_str, "[^,]+") do
        if col_idx <= col_count then
          table.insert(row, col_str)
        end
        col_idx = col_idx + 1
      end
      -- 补齐不足的列
      while #row < col_count do
        table.insert(row, "")
      end
      if #row > 0 then
        table.insert(data, row)
      end
    end
  else
    -- 格式2: 没有分号，按逗号分割所有数据，然后按列数分组
    local all_values = {}
    for value in string.gmatch(str, "[^,]+") do
      table.insert(all_values, value)
    end
    
    -- 按列数分组
    for i = 1, #all_values, col_count do
      local row = {}
      for j = 0, col_count - 1 do
        local idx = i + j
        if idx <= #all_values then
          table.insert(row, all_values[idx])
        else
          table.insert(row, "")
        end
      end
      table.insert(data, row)
    end
  end
  
  return data
end

function DataTable.new(parent, state)
  state = state or {}
  local self = {}
  
  -- 初始化属性
  self.props = {}
  for _, p in ipairs(DataTable.__widget_meta.properties) do
    if state[p.name] ~= nil then
      self.props[p.name] = state[p.name]
    else
      self.props[p.name] = p.default
    end
  end
  
  local col_count = self.props.col_count
  local rows_per_page = self.props.rows_per_page
  
  -- 解析数据
  local all_data = parse_data_source(self.props.data_source, col_count)
  local current_page = 1
  local total_pages = math.ceil(#all_data / rows_per_page)
  if total_pages < 1 then total_pages = 1 end
  
  -- 创建主容器
  self.container = lv.obj_create(parent)
  self.container:set_size(self.props.width, self.props.height)
  self.container:set_pos(self.props.x, self.props.y)
  self.container:set_style_border_width(1, 0)
  self.container:set_style_border_color(parse_color(self.props.border_color), 0)
  self.container:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
  
  
  -- 创建表格
  self.table = lv.table_create(self.container)
  self.table:set_size(self.props.width - 20, self.props.height - 90)--80
  self.table:align(lv.ALIGN_TOP_MID, 0, 10)
  self.table:set_col_cnt(col_count)
  self.table:set_row_cnt(rows_per_page + 1)
 
  
  -- 设置列宽
  for col = 1, col_count do
    local width_prop = "col" .. col .. "_width"
    local width = self.props[width_prop] or 100
    self.table:set_column_width(col - 1, width)
  end
  
  -- 设置表头
  for col = 1, col_count do
    local header_prop = "header" .. col
    local header_text = self.props[header_prop] or "列" .. col
    self.table:set_cell_value(0, col - 1, header_text)
  end
  
  -- 页码按钮容器
  self.page_cont = lv.obj_create(self.container)
  self.page_cont:set_size(self.props.width - 20, 40)
  self.page_cont:align(lv.ALIGN_BOTTOM_MID, 0, 10)
  self.page_cont:set_style_bg_opa(lv.OPA_TRANSP, 0)
  self.page_cont:set_flex_flow(lv.FLEX_FLOW_ROW)
  self.page_cont:set_flex_align(lv.FLEX_ALIGN_CENTER, lv.FLEX_ALIGN_CENTER, lv.FLEX_ALIGN_CENTER)
  self.page_cont:remove_flag(lv.OBJ_FLAG_SCROLLABLE)
  
  -- 更新表格内容
  local function update_table_content()
    local start_idx = (current_page - 1) * rows_per_page + 1
    local end_idx = math.min(start_idx + rows_per_page - 1, #all_data)
    
    -- 清空数据行
    for row = 1, rows_per_page do
      for col = 0, col_count - 1 do
        self.table:set_cell_value(row, col, "")
      end
    end
    
    -- 填充新数据
    local data_row = 1
    for i = start_idx, end_idx do
      if all_data[i] then
        for col = 1, col_count do
          local value = all_data[i][col] or ""
          self.table:set_cell_value(data_row, col - 1, tostring(value))
        end
        data_row = data_row + 1
      end
    end
    
    self.table:invalidate()
  end
  
  -- 更新页码显示
  local function update_page_buttons()
    if self.page_info then
      self.page_info:set_text(current_page .. " / " .. total_pages)
    end
  end
  
  -- 跳转页面
  local function go_to_page(page)
    if page < 1 then page = 1 end
    if page > total_pages then page = total_pages end
    current_page = page
    update_table_content()
    update_page_buttons()
  end
  
  -- 创建分页按钮
  local first_btn = lv.btn_create(self.page_cont)
  first_btn:set_size(50, 35)
  local first_label = lv.label_create(first_btn)
  first_label:set_text("首页")
  first_label:center()
  first_btn:add_event_cb(function() 
    if current_page > 1 then go_to_page(1) end
  end, lv.EVENT_CLICKED, nil)
  
  local prev_btn = lv.btn_create(self.page_cont)
  prev_btn:set_size(50, 35)
  local prev_label = lv.label_create(prev_btn)
  prev_label:set_text("〈")
  prev_label:center()
  prev_btn:add_event_cb(function() 
    if current_page > 1 then go_to_page(current_page - 1) end
  end, lv.EVENT_CLICKED, nil)
  
  self.page_info = lv.label_create(self.page_cont)
  self.page_info:set_style_pad_left(10, 0)
  self.page_info:set_style_pad_right(10, 0)
  
  local next_btn = lv.btn_create(self.page_cont)
  next_btn:set_size(50, 35)
  local next_label = lv.label_create(next_btn)
  next_label:set_text("〉")
  next_label:center()
  next_btn:add_event_cb(function() 
    if current_page < total_pages then go_to_page(current_page + 1) end
  end, lv.EVENT_CLICKED, nil)
  
  local last_btn = lv.btn_create(self.page_cont)
  last_btn:set_size(50, 35)
  local last_label = lv.label_create(last_btn)
  last_label:set_text("末页")
  last_label:center()
  last_btn:add_event_cb(function() 
    if current_page < total_pages then go_to_page(total_pages) end
  end, lv.EVENT_CLICKED, nil)
  
  -- 打印调试信息
  print("表格初始化完成:")
  print("  列数:", col_count)
  print("  每页行数:", rows_per_page)
  print("  数据行数:", #all_data)
  print("  总页数:", total_pages)
  
  -- 初始化显示
  update_table_content()
  update_page_buttons()
  
  -- ============ 公共方法 ============
  
  function self.get_property(self, name)
    return self.props[name]
  end
  
  function self.set_property(self, name, value)
    self.props[name] = value
    
    if name == "x" or name == "y" then
      self.container:set_pos(self.props.x, self.props.y)
      
    elseif name == "width" or name == "height" then
      self.container:set_size(self.props.width, self.props.height)
      self.table:set_size(self.props.width - 20, self.props.height - 80)
      self.page_cont:set_size(self.props.width - 20, 30)
      
    elseif name == "col_count" then
      -- 列数改变，重新创建表格
      col_count = value
      self.table:set_col_cnt(col_count)
      self.table:set_row_cnt(rows_per_page + 1)
      
      -- 重新设置列宽
      for col = 1, col_count do
        local width_prop = "col" .. col .. "_width"
        local width = self.props[width_prop] or 100
        self.table:set_column_width(col - 1, width)
      end
      
      -- 重新设置表头
      for col = 1, col_count do
        local header_prop = "header" .. col
        local header_text = self.props[header_prop] or "列" .. col
        self.table:set_cell_value(0, col - 1, header_text)
      end
      
      -- 重新解析数据
      all_data = parse_data_source(self.props.data_source, col_count)
      total_pages = math.ceil(#all_data / rows_per_page)
      if total_pages < 1 then total_pages = 1 end
      current_page = 1
      update_table_content()
      update_page_buttons()
      
    elseif name:match("^col%d+_width$") then
      -- 列宽改变
      local col_num = tonumber(name:match("(%d+)"))
      if col_num and col_num <= col_count then
        self.table:set_column_width(col_num - 1, value)
      end
      
    elseif name:match("^header%d+$") then
      -- 表头文字改变
      local col_num = tonumber(name:match("(%d+)"))
      if col_num and col_num <= col_count then
        self.table:set_cell_value(0, col_num - 1, value)
      end
      
    elseif name == "border_color" then
      self.container:set_style_border_color(parse_color(value), 0)
      
    elseif name == "data_source" then
      -- 重新解析数据并刷新
      all_data = parse_data_source(value, col_count)
      total_pages = math.ceil(#all_data / rows_per_page)
      if total_pages < 1 then total_pages = 1 end
      current_page = 1
      update_table_content()
      update_page_buttons()
      
    elseif name == "rows_per_page" then
      rows_per_page = value
      self.table:set_row_cnt(rows_per_page + 1)
      total_pages = math.ceil(#all_data / rows_per_page)
      if total_pages < 1 then total_pages = 1 end
      if current_page > total_pages then current_page = total_pages end
      update_table_content()
      update_page_buttons()
    end
    
    return true
  end
  
  function self.get_properties(self)
    local out = {}
    for k, v in pairs(self.props) do out[k] = v end
    return out
  end
  
  function self.apply_properties(self, props_table)
    for k, v in pairs(props_table) do
      self:set_property(k, v)
    end
    return true
  end
  
  function self.to_state(self)
    return self:get_properties()
  end
  
  return self
end

return DataTable