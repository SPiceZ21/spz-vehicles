-- client/garage.lua — garage (car spawner): /car, /dv, F5.
-- Moved from spz-carspawner/client/main.lua when it was merged into spz-vehicles.
-- Its page is still the "spz-carspawner" app in spz-hud; these locals send to that page only.
local SendNUIMessage, SetNuiFocus, SetNuiFocusKeepInput = SpzHudApp('spz-carspawner')

-- client/main.lua — Dynamic Car Spawner (ox_lib context menu)

-- Registry: Docs/keybinds.md
RegisterKeyMapping("car", "Open Car Spawner", "keyboard", "F5")

    -- Race classes only — no civilian / service / utility / prop vehicles.
local CLASS_NAMES = {
    [3]  = "Coupes",
    [4]  = "Muscle",
    [5]  = "Sports Classics",
    [6]  = "Sports",
    [7]  = "Super",
    [22] = "Open Wheel",
}

-- Whitelist mirrors CLASS_NAMES: only these GTA vehicle classes are spawnable.
local RACE_CLASSES = {}
for classId in pairs(CLASS_NAMES) do RACE_CLASSES[classId] = true end

-- Add-on packs are wider than the base-game race set: a Gabz-style pack is
-- mostly real-world sedans, hatches and SUVs, which GTA files under Sedans /
-- Compacts / SUVs. Hiding those hid most of the pack. Still no bikes, boats,
-- aircraft, service or utility vehicles.
local ADDON_CLASS_NAMES = {
    [0]  = "Compacts",
    [1]  = "Sedans",
    [2]  = "SUVs",
    [9]  = "Off-road",
    [12] = "Vans",
}
local ADDON_CLASSES = {}
for classId in pairs(RACE_CLASSES) do ADDON_CLASSES[classId] = true end
for classId in pairs(ADDON_CLASS_NAMES) do ADDON_CLASSES[classId] = true end

--- model -> resource, published by spz-vehicles/server/addons.lua after it
--- scans every running car pack. Authoritative where the label check below is
--- only a guess (a well-packaged pack ships text labels, so it looks vanilla).
local function discoveredAddons()
    local set = GlobalState.spzAddonModels
    return type(set) == "table" and set or {}
end

local function FormatModelLabel(model)
    local hash = GetHashKey(model)
    local makeGxt = GetMakeNameFromVehicleModel(hash)
    local makeText = (makeGxt and makeGxt ~= "") and GetLabelText(makeGxt) or ""
    if makeText == "NULL" or makeText == "" then makeText = nil end

    local nameGxt = GetDisplayNameFromVehicleModel(hash)
    local nameText = (nameGxt and nameGxt ~= "") and GetLabelText(nameGxt) or ""
    if nameText == "NULL" or nameText == "" then nameText = nil end

    if makeText and nameText then
        return makeText .. " " .. nameText
    elseif nameText then
        return nameText
    else
        return model:sub(1,1):upper() .. model:sub(2)
    end
end

local function BuildVehicleList()
    local models = GetAllVehicleModels()
    local registered = {}

    local ok, reg = pcall(function()
        return exports["spz-vehicles"]:GetVehicleRegistry()
    end)
    if ok and type(reg) == "table" then
        registered = reg
    end

    local list = {}
    local seen = {}
    local addons = discoveredAddons()

    -- Discovered add-ons are walked too, in case this build's
    -- GetAllVehicleModels misses a streamed model.
    local candidates = {}
    for _, rawModel in ipairs(models) do candidates[#candidates + 1] = rawModel end
    for model in pairs(addons) do candidates[#candidates + 1] = model end

    for _, rawModel in ipairs(candidates) do
        local model = rawModel:lower()
        if not seen[model] then
            seen[model] = true
            local hash = GetHashKey(model)

            if IsModelInCdimage(hash) and IsModelAVehicle(hash) then
                local classId = GetVehicleClassFromName(hash)
                local regData = registered[model]
                local nameGxt = GetDisplayNameFromVehicleModel(hash)

                local isAddon = addons[model] ~= nil
                    or ((not regData) and (GetLabelText(nameGxt) == "NULL"))

                if (isAddon and ADDON_CLASSES[classId]) or RACE_CLASSES[classId] then
                    local label
                    if regData and regData.label then
                        label = regData.label
                    else
                        label = FormatModelLabel(model)
                    end

                    table.insert(list, {
                        model     = model,
                        label     = label,
                        classId   = classId,
                        className = CLASS_NAMES[classId] or ADDON_CLASS_NAMES[classId] or "Other",
                        isAddon   = isAddon
                    })
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.label:lower() < b.label:lower() end)
    return list
end

-- ── NUI ───────────────────────────────────────────────────────────────────────

local isOpen = false

local function setOpen(v)
    isOpen = v
    SetNuiFocus(v, v)
    if not v then SendNUIMessage({ action = "close" }) end
end

local function pushTheme()
    local ok, theme = pcall(function() return exports["spz-core"]:GetTheme() end)
    if ok and theme and next(theme) then SendNUIMessage({ action = "theme", theme = theme }) end
end
AddEventHandler("SPZ:themeUpdated", function(theme)
    if theme and next(theme) then SendNUIMessage({ action = "theme", theme = theme }) end
end)

local function OpenCarSpawner()
    if isOpen then return end
    local vehicles = BuildVehicleList()
    if #vehicles == 0 then
        lib.notify({ description = "No vehicles found on server", type = "error" })
        return
    end

    -- Images are matched in the page by model name: ui/img/<model>.png first,
    -- then the uz_AutoShot capture, then a placeholder.
    local shots = nil
    if GetResourceState("uz_AutoShot") == "started" then
        local ok, base = pcall(function() return exports["uz_AutoShot"]:getShotsBaseURL() end)
        local okF, fmt = pcall(function() return exports["uz_AutoShot"]:getPhotoFormat() end)
        if ok and base then shots = { base = base .. "/vehicles", fmt = okF and fmt or "png" } end
    end

    pushTheme()
    SendNUIMessage({ action = "open", vehicles = vehicles, shots = shots })
    setOpen(true)
end

RegisterNUICallback("close", function(_, cb) setOpen(false); cb(1) end)

-- spz-tutorial closes whatever it opened when the tour moves on.
AddEventHandler("spz-tutorial:closeUI", function() if isOpen then setOpen(false) end end)


RegisterNUICallback("spawn", function(data, cb)
    cb(1)
    local model = type(data) == "table" and tostring(data.model or ""):lower():gsub("%s+", "") or ""
    if model == "" then return end
    setOpen(false)
    TriggerServerEvent("SPZ:carspawner:spawnVehicle", model)
end)

RegisterNUICallback("uiReady", function(_, cb) cb(1); pushTheme() end)

RegisterNetEvent("SPZ:carspawner:openMenu", function()
    OpenCarSpawner()
end)

AddEventHandler("onResourceStop", function(res)
    if res == GetCurrentResourceName() and isOpen then SetNuiFocus(false, false) end
end)
