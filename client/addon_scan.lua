-- Add-on discovery fallback.
--
-- Manifest scanning on the server is the preferred source, but some hosted
-- packs use wildcards or only stream assets. Once the player has loaded the
-- resources, FiveM exposes their vehicle model names here. GTA's own labels
-- resolve through the text database; an unknown label is a strong signal that
-- this is a custom streamed vehicle. Send those candidates once to the server.

local function reportStreamedAddons()
    local models = GetAllVehicleModels()
    if type(models) ~= "table" then return end

    local found, seen = {}, {}
    for _, rawModel in ipairs(models) do
        if type(rawModel) == "string" then
            local model = rawModel:lower()
            if not seen[model] then
                seen[model] = true
                local hash = GetHashKey(model)
                if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
                    local gxt = GetDisplayNameFromVehicleModel(hash)
                    local text = gxt and gxt ~= "" and GetLabelText(gxt) or "NULL"

                    -- ONLY an unresolved label counts.
                    --
                    -- The "GXT key equals the model name" test that used to be
                    -- here matches nearly every BASE-GAME car as well —
                    -- `adder`'s display name is the GXT key "ADDER" — so it
                    -- reported the whole vanilla roster as add-ons, which is
                    -- why everything turned up in Custom Mod Cars and the poll
                    -- weighting went sideways.
                    --
                    -- A pack that ships proper labels (Gabz does) is therefore
                    -- invisible to this scan by design. That is fine: the
                    -- server reads such packs straight from their files, and
                    -- this only has to catch packs that ship no labels at all.
                    if text == "NULL" then
                        found[#found + 1] = model
                    end
                end
            end
        end
    end

    TriggerServerEvent("SPZ:vehicle:reportAddonModels", found)
end

CreateThread(function()
    -- Wait for pack resources and text dictionaries to finish streaming.
    Wait(15000)
    reportStreamedAddons()

    -- A few large packs finish registering DLC assets after the initial join.
    -- Repeating is harmless: the server de-duplicates models and only probes
    -- entries that have no cached classification.
    Wait(30000)
    reportStreamedAddons()
end)
