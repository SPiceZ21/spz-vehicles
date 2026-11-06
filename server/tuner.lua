-- server/tuner.lua — tuner preset onto the car (statebag).
-- Moved from spz-tunners/server/main.lua when it was merged into spz-vehicles.

-- server/main.lua

-- Receive vehicle tuning preset save event from client
RegisterNetEvent("SPZ:tuner:saveVehicle", function(netId, preset)
    local src = source
    if not netId or not preset then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then return end

    -- Store preset into entity statebag so any player streaming the vehicle receives the state
    Entity(vehicle).state:set("tunerPreset", preset, true)

    -- The player's saved look is written by /savecustom (client/commands.lua →
    -- SPZ:vehicle:saveCustom), which the tuner menu runs. The SaveCustomization
    -- export this used to call never existed.
end)

