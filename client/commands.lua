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
  TriggerServerEvent("SPZ:vehicle:saveCustom", modelHash, preset)
end, false)
