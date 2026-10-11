lib.locale()

local utils = require 'client.utils'
local state = require 'client.state'
local options = require 'client.api'.getTargetOptions()

require 'client.debug'
require 'client.compat.qtarget'

local SendNuiMessage = SendNuiMessage
local GetEntityCoords = GetEntityCoords
local GetEntityType = GetEntityType
local GetEntityModel = GetEntityModel
local HasEntityClearLosToEntity = HasEntityClearLosToEntity
local GetEntityBoneIndexByName = GetEntityBoneIndexByName
local GetWorldPositionOfEntityBone = GetWorldPositionOfEntityBone
local GetModelDimensions = GetModelDimensions
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local IsControlJustPressed = IsControlJustPressed
local IsControlJustReleased = IsControlJustReleased
local IsDisabledControlJustPressed = IsDisabledControlJustPressed
local IsDisabledControlJustReleased = IsDisabledControlJustReleased
local DisableControlAction = DisableControlAction
local DisablePlayerFiring = DisablePlayerFiring

-- RedM control hashes
local INPUT_ATTACK = 0x07CE1E61
local INPUT_AIM = 0xF84FA74F
local INPUT_MELEE_ATTACK = 0xB2F377E8
local INPUT_LOOK_LR = 0xA987235F
local INPUT_LOOK_UD = 0xD2047988

local toggleHotkey = GetConvarInt('ox_target:toggleHotkey', 0) == 1
local openKey = tonumber(GetConvar('ox_target:openKey', '0x8AAA0AD4')) or 0x8AAA0AD4 -- INPUT_PC_FREE_LOOK (Left Alt)
local selectButton = GetConvarInt('ox_target:leftClick', 1) == 1 and INPUT_ATTACK or INPUT_AIM
local debug = GetConvarInt('ox_target:debug', 0) == 1
local vec0 = vec3(0, 0, 0)
local FLAG_ALL, FLAG_ENTITIES = 511, 26

local currentTarget = {}
local currentMenu
local menuChanged
local menuHistory = {}
local nearbyZones

---@param option OxTargetOption
---@param distance number
---@param endCoords vector3
---@param entityHit? number
---@param entityModel? number | false
local function shouldHide(option, distance, endCoords, entityHit, entityModel)
    if option.menuName ~= currentMenu then return true end
    if distance > (option.distance or 7) then return true end
    if option.groups and not utils.hasPlayerGotGroup(option.groups) then return true end
    if option.items and not utils.hasPlayerGotItems(option.items, option.anyItem) then return true end

    local bone = entityModel and option.bones or nil

    if bone then
        ---@cast entityHit number
        if type(bone) == 'string' then
            local boneId = GetEntityBoneIndexByName(entityHit, bone)

            if boneId == -1 or #(endCoords - GetWorldPositionOfEntityBone(entityHit, boneId)) > 2 then
                return true
            end

            bone = boneId
        else
            local closestBone, boneDistance

            for j = 1, #bone do
                local boneId = GetEntityBoneIndexByName(entityHit, bone[j])

                if boneId ~= -1 then
                    local dist = #(endCoords - GetWorldPositionOfEntityBone(entityHit, boneId))

                    if dist <= (boneDistance or 1) then
                        closestBone, boneDistance = boneId, dist
                    end
                end
            end

            if not closestBone then return true end

            bone = closestBone
        end
    end

    local offset = entityModel and option.offset or nil

    if offset then
        ---@cast entityHit number
        ---@cast entityModel number
        if not option.absoluteOffset then
            local min, max = GetModelDimensions(entityModel)
            offset = (max - min) * offset + min
        end

        offset = GetOffsetFromEntityInWorldCoords(entityHit, offset.x, offset.y, offset.z)

        if #(endCoords - offset) > (option.offsetSize or 1) then
            return true
        end
    end

    if option.canInteract then
        local success, resp = pcall(option.canInteract, entityHit, distance, endCoords, option.name, bone)
        return not success or not resp
    end
end

---@param entity number
---@return number
local function safeEntityType(entity)
    local success, result = pcall(GetEntityType, entity)
    return success and result or 0
end

