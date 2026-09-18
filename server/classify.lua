-- server/classify.lua
-- Dynamic vehicle classification. Performance natives are client-only, so we ask
-- a connected client to probe models, then convert the raw numbers into a class
-- tier + display stats via SPZ.ClassifyStats. Results are cached to a JSON file
-- so a model is only ever probed once.
--
-- Curation stays in data/vehicles.lua (which cars exist / race / freeroam);
-- CLASS + STATS are computed here so they always match real performance.

local CACHE_FILE = "classify_cache.json"
local Cache      = {}      -- [model] = { class, top_speed, accel, braking, handling, perf }
local pending    = {}      -- [model] = GetGameTimer() when the probe was sent
local PENDING_TTL = 120000 -- a probe unanswered this long is asked again: the
                           -- client drops models it could not load and may
                           -- disconnect mid-batch, so "pending" must expire
local dirty      = false

-- ── Cache load/save ──────────────────────────────────────────────────────────
local function loadCache()
    local raw = LoadResourceFile(GetCurrentResourceName(), CACHE_FILE)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == "table" then Cache = data end
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
    entry.class       = stats.class
    entry.top_speed   = stats.top_speed
    entry.accel       = stats.accel
    entry.braking     = stats.braking
    entry.handling    = stats.handling
    entry.poll_weight = SPZ.PollWeightFor(entry, stats.class)
    entry.autoClass   = true

    -- A discovered add-on is held out of the race poll until this point, so it
    -- can never be offered in the wrong class with placeholder stats. Now that
    -- the class and the numbers on its card are real, let it in.
    if entry.racePending then
        entry.race        = true
        entry.racePending = nil
        print(("[spz-vehicles] add-on '%s' classified -> class %d, now in the poll.")
            :format(model, stats.class))
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
    for model in pairs(SPZ.VehicleRegistry) do
        local sent = pending[model]
        if not Cache[model] and (not sent or now - sent > PENDING_TTL) then
            pending[model] = now
            todo[#todo + 1] = model
        end
    end
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
end)

-- ── Boot ─────────────────────────────────────────────────────────────────────
AddEventHandler("onResourceStart", function(res)
    if res ~= GetCurrentResourceName() then return end
    loadCache()
    -- Apply whatever we already know immediately.
    for model, stats in pairs(Cache) do applyToRegistry(model, stats) end
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
