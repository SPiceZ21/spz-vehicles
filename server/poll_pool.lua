-- Poll Pool Logic
--
-- Every selector here skips models a client has reported it cannot load
-- (server/validate.lua). A poll must only ever offer cars the field can
-- actually spawn — a winning car nobody can load cancels the race.

local function Eligible(name, data, class)
    return data.class == class and data.race and not IsModelUnavailable(name)
end

--- Add-ons before vanilla?  See Config.Addons.Prioritize.
local function prioritize()
    local c = (Config and Config.Addons) or {}
    return c.Prioritize ~= false
end

--- Weighted draw of up to `count` distinct entries from `list`, removing each
--- pick so nothing is offered twice. Weight 10 is twice as likely as weight 5.
local function weightedDraw(list, count, out)
    local total = 0
    for _, d in ipairs(list) do total = total + d.poll_weight end

    while count > 0 and #list > 0 do
        local rnd, acc = math.random() * total, 0
        for i, d in ipairs(list) do
            acc = acc + d.poll_weight
            if rnd <= acc then
                out[#out + 1] = { model = d.model, label = d.label, class = d.class }
                total = total - d.poll_weight
                table.remove(list, i)
                count = count - 1
                break
            end
        end
    end
    return count
end

--- Returns up to N distinct race-eligible vehicles from a class.
---
--- TIERED when Config.Addons.Prioritize is on (the default): every slot is
--- filled from the class's ADD-ON cars first, and vanilla cars only fill what
--- is left. Within each tier the draw is still weighted by poll_weight, so a
--- pack of several add-ons still rotates rather than always offering the same
--- one. With Prioritize off, both tiers share one weighted pool and add-ons
--- just carry Config.Addons.PollBoost — the previous behaviour.
---
--- Add-ons only reach this at all once server/classify.lua has probed them
--- (they register race=false until then), so an unclassified car can never be
--- prioritised into the wrong class.
--- @param class number
--- @param count number
--- @return table
function GetPollPool(class, count)
    local addons, vanilla = {}, {}

    for name, data in pairs(SPZ.VehicleRegistry) do
        if Eligible(name, data, class) then
            local e = {
                model       = data.model,
                label       = data.label,
                class       = data.class,
                poll_weight = data.poll_weight or 10,
            }
            if data.isAddon and prioritize() then
                addons[#addons + 1] = e
            else
                vanilla[#vanilla + 1] = e
            end
        end
    end

    local pool = {}
    local left = weightedDraw(addons, count, pool)
    weightedDraw(vanilla, left, pool)
    return pool
end

--- Class ids that currently have at least one race-eligible add-on.
--- spz-races/server/poll.lua uses this to put those classes first when it
--- picks which classes the poll offers — without it, add-on priority inside a
--- class would do nothing whenever the shuffle happened to pick two classes
--- the pack has no cars in.
function GetAddonRaceClasses()
    local set = {}
    if not prioritize() then return set end
    for name, data in pairs(SPZ.VehicleRegistry) do
        if data.isAddon and data.race and data.class and not IsModelUnavailable(name) then
            set[data.class] = true
        end
    end
    return set
end

exports("GetAddonRaceClasses", GetAddonRaceClasses)

exports("GetPollPool", GetPollPool)

--- Returns all race-eligible vehicles for a specific class
--- @param class number
--- @return table
function GetAllPollOptions(class)
    local results = {}
    for name, data in pairs(SPZ.VehicleRegistry) do
        if Eligible(name, data, class) then
            table.insert(results, {
                model = data.model,
                label = data.label,
                class = data.class
            })
        end
    end
    return results
end

exports("GetAllPollOptions", GetAllPollOptions)

--- Returns a list of class IDs that have at least one race-eligible vehicle
--- @return table  e.g. {0, 1, 2, 3}
function GetRaceClasses()
    local seen = {}
    local classes = {}
    for name, data in pairs(SPZ.VehicleRegistry) do
        if data.race and data.class and not seen[data.class] and not IsModelUnavailable(name) then
            seen[data.class] = true
            table.insert(classes, data.class)
        end
    end
    return classes
end

exports("GetRaceClasses", GetRaceClasses)
