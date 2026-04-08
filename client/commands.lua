-- Client Commands
SPZ = SPZ or {}

function SPZ.Notify(msg, type, time)
    TriggerEvent("spz-lib:Notify", msg, type, time)
end

RegisterCommand("savecustom", function()
  local playerPed = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(playerPed, false)

  if vehicle == 0 then
    SPZ.Notify("Get in a vehicle first", "error", 3000)
    return
  end

  local preset = SPZ.CaptureVisuals(vehicle)
  local modelHash = GetEntityModel(vehicle)
  TriggerServerEvent("SPZ:vehicle:saveCustom", modelHash, preset)
end, false)
