local RSGCore = exports['rsg-core']:GetCoreObject()
local utils = require 'client.utils'
local playerItems = utils.getItems()
local playerGroups = {} ---@type table<string, number> group name -> grade level

---@param data table? RSGCore PlayerData
local function setPlayerData(data)
    if not data then return end

    table.wipe(playerGroups)

    for _, key in ipairs({ 'job', 'gang' }) do
        local group = data[key]

        if group and group.name then
            playerGroups[group.name] = tonumber(group.grade and group.grade.level) or 0
        end
    end

    if data.items then
        table.wipe(playerItems)

        for _, item in pairs(data.items) do
            if item and item.name then
                playerItems[item.name] = (playerItems[item.name] or 0) + (tonumber(item.amount or item.count) or 0)
            end
        end
    end
end

setPlayerData(RSGCore.Functions.GetPlayerData())

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    setPlayerData(RSGCore.Functions.GetPlayerData())
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', setPlayerData)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    table.wipe(playerGroups)
    table.wipe(playerItems)
end)

---Accepts 'job', { 'job', 'gang' } or { job = minGrade }; matches the player's job or gang.
---@diagnostic disable-next-line: duplicate-set-field
function utils.hasPlayerGotGroup(filter)
    local _type = type(filter)

    if _type == 'string' then
        return playerGroups[filter] ~= nil
    elseif _type == 'table' then
        if table.type(filter) == 'hash' then
            for name, grade in pairs(filter) do
                local level = playerGroups[name]
                if level and level >= (tonumber(grade) or 0) then return true end
            end
        else
            for i = 1, #filter do
                if playerGroups[filter[i]] then return true end
            end
        end
    end

    return false
end
