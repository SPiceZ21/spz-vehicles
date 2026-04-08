-- Client Despawn Logic

RegisterNetEvent("SPZ:vehicle:despawn", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        TriggerServerEvent("SPZ:vehicle:despawned")
    end
end)
