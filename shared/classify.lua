SPZ = SPZ or {}

-- Turns a vehicle's RAW model performance (read from game natives, client-side)
-- into a class tier (0=C … 3=S) plus 0–100 display stats + a km/h top speed.
-- Pure math + shared, so client computes and server trusts the same thresholds.
--
-- raw = { maxSpeed (m/s), accel (0..~0.45), braking (0.5..~1.5), traction (1.8..~2.7) }

local function clamp01to100(v) return math.max(0, math.min(100, v)) end
local function normalize(v, lo, hi) return clamp01to100((v - lo) / (hi - lo) * 100) end

function SPZ.ClassifyStats(raw)
    raw = raw or {}
    local kmh = (raw.maxSpeed or 0) * 3.6

    -- Empirical GTA V ranges → 0–100 scores.
    local sSpeed = normalize(kmh,            120.0, 220.0)
    local sAccel = normalize(raw.accel or 0,   0.10,   0.42)
    local sBrake = normalize(raw.braking or 0, 0.50,   1.40)
    local sTrac  = normalize(raw.traction or 0,1.80,   2.70)

    -- Weighted performance index (speed + accel dominate) → tier.
    local perf = sSpeed * 0.40 + sAccel * 0.30 + sBrake * 0.15 + sTrac * 0.15

    local class
    if     perf >= 78 then class = 3   -- S — Elite (super/exotic)
    elseif perf >= 60 then class = 2   -- A — Pro
    elseif perf >= 42 then class = 1   -- B — Sport
    else                    class = 0  -- C — Street
    end

    return {
        class       = class,
        top_speed   = math.floor(kmh + 0.5),
        accel       = math.floor(sAccel + 0.5),
        braking     = math.floor(sBrake + 0.5),
        handling    = math.floor((sTrac + sBrake) / 2 + 0.5),
        perf        = math.floor(perf + 0.5),

        -- GTA's own class for the model, carried through from the probe so the
        -- server can tell a race car from a tow truck. Cached with the rest, so
        -- an entry classified before this field existed simply has no value —
        -- see SPZ.IsRaceVehicleClass.
        vehicleClass = raw.vehicleClass,
    }
end

--- Whether a GTA vehicle class belongs in a race.
---
--- Performance alone cannot make this call: a fire truck and an ambulance can
--- both out-accelerate a hatchback, and a pack's police cars are usually its
--- FASTEST models — they are tuned pursuit versions. Judging on numbers alone
--- puts them straight into the top class of the poll.
---
--- Unknown (nil) is allowed through. Entries cached before the probe reported
--- this field have no value, and refusing those would silently empty the poll
--- until every car was re-probed.
local RACE_VEHICLE_CLASSES = {
    [0]  = true,  -- Compacts
    [1]  = true,  -- Sedans
    [2]  = true,  -- SUVs
    [3]  = true,  -- Coupes
    [4]  = true,  -- Muscle
    [5]  = true,  -- Sports Classics
    [6]  = true,  -- Sports
    [7]  = true,  -- Super
    [9]  = true,  -- Off-road
    [22] = true,  -- Open Wheel
}

function SPZ.IsRaceVehicleClass(vehicleClass)
    if vehicleClass == nil then return true end
    return RACE_VEHICLE_CLASSES[vehicleClass] == true
end

-- Poll weight from tier: keep lower classes a touch more common.
function SPZ.ClassPollWeight(class)
    local w = { [0] = 10, [1] = 8, [2] = 6, [3] = 4 }
    return w[class] or 6
end

--- The weight an entry should actually carry in the poll.
---
--- One place, because two computed it and they would have drifted:
--- server/classify.lua sets it whenever a probe lands, and server/addons.lua
--- has to set something sensible before any probe has happened.
---
--- `poll_weight_override` still wins outright — a hand-tuned number in
--- data/vehicles.lua is a decision, and the add-on boost is a default.
function SPZ.PollWeightFor(entry, class)
    if entry and entry.poll_weight_override then return entry.poll_weight_override end

    local w = SPZ.ClassPollWeight(class)
    local cfg = (Config and Config.Addons) or {}
    if entry and entry.isAddon then
        w = w * (tonumber(cfg.PollBoost) or 1.0)
    end
    return math.max(1, math.floor(w + 0.5))
end
