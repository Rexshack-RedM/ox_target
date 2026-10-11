AddEventHandler('ox_target:debug', function(data)
    if data.entity and GetEntityType(data.entity) > 0 then
        data.model = GetEntityModel(data.entity)
    end

    print(json.encode(data, { indent = true }))
end)

if GetConvarInt('ox_target:debug', 0) ~= 1 then return end

local api = require 'client.api'

-- Debug zones are created where you stand when you run /ox_target_debugzones
RegisterCommand('ox_target_debugzones', function()
    local coords = GetEntityCoords(cache.ped)

    api.removeZone('ox_target_debug_box', true)
    api.removeZone('ox_target_debug_sphere', true)

    api.addBoxZone({
        name = 'ox_target_debug_box',
        coords = coords + vec3(2.0, 0.0, 0.0),
        size = vec3(1.5, 1.5, 1.5),
        debug = true,
        options = { { name = 'debug_box', event = 'ox_target:debug', icon = 'fa-solid fa-cube', label = locale('debug_box') } }
    })

    api.addSphereZone({
        name = 'ox_target_debug_sphere',
        coords = coords + vec3(-2.0, 0.0, 0.0),
        radius = 1.0,
        debug = true,
        options = { { name = 'debug_sphere', event = 'ox_target:debug', icon = 'fa-solid fa-circle', label = locale('debug_sphere') } }
    })
end, false)

api.addGlobalPed({ { name = 'debug_ped', event = 'ox_target:debug', icon = 'fa-solid fa-person', label = locale('debug_ped') } })
api.addGlobalVehicle({ { name = 'debug_vehicle', event = 'ox_target:debug', icon = 'fa-solid fa-horse-head', label = locale('debug_vehicle') } })
api.addGlobalObject({ { name = 'debug_object', event = 'ox_target:debug', icon = 'fa-solid fa-box', label = locale('debug_object') } })
api.addGlobalOption({ { name = 'debug_global', icon = 'fa-solid fa-globe', label = locale('debug_global'), openMenu = 'debug_global' } })
api.addGlobalOption({ { name = 'debug_global2', event = 'ox_target:debug', icon = 'fa-solid fa-globe', label = locale('debug_global') .. ' 2', menuName = 'debug_global' } })
