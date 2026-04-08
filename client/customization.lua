-- Client Customization Logic
SPZ = SPZ or {}

function SPZ.CaptureVisuals(vehicle)
  local p1, p2      = GetVehicleColour(vehicle)
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

RegisterNetEvent("SPZ:vehicle:applyCustom", function(netId, preset)
  if not preset then return end  -- no saved preset, keep defaults

  local vehicle = NetToVeh(netId)
  local timeout = 50
  while not DoesEntityExist(vehicle) and timeout > 0 do Wait(50); timeout = timeout - 1 end

  if not DoesEntityExist(vehicle) then return end

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

  SetVehicleNumberPlateText(vehicle, preset.plate_text)
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