local function startTargeting()
    if state.isDisabled() or state.isActive() or IsNuiFocused() or IsPauseMenuActive() then return end

    state.setActive(true)

    local flag = FLAG_ALL
    local hit, entityHit, endCoords, distance, lastEntity, entityType, entityModel, hasTarget, zonesChanged
    local zones = {}

    -- per-frame thread: control handling and marker drawing only
    CreateThread(function()
        local lastCoords = vec0

        while state.isActive() do
            if debug then
                lastCoords = (endCoords and endCoords ~= vec0) and endCoords or lastCoords
                Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, lastCoords.x, lastCoords.y, lastCoords.z,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.1, 0.1, 255, 42, 24, 100, false, false, 2, false, nil, nil, false)
            end

            utils.drawZoneMarkers()
            DisablePlayerFiring(cache.playerId, true)
            DisableControlAction(0, INPUT_ATTACK, true)
            DisableControlAction(0, INPUT_AIM, true)
            DisableControlAction(0, INPUT_MELEE_ATTACK, true)

            if state.isNuiFocused() then
                DisableControlAction(0, INPUT_LOOK_LR, true)
                DisableControlAction(0, INPUT_LOOK_UD, true)

                if not hasTarget or IsDisabledControlJustPressed(0, INPUT_AIM) then
                    state.setNuiFocus(false, false)
                end
            elseif hasTarget and IsDisabledControlJustPressed(0, selectButton) then
                state.setNuiFocus(true, true)
            end

            Wait(0)
        end
    end)

    while state.isActive() do
        if not state.isNuiFocused() and lib.progressActive() then
            state.setActive(false)
            break
        end

        local playerCoords = GetEntityCoords(cache.ped)
        hit, entityHit, endCoords = utils.raycastFromCamera(flag, 20)
        distance = #(playerCoords - endCoords)

        if entityHit ~= 0 and entityHit ~= lastEntity then
            entityType = safeEntityType(entityHit)
        end

        -- nothing useful hit: try the other flag set and keep whichever is closer
        if entityType == 0 then
            local _flag = flag == FLAG_ALL and FLAG_ENTITIES or FLAG_ALL
            local _hit, _entityHit, _endCoords = utils.raycastFromCamera(_flag, 20)
            local _distance = #(playerCoords - _endCoords)

            if _distance < distance then
                flag, hit, entityHit, endCoords, distance = _flag, _hit, _entityHit, _endCoords, _distance

                if entityHit ~= 0 then
                    entityType = safeEntityType(entityHit)
                end
            end
        end

        nearbyZones, zonesChanged = utils.getNearbyZones(endCoords)

        local entityChanged = entityHit ~= lastEntity
        local newOptions = zonesChanged or entityChanged or menuChanged

        if entityHit > 0 and entityChanged then
            currentMenu = nil

            if flag ~= FLAG_ALL then
                entityHit = HasEntityClearLosToEntity(entityHit, cache.ped, 7) and entityHit or 0
            end

            if entityHit > 0 then
                local success, result = pcall(GetEntityModel, entityHit)
                entityModel = success and result
            end
        end

        -- hasTarget is false, true, or a number (option source count); guard the numeric compare
        if hasTarget and (zonesChanged or entityChanged and (hasTarget == true or hasTarget > 1)) then
            SendNuiMessage('{"event": "leftTarget"}')

            if entityChanged then options:wipe() end

            hasTarget = false
        end

        if newOptions and entityModel and entityHit > 0 then
            options:set(entityHit, entityType, entityModel)
        end

        lastEntity = entityHit
        currentTarget.entity = entityHit
        currentTarget.coords = endCoords
        currentTarget.distance = distance
        local hidden = 0
        local totalOptions = 0

        for k, v in pairs(options) do
            local optionCount = #v
            local dist = k == '__global' and 0 or distance
            totalOptions += optionCount

            for i = 1, optionCount do
                local option = v[i]
                local hide = shouldHide(option, dist, endCoords, entityHit, entityModel)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then hidden += 1 end
            end
        end

        if zonesChanged then table.wipe(zones) end

        for i = 1, #nearbyZones do
            local zoneOptions = nearbyZones[i].options
            local optionCount = #zoneOptions
            totalOptions += optionCount
            zones[i] = zoneOptions

            for j = 1, optionCount do
                local option = zoneOptions[j]
                local hide = shouldHide(option, distance, endCoords, entityHit)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then hidden += 1 end
            end
        end

        if newOptions then
            if hasTarget == 1 and (totalOptions - hidden) > 1 then
                hasTarget = true
            end

            if hasTarget and hidden == totalOptions then
                if hasTarget ~= 1 then
                    hasTarget = false
                    SendNuiMessage('{"event": "leftTarget"}')
                end
            elseif menuChanged or hasTarget ~= 1 and hidden ~= totalOptions then
                hasTarget = options.size

                if currentMenu and options.__global[1]?.name ~= 'builtin:goback' then
                    table.insert(options.__global, 1, {
                        icon = 'fa-solid fa-circle-chevron-left',
                        label = locale('go_back'),
                        name = 'builtin:goback',
                        menuName = currentMenu,
                        openMenu = 'home'
                    })
                end

                SendNuiMessage(json.encode({
                    event = 'setTarget',
                    options = options,
                    zones = zones,
                }, { sort_keys = true }))
            end

            menuChanged = false
        end

        if toggleHotkey and IsPauseMenuActive() then
            state.setActive(false)
        end

        if not hasTarget or hasTarget == 1 then
            flag = flag == FLAG_ALL and FLAG_ENTITIES or FLAG_ALL
        end

        Wait(hit and 50 or 100)
    end

    state.setNuiFocus(false)
    SendNuiMessage('{"event": "visible", "state": false}')
    table.wipe(currentTarget)
    table.wipe(menuHistory)
    currentMenu = nil
    options:wipe()

    if nearbyZones then table.wipe(nearbyZones) end
