-- Client Despawn Logic
-- Deletes the SPECIFIC SPZ vehicle by net id. Never deletes "whatever the player
-- is in" — that blindly removed vMenu / other cars spawned after a race.

RegisterNetEvent("SPZ:vehicle:despawn", function(netId)
    local veh

    if netId and NetworkDoesEntityExistWithNetworkId(netId) then
        local e = NetToVeh(netId)
        if e and e ~= 0 and DoesEntityExist(e) then veh = e end
    end

    -- Legacy fallback (no netId): only delete the car you're in if it's OURS.
    if not veh then
        local cur = GetVehiclePedIsIn(PlayerPedId(), false)
        if cur ~= 0 and Entity(cur).state.spzVehicle == true then veh = cur end
    end

    if veh and veh ~= 0 and DoesEntityExist(veh) then
        DeleteEntity(veh)
        TriggerServerEvent("SPZ:vehicle:despawned")
    end
end)
