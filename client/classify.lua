-- client/classify.lua
-- The performance natives only exist client-side, so the server asks us to probe
-- a model: we load it, read its real handling values, and send them back. The
-- server converts them to a class + display stats (shared/classify.lua) and
-- caches the result, so every vehicle is classified from ACTUAL performance
-- instead of hand-written numbers.

local function probe(modelName)
    local hash = GetHashKey(modelName)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end

    RequestModel(hash)
    local deadline = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    if not HasModelLoaded(hash) then return nil end

    local raw = {
        maxSpeed = GetVehicleModelMaxSpeed(hash),      -- m/s
        accel    = GetVehicleModelAcceleration(hash),
        braking  = GetVehicleModelMaxBraking(hash),
        traction = GetVehicleModelMaxTraction(hash),
    }

    SetModelAsNoLongerNeeded(hash)
    return raw
end

-- Server requests a batch of models; we return raw stats for each.
RegisterNetEvent("SPZ:vehicle:probeModels", function(models)
    if type(models) ~= "table" then return end
    local out = {}
    for _, m in ipairs(models) do
        local raw = probe(m)
        if raw then out[m] = raw end
        Wait(0)   -- spread the model loads over frames
    end
    TriggerServerEvent("SPZ:vehicle:probeResult", out)
end)
