-- clipboard.lua
-- 剪贴板辅助模块
local lv = require("lvgl")

local Clipboard = {}

-- 从系统剪贴板获取文本
function Clipboard.get_text()
    if lv.clipboard_get_text then
        return lv.clipboard_get_text()
    end
    return nil
end

-- 设置文本到系统剪贴板
function Clipboard.set_text(text)
    if lv.clipboard_set_text then
        return lv.clipboard_set_text(text)
    end
    return false
end

-- 粘贴到指定的 textarea
function Clipboard.paste_to(textarea)
    if textarea and textarea.paste then
        return textarea:paste()
    elseif textarea and textarea.add_text then
        local text = Clipboard.get_text()
        if text then
            textarea:add_text(text)
            return true
        end
    end
    return false
end

-- 从 textarea 复制文本
function Clipboard.copy_from(textarea)
    if textarea and textarea.copy then
        return textarea:copy()
    elseif textarea and lv.textarea_get_text then
        local text = lv.textarea_get_text(textarea)
        if text then
            return Clipboard.set_text(text)
        end
    end
    return false
end

return Clipboard
