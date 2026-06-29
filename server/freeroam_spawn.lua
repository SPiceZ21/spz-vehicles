-- Freeroam Spawning Logic
SPZ = SPZ or {}

SPZ.Notify = SPZ.Notify or function(src, msg, ntype, time)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = ntype, duration = time })
end

local SpawnCooldowns = {}

--- Validates and triggers a freeroam vehicle spawn
--- @param source number
--- @param model string
function FreeroamSpawn(source, model)
    -- 1. Check Player State
    if Player(source).state.inRace then
        SPZ.Notify(source, "Cannot spawn vehicle during a race", "error", 3000)
        return
    end
    if Player(source).state.inQueue then
        SPZ.Notify(source, "Cannot spawn vehicle while queued", "error", 3000)
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
    local isRental = false
    
    if data.class > licenseTier then
        -- Check if it's the rental
        if model ~= Config.RentalVehicles[data.class] then
            local classLabel = (SPZ.ClassMeta[data.class] and SPZ.ClassMeta[data.class].label) or "Higher"
            SPZ.Notify(source, classLabel .. " license required for this vehicle. Try the rental instead.", "error", 3000)
            return
        end
        isRental = true
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
    SpawnVehicle(source, model, "freeroam", nil, nil, isRental)
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
            -- Only the rental is available for higher classes
            local rentalModel = Config.RentalVehicles[i]
            local data = exports["spz-vehicles"]:GetVehicleData(rentalModel)
            if data then
                filtered[i] = { data }
            else
                filtered[i] = {}
            end
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
