local utils = {}

local GetGameplayCamCoord = GetGameplayCamCoord
local GetGameplayCamRot = GetGameplayCamRot
local StartShapeTestLosProbe = StartShapeTestLosProbe
local GetShapeTestResult = GetShapeTestResult
local rad, sin, cos, abs = math.rad, math.sin, math.cos, math.abs

---@param rot vector3
---@return vector3
local function rotationToDirection(rot)
    local x, z = rad(rot.x), rad(rot.z)
    local num = abs(cos(x))

    return vec3(-sin(z) * num, cos(z) * num, sin(x))
end

---RedM-safe camera raycast (ox_lib's raycast relies on GTA-only natives).
---@param flag number
---@param distance? number
---@return boolean hit
---@return number entityHit
---@return vector3 endCoords
function utils.raycastFromCamera(flag, distance)
    local coords = GetGameplayCamCoord()
    local destination = coords + rotationToDirection(GetGameplayCamRot(2)) * (distance or 20)
    local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z,
        flag, cache.ped, 4)

    while true do
        local retval, hit, endCoords, _, entityHit = GetShapeTestResult(handle)

        if retval ~= 1 then
            return hit == 1 or hit == true, entityHit or 0, endCoords
        end

        Wait(0)
    end
end

-- Zone markers. Set ox_target:drawSprite to 0 to disable, otherwise it is the max drawn per frame.
local maxZoneMarkers = GetConvarInt('ox_target:drawSprite', 24)
local MARKER_CYLINDER = 0x94FDAE17
local colour = { r = 155, g = 155, b = 155, a = 175 }
local hover = { r = 255, g = 255, b = 255, a = 255 }
local currentZones = {}
local previousZones = {}
local drawZones = {}
local drawN = 0

---@param coords vector3
---@return CZone[], boolean
function utils.getNearbyZones(coords)
    if not Zones then return currentZones, false end

    local n = 0
    local nearbyZones = lib.zones.getNearbyZones()
    drawN = 0
    previousZones, currentZones = currentZones, table.wipe(previousZones)

    for i = 1, #nearbyZones do
        local zone = nearbyZones[i]
        local contains = zone:contains(coords)

        if contains then
            n += 1
            currentZones[n] = zone
        end

        if drawN < maxZoneMarkers and zone.drawSprite ~= false and (contains or (zone.distance or 7) < 7) then
            drawN += 1
            drawZones[drawN] = zone
            zone.colour = contains and hover or nil
        end
    end

    local previousN = #previousZones

    if n ~= previousN then
        return currentZones, true
    end

    for i = 1, n do
        local zoneA = currentZones[i]
        local found = false

        for j = 1, previousN do
            if zoneA == previousZones[j] then
                found = true
                break
            end
        end

        if not found then
            return currentZones, true
        end
    end

    return currentZones, false
end

---Draws a small marker at each nearby zone centre (call every frame).
function utils.drawZoneMarkers()
    for i = 1, drawN do
        local zone = drawZones[i]
        local c = zone.colour or colour
        local pos = zone.coords

        Citizen.InvokeNative(0x2A32FAA57B937173, MARKER_CYLINDER, pos.x, pos.y, pos.z - 0.04, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            0.08, 0.08, 0.08, c.r, c.g, c.b, c.a, false, false, 2, false, nil, nil, false)
    end
end

---@param export string 'resource.exportName'
---@return boolean
function utils.hasExport(export)
    local resource, exportName = string.strsplit('.', export)

    return pcall(function()
        return exports[resource][exportName]
    end)
end

---@type table<string, number>
local playerItems = {}

function utils.getItems()
    return playerItems
end

---@param filter string | string[] | table<string, number>
---@param hasAny boolean?
---@return boolean
function utils.hasPlayerGotItems(filter, hasAny)
    local _type = type(filter)

    if _type == 'string' then
        return (playerItems[filter] or 0) > 0
    elseif _type == 'table' then
        local isHash = table.type(filter) == 'hash'

        for k, v in pairs(filter) do
            local name, amount = isHash and k or v, isHash and v or 1
            local hasItem = (playerItems[name] or 0) >= amount

            if hasAny then
                if hasItem then return true end
            elseif not hasItem then
                return false
            end
        end
    end

    return not hasAny
end

---Overridden by the framework adapter.
---@param filter string | string[] | table<string, number>
---@return boolean
function utils.hasPlayerGotGroup(filter)
    return true
end

SetTimeout(0, function()
    if GetResourceState('rsg-core') ~= 'missing' then
        require 'client.framework.rsg'
    end
end)

function utils.warn(msg)
    local trace = Citizen.InvokeNative(`FORMAT_STACK_TRACE` & 0xFFFFFFFF, nil, 0, Citizen.ResultAsString())
    local _, _, src = string.strsplit('\n', trace, 4)

    warn(('%s ^0%s\n'):format(msg, src and src:gsub('.-%(', '(') or ''))
end

return utils
