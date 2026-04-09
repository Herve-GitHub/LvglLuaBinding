local DataManager = require("editor.DataManager")
local ChartAction = {}

function ChartAction.create_callback(action_type, params)
    return function()
        print("[ChartAction] 执行回调: " .. action_type)
        
        if action_type == "读取绑定数据点" then
            if params.chart and params.bind_point then
                DataManager.register_chart(params.bind_point, params.chart)
                DataManager.read(params.bind_point)
            end
        end
    end
end

function ChartAction.unregister_chart(bind_point)
    if bind_point then
        DataManager.unregister_chart(bind_point)
        print("[ChartAction] 已解除图表绑定: " .. bind_point)
    end
end

return ChartAction