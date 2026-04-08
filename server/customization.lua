-- Customization DB Logic
SPZ = SPZ or {}

SPZ.Notify = function(src, msg, type, time)
    TriggerClientEvent("spz-lib:Notify", src, msg, type, time)
end

RegisterNetEvent("SPZ:vehicle:saveCustom", function(modelHash, preset)
  local src     = source
  local profile = exports["spz-identity"]:GetProfile(src)
  
  if not profile then return end

  local modelName = GetDisplayNameFromVehicleModel(modelHash):lower()

  if not exports["spz-vehicles"]:IsRegistered(modelName) then
    SPZ.Notify(src, "Cannot save — unknown vehicle", "error", 3000)
    return
  end

  exports.oxmysql:execute(
    [[INSERT INTO vehicle_customizations (player_id, model, preset)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE preset = VALUES(preset), updated_at = NOW()]],
    { profile.id, modelName, json.encode(preset) }
  )

  SPZ.Notify(src, "Look saved for " .. modelName, "success", 3000)
end)

--- Loads saved customization preset for a player and model
--- @param playerId number (DB ID)
--- @param model string
--- @return table | nil
function LoadCustomization(playerId, model)
    local result = exports.oxmysql:scalarSync(
        "SELECT preset FROM vehicle_customizations WHERE player_id = ? AND model = ?",
        { playerId, model }
    )
    return result and json.decode(result) or nil
end

--- Resets (deletes) saved customization for a player and model
--- @param src number (Source)
--- @param model string
function ResetCustomization(src, model)
    local profile = exports["spz-identity"]:GetProfile(src)
    if not profile then return end

    exports.oxmysql:execute(
        "DELETE FROM vehicle_customizations WHERE player_id = ? AND model = ?",
        { profile.id, model:lower() }
    )
end

exports("LoadCustomization", LoadCustomization)
exports("ResetCustomization", ResetCustomization)

RegisterCommand("resetcustom", function(source, args)
  local model = args[1]
  if not model then
    SPZ.Notify(source, "Usage: /resetcustom [model]", "info", 3000)
    return
  end
  ResetCustomization(source, model)
  SPZ.Notify(source, "Look reset for " .. model, "info", 3000)
end, false)
