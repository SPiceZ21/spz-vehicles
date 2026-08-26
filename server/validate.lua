-- server/validate.lua
-- Keeps unloadable vehicle models out of races.
--
-- A model name in data/vehicles.lua that no client can actually stream (a typo,
-- an addon car that is not installed, a DLC the server does not have) used to be
-- invisible until it won a vehicle poll — at which point the winning car could
-- not be pre-loaded, nobody spawned, and the whole race cancelled after the 30 s
-- spawn timeout, with everyone already teleported to the grid.
--
-- The registry is server-side, so the server cannot check a model itself: only a
-- game client can say whether a model exists. Each client validates the list
-- once shortly after joining and reports back what it cannot load. Anything
-- reported is marked unavailable and dropped from poll pools and spawns, and
-- named once in the console so it can be fixed at the source.
--
-- Reported by ANY client is enough to disable a model: a race needs every
-- participant to load the winning car, so one player missing it is already a
-- broken race.

SPZ = SPZ or {}
SPZ.UnavailableModels = SPZ.UnavailableModels or {}

local reported = {}   -- [model] = true once printed, so one bad name = one line

--- True when a model is known to be unloadable on at least one client.
function IsModelUnavailable(model)
    if not model then return false end
    return SPZ.UnavailableModels[tostring(model):lower()] == true
end
exports("IsModelUnavailable", IsModelUnavailable)

--- A registered, race-eligible model that clients can actually load. Used as the
--- spawn fallback: the configured one is preferred, but a fallback that is
--- itself missing (or missing from the registry) is worse than useless — it
--- fails silently and cancels the race.
function ResolveFallbackModel()
    local configured = Config and Config.FallbackVehicleModel
    if configured and SPZ.VehicleRegistry[configured] and not IsModelUnavailable(configured) then
        return configured
    end

    for name, data in pairs(SPZ.VehicleRegistry) do
        if data.race and not IsModelUnavailable(name) then return name end
    end
    return configured   -- registry empty/all broken: nothing better to offer
end
exports("ResolveFallbackModel", ResolveFallbackModel)

-- ── Client round trip ────────────────────────────────────────────────────────

RegisterNetEvent("SPZ:vehicle:requestValidation", function()
    local src = source
    local list = {}
    for name, data in pairs(SPZ.VehicleRegistry) do
        -- Dynamically registered models came FROM a client, so they are known
        -- good; only the authored registry needs checking.
        if not data.isDynamic then list[#list + 1] = name end
    end
    if #list == 0 then return end
    TriggerClientEvent("SPZ:vehicle:validateModels", src, list)
end)

RegisterNetEvent("SPZ:vehicle:invalidModels", function(list)
    if type(list) ~= "table" then return end

    local fresh = {}
    for _, model in ipairs(list) do
        if type(model) == "string" then
            local key = model:lower()
            SPZ.UnavailableModels[key] = true
            if not reported[key] then
                reported[key] = true
                fresh[#fresh + 1] = model
            end
        end
    end

    if #fresh > 0 then
        print(("^1[spz-vehicles] %d model(s) cannot be loaded by clients and are now excluded from races: %s^7")
            :format(#fresh, table.concat(fresh, ", ")))
        print("^1[spz-vehicles] Fix the spawn names in data/vehicles.lua, or install the addon cars they refer to.^7")
    end
end)

-- Console check on demand, e.g. after editing the registry.
RegisterCommand("vehcheck", function(source)
    if source ~= 0 then return end   -- server console only
    local total, bad = 0, 0
    for name in pairs(SPZ.VehicleRegistry) do
        total = total + 1
        if IsModelUnavailable(name) then bad = bad + 1 end
    end
    print(("[spz-vehicles] registry: %d model(s), %d unavailable"):format(total, bad))
    for name in pairs(SPZ.UnavailableModels) do print("  unavailable: " .. name) end
end, true)
