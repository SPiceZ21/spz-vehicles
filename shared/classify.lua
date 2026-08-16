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
    }
end

-- Poll weight from tier: keep lower classes a touch more common.
function SPZ.ClassPollWeight(class)
    local w = { [0] = 10, [1] = 8, [2] = 6, [3] = 4 }
    return w[class] or 6
end
