local state = {}

local isActive = false
local nuiFocus = false
local isDisabled = false

---@return boolean
function state.isActive()
    return isActive
end

---@param value boolean
function state.setActive(value)
    isActive = value

    if value then
        SendNuiMessage('{"event": "visible", "state": true}')
    end
end

---@return boolean
function state.isNuiFocused()
    return nuiFocus
end

---@param value boolean
---@param cursor? boolean
function state.setNuiFocus(value, cursor)
    -- SetCursorLocation is GTA-only; guard it so RedM builds without it don't error
    if value and SetCursorLocation then SetCursorLocation(0.5, 0.5) end

    nuiFocus = value
    SetNuiFocus(value, cursor or false)
    SetNuiFocusKeepInput(value)
end

---@return boolean
function state.isDisabled()
    return isDisabled
end

---@param value boolean
function state.setDisabled(value)
    isDisabled = value
end

return state
