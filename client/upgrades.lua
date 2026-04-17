-- Client Upgrades Logic

RegisterNetEvent("SPZ:vehicle:applyUpgrades", function(netId)
    -- Re-fetch handle each iteration — NetToVeh may return 0 until the entity
    -- is mapped on this client, which can take a few frames after spawn
    local vehicle = 0
    local timeout = 100
    while timeout > 0 do
        vehicle = NetToVeh(netId)
        if DoesEntityExist(vehicle) then break end
        Wait(50)
        timeout = timeout - 1
    end

    if not DoesEntityExist(vehicle) then
        print(("[spz-vehicles] applyUpgrades: entity for netId %s never resolved, aborting"):format(netId))
        return
    end

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
