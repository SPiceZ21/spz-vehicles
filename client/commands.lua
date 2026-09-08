-- Client Commands
SPZ = SPZ or {}

RegisterCommand("savecustom", function()
  local playerPed = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(playerPed, false)

  if vehicle == 0 then
    lib.notify({ description = "Get in a vehicle first", type = "error", duration = 3000 })
    return
  end

  local preset = SPZ.CaptureVisuals(vehicle)
  local modelHash = GetEntityModel(vehicle)

  -- The model NAME is resolved here and sent along, because
  -- GetDisplayNameFromVehicleModel is a client-only native — there is no server
  -- equivalent. The server can reverse a hash for anything already in the
  -- registry, but a vanilla or add-on car that is not in it has no other way of
  -- being identified, and those are exactly the ones the registry's dynamic
  -- fallback exists to accept.
  local modelName = GetDisplayNameFromVehicleModel(modelHash)

  TriggerServerEvent("SPZ:vehicle:saveCustom", modelHash, preset, modelName)
end, false)
