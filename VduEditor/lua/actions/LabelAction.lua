local DataManager = require("editor.DataManager")
local LabelAction = {}

-- 清空所有冗余的全局变量（connected_websockets/pending_reads等）
-- 所有状态由DataManager统一管理

-- 创建动作回调（仅保留核心逻辑，依赖DataManager）
function LabelAction.create_callback(action_type, params)
    return function()
        print("[LabelAction] 执行回调: " .. action_type)
        
        if action_type == "写入绑定数据点" then
            if params.bind_point then
                DataManager.write(params.bind_point, params.value or "1")
            end
            
        elseif action_type == "读取绑定数据点" then
            if params.label and params.bind_point then
                DataManager.register_label(params.bind_point, params.label)
                DataManager.read(params.bind_point)
            end
            
        elseif action_type == "读写数据点" then
            if params.label and params.bind_point then
                DataManager.register_label(params.bind_point, params.label)
                DataManager.read(params.bind_point)
            end
        end
    end
end

-- 解绑标签（调用DataManager的解绑方法）
function LabelAction.unbind_label(bind_point)
    if bind_point then
        DataManager.unregister_label(bind_point)
        print("[LabelAction] 已解除标签绑定: " .. bind_point)
    end
end

return LabelAction