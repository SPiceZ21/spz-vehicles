-- Vehicle Registry Logic

-- Build hash→model reverse lookup once at resource start (O(1) lookups thereafter)
local _hashToModel = {}
AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for name in pairs(SPZ.VehicleRegistry) do
        _hashToModel[GetHashKey(name)] = name
    end
end)

--- Returns the full data object for a specific vehicle model
--- @param model string | number
--- @return table | nil
function GetVehicleData(model)
    if not model then return nil end

    local name = (type(model) == "number") and _hashToModel[model] or model
    if not name and type(model) == "string" then name = model end
    if not name then return nil end

    if not SPZ.VehicleRegistry[name] then
        -- Dynamic registration fallback for vanilla & add-on mod vehicles.
        -- Placeholder stats only: server/classify.lua probes the model's REAL
        -- performance and overwrites class/stats as soon as a client reports in
        -- (cached, so it happens once per model).
        local hash = type(model) == "number" and model or GetHashKey(name)
        local okc, cached = pcall(function()
            return exports[GetCurrentResourceName()]:GetClassification(name)
        end)
        cached = okc and cached or nil
        SPZ.VehicleRegistry[name] = {
            model       = name,
            label       = name:sub(1,1):upper() .. name:sub(2),
            class       = cached and cached.class     or 0,
            top_speed   = cached and cached.top_speed or 180,
            handling    = cached and cached.handling  or 70,
            accel       = cached and cached.accel     or 70,
            braking     = cached and cached.braking   or 70,
            poll_weight = SPZ.ClassPollWeight and SPZ.ClassPollWeight(cached and cached.class or 0) or 5,
            freeroam    = true,
            race        = true,
            isDynamic   = true,
            autoClass   = cached ~= nil,
        }
        _hashToModel[hash] = name
    end

    return SPZ.VehicleRegistry[name]
end

--- Returns a list of vehicles belonging to a specific class with optional filtering
--- @param class number
--- @param filters table | nil { race = bool, freeroam = bool }
--- @return table
function GetClassVehicles(class, filters)
    local results = {}
    for _, data in pairs(SPZ.VehicleRegistry) do
        if data.class == class then
            local match = true
            
            if filters then
                for key, value in pairs(filters) do
                    if data[key] ~= value then
                        match = false
                        break
                    end
                end
            end

            if match then
                table.insert(results, data)
            end
        end
    end
    return results
end

--- Checks if a vehicle model is registered
--- @param model string | number
--- @return boolean
function IsRegistered(model)
    return GetVehicleData(model) ~= nil
end

--- Returns metadata for a specific vehicle class
--- @param class number
--- @return table | nil
function GetClassMeta(class)
    return SPZ.ClassMeta[class]
end

--- Returns all distinct class IDs that have at least one race-eligible vehicle
--- @return table
function GetRaceClasses()
    local seen = {}
    local classes = {}
    for _, data in pairs(SPZ.VehicleRegistry) do
        if data.race and data.class and not seen[data.class] then
            seen[data.class] = true
            table.insert(classes, data.class)
        end
    end
    return classes
end

--- Returns the entire vehicle registry
--- @return table
function GetVehicleRegistry()
    return SPZ.VehicleRegistry
end

exports("GetVehicleData", GetVehicleData)
exports("GetClassVehicles", GetClassVehicles)
exports("IsRegistered", IsRegistered)
exports("GetClassMeta", GetClassMeta)
exports("GetRaceClasses", GetRaceClasses)
exports("GetVehicleRegistry", GetVehicleRegistry)

-- Physics integration removed. Relying on static classes from vehicles.lua
