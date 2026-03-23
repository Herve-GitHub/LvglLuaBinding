local DataManager = require("editor.DataManager")
local DataAction = {}

-- 清空所有冗余的全局变量（pending_reads/bound_buttons等）
-- 所有状态由DataManager统一管理

-- 创建动作回调（仅保留核心逻辑，依赖DataManager）
function DataAction.create_callback(action_type, params)
    return function()
        print("[DataAction] 执行回调: " .. action_type)
        
        if action_type == "写入绑定数据点" then
            if params.bind_point then
                DataManager.write(params.bind_point, params.value or "1")
            end
            
        elseif action_type == "读取绑定数据点" then
            if params.button and params.bind_point then
                DataManager.register_button(params.bind_point, params.button)
                DataManager.read(params.bind_point)
            end
            
        elseif action_type == "读写数据点" then
            if params.button and params.bind_point then
                DataManager.register_button(params.bind_point, params.button)
                DataManager.read(params.bind_point)
            end
        end
    end
end

-- 解绑按钮（调用DataManager的解绑方法）
function DataAction.unbind_button(bind_point)
    if bind_point then
        DataManager.unregister_button(bind_point)
        print("[DataAction] 已解除按钮绑定: " .. bind_point)
    end
end

return DataAction