-- server/garage.lua — garage spawn / delete requests, blocked during races.
-- Moved from spz-carspawner/server/main.lua when it was merged into spz-vehicles.

-- server/main.lua

SPZ = SPZ or {}

-- ── Race gate ─────────────────────────────────────────────────────────────────
--
-- Spawning or deleting a car mid-race puts the racer in a vehicle the race
-- engine never issued: the field desyncs, the old car is orphaned in the race
-- bucket, and the new one carries none of the race's handling or damage state.
--
-- The radial menu already hides these options while a route is running, but
-- hiding a button is presentation, not enforcement — /car and /dv are still
-- typeable, and the net event behind the menu is still callable by anything on
-- the client. The check has to live here, where the server can be sure.

local function RaceBlocked(src)
    local state = Player(src).state

    if state.inRace then return "You cannot do that during a race." end
    if state.inQueue then return "You cannot do that while queued for a race." end
    if state.inPursuit then return "You cannot do that during Hot Pursuit." end

    if GetResourceState('spz-races') == 'started' then
        local ok, inTrial = pcall(function()
            return exports['spz-races']:IsInTimeTrial(src)
        end)
        if ok and inTrial then return "You cannot do that during a time trial." end
    end

    return nil
end

local function Deny(src, reason)
    TriggerClientEvent('ox_lib:notify', src, {
        description = reason,
        type        = "error",
    })
end

--- Spawn vehicle request from client menu or command
RegisterNetEvent("SPZ:carspawner:spawnVehicle", function(model)
    local src = source
    if not model or type(model) ~= "string" then return end

    local blocked = RaceBlocked(src)
    if blocked then return Deny(src, blocked) end

    local modelLower = model:lower():gsub("%s+", "")
    if exports["spz-vehicles"]:IsRegistered(modelLower) then
        exports["spz-vehicles"]:SpawnVehicle(src, modelLower, "freeroam")
    else
        TriggerClientEvent('ox_lib:notify', src, { description = "Invalid model: " .. tostring(model), type = "error" })
    end
end)

--- Command to open menu or spawn directly by model name (/car or /car <model>)
RegisterCommand("car", function(source, args)
    if source == 0 then return end

    local blocked = RaceBlocked(source)
    if blocked then return Deny(source, blocked) end

    if not args[1] then
        TriggerClientEvent("SPZ:carspawner:openMenu", source)
    else
        local model = tostring(args[1]):lower():gsub("%s+", "")
        if exports["spz-vehicles"]:IsRegistered(model) then
            exports["spz-vehicles"]:SpawnVehicle(source, model, "freeroam")
        else
            TriggerClientEvent('ox_lib:notify', source, { description = "Invalid model: " .. model, type = "error" })
        end
    end
end, false)

--- Command to delete current vehicle (/dv)
RegisterCommand("dv", function(source)
    if source == 0 then return end

    local blocked = RaceBlocked(source)
    if blocked then return Deny(source, blocked) end

    exports["spz-vehicles"]:DespawnVehicle(source)
end, false)
