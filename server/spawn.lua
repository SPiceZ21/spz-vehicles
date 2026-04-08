-- Spawn Logic
SPZ = SPZ or {}

-- Single active vehicle record per source
-- [source] = { entity, netId, model, class, type, spawnedAt, upgraded }
SPZ.ActiveVehicles = {}

--- Despawns the active vehicle for a specific player
--- @param source number
function DespawnVehicle(source)
    local active = SPZ.ActiveVehicles[source]
    if not active then return end

    TriggerClientEvent("SPZ:vehicle:despawn", source)
    
    SetTimeout(Config.DespawnDelay or 500, function()
        SPZ.ActiveVehicles[source] = nil
        TriggerEvent("SPZ:vehicleDespawned", source)
    end)
end

exports("DespawnVehicle", DespawnVehicle)

local PendingSpawns = {}

--- Internal core spawn sequence entry point
--- @param source number
--- @param model string
--- @param spawnType string "freeroam" | "race"
function SpawnVehicle(source, model, spawnType)
    local vehicleData = exports["spz-vehicles"]:GetVehicleData(model)
    if not vehicleData then return end

    -- 2. Despawn existing
    DespawnVehicle(source)

    -- Track spawn type for the callback
    PendingSpawns[source] = spawnType or "freeroam"

    -- 3. Trigger client spawn
    TriggerClientEvent("SPZ:vehicle:spawn", source, model)
end

-- 4. Receive spawn confirmation from client
RegisterNetEvent("SPZ:vehicle:spawned", function(netId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    local modelHash = GetEntityModel(vehicle)
    local vehicleData = nil
    for name, data in pairs(SPZ.VehicleRegistry) do
        if GetHashKey(name) == modelHash then
            vehicleData = data
            break
        end
    end

    -- 5. Store in active vehicles
    local spawnType = PendingSpawns[src] or "freeroam"
    PendingSpawns[src] = nil

    SPZ.ActiveVehicles[src] = {
        entity    = vehicle,
        netId     = netId,
        model     = vehicleData.model,
        class     = vehicleData.class,
        type      = spawnType,
        spawnedAt = os.time(),
        upgraded  = false,
    }

    -- 6. Trigger full performance upgrades
    TriggerClientEvent("SPZ:vehicle:applyUpgrades", src, netId)
end)

-- 7. Receive upgrades confirmation
RegisterNetEvent("SPZ:vehicle:upgradesApplied", function()
    local src = source
    local active = SPZ.ActiveVehicles[src]
    if not active then return end

    active.upgraded = true

    -- 8. Load customization (Stub for now)
    local customization = nil -- exports["spz-vehicles"]:GetSavedCustomization(active.model)

    -- 9. Apply customization
    TriggerClientEvent("SPZ:vehicle:applyCustom", src, customization)

    -- 10. Place player in seat
    TriggerClientEvent("SPZ:vehicle:enter", src, active.netId)

    -- 11. Final event
    TriggerEvent("SPZ:vehicleSpawned", src, active.model, active.entity)
end)
