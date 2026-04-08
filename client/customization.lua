-- Client Customization Logic

RegisterNetEvent("SPZ:vehicle:applyCustom", function(customData)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if not DoesEntityExist(vehicle) then return end

    if not customData then return end

    -- Apply Primary/Secondary colors if present
    if customData.primary then
        SetVehicleColours(vehicle, customData.primary, customData.secondary or customData.primary)
    end
end)
