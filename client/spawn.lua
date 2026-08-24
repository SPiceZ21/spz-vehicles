-- Client Spawn Logic

RegisterNetEvent("SPZ:vehicle:preloadModel", function(model)
    local hash = type(model) == "number" and model or GetHashKey(model)

    -- Streaming/DLC metadata can still be catching up right after connect —
    -- poll for a few seconds instead of bailing on the very first check.
    local checkDeadline = GetGameTimer() + (Config.ModelCheckGraceMs or 3000)
    while (not IsModelInCdimage(hash) or not IsModelAVehicle(hash)) and GetGameTimer() < checkDeadline do
        Wait(100)
    end
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        TriggerServerEvent("SPZ:vehicle:preloadFailed", model, "unknown_model")
        return
    end

    RequestModel(hash)
    local loadDeadline = GetGameTimer() + (Config.ModelLoadTimeoutMs or 15000)
    while not HasModelLoaded(hash) and GetGameTimer() < loadDeadline do
        Wait(0)
    end

    if not HasModelLoaded(hash) then
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent("SPZ:vehicle:preloadFailed", model, "load_timeout")
        return
    end

    TriggerServerEvent("SPZ:vehicle:modelLoaded")
    SetModelAsNoLongerNeeded(hash)
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
