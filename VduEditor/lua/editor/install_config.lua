-- install_config.lua
-- 下装配置文件，修改这里的值即可

return {
    -- 远程服务器配置
    remote_host = "192.168.1.230",
    remote_user = "root",
    remote_path = "/root/",
    password = "LM&PASSw0rdl",
    
    -- 本地路径配置
    local_base_dir = "C:\\Users\\86188\\Desktop\\LvgLuaBling\\git\\LvglLuaBinding\\Output\\Binaries\\Release\\x64\\",
    sshpass_exe = "sshpass.exe",
    lua_file = "lua\\project.lua",
    
    -- 可选：是否在下载前编译
    compile_before_install = true,
    
    -- 可选：是否显示详细输出
    verbose = true
}