end

-- RedM has no RegisterKeyMapping (lib.addKeybind is a no-op), so poll the control instead.
local function controlJustPressed(control)
    return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end

local function controlJustReleased(control)
    return IsControlJustReleased(0, control) or IsDisabledControlJustReleased(0, control)
end

CreateThread(function()
    while true do
        if controlJustPressed(openKey) then
            if toggleHotkey and state.isActive() then
                state.setActive(false)
            else
                CreateThread(startTargeting)
            end
        elseif not toggleHotkey and state.isActive() and controlJustReleased(openKey) then
            state.setActive(false)
        end

        Wait(0)
    end
end)

---@generic T
---@param option T
---@param server? boolean
---@return T
local function getResponse(option, server)
    local response = table.clone(option)
    response.entity = currentTarget.entity
    response.zone = currentTarget.zone
    response.coords = currentTarget.coords
    response.distance = currentTarget.distance

    if server then
        response.entity = response.entity and response.entity ~= 0 and NetworkGetEntityIsNetworked(response.entity) and
            NetworkGetNetworkIdFromEntity(response.entity) or 0
    end

    response.icon = nil
    response.groups = nil
    response.items = nil
    response.canInteract = nil
    response.onSelect = nil
    response.export = nil
    response.event = nil
    response.serverEvent = nil
    response.command = nil

    return response
end

RegisterNUICallback('select', function(data, cb)
    cb(1)

    if type(data) ~= 'table' then return end

    local zone = data[3] and nearbyZones and nearbyZones[data[3]]
    local group = not zone and options[data[1]]

    ---@type OxTargetOption?
    local option = zone and zone.options[data[2]] or type(group) == 'table' and group[data[2]] or nil

    -- re-check on click: the option may have become hidden since the menu was drawn
    if option and option.hide then option = nil end

    if option then
        if option.openMenu then
            local menuDepth = #menuHistory

            if option.name == 'builtin:goback' then
                option.menuName = option.openMenu
                option.openMenu = menuHistory[menuDepth]

                if menuDepth > 0 then
                    menuHistory[menuDepth] = nil
                end
            else
                menuHistory[menuDepth + 1] = currentMenu
            end

            menuChanged = true
            currentMenu = option.openMenu ~= 'home' and option.openMenu or nil

            options:wipe()
        else
            state.setNuiFocus(false)
        end

        currentTarget.zone = zone and zone.id

        if option.onSelect then
            option.onSelect(option.qtarget and currentTarget.entity or getResponse(option))
        elseif option.export then
            exports[option.resource or zone.resource][option.export](nil, getResponse(option))
        elseif option.event then
            TriggerEvent(option.event, getResponse(option))
        elseif option.serverEvent then
            TriggerServerEvent(option.serverEvent, getResponse(option, true))
        elseif option.command then
            ExecuteCommand(option.command)
        end

        if option.menuName == 'home' then return end
    end

    if not (option and option.openMenu) and IsNuiFocused() then
        state.setActive(false)
    end
end)
