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
--- @param coords table {x,y,z} | nil
--- @param heading number | nil
function SpawnVehicle(source, model, spawnType, coords, heading)
    local vehicleData = exports["spz-vehicles"]:GetVehicleData(model)
    if not vehicleData then return end

    -- 2. Despawn existing
    DespawnVehicle(source)

    -- Track spawn type for the callback
    PendingSpawns[source] = spawnType or "freeroam"

    -- 3. Trigger client spawn
    TriggerClientEvent("SPZ:vehicle:spawn", source, model, coords, heading)
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

    -- 6.1 Set timeout for confirmation
    SetTimeout(Config.UpgradeConfirmTimeout or 3000, function()
        local current = SPZ.ActiveVehicles[src]
        if current and current.netId == netId and not current.upgraded then
            print(("^1[spz-vehicles] Spawn aborted for %s - Upgrade confirmation timeout^7"):format(src))
            if DoesEntityExist(current.entity) then
                DeleteEntity(current.entity)
            end
            SPZ.ActiveVehicles[src] = nil
        end
    end)
end)

-- 7. Receive upgrades confirmation
RegisterNetEvent("SPZ:vehicle:upgradesApplied", function(netId)
    local src = source
    local active = SPZ.ActiveVehicles[src]
    if not active then return end

    active.upgraded = true

    -- 8. Load customization (protected — DB table may not exist yet)
    local ok, profile = pcall(function()
        return exports["spz-identity"]:GetProfile(src)
    end)
    
    if ok and profile then
        local cOk, preset = pcall(function()
            return exports["spz-vehicles"]:LoadCustomization(profile.id, active.model)
        end)
        if cOk and preset then
            -- 9. Apply customization
            TriggerClientEvent("SPZ:vehicle:applyCustom", src, active.netId, preset)
        end
    end

    -- 10. Place player in seat
    TriggerClientEvent("SPZ:vehicle:enter", src, active.netId)

    -- 11. Final event (MUST always fire so spz-races spawn monitor can proceed)
    if active.type == "race" then
        SetVehicleDoorsLocked(active.entity, 2)
        TriggerEvent("SPZ:raceVehicleSpawned", src, active.model, active.entity)
    else
        TriggerEvent("SPZ:vehicleSpawned", src, active.model, active.entity)
    end
end)

--- Returns the active vehicle data for a player
--- @param source number
--- @return table | nil
function GetPlayerVehicle(source)
    return SPZ.ActiveVehicles[source]
end

exports("GetPlayerVehicle", GetPlayerVehicle)

-- Lifecycle Listeners

-- Handle player disconnect
AddEventHandler("SPZ:playerDisconnected", function(source)
    DespawnVehicle(source)
end)

-- Handle state changes (e.g. going to spectator)
AddEventHandler("SPZ:stateChanged", function(source, newState)
    if newState == "QUEUED" or newState == "SPECTATING" then
        DespawnVehicle(source)
    end
end)

-- Confirmation from client that entity is gone
RegisterNetEvent("SPZ:vehicle:despawned", function()
    local src = source
    -- Currently handled by server-side timeout in DespawnVehicle
end)
