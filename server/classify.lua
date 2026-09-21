-- server/classify.lua
-- Dynamic vehicle classification. Performance natives are client-only, so we ask
-- a connected client to probe models, then convert the raw numbers into a class
-- tier + display stats via SPZ.ClassifyStats. Results are cached to a JSON file
-- so a model is only ever probed once.
--
-- Curation stays in data/vehicles.lua (which cars exist / race / freeroam);
-- CLASS + STATS are computed here so they always match real performance.

local CACHE_FILE = "classify_cache.json"
local CACHE_SCHEMA = 2
local Cache      = {}      -- [model] = { class, top_speed, accel, braking, handling, perf }
local pending    = {}      -- [model] = GetGameTimer() when the probe was sent
local PENDING_TTL = 120000 -- a probe unanswered this long is asked again: the
                           -- client drops models it could not load and may
                           -- disconnect mid-batch, so "pending" must expire
local PROBE_BATCH_SIZE = 20 -- never make one slow streamed car hold up the pack
local dirty      = false

-- Actual road-car GTA classes. Performance numbers alone make a tanker look
-- like a slow Class C car, which is why it leaked into the race poll.
local RACE_VEHICLE_CLASSES = {
    [0] = true, [1] = true, [2] = true, [3] = true, [4] = true,
    [5] = true, [6] = true, [7] = true, [9] = true, [12] = true,
    [22] = true,
}

-- ── Cache load/save ──────────────────────────────────────────────────────────
local function loadCache()
    local raw = LoadResourceFile(GetCurrentResourceName(), CACHE_FILE)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == "table" then
        Cache = data
        -- Old cache rows had no GTA vehicle class. Re-probe once so trucks,
        -- trailers and aircraft can be removed from every add-on pool.
        if Cache._schema ~= CACHE_SCHEMA then
            Cache = { _schema = CACHE_SCHEMA }
            dirty = true
        end
    end
end

local function saveCache()
    if not dirty then return end
    dirty = false
    SaveResourceFile(GetCurrentResourceName(), CACHE_FILE, json.encode(Cache), -1)
end

-- Apply a computed result onto the live registry entry.
local function applyToRegistry(model, stats)
    local entry = SPZ.VehicleRegistry and SPZ.VehicleRegistry[model]
    if not entry then return end

    if entry.isAddon and stats.vehicleClass ~= nil and not RACE_VEHICLE_CLASSES[stats.vehicleClass] then
        entry.race = false
        entry.racePending = nil
        print(("^3[spz-vehicles] add-on '%s' ignored: GTA vehicle class %d is not raceable.^7")
            :format(model, stats.vehicleClass))
        return
    end
    entry.class       = stats.class
    entry.top_speed   = stats.top_speed
    entry.accel       = stats.accel
    entry.braking     = stats.braking
    entry.handling    = stats.handling
    entry.poll_weight = SPZ.PollWeightFor(entry, stats.class)
    entry.autoClass   = true

    entry.vehicleClass = stats.vehicleClass

    -- A discovered add-on is held out of the race poll until this point, so it
    -- can never be offered in the wrong class with placeholder stats. Now that
    -- the class and the numbers on its card are real, decide.
    if entry.racePending then
        entry.racePending = nil

        if SPZ.IsRaceVehicleClass(stats.vehicleClass) then
            entry.race = true
            print(("[spz-vehicles] add-on '%s' classified -> class %d, now in the poll.")
                :format(model, stats.class))
        else
            -- Spawnable in freeroam, never offered in a race: a van, a tow
            -- truck, a boat or — the common case in a car pack — a police
            -- interceptor, which is fast enough to win the top class outright.
            entry.race = false
            print(("[spz-vehicles] add-on '%s' is GTA class %d — freeroam only, kept out of the poll.")
                :format(model, stats.vehicleClass))
        end
    end
end

-- ── Probing ──────────────────────────────────────────────────────────────────
local function anyClient()
    local players = GetPlayers()
    return players[1] and tonumber(players[1]) or nil
end

-- Ask a client for every model we don't have cached yet.
local function requestMissing()
    if not SPZ.VehicleRegistry then return end
    local src = anyClient()
    if not src then return end            -- nobody online; retry later

    local now, todo = GetGameTimer(), {}
    local function collect(addonsOnly)
        for model, entry in pairs(SPZ.VehicleRegistry) do
            local sent = pending[model]
            if (not addonsOnly or entry.isAddon) and not Cache[model]
                and (not sent or now - sent > PENDING_TTL) then
                pending[model] = now
                todo[#todo + 1] = model
                if #todo >= PROBE_BATCH_SIZE then return true end
            end
        end
        return false
    end

    -- Pack cars get their real stats first, so they become poll-ready before
    -- the much larger curated/base-game registry finishes its background pass.
    if not collect(true) then collect(false) end
    if #todo == 0 then return end

    print(("[spz-vehicles] Classifying %d vehicle(s) from real performance…"):format(#todo))
    TriggerClientEvent("SPZ:vehicle:probeModels", src, todo)
end

RegisterNetEvent("SPZ:vehicle:probeResult", function(results)
    if type(results) ~= "table" then return end
    local n = 0
    for model, raw in pairs(results) do
        pending[model] = nil
        if type(raw) == "table" then
            local stats = SPZ.ClassifyStats(raw)
            stats.vehicleClass = raw.vehicleClass
            Cache[model] = stats
            applyToRegistry(model, stats)
            dirty = true
            n = n + 1
        end
    end
    if n > 0 then
        print(("[spz-vehicles] Classified %d vehicle(s)."):format(n))
        saveCache()
    end

    -- Continue automatically until every newly discovered model is cached.
    -- The old implementation sent the entire registry in one request; a single
    -- streamed model timing out kept the response from reaching later add-ons.
    SetTimeout(100, requestMissing)
end)

-- ── Boot ─────────────────────────────────────────────────────────────────────
AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    loadCache()
    -- Apply whatever we already know immediately.
    for model, stats in pairs(Cache) do applyToRegistry(model, stats) end
    saveCache()
end)

-- Probe when someone joins (first client online triggers the initial sweep) and
-- periodically, so newly added models get picked up without a restart.
AddEventHandler("playerJoining", function()
    SetTimeout(15000, requestMissing)
end)

CreateThread(function()
    while true do
        Wait(300000)   -- every 5 min
        requestMissing()
        saveCache()
    end
end)

-- Force a re-classification of everything (admin/debug).
RegisterCommand("reclassify", function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, "spz.admin") then return end
    Cache = {}
    pending = {}
    dirty = true
    saveCache()
    requestMissing()
    print("[spz-vehicles] Re-classification requested.")
end, false)

exports("GetClassification", function(model) return Cache[model] end)

-- For server/addons.lua. Add-ons are registered ~2 s AFTER the boot pass above
-- has applied the cache, so without this a pack car classified on an earlier
-- boot would be registered as unclassified, skipped by requestMissing (it IS
-- cached) and never enter the poll again.
SPZ.ApplyCachedClass = function(model)
    local stats = Cache[model]
    if stats then applyToRegistry(model, stats) return true end
    return false
end

-- Probe newly registered models now instead of at the next 5-minute sweep.
SPZ.RequestClassification = requestMissing
