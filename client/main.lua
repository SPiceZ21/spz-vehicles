-- client/main.lua — Vehicle lifecycle, auto-despawn on exit, race vehicle exit prevention

local lastVehicle = 0

-- Authoritative racing flag. The server sets inRace for the whole warmup→race
-- window and clears it on finish/DNF/cleanup. Gating on this statebag (instead
-- of a pile of client events) means the lock can NEVER get stuck true after a
-- race — which was trapping players out of vehicles in freeroam.
local function inRace() return LocalPlayer.state.inRace == true end

-- Is `veh` a vehicle SPZ spawned? Checks a per-entity statebag set at spawn —
-- vMenu / any other vehicle never carries it, and (unlike a netId compare) it
-- can't false-positive after the engine reuses a freed netId post-race.
local function isOwnedVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    return Entity(veh).state.spzVehicle == true
end

-- ── Lock vehicle exit during races ────────────────────────────────────────────
CreateThread(function()
    while true do
        if inRace() then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                -- No bailing out mid-race (INPUT_VEH_EXIT). We deliberately do NOT
                -- disable INPUT_ENTER — you're already seated, and doing so caused
                -- entry-cancel glitches that bled into freeroam.
                DisableControlAction(0, 75, true)
                SetVehicleDoorsLocked(veh, 4)

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

-- When the race ends, unlock whatever car we're sitting in so we're never trapped
-- (a race car kept for the post-race cooldown, etc.). Bound with a nil bag +
-- own-player filter so it doesn't depend on the server id being assigned at load.
AddStateBagChangeHandler("inRace", nil, function(bagName, _, value)
    if value then return end
    if bagName ~= ('player:%d'):format(GetPlayerServerId(PlayerId())) then return end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then SetVehicleDoorsLocked(veh, 1) end
end)

-- ── Auto-despawn the SPZ car when player steps out in freeroam ─────────────────
-- Only the SPZ-spawned vehicle is auto-removed. vMenu / other vehicles are left
-- alone so they no longer vanish the instant you get out.

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local currentVeh = GetVehiclePedIsIn(ped, false)

        if currentVeh ~= 0 and GetPedInVehicleSeat(currentVeh, -1) == ped and isOwnedVehicle(currentVeh) then
            -- Player is driver of OUR spawned vehicle
            lastVehicle = currentVeh
        elseif lastVehicle ~= 0 then
            -- Player was driver, but is no longer in driver seat
            if not inRace() then
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
