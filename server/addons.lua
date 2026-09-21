-- server/addons.lua
-- Discover add-on car packs and put them in the registry.
--
-- THE GAP THIS FILLS
--
-- data/vehicles.lua is the curated base-game roster. An add-on pack is a
-- separate resource shipping its own vehicles.meta, and nothing here knew those
-- models existed.
--
-- server/registry.lua does have a dynamic-registration fallback, but it is
-- LAZY: it fires inside GetVehicleData(model), so a model only enters the
-- registry once something asks for it BY NAME. The poll does the opposite — it
-- iterates SPZ.VehicleRegistry looking for candidates (server/poll_pool.lua) —
-- so a pack nobody had already driven could never be offered, and therefore
-- could never be driven. Cars added to the server simply never appeared.
--
-- This walks the other way round: read what each resource DECLARES it ships,
-- and register it up front.
--
-- WHAT HAPPENS AFTER DISCOVERY IS NOT THIS FILE'S JOB
--
-- Everything downstream already works and is deliberately not duplicated here:
--
--   server/classify.lua   probes each new model's REAL performance on a client
--                         and assigns the class and display stats. It sweeps
--                         every uncached model in the registry, so a car
--                         registered here is picked up with no extra wiring —
--                         15s after the next player joins, or within 5 minutes.
--   server/validate.lua   drops any model a client reports it cannot load, so a
--                         broken or half-streamed pack cannot win a poll and
--                         cancel the race.
--   shared/classify.lua   SPZ.PollWeightFor applies Config.Addons.PollBoost.
--
-- So the only thing invented here is the model list.

local DISCOVERED = {}    -- model -> resource that ships it
local scanned    = false

local function cfg()
    return (Config and Config.Addons) or {}
end

-- ── Exclusions ───────────────────────────────────────────────────────────────

local function matchesAny(text, patterns)
    local low = text:lower()
    for _, pat in ipairs(patterns or {}) do
        -- pcall because these are user-supplied patterns and a malformed one
        -- should skip that rule, not take the whole scan down.
        local ok, hit = pcall(string.match, low, pat:lower())
        if ok and hit then return true end
    end
    return false
end

local function excluded(model)
    return matchesAny(model, cfg().Exclude)
end

--- Whole resources to skip. A pack usually splits its emergency vehicles into
--- their own resource (gb_vehicles_pd_ems), which is cheaper and more reliable
--- to exclude by name than to catch car by car. The GTA class check in
--- server/classify.lua is the backstop for anything that slips through.
local function excludedResource(res)
    return matchesAny(res, cfg().ExcludeResources)
end

-- ── Reading vehicles.meta ────────────────────────────────────────────────────

