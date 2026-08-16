-- Spawn Logic
SPZ = SPZ or {}

-- Single active vehicle record per source
-- [source] = { entity, netId, model, class, type, spawnedAt, upgraded }
SPZ.ActiveVehicles = {}

--- Despawns the active vehicle for a specific player.
--- Snapshots the netId so the deferred nil-out only clears the OLD vehicle —
--- if a new spawn is registered in the meantime, it is left untouched.
--- @param source number
function DespawnVehicle(source)
    local active = SPZ.ActiveVehicles[source]
    if not active then return end

    local oldNetId = active.netId   -- capture identity of vehicle being removed
    TriggerClientEvent("SPZ:vehicle:despawn", source)

    SetTimeout(Config.DespawnDelay or 500, function()
        local current = SPZ.ActiveVehicles[source]
        -- Only clear if the slot still holds the OLD vehicle (not a new spawn)
        if current and current.netId == oldNetId then
            SPZ.ActiveVehicles[source] = nil
            
            -- Clear player statebags
            Player(source).state:set("vehicleModel", nil, true)

            TriggerEvent("SPZ:vehicleDespawned", source)
        end
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
--- @param isRental boolean | nil
function SpawnVehicle(source, model, spawnType, coords, heading, isRental)
    local vehicleData = exports["spz-vehicles"]:GetVehicleData(model)
    if not vehicleData then return end

    -- 2. Despawn existing
    DespawnVehicle(source)

    local x, y, z, h
    if coords then
        x, y, z = coords.x, coords.y, coords.z
        h = heading or 0.0
    else
        local ped = GetPlayerPed(source)
        local pPos = GetEntityCoords(ped)
        x, y, z = pPos.x, pPos.y, pPos.z
        h = GetEntityHeading(ped)
    end

    -- Track spawn data for the callback
    PendingSpawns[source] = {
        model    = model,
        type     = spawnType or "freeroam",
        coords   = { x = x, y = y, z = z },
        heading  = h,
        isRental = isRental or false
    }

    -- Trigger client pre-load
    print(string.format("[spz-vehicles] DEBUG: Requesting client pre-load for player %d, model: %s", source, model))
    TriggerClientEvent("SPZ:vehicle:preloadModel", source, model)
end

exports("SpawnVehicle", SpawnVehicle)

-- Receive model pre-load confirmation from client and spawn on server
RegisterNetEvent("SPZ:vehicle:modelLoaded", function()
    local src = source
    local spawnData = PendingSpawns[src]
    if not spawnData then return end
    PendingSpawns[src] = nil

    local hash = GetHashKey(spawnData.model)
    local vehicleData = exports["spz-vehicles"]:GetVehicleData(spawnData.model)
    if not vehicleData then return end

    -- Create vehicle server-side
    local vehicle = CreateVehicle(
        hash,
        spawnData.coords.x,
        spawnData.coords.y,
        spawnData.coords.z,
        spawnData.heading,
        true,
        true
    )

    -- Wait briefly for creation tick
    local waitCount = 0
    while not DoesEntityExist(vehicle) and waitCount < 10 do
        Wait(50)
        waitCount = waitCount + 1
    end

    if not DoesEntityExist(vehicle) then
        print(string.format("^1[spz-vehicles] SPZ:vehicle:modelLoaded - failed to create vehicle entity on server (src %s)^7", src))
        return
    end

    -- Set routing bucket of the spawned vehicle entity to match player's bucket
    local playerBucket = GetPlayerRoutingBucket(src)
    SetEntityRoutingBucket(vehicle, playerBucket)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    -- Per-entity tag so clients can reliably tell OUR spawned cars apart from
    -- vMenu / any other vehicle. Entity statebags are never reused across
    -- different entities, so this can't false-positive after netId reuse.
    Entity(vehicle).state:set('spzVehicle', true, true)

    print(string.format("[spz-vehicles] DEBUG: Server-spawned vehicle (netId: %d) for player %d in bucket %d", netId, src, playerBucket))

    -- 5. Store in active vehicles
    SPZ.ActiveVehicles[src] = {
        entity    = vehicle,
        netId     = netId,
        model     = vehicleData.model,
        class     = vehicleData.class,
        type      = spawnData.type,
        isRental  = spawnData.isRental,
        spawnedAt = os.time(),
        upgraded  = false,
    }

    -- 6. Trigger full performance upgrades
    TriggerClientEvent("SPZ:vehicle:applyUpgrades", src, netId)

    -- 6.1 Set timeout for confirmation — must be >= client entity resolve window (5s)
    --     and <= world.lua SpawnTimeout (8s) to give client enough time.
    SetTimeout(Config.UpgradeConfirmTimeout or 7000, function()
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

RegisterNetEvent("SPZ:vehicle:upgradesApplied", function(netId)
    local src = source
    print(string.format("[spz-vehicles] DEBUG: Received SPZ:vehicle:upgradesApplied from %s (netId: %s)", src, netId))
    local active = SPZ.ActiveVehicles[src]
    if not active then return end

    active.upgraded = true
    print(string.format("[spz-vehicles] DEBUG: Upgrades applied for player %s (netId %s). Type: %s", src, netId, active.type))

    -- 8. Load customization (skip for rentals)
    if not active.isRental then
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
    end

    -- 10. Place player in seat
    TriggerClientEvent("SPZ:vehicle:enter", src, active.netId)

    -- 11. Final event so spz-races spawn monitor can proceed.
    --     TriggerEvent is resource-local server-side, so also call the export
    --     for reliable cross-resource confirmation.
    if active.type == "race" then
        SetVehicleDoorsLocked(active.entity, 2)
        TriggerEvent("SPZ:raceVehicleSpawned", src, active.model, active.entity)
        pcall(function() exports["spz-races"]:ConfirmRaceSpawn(src) end)
    else
        TriggerEvent("SPZ:vehicleSpawned", src, active.model, active.entity)
    end

    -- 12. Set statebags (Entity() takes an entity HANDLE, not a netId)
    Entity(active.entity).state:set("ownerId", src, true)
    Entity(active.entity).state:set("vehicleClass", active.class, true)
    Entity(active.entity).state:set("modelName", active.model, true)

    Player(src).state:set("vehicleModel", active.model, true)
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
-- No longer needed with statebags, but kept for non-linear state changes if any.
-- Actually, the guide says remove state machine logic.
-- So we only despawn if the player enters a state that shouldn't have a vehicle.
-- But since we don't have a central state machine, we'll listen for specific statebag changes in the future if needed.
-- For now, let's just remove it as per guide.

-- Confirmation from client that entity is gone
RegisterNetEvent("SPZ:vehicle:despawned", function()
    local src = source
    -- Currently handled by server-side timeout in DespawnVehicle
end)

-- Auto-despawn event triggered when player exits vehicle in freeroam
RegisterNetEvent("SPZ:vehicle:autoDespawn", function()
    local src = source
    DespawnVehicle(src)
end)
