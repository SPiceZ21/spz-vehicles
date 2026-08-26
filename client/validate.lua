-- client/validate.lua
-- Answers the server's "can you load these?" question about the vehicle
-- registry (see server/validate.lua). Only a game client can tell whether a
-- model name is real, so this is the one place that knows.
--
-- Runs once per session, a few seconds after joining so streaming/DLC metadata
-- has settled — checking too early reports base-game cars as missing.

CreateThread(function()
    Wait(8000)
    TriggerServerEvent("SPZ:vehicle:requestValidation")
end)

RegisterNetEvent("SPZ:vehicle:validateModels", function(list)
    if type(list) ~= "table" then return end

    local invalid = {}
    for i, name in ipairs(list) do
        local hash = GetHashKey(name)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
            invalid[#invalid + 1] = name
        end
        -- Yield periodically: the registry can be hundreds of entries and this
        -- must never cost a visible frame.
        if i % 40 == 0 then Wait(0) end
    end

    if #invalid > 0 then
        print(("^3[spz-vehicles]^7 %d registry model(s) missing on this client: %s")
            :format(#invalid, table.concat(invalid, ", ")))
    end
    TriggerServerEvent("SPZ:vehicle:invalidModels", invalid)
end)
