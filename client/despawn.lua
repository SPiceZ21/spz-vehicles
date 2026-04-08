-- Client Despawn Logic

RegisterNetEvent("SPZ:vehicle:despawn", function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
end)
