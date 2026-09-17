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

local function excluded(model)
    local low = model:lower()
    for _, pat in ipairs(cfg().Exclude or {}) do
        -- pcall because these are user-supplied patterns and a malformed one
        -- should skip that rule, not take the whole scan down.
        local ok, hit = pcall(string.match, low, pat:lower())
        if ok and hit then return true end
    end
    return false
end

-- ── Reading vehicles.meta ────────────────────────────────────────────────────

--- Model names declared by one resource.
---
--- `data_file 'VEHICLE_METADATA_FILE' 'vehicles.meta'` is stored as a pair: the
--- TYPE under the `data_file` key and the PATH under `data_file_extra` at the
--- same index. Only VEHICLE_METADATA_FILE entries are read; a pack also ships
--- handling.meta, carcols.meta and so on, and none of those list models.
---
--- The model name is pulled with a pattern rather than a parser. That is a
--- deliberate limit, not an oversight: vehicles.meta nests <Item> elements
--- several levels deep (doors, mods, seats), so matching blocks is more fragile
--- than matching the one tag that is unique per vehicle and always present.
---
--- The declared <type> is paired to it by POSITION — the first one after this
--- model name and before the next. That is the order every stock-format
--- vehicles.meta uses, and it filters out the bikes, boats and helicopters a
--- pack may ship alongside its cars. Without it, "car pack" support quietly
--- means putting a boat in the race poll. An entry with no <type> at all is
--- kept: a malformed line should not silently vanish, and validate.lua drops
--- anything that will not actually load.
local function modelsIn(res)
    local out = {}
    local n = GetNumResourceMetadata(res, "data_file") or 0

    for i = 0, n - 1 do
        local kind = GetResourceMetadata(res, "data_file", i)
        if kind == "VEHICLE_METADATA_FILE" then
            local path = GetResourceMetadata(res, "data_file_extra", i)

            -- A wildcard path (data/*.meta) cannot be read back through
            -- LoadResourceFile — there is no directory listing available to a
            -- resource. Say so rather than silently finding nothing.
            if path and path:find("%*") then
                print(("^3[spz-vehicles] %s declares '%s' with a wildcard — "
                    .. "list the .meta files individually for auto-discovery to see them.^7")
                    :format(res, path))
            elseif path then
                local raw = LoadResourceFile(res, path)
                if raw then
                    -- Positions of every model name, then of every type, so the
                    -- two can be paired by document order.
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
                else
                    print(("^3[spz-vehicles] %s declares '%s' but it could not be read.^7")
                        :format(res, path))
                end
            end
        end
    end

    return out
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
    return true
end

-- ── Scan ─────────────────────────────────────────────────────────────────────

local function scan(reason)
    if cfg().AutoDiscover == false then return 0, 0 end
    if not SPZ or not SPZ.VehicleRegistry then return 0, 0 end

    local added, seen, packs = 0, 0, {}

    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= GetCurrentResourceName() and GetResourceState(res) == "started" then
            local models = modelsIn(res)
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

    if added > 0 then
        print(("^2[spz-vehicles] add-ons: registered %d new vehicle(s) from %d declared — %s^7")
            :format(added, seen, table.concat(packs, ", ")))
        print("^2[spz-vehicles] ...classification will follow from a real performance probe; "
            .. "they enter the poll once classified.^7")
    elseif reason == "boot" and seen > 0 then
        print(("^2[spz-vehicles] add-ons: %d declared vehicle(s) already known.^7"):format(seen))
    end

    scanned = true
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

RegisterCommand("spzaddonscan", function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, "spz.admin") then return end
    local added, seen = scan("manual")
    print(("[spz-vehicles] rescan: %d new, %d declared."):format(added, seen))
end, true)

exports("GetDiscoveredAddons", function() return DISCOVERED end)
