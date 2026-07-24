-- client/main.lua — Vehicle lifecycle, auto-despawn on exit, race vehicle exit prevention

local isRacing = false
local lastVehicle = 0

-- ── Race events: track racing state ───────────────────────────────────────────

local function SetRacingState(state)
    isRacing = state
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and DoesEntityExist(veh) then
        SetVehicleDoorsLocked(veh, state and 4 or 1)
    end
end

RegisterNetEvent("SPZ:warmupPhase",      function() SetRacingState(true)  end)
RegisterNetEvent("SPZ:stagingPhase",     function() SetRacingState(true)  end)
RegisterNetEvent("SPZ:countdown",        function() SetRacingState(true)  end)
RegisterNetEvent("SPZ:go",               function() SetRacingState(true)  end)
RegisterNetEvent("SPZ:spawnCheckpoints", function() SetRacingState(true)  end)
RegisterNetEvent("SPZ:tt:Begin",         function() SetRacingState(true)  end)

RegisterNetEvent("SPZ:raceFinished",     function() SetRacingState(false) end)
RegisterNetEvent("SPZ:raceEnd",          function() SetRacingState(false) end)
RegisterNetEvent("SPZ:playerDNF",         function() SetRacingState(false) end)
RegisterNetEvent("SPZ:tpToSafeZone",     function() SetRacingState(false) end)
RegisterNetEvent("SPZ:tt:End",           function() SetRacingState(false) end)

-- ── Lock vehicle exit during races ────────────────────────────────────────────

CreateThread(function()
    while true do
        if isRacing then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                -- Disable INPUT_VEH_EXIT (75) and INPUT_ENTER (23)
                DisableControlAction(0, 75, true)
                DisableControlAction(0, 23, true)

                -- Ensure doors remain locked
                SetVehicleDoorsLocked(veh, 4)

                -- Feedback if player attempts to press exit key (F / controller Y)
                if IsDisabledControlJustPressed(0, 75) then
                    lib.notify({
                        title = "Race Active",
                        description = "You cannot exit your vehicle while racing!",
                        type = "warning",
                        duration = 2000
                    })
                end
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

-- ── Auto-despawn vehicle when player steps out in freeroam ─────────────────────

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local currentVeh = GetVehiclePedIsIn(ped, false)

        if currentVeh ~= 0 and GetPedInVehicleSeat(currentVeh, -1) == ped then
            -- Player is driver of a vehicle
            lastVehicle = currentVeh
        elseif lastVehicle ~= 0 then
            -- Player was driver, but is no longer in driver seat
            if not isRacing then
                local toDespawn = lastVehicle
                lastVehicle = 0

                -- Brief 1-second delay to ensure player isn't just seat-swapping/warping
                SetTimeout(1000, function()
                    local checkPed = PlayerPedId()
                    local checkVeh = GetVehiclePedIsIn(checkPed, false)
                    if checkVeh == 0 and DoesEntityExist(toDespawn) then
                        -- Player is completely outside the vehicle — auto despawn
                        TriggerServerEvent("SPZ:vehicle:autoDespawn")
                        if DoesEntityExist(toDespawn) then
                            DeleteEntity(toDespawn)
                        end
                        lib.notify({
                            description = "Vehicle auto-despawned",
                            type = "inform",
                            duration = 2500
                        })
                    end
                end)
            else
                lastVehicle = 0
            end
        end
    end
end)
