-- Client Spawn Logic

-- Pre-load is the step the whole race start waits on: the server asks, the
-- client answers "loaded" or "failed", and silence from here is what produces a
-- 30 s stall and a "Nobody spawned — cancelling race". Every branch therefore
-- both answers the server AND says so in the client console, so a stall can be
-- read off F8 instead of guessed at.
-- Read through a local table rather than the global: an error anywhere in this
-- handler means the server never hears back and stalls the whole race on its
-- spawn timeout, so it must not be possible for a missing/late Config to throw.
local function cfg(key, default)
    local c = rawget(_G, "Config")
    local v = c and c[key]
    if v == nil then return default end
    return v
end

local function doPreload(model)
    local hash  = type(model) == "number" and model or GetHashKey(model)
    local began = GetGameTimer()

    print(("[spz-vehicles] preload: '%s' requested"):format(tostring(model)))

    -- Streaming/DLC metadata can still be catching up right after connect —
    -- poll for a few seconds instead of bailing on the very first check.
    local checkDeadline = GetGameTimer() + cfg("ModelCheckGraceMs", 3000)
    while (not IsModelInCdimage(hash) or not IsModelAVehicle(hash)) and GetGameTimer() < checkDeadline do
        Wait(100)
    end
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        print(("^1[spz-vehicles] preload: '%s' is not a streamed vehicle model^7"):format(tostring(model)))
        TriggerServerEvent("SPZ:vehicle:preloadFailed", model, "unknown_model")
        return
    end

    RequestModel(hash)
    local loadDeadline = GetGameTimer() + cfg("ModelLoadTimeoutMs", 15000)
    while not HasModelLoaded(hash) and GetGameTimer() < loadDeadline do
        Wait(0)
    end

    if not HasModelLoaded(hash) then
        print(("^1[spz-vehicles] preload: '%s' timed out after %d ms^7")
            :format(tostring(model), GetGameTimer() - began))
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent("SPZ:vehicle:preloadFailed", model, "load_timeout")
        return
    end

    print(("[spz-vehicles] preload: '%s' loaded in %d ms"):format(tostring(model), GetGameTimer() - began))
    TriggerServerEvent("SPZ:vehicle:modelLoaded")
    SetModelAsNoLongerNeeded(hash)
end

-- Any error in there is still an answer the server needs: a script error used to
-- mean total silence, and total silence means the race waits out its spawn
-- timeout and cancels for everyone. Fail loudly, then fail *to the server*, so
-- it can retry on the fallback model instead of stalling.
RegisterNetEvent("SPZ:vehicle:preloadModel", function(model)
    local ok, err = pcall(doPreload, model)
    if not ok then
        print(("^1[spz-vehicles] preload: error handling '%s': %s^7"):format(tostring(model), tostring(err)))
        TriggerServerEvent("SPZ:vehicle:preloadFailed", model, "client_error")
    end
end)

RegisterNetEvent("SPZ:vehicle:enter", function(netId)
    local timeout = 50 -- 2.5 seconds max wait
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
        Wait(50)
        timeout = timeout - 1
    end

    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    
    local vehicle = NetToVeh(netId)
    if DoesEntityExist(vehicle) then
        local playerPed = PlayerPedId()
        TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
    end
end)

RegisterNetEvent("SPZ:vehicle:unlock", function(netId)
    local vehicle = NetToVeh(netId)
    if DoesEntityExist(vehicle) then
        SetVehicleDoorsLocked(vehicle, 1)
        PlayVehicleDoorOpenSound(vehicle, 0)
    end
end)
