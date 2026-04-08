-- Client Upgrades Logic

RegisterNetEvent("SPZ:vehicle:applyUpgrades", function(netId)
    local vehicle = NetToVeh(netId)
    if not DoesEntityExist(vehicle) then return end
    
    SetVehicleModKit(vehicle, 0)
    
    -- Apply Max Performance Mods
    local mods = {
        [11] = true, -- Engine
        [12] = true, -- Brakes
        [13] = true, -- Transmission
        [15] = true, -- Suspension
    }
    
    for modType, _ in pairs(mods) do
        local max = GetNumVehicleMods(vehicle, modType) - 1
        if max >= 0 then
            SetVehicleMod(vehicle, modType, max, false)
        end
    end
    
    ToggleVehicleMod(vehicle, 18, true) -- Turbo
    
    TriggerServerEvent("SPZ:vehicle:upgradesApplied")
end)
