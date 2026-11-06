-- client/tuner.lua — tuner command, shops, exports.
-- Moved from spz-tunners/client/main.lua when it was merged into spz-vehicles.

-- client/main.lua
SPZ_Tuners = SPZ_Tuners or {}

local function TryOpenTuner()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        lib.notify({ title = 'Tuner Shop', description = 'You must be inside a vehicle to access the tuning menu.', type = 'error' })
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then
        lib.notify({ title = 'Tuner Shop', description = 'Only the driver can tune the vehicle.', type = 'error' })
        return
    end

    -- Check shop range if AllowAnywhere is false
    if not Config.Tuner.AllowAnywhere then
        local pPos = GetEntityCoords(ped)
        local nearShop = false
        for _, shop in ipairs(Config.Tuner.Shops or {}) do
            if #(pPos - shop.coords) <= (shop.radius or 5.0) then
                nearShop = true
                break
            end
        end

        if not nearShop then
            lib.notify({ title = 'Tuner Shop', description = 'You must be at a Tuner Shop / LSC garage location.', type = 'error' })
            return
        end
    end

    SPZ_Tuners.OpenTunerMenu(veh)
end

-- Command Registration (/tuner, /tune, /customs)
if Config.Tuner.EnableCommand then
    RegisterCommand(Config.Tuner.Command or 'tuner', function()
        TryOpenTuner()
    end, false)

    RegisterCommand('tune', function()
        TryOpenTuner()
    end, false)

    RegisterCommand('customs', function()
        TryOpenTuner()
    end, false)
end

RegisterCommand('save_customs', function() SPZ_Tuners.SaveCustoms() end, false)

-- Race start: close the tuner (autosaving) when the grid teleport / countdown fires.
for _, ev in ipairs({ 'SPZ:tpToGrid', 'SPZ:countdown', 'SPZ:go' }) do
    RegisterNetEvent(ev, function() SPZ_Tuners.CloseForRace() end)
end

-- Export to open tuner menu from other scripts / garages
exports('OpenTunerMenu', function(targetVeh)
    local veh = targetVeh or GetVehiclePedIsIn(PlayerPedId(), false)
    if DoesEntityExist(veh) then
        SPZ_Tuners.OpenTunerMenu(veh)
        return true
    end
    return false
end)

-- Export to capture vehicle mods snapshot
exports('GetVehicleMods', function(targetVeh)
    local veh = targetVeh or GetVehiclePedIsIn(PlayerPedId(), false)
    if DoesEntityExist(veh) then
        return SPZ_Tuners.SnapshotVehicle(veh)
    end
    return nil
end)

-- Export to apply vehicle mods preset
exports('ApplyVehicleMods', function(targetVeh, preset)
    local veh = targetVeh or GetVehiclePedIsIn(PlayerPedId(), false)
    if DoesEntityExist(veh) and preset then
        SPZ_Tuners.RestoreVehicle(veh, preset)
        return true
    end
    return false
end)

-- Garage Shop Markers & Interaction Points
CreateThread(function()
    if not Config.Tuner.Shops or #Config.Tuner.Shops == 0 then return end

    for _, shop in ipairs(Config.Tuner.Shops) do
        -- Add blip
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 72) -- Tuning wrench sprite
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 47) -- Orange
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.name or "Tuner Customs Shop")
        EndTextCommandSetBlipName(blip)

        -- Zone prompt via ox_lib
        if lib and lib.points then
            lib.points.new({
                coords = shop.coords,
                distance = shop.radius or 5.0,
                onEnter = function()
                    local ped = PlayerPedId()
                    if IsPedInAnyVehicle(ped, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) == ped then
                        lib.showTextUI("[E] Open Tuner Shop Menu", { icon = "wrench" })
                    end
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                nearby = function(point)
                    local ped = PlayerPedId()
                    if IsControlJustPressed(0, 38) then -- [E]
                        if IsPedInAnyVehicle(ped, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) == ped then
                            lib.hideTextUI()
                            SPZ_Tuners.OpenTunerMenu(GetVehiclePedIsIn(ped, false))
                        end
                    end
                end
            })
        end
    end
end)
