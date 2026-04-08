-- Client Spawn Logic

RegisterNetEvent("SPZ:vehicle:spawn", function(model)
    local hash = type(model) == "number" and model or GetHashKey(model)
    
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        return
    end

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    local playerPed = PlayerPedId()
    local pos = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    local vehicle = CreateVehicle(hash, pos.x, pos.y, pos.z, heading, true, false)
    
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