--- Model names in one vehicles.meta, filtered by declared <type>.
---
--- The model name is pulled with a pattern rather than a parser: vehicles.meta
--- nests <Item> elements several levels deep (doors, mods, seats), so matching
--- blocks is more fragile than matching the one tag that is unique per vehicle.
---
--- The declared <type> is paired to it by POSITION — the first one after this
--- model name and before the next — which filters out the bikes, boats and
--- helicopters a pack may ship alongside its cars. An entry with no <type> is
--- kept; validate.lua drops anything that will not actually load.
local function extractModels(raw, out)
    local names, types = {}, {}
    for pos, model in raw:gmatch("()<modelName>%s*([%w_%-]+)%s*</modelName>") do
        names[#names + 1] = { pos = pos, model = model:lower() }
    end
    for pos, t in raw:gmatch("()<type>%s*(VEHICLE_TYPE_%u+)%s*</type>") do
        types[#types + 1] = { pos = pos, t = t }
    end

    local allow = cfg().AllowTypes or { VEHICLE_TYPE_CAR = true }
    for i, entry in ipairs(names) do
        local stop = names[i + 1] and names[i + 1].pos or (#raw + 1)
        local declared
        for _, ty in ipairs(types) do
            if ty.pos > entry.pos and ty.pos < stop then declared = ty.t break end
        end
        if declared == nil or allow[declared] then
            out[#out + 1] = entry.model
        end
    end
end

-- ── Wildcard paths ───────────────────────────────────────────────────────────
--
-- Multi-car packs almost always declare their meta with a wildcard:
--
--     data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles.meta'
--
-- The first version of this file skipped those with a warning, because
-- LoadResourceFile cannot list a directory — which meant a typical car pack was
-- discovered as ZERO cars and the poll quietly stayed on base-game vehicles.
--
-- So the pattern is resolved against the resource's real files on disk: list
-- everything under GetResourcePath(res) once, and match the glob against the
-- relative paths. `**` spans directories, `*` stays inside one.
--
-- A false positive here is harmless — a matched file that is not a
-- vehicles.meta has no <modelName> tags and contributes nothing — so the glob
-- translation errs on the side of matching.

--- Every file under a resource, as forward-slash paths relative to its root.
--- nil when the listing is not possible on this host.
local function listFiles(res)
    local rawRoot = GetResourcePath(res)
    if not rawRoot or rawRoot == "" then return nil end

    -- package.config is nil in the FXServer sandbox. The resource path itself
    -- is authoritative: Windows paths contain backslashes; Linux paths do not.
    local isWindows = rawRoot:find("\\", 1, true) ~= nil
    local root = rawRoot
    root = root:gsub("\\", "/"):gsub("/+$", "")

    local cmd = isWindows
        and ('dir /s /b /a-d "' .. root:gsub("/", "\\") .. '" 2>nul')
        or  ('find "' .. root .. '" -type f 2>/dev/null')

    local ok, handle = pcall(io.popen, cmd)
    if not ok or not handle then return nil end

    local files = {}
    local prefix = root:lower() .. "/"
    for line in handle:lines() do
        local path = line:gsub("\r", ""):gsub("\\", "/")
        if path:lower():sub(1, #prefix) == prefix then
            files[#files + 1] = path:sub(#prefix + 1)
        end
    end
    handle:close()
    return files
end

--- Glob -> anchored Lua pattern.  ** = anything (including /), * = anything
--- but /, ? = one char but /.
local function globToPattern(glob)
    glob = glob:gsub("\\", "/"):gsub("^%./", "")
    local out, i = { "^" }, 1
    while i <= #glob do
        local c = glob:sub(i, i)
        if c == "*" then
            if glob:sub(i + 1, i + 1) == "*" then
                out[#out + 1] = ".-"
                i = i + 2
                if glob:sub(i, i) == "/" then i = i + 1 end   -- "**/" may match no dirs
            else
                out[#out + 1] = "[^/]*"
                i = i + 1
            end
        elseif c == "?" then
            out[#out + 1] = "[^/]"
            i = i + 1
        elseif c:match("[%^%$%(%)%%%.%[%]%+%-]") then
            out[#out + 1] = "%" .. c
            i = i + 1
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    out[#out + 1] = "$"
    return table.concat(out):lower()
end

--- The path half of a data_file entry. The server stores it JSON-encoded
--- (`"data/vehicles.meta"`, quotes included), so a raw LoadResourceFile on it
--- finds nothing. Decode when it looks encoded; pass it through otherwise.
local function metaPath(extra)
    if type(extra) ~= "string" or extra == "" then return nil end
    local first = extra:sub(1, 1)
    if first == '"' or first == "[" or first == "{" then
        local ok, v = pcall(json.decode, extra)
        if ok then
            if type(v) == "string" then return v end
            if type(v) == "table" and type(v[1]) == "string" then return v[1] end
        end
        return (extra:gsub('^"(.*)"$', "%1"))
    end
    return extra
end

--- Models from a spawn-name list shipped at a FIXED path in the resource root.
---
--- Gabz packs (and several others built from the same template) ship
--- `vehicle_spawn_names.txt`, one model name per line. That is worth reading
--- first: it needs no wildcard expansion and no directory listing, so it works
--- on hosts where io.popen is unavailable — which is exactly where the meta
--- scan gives up.
---
--- It carries no <type>, so bikes and boats in a mixed pack are not filtered
--- here. The GTA class check after the performance probe is what keeps those
--- out of races.
local SPAWN_NAME_FILES = { "vehicle_spawn_names.txt", "vehicle_names.txt" }

local function modelsFromSpawnList(res, out)
    for _, file in ipairs(SPAWN_NAME_FILES) do
        local raw = LoadResourceFile(res, file)
        if raw then
            local n = 0
            for line in raw:gmatch("[^\r\n]+") do
                local model = line:match("^%s*([%w_%-]+)%s*$")
                if model then
                    out[#out + 1] = model:lower()
                    n = n + 1
                end
            end
            if n > 0 then return file, n end
        end
    end
    return nil, 0
end

--- Model names declared by one resource, plus a note on anything that could
--- not be read, for the scan log.
---
--- `data_file 'VEHICLE_METADATA_FILE' 'path'` is stored as a pair: the TYPE
--- under `data_file` and the PATH under `data_file_extra` at the same index.
local function modelsIn(res)
    local out, notes = {}, {}
    local n = GetNumResourceMetadata(res, "data_file") or 0
    local listing   -- fetched once per resource, only if a wildcard needs it

    for i = 0, n - 1 do
        if GetResourceMetadata(res, "data_file", i) == "VEHICLE_METADATA_FILE" then
            local path = metaPath(GetResourceMetadata(res, "data_file_extra", i))

            if path and path:find("[%*%?]") then
                if listing == nil then listing = listFiles(res) or false end
                if not listing then
                    notes[#notes + 1] = ("'%s' is a wildcard and this host cannot list files"):format(path)
                else
                    local pat, hits = globToPattern(path), 0
                    for _, rel in ipairs(listing) do
                        if rel:lower():match(pat) then
                            local raw = LoadResourceFile(res, rel)
                            if raw then extractModels(raw, out); hits = hits + 1 end
                        end
                    end
                    if hits == 0 then
                        notes[#notes + 1] = ("'%s' matched no files"):format(path)
                    end
                end
            elseif path then
                local raw = LoadResourceFile(res, path)
                if raw then
                    extractModels(raw, out)
                else
                    notes[#notes + 1] = ("'%s' could not be read"):format(path)
                end
            end
        end
    end

    -- Nothing from the manifest: fall back to the pack's own spawn-name list.
    -- This is the path that actually carries a Gabz pack on a hosted server,
    -- where its 'data/**/vehicles.meta' cannot be expanded.
    if #out == 0 then
        local file, n = modelsFromSpawnList(res, out)
        if file then
            notes[#notes + 1] = ("read %d model(s) from %s (manifest wildcard unreadable)")
                :format(n, file)
        end
    end

    return out, notes
end

-- ── Registration ─────────────────────────────────────────────────────────────

local function prettyLabel(model)
    -- The real display name lives in a GXT entry this cannot read, so the model
    -- name is tidied instead: "vulkanus_gt" -> "Vulkanus Gt". Better than the
    -- raw string in a poll card, and honest about being derived.
    return (model:gsub("[_%-]+", " "):gsub("(%a)([%w]*)", function(a, b)
        return a:upper() .. b
    end))
end

local function register(model, res)
    if SPZ.VehicleRegistry[model] then return false end   -- curated entry wins
    if excluded(model) then return false end

    local c = cfg()
    local entry = {
        model     = model,
        label     = prettyLabel(model),

        -- Placeholders. server/classify.lua overwrites all of these from a real
        -- performance probe; they exist so the entry is well-formed in the
        -- window before that lands.
        class     = 0,
        top_speed = 180,
        handling  = 70,
        accel     = 70,
        braking   = 70,

        freeroam  = c.Freeroam ~= false,

        -- NOT race-eligible yet, on purpose.
        --
        -- `class` above is a placeholder until a client has probed the model,
        -- and until then every undiscovered add-on would sit in class 0 with
        -- invented stats. The poll picks one car per class and prints its
        -- numbers on the card, so offering them early means Class C polls
        -- dominated by add-ons advertising 180 km/h and 70 across the board —
        -- whatever the car actually is. server/classify.lua flips this on the
        -- moment it has real numbers.
        race      = false,
        racePending = c.Race ~= false,

        isDynamic = true,
        isAddon   = true,
        addonFrom = res,
    }
    entry.poll_weight = SPZ.PollWeightFor(entry, entry.class)

    SPZ.VehicleRegistry[model] = entry
    DISCOVERED[model] = res

    -- Classified on an earlier boot? Then it has real numbers already — apply
    -- them now and it is in the poll immediately (see server/classify.lua).
    if SPZ.ApplyCachedClass then SPZ.ApplyCachedClass(model) end
    return true
end

-- Keep the client-visible add-on set in one place. The car spawner reads this
-- state bag instead of attempting to call a server-only registry export.
local function publish()
    local set = {}
    for model, res in pairs(DISCOVERED) do set[model] = res end
    GlobalState.spzAddonModels = set
end

-- ── Scan ─────────────────────────────────────────────────────────────────────

local function scan(reason)
    if cfg().AutoDiscover == false then return 0, 0 end
    if not SPZ or not SPZ.VehicleRegistry then return 0, 0 end

    local added, seen, packs = 0, 0, {}

    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= GetCurrentResourceName() and GetResourceState(res) == "started"
           and not excludedResource(res) then
            local models, notes = modelsIn(res)
            for _, note in ipairs(notes) do
                print(("^3[spz-vehicles] add-ons: %s — %s^7"):format(res, note))
            end
            if #models > 0 then
                local fromThis = 0
                for _, model in ipairs(models) do
                    seen = seen + 1
                    if register(model, res) then
                        added = added + 1
                        fromThis = fromThis + 1
                    end
                end
                if fromThis > 0 then packs[#packs + 1] = ("%s (%d)"):format(res, fromThis) end
            end
        end
    end

    if added > 0 and SPZ.RequestClassification then
        -- Anything not in the cache gets probed by an online client now,
        -- rather than waiting for the next 5-minute sweep.
        SetTimeout(1000, SPZ.RequestClassification)
    end

    if added > 0 then
        print(("^2[spz-vehicles] add-ons: registered %d new vehicle(s) from %d declared — %s^7")
            :format(added, seen, table.concat(packs, ", ")))
        print("^2[spz-vehicles] ...classification will follow from a real performance probe; "
            .. "they enter the poll once classified.^7")
    elseif seen == 0 and reason ~= "hotload" then
        print("^3[spz-vehicles] add-ons: no VEHICLE_METADATA_FILE found in any started "
            .. "resource. Is the car pack ensured in server.cfg, and does its "
            .. "fxmanifest declare data_file 'VEHICLE_METADATA_FILE'?^7")
    elseif reason == "boot" and seen > 0 then
        print(("^2[spz-vehicles] add-ons: %d declared vehicle(s) already known.^7"):format(seen))
    end

    scanned = true

    -- Publish the set so CLIENTS can tell an add-on from a base-game car.
    -- spz-carspawner uses it to list add-ons in their own section and to let
    -- them past its race-class filter; before this it guessed from whether a
    -- car had a text label, which a properly packaged pack defeats.
    publish()

    return added, seen
end

-- ── Triggers ─────────────────────────────────────────────────────────────────
--
-- Boot, and again whenever ANY resource starts. The second one is what makes a
-- pack added to a running server work without restarting this one — and it is
-- also the ordering fix, since a car pack that starts after spz-vehicles would
-- otherwise have missed the only scan there was.

AddEventHandler("onResourceStart", function(res)
    if res == GetCurrentResourceName() then
        -- data/vehicles.lua is a server_script loaded before this one, so the
        -- registry exists by now; the small wait is for OTHER resources still
        -- coming up during a cold boot.
        SetTimeout(2000, function() scan("boot") end)
    elseif scanned then
        SetTimeout(500, function() scan("hotload") end)
    end
end)

-- ── Console ──────────────────────────────────────────────────────────────────

RegisterCommand("spzaddons", function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, "spz.admin") then return end

    local rows, n = {}, 0
    for model, res in pairs(DISCOVERED) do
        local e = SPZ.VehicleRegistry[model]
        n = n + 1
        rows[#rows + 1] = ("  %-24s class %-2s  weight %-4s %-10s %s")
            :format(model,
                    e and tostring(e.class) or "?",
                    e and tostring(e.poll_weight) or "?",
                    (e and e.race) and "in poll" or "^3unclassified^7",
                    res)
    end
    table.sort(rows)

    print("^5── discovered add-on vehicles ──────────────────────────────^7")
    if n == 0 then
        print("  none. Either no pack is running, Config.Addons.AutoDiscover is")
        print("  off, or the pack does not declare a VEHICLE_METADATA_FILE.")
    else
        print(table.concat(rows, "\n"))
    end
    print(("^5── %d discovered · boost x%.1f · race=%s ──────────────^7")
        :format(n, tonumber(cfg().PollBoost) or 1.0, tostring(cfg().Race ~= false)))
end, true)

-- Some car packs use a manifest wildcard that a hosted FXServer cannot expand,
-- or stream models without declaring vehicles.meta at all. A connected client
-- can see the streamed model list, so it supplies only models without a GTA
-- text label as a fallback. The cap and strict model-name check keep this from
-- becoming an unbounded registry write from a client event.
RegisterNetEvent("SPZ:vehicle:reportAddonModels", function(models)
    if type(models) ~= "table" then return end

    local added = 0
    local sourceName = ("client:%d"):format(source)
    for i = 1, math.min(#models, 400) do
        local model = models[i]
        if type(model) == "string" then
            model = model:lower()
            if #model <= 64 and model:match("^[%w_%-]+$") and register(model, sourceName) then
                added = added + 1
            end
        end
    end

    print(("^5[spz-vehicles] add-on client scan: %d candidate(s), %d new from player %d.^7")
        :format(math.min(#models, 400), added, source))

    if added > 0 then
        publish()
        print(("^2[spz-vehicles] add-ons: registered %d streamed vehicle(s) reported by player %d.^7")
            :format(added, source))
        if SPZ.RequestClassification then SetTimeout(1000, SPZ.RequestClassification) end
    end
end)

RegisterCommand("spzaddonscan", function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, "spz.admin") then return end
    local added, seen = scan("manual")
    print(("[spz-vehicles] rescan: %d new, %d declared."):format(added, seen))
end, true)

exports("GetDiscoveredAddons", function() return DISCOVERED end)
