M={}
--完美打印table
function M.print_r ( t )  
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end
--tabletoJson
function M.tableToJson(t, visited)
    visited = visited or {}
    if visited[t] then
        return '"[循环引用]"'
    end
    visited[t] = true
    
    local result = "{"
    local first = true
    
    for k, v in pairs(t) do
        if not first then
            result = result .. ","
        end
        first = false
        
        -- 处理键
        if type(k) == "string" then
            result = result .. '"' .. escapeJsonString(k) .. '":'
        elseif type(k) == "number" then
            result = result .. '"' .. k .. '":'
        else
            result = result .. '"' .. tostring(k) .. '":'
        end
        
        -- 处理值
        if type(v) == "table" then
            result = result .. M.tableToJson(v, visited)
        elseif type(v) == "string" then
            result = result .. '"' .. escapeJsonString(v) .. '"'
        elseif type(v) == "boolean" then
            result = result .. tostring(v)
        elseif type(v) == "number" then
            result = result .. tostring(v)
        elseif v == nil then
            result = result .. "null"
        else
            result = result .. '"' .. tostring(v) .. '"'
        end
    end
    
    result = result .. "}"
    return result
end
return M