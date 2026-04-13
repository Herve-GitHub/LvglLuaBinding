local lv = require("lvgl")

-- 调用 Windows 系统原生【文件夹选择框】
local function win32_open_folder_dialog(title, initial_dir)
    local f = io.popen([[powershell -Command "Add-Type -AssemblyName System.Windows.Forms; $dlg = New-Object System.Windows.Forms.FolderBrowserDialog; $dlg.Description = ']] .. title .. [['; $dlg.SelectedPath = ']] .. initial_dir .. [['; if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $dlg.SelectedPath }" 2>nul]])
    
    local path = f:read("*l")
    f:close()
    return path
end

local PathDialog = {}
PathDialog.__index = PathDialog

function PathDialog.new(parent, props)
    props = props or {}
    local callback = props.callback or function() end
    local initial_dir = props.initial_dir or [[C:\]]
    
    -- 打开系统文件夹选择器
    local full_path = win32_open_folder_dialog(
        "选择下装路径",
        initial_dir
    )
    
    -- 路径格式：C:\Users\86188\Desktop\...
    if full_path and full_path ~= "" then
        callback(full_path)
    end
    
    return setmetatable({}, PathDialog)
end

function PathDialog:close()
end

return PathDialog