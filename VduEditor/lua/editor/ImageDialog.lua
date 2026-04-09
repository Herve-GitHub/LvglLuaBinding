local lv = require("lvgl")

-- 调用 Windows 系统原生文件选择框
local function win32_open_file_dialog(filter, title, initial_dir)
    local f = io.popen([[powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter = ']] .. filter .. [['; $dlg.Title = ']] .. title .. [['; $dlg.InitialDirectory = ']] .. initial_dir .. [['; if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $dlg.FileName }" 2>nul]])
    
    local path = f:read("*l")
    f:close()
    return path
end

local ImageDialog = {}
ImageDialog.__index = ImageDialog

function ImageDialog.new(parent, props)
    props = props or {}
    local callback = props.callback or function() end
    local initial_dir = props.initial_dir or [[C:\]]
    
    -- 🔥 直接打开你电脑的文件选择器
    local full_path = win32_open_file_dialog(
        "Image Files|*.png;*.jpg;*.jpeg;*.bmp",
        "选择图片",
        initial_dir
    )
    
    if full_path and full_path ~= "" then
        local filename = full_path:match("[^\\/]+$")
        callback(full_path, filename)
    end
    
    return setmetatable({}, ImageDialog)
end

function ImageDialog:close()
end

return ImageDialog