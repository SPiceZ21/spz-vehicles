-- Client Spawn Logic

RegisterNetEvent("SPZ:vehicle:spawn", function(model, coords, heading)
    local hash = type(model) == "number" and model or GetHashKey(model)
    
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    local x, y, z, h
    if coords then
        x, y, z = coords.x, coords.y, coords.z
        h = heading or 0.0
    else
        local playerPed = PlayerPedId()
        local pPos = GetEntityCoords(playerPed)
        x, y, z = pPos.x, pPos.y, pPos.z
        h = GetEntityHeading(playerPed)
    end

    local vehicle = CreateVehicle(hash, x, y, z, h, true, false)
    
    -- Network settings
    SetEntityAsMissionEntity(vehicle, true, true)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)

    TriggerServerEvent("SPZ:vehicle:spawned", netId)
    
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
