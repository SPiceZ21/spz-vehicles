-- Vehicle Registry Logic

--- Returns the full data object for a specific vehicle model
--- @param model string | number
--- @return table | nil
function GetVehicleData(model)
    if not model then return nil end
    
    if type(model) == "number" then
        for name, data in pairs(SPZ.VehicleRegistry) do
            if GetHashKey(name) == model then
                return data
            end
        end
        return nil
    end

    return SPZ.VehicleRegistry[model]
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
--- Used by spz-races poll system to discover available classes without
--- needing direct access to SPZ.VehicleRegistry.
--- @return table  Array of class IDs (e.g. {0, 1, 2, 3})
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

exports("GetVehicleData", GetVehicleData)
exports("GetClassVehicles", GetClassVehicles)
exports("IsRegistered", IsRegistered)
exports("GetClassMeta", GetClassMeta)
exports("GetRaceClasses", GetRaceClasses)

CreateThread(function()
    -- Wait a bit for spz-physics to initialize and load data
    Wait(1000)
    
    if GetResourceState("spz-physics") ~= "started" then
        print("^3[SPZ-Vehicles]^0 spz-physics is not running. Using fallback static classes.^0")
        return
    end

    local count = 0
    for modelName, vehicle in pairs(SPZ.VehicleRegistry) do
        -- Try to fetch PP for the baseline standard model, false = not tuned
        local ppData = exports["spz-physics"]:GetPP(modelName, false)
        if ppData and ppData.pp then
            vehicle.pp = ppData.pp
            if ppData.class then
                vehicle.class = ppData.class
            end
            count = count + 1
        else
            -- Calculate a fallback class or keep existing from vehicles.lua
            vehicle.pp = 0
        end
    end
    print(("^2[SPZ-Vehicles]^0 Loaded physics PP for %s vehicles.^0"):format(count))
end)
