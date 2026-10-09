-- Client Customization Logic
SPZ = SPZ or {}

function SPZ.CaptureVisuals(vehicle)
  local p1, p2      = GetVehicleColours(vehicle)
  local pearl, wheel = GetVehicleExtraColours(vehicle)
  local r1,g1,b1    = GetVehicleCustomPrimaryColour(vehicle)
  local r2,g2,b2    = GetVehicleCustomSecondaryColour(vehicle)
  local nr,ng,nb    = GetVehicleNeonLightsColour(vehicle)

  local VISUAL_SLOTS = {0,1,2,3,4,8,10,14,22,25,33,34,48}
  local visualMods = {}
  for _, slot in ipairs(VISUAL_SLOTS) do
    visualMods[slot] = GetVehicleMod(vehicle, slot)
  end

  return {
    primary_color    = p1,
    secondary_color  = p2,
    pearlescent      = pearl,
    wheel_color      = wheel,
    custom_primary   = GetIsVehiclePrimaryColourCustom(vehicle)   and {r1,g1,b1} or nil,
    custom_secondary = GetIsVehicleSecondaryColourCustom(vehicle) and {r2,g2,b2} or nil,
    livery           = GetVehicleLivery(vehicle),
    plate_text       = GetVehicleNumberPlateText(vehicle),
    plate_style      = GetVehicleNumberPlateTextIndex(vehicle),
    window_tint      = GetVehicleWindowTint(vehicle),
    neon_enabled     = {
      left  = IsVehicleNeonLightEnabled(vehicle, 0),
      right = IsVehicleNeonLightEnabled(vehicle, 1),
      front = IsVehicleNeonLightEnabled(vehicle, 2),
      back  = IsVehicleNeonLightEnabled(vehicle, 3),
    },
    neon_color       = { nr, ng, nb },
    xenon_color      = GetVehicleXenonLightsColor(vehicle),
    visual_mods      = visualMods,
  }
end

--- Wait for a networked car to reach this client and take control of it.
--- The net id has to be resolved again on every tick: NetToVeh returns 0
--- until the entity has streamed in, and the old loops resolved it once and
--- then waited on that 0 forever, so the plate / preset was silently skipped.
local function awaitVehicle(netId, ms)
  local deadline = GetGameTimer() + (ms or 5000)
  local vehicle = 0
  while GetGameTimer() < deadline do
    if NetworkDoesEntityExistWithNetworkId(netId) then
      vehicle = NetToVeh(netId)
      if vehicle ~= 0 and DoesEntityExist(vehicle) then break end
    end
    Wait(50)
  end
  if vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
  local ctl = GetGameTimer() + 1500
  while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < ctl do
    NetworkRequestControlOfEntity(vehicle); Wait(0)
  end
  return vehicle
end

RegisterNetEvent("SPZ:vehicle:applyCustom", function(netId, preset)
  if not preset then return end  -- no saved preset, keep defaults

  local vehicle = awaitVehicle(netId)
  if vehicle == 0 then return end

  SetVehicleModKit(vehicle, 0)

  SetVehicleColours(vehicle, preset.primary_color, preset.secondary_color)
  SetVehicleExtraColours(vehicle, preset.pearlescent, preset.wheel_color)

  if preset.custom_primary then
    SetVehicleCustomPrimaryColour(vehicle,
      preset.custom_primary[1], preset.custom_primary[2], preset.custom_primary[3])
  end
  if preset.custom_secondary then
    SetVehicleCustomSecondaryColour(vehicle,
      preset.custom_secondary[1], preset.custom_secondary[2], preset.custom_secondary[3])
  end

  if preset.livery and preset.livery >= 0 then
    SetVehicleLivery(vehicle, preset.livery)
  end

  -- The server swaps in the player's vanity plate before sending, so this
  -- never puts the old random plate back over it.
  if preset.plate_text and preset.plate_text ~= "" then
    SetVehicleNumberPlateText(vehicle, preset.plate_text)
  end
  SetVehicleNumberPlateTextIndex(vehicle, preset.plate_style)
  SetVehicleWindowTint(vehicle, preset.window_tint)

  SetVehicleNeonLightEnabled(vehicle, 0, preset.neon_enabled.left)
  SetVehicleNeonLightEnabled(vehicle, 1, preset.neon_enabled.right)
  SetVehicleNeonLightEnabled(vehicle, 2, preset.neon_enabled.front)
  SetVehicleNeonLightEnabled(vehicle, 3, preset.neon_enabled.back)
  SetVehicleNeonLightsColour(vehicle,
    preset.neon_color[1], preset.neon_color[2], preset.neon_color[3])

  if preset.xenon_color and preset.xenon_color >= 0 then
    SetVehicleXenonLightsColor(vehicle, preset.xenon_color)
  end

  for slot, modIndex in pairs(preset.visual_mods) do
    SetVehicleMod(vehicle, tonumber(slot), modIndex, false)
  end
end)

--- The player's personal vanity plate, applied after any saved preset so it is
--- the last word on the plate text. Sent for every spawn, preset or not.
RegisterNetEvent("SPZ:vehicle:applyPlate", function(netId, plate)
  if not plate or plate == "" then return end

  local vehicle = awaitVehicle(netId)
  if vehicle == 0 then return end
  SetVehicleNumberPlateText(vehicle, plate)
end)
