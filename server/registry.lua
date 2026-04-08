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

exports("GetVehicleData", GetVehicleData)
exports("GetClassVehicles", GetClassVehicles)
exports("IsRegistered", IsRegistered)
exports("GetClassMeta", GetClassMeta)
