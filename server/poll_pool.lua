-- Poll Pool Logic

--- Returns N distinct race-eligible vehicles from a class using weighted random selection
--- @param class number
--- @param count number
--- @return table
function GetPollPool(class, count)
    local eligible = {}
    local totalWeight = 0
    
    -- 1. Filter race-eligible vehicles for the class
    for name, data in pairs(SPZ.VehicleRegistry) do
        if data.class == class and data.race then
            -- Create a local copy to avoid modifying registry
            table.insert(eligible, {
                model = data.model,
                label = data.label,
                class = data.class,
                poll_weight = data.poll_weight or 10
            })
            totalWeight = totalWeight + (data.poll_weight or 10)
        end
    end

    local pool = {}
    local remainingCount = count
    
    -- 2. Weighted selection without replacement
    -- Weight 10 is twice as likely as weight 5
    while remainingCount > 0 and #eligible > 0 do
        local rnd = math.random() * totalWeight
        local currentWeight = 0
        
        for i, data in ipairs(eligible) do
            currentWeight = currentWeight + data.poll_weight
            if rnd <= currentWeight then
                table.insert(pool, {
                    model = data.model,
                    label = data.label,
                    class = data.class
                })
                
                -- Subtract selected weight and remove to ensure distinctness
                totalWeight = totalWeight - data.poll_weight
                table.remove(eligible, i)
                remainingCount = remainingCount - 1
                break
            end
        end
    end

    return pool
end

exports("GetPollPool", GetPollPool)

--- Returns all race-eligible vehicles for a specific class
--- @param class number
--- @return table
function GetAllPollOptions(class)
    local results = {}
    for _, data in pairs(SPZ.VehicleRegistry) do
        if data.class == class and data.race then
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
