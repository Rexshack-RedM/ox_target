---@type table<number, EntityInterface>
local entityStates = {}

---Flags a networked entity as having target options so other clients clean up when it is gone.
---@param netId number
RegisterNetEvent('ox_target:setEntityHasOptions', function(netId)
    netId = tonumber(netId)
    if not netId or entityStates[netId] then return end

    local handle = NetworkGetEntityFromNetworkId(netId)
    if not handle or handle == 0 or not DoesEntityExist(handle) then return end

    local entity = Entity(handle)
    entity.state.hasTargetOptions = true
    entityStates[netId] = entity
end)

CreateThread(function()
    local removed, num = {}, 0

    while true do
        Wait(10000)

        for netId, entity in pairs(entityStates) do
            if not DoesEntityExist(entity.__data) or not entity.state.hasTargetOptions then
                entityStates[netId] = nil
                num += 1
                removed[num] = netId
            end
        end

        if num > 0 then
            TriggerClientEvent('ox_target:removeEntity', -1, removed)
            table.wipe(removed)
            num = 0
        end
    end
end)
