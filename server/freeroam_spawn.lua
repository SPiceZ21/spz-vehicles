-- Freeroam Spawning Logic
SPZ = SPZ or {}

SPZ.Notify = SPZ.Notify or function(src, msg, type, time)
    TriggerClientEvent("spz-lib:Notify", src, msg, type, time)
end

local SpawnCooldowns = {}

--- Validates and triggers a freeroam vehicle spawn
--- @param source number
--- @param model string
function FreeroamSpawn(source, model)
    -- 1. Check Player State
    local state = exports["spz-core"]:GetPlayerState(source)
    if state ~= "FREEROAM" then
        SPZ.Notify(source, "You can't spawn here", "error", 3000)
        return
    end

    -- 2. Check Registration
    if not exports["spz-vehicles"]:IsRegistered(model) then
        SPZ.Notify(source, "Unknown vehicle", "error", 3000)
        return
    end

    -- 3. Check Freeroam Availability
    local data = exports["spz-vehicles"]:GetVehicleData(model)
    if not data.freeroam then
        SPZ.Notify(source, "Vehicle not available in freeroam", "error", 3000)
        return
    end

    -- 4. Check License Gate
    local licenseTier = exports["spz-identity"]:GetLicenseTier(source) or 0
    if data.class > licenseTier then
        local classLabel = SPZ.ClassMeta[data.class].label or "Higher"
        SPZ.Notify(source, classLabel .. " license required", "error", 3000)
        return
    end

    -- 5. Check Cooldown
    local now = os.time()
    local cooldown = Config.FreeroamSpawnCooldown or 10
    if SpawnCooldowns[source] and (now - SpawnCooldowns[source]) < cooldown then
        local remaining = cooldown - (now - SpawnCooldowns[source])
        SPZ.Notify(source, ("Wait %ds before spawning again"):format(remaining), "error", 3000)
        return
    end

    -- 6. Trigger Sequence
    SpawnCooldowns[source] = now
    SpawnVehicle(source, model, "freeroam")
end

--- Returns available freeroam vehicles grouped by class for the player
--- @param source number
--- @return table
function GetFreeroamVehicles(source)
    local licenseTier = exports["spz-identity"]:GetLicenseTier(source) or 0
    local filtered = {}
    
    for i = 0, 3 do
        if i <= licenseTier then
            filtered[i] = exports["spz-vehicles"]:GetClassVehicles(i, { freeroam = true })
        else
            filtered[i] = {}
        end
    end
    
    return filtered
end

exports("FreeroamSpawn", FreeroamSpawn)
exports("GetFreeroamVehicles", GetFreeroamVehicles)

RegisterNetEvent("SPZ:freeroamSpawn", function(model)
    local src = source
    FreeroamSpawn(src, model)
end)
