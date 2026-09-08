-- Customization DB Logic
SPZ = SPZ or {}

SPZ.Notify = function(src, msg, ntype, time)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = ntype, duration = time, position = "center-left" })
end

RegisterNetEvent("SPZ:vehicle:saveCustom", function(modelHash, preset, clientName)
  local src     = source
  local profile = exports["spz-identity"]:GetProfile(src)

  if not profile then return end

  -- GetDisplayNameFromVehicleModel is CLIENT ONLY. Calling it here was a nil
  -- global and killed the handler outright, so no custom look could be saved.
  --
  -- The registry resolves a hash for anything it knows (it keeps its own
  -- hash to name table), and the client sends the display name as well for the
  -- cars it does not — vanilla and add-on models, which the registry's dynamic
  -- registration is there to take on.
  local data = exports["spz-vehicles"]:GetVehicleData(modelHash)

  if not data and type(clientName) == "string" and clientName ~= "" then
    data = exports["spz-vehicles"]:GetVehicleData(clientName:lower())
  end

  if not data or not data.model then
    SPZ.Notify(src, "Cannot save — unknown vehicle", "error", 3000)
    return
  end

  local modelName = tostring(data.model):lower()

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
    -- await (not Sync): sync variants block the whole server thread
    local result = MySQL.scalar.await(
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
