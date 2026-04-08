-- Client Upgrades Logic

RegisterNetEvent("SPZ:vehicle:applyUpgrades", function(netId)
    local vehicle = NetToVeh(netId)
    local timeout = 50
    while not DoesEntityExist(vehicle) and timeout > 0 do
        Wait(50)
        timeout = timeout - 1
    end

    if not DoesEntityExist(vehicle) then return end

    SetVehicleModKit(vehicle, 0)

    for _, mod in ipairs(SPZ.FullUpgrade) do
        if mod.toggle then
            ToggleVehicleMod(vehicle, mod.type, true)
        else
            SetVehicleMod(vehicle, mod.type, mod.value, false)
        end
    end

    SetVehicleTyresCanBurst(vehicle, false)   -- bulletproof tyres
    SetVehicleEngineOn(vehicle, true, true, false)

    TriggerServerEvent("SPZ:vehicle:upgradesApplied", netId)
end)
