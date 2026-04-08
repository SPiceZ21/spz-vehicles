-- Race Spawning Logic

--- Called by spz-races to place a vehicle on the grid
--- @param source number
--- @param model string
--- @param coords table {x,y,z}
--- @param heading number
function SpawnRaceVehicle(source, model, coords, heading)
    SpawnVehicle(source, model, "race", coords, heading)
end

--- Called on race start to unlock doors
--- @param source number
function UnlockRaceVehicle(source)
    local active = SPZ.ActiveVehicles[source]
    if active and active.type == "race" and DoesEntityExist(active.entity) then
        TriggerClientEvent("SPZ:vehicle:unlock", source, active.netId)
        SetVehicleDoorsLocked(active.entity, 1)
    end
end

exports("SpawnRaceVehicle", SpawnRaceVehicle)
exports("UnlockRaceVehicle", UnlockRaceVehicle)
