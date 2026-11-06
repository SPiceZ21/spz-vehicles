-- client/tuner_menu.lua — tuner menu.
-- Moved from spz-tunners/client/menu.lua when it was merged into spz-vehicles.
-- Its page is still the "spz-tunners" app in spz-hud; these locals send to that page only.
local SendNUIMessage, SetNuiFocus, SetNuiFocusKeepInput = SpzHudApp('spz-tunners')

-- client/menu.lua
-- Tuner menus, drawn by the NUI page in ui/ (the menu definitions below are
-- renderer-agnostic: options with value lists, submenus or actions).
--
--   * ←/→ (or the arrows on a row) changes an option on the car.
--   * Enter installs it: "<part> installed" + the pick-up chime. Picking what is
--     already on the car says "Already installed" instead.
--   * Leaving a menu (Backspace) puts every un-installed preview back.
--   * ↑/↓ ticks, and backing out returns you to the row you came from.
--   * A damaged car gets a Repair-only main menu until it's fixed.
--
-- Menu tree:
--   Main ─ Performance
--        ─ Parts ─ (body + interior mods, plate style) ─ Wheels
--        ─ Cosmetics & Colors ─ Primary Paint, Secondary Paint, Neon (submenus)
--                             ─ xenon, pearlescent, wheel colour, window tint,
--                               tyre smoke, interior colour, livery
--        ─ Extras
SPZ_Tuners = SPZ_Tuners or {}

local CurrentVehicle = 0
local MAIN = 'spz_tuner_main'

-- Mod Type Names
local MOD_SLOT_NAMES = {
    [0]  = "Spoiler",           [1]  = "Front Bumper",     [2]  = "Rear Bumper",
    [3]  = "Side Skirt",        [4]  = "Exhaust",          [5]  = "Roll Cage",
    [6]  = "Grille",            [7]  = "Hood",             [8]  = "Left Fender",
    [9]  = "Right Fender",      [10] = "Roof",             [11] = "Engine",
    [12] = "Brakes",            [13] = "Transmission",     [14] = "Horn",
    [15] = "Suspension",        [16] = "Armor",            [25] = "Plate Holder",
    [26] = "Vanity Plate",      [27] = "Trim Design",      [28] = "Ornaments",
    [29] = "Dashboard",         [30] = "Dials",            [31] = "Door Speakers",
    [32] = "Seats",             [33] = "Steering Wheel",   [34] = "Gear Lever",
    [35] = "Plaques",           [36] = "Speakers",         [37] = "Trunk",
    [38] = "Hydraulics",        [39] = "Engine Block",     [40] = "Air Filter",
    [41] = "Struts",            [42] = "Arch Cover",       [43] = "Aerials",
    [44] = "Trim Option 2",     [45] = "Fuel Tank",        [46] = "Windows",
}

local PERFORMANCE_SLOTS = { 11, 12, 13, 15, 16 }
local PARTS_SLOTS = {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 14, 25, 26, 27, 28, 29, 30, 31, 32, 33,
    34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46,
}

local TYRE_SMOKE = {
    { label = 'White Smoke',  rgb = { 254, 254, 254 } },
    { label = 'Black Smoke',  rgb = { 1, 1, 1 } },
    { label = 'Blue Smoke',   rgb = { 0, 150, 255 } },
    { label = 'Yellow Smoke', rgb = { 255, 255, 50 } },
    { label = 'Orange Smoke', rgb = { 255, 153, 51 } },
    { label = 'Red Smoke',    rgb = { 255, 10, 10 } },
    { label = 'Green Smoke',  rgb = { 10, 255, 10 } },
    { label = 'Purple Smoke', rgb = { 153, 10, 153 } },
    { label = 'Pink Smoke',   rgb = { 255, 102, 178 } },
    { label = 'Gray Smoke',   rgb = { 128, 128, 128 } },
}

-- ── Snapshot / restore (used by the exports in client/main.lua) ──────────────

function SPZ_Tuners.SnapshotVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return nil end

    SetVehicleModKit(vehicle, 0)
    local p1, p2       = GetVehicleColours(vehicle)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    local r1, g1, b1   = GetVehicleCustomPrimaryColour(vehicle)
    local r2, g2, b2   = GetVehicleCustomSecondaryColour(vehicle)
    local nr, ng, nb   = GetVehicleNeonLightsColour(vehicle)
    local sr, sg, sb   = GetVehicleTyreSmokeColor(vehicle)

    local mods = {}
    for slot = 0, 49 do
        mods[slot] = GetVehicleMod(vehicle, slot)
    end

    local extras = {}
    for i = 1, 14 do
        if DoesExtraExist(vehicle, i) then
            extras[i] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    return {
        primary = p1,
        secondary = p2,
        pearlescent = pearl,
        wheelColor = wheel,
        interiorColor = GetVehicleInteriorColor(vehicle),
        customPrimary = GetIsVehiclePrimaryColourCustom(vehicle) and { r1, g1, b1 } or nil,
        customSecondary = GetIsVehicleSecondaryColourCustom(vehicle) and { r2, g2, b2 } or nil,
        livery = GetVehicleLivery(vehicle),
        wheelType = GetVehicleWheelType(vehicle),
        customTires = GetVehicleModVariation(vehicle, 23),
        plateText = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        windowTint = GetVehicleWindowTint(vehicle),
        xenonColor = GetVehicleXenonLightsColor(vehicle),
        turbo = IsToggleModOn(vehicle, 18),
        tyreSmoke = IsToggleModOn(vehicle, 20),
        tyreSmokeColor = { sr, sg, sb },
        xenonEnabled = IsToggleModOn(vehicle, 22),
        neonEnabled = {
            left  = IsVehicleNeonLightEnabled(vehicle, 0),
            right = IsVehicleNeonLightEnabled(vehicle, 1),
            front = IsVehicleNeonLightEnabled(vehicle, 2),
            back  = IsVehicleNeonLightEnabled(vehicle, 3),
        },
        neonColor = { nr, ng, nb },
        mods = mods,
        extras = extras
    }
end

function SPZ_Tuners.RestoreVehicle(vehicle, state)
    if not DoesEntityExist(vehicle) or not state then return end

    SetVehicleModKit(vehicle, 0)
    SetVehicleColours(vehicle, state.primary, state.secondary)
    SetVehicleExtraColours(vehicle, state.pearlescent, state.wheelColor)
    if state.interiorColor then SetVehicleInteriorColor(vehicle, state.interiorColor) end

    if state.customPrimary then
        SetVehicleCustomPrimaryColour(vehicle, state.customPrimary[1], state.customPrimary[2], state.customPrimary[3])
    end
    if state.customSecondary then
        SetVehicleCustomSecondaryColour(vehicle, state.customSecondary[1], state.customSecondary[2], state.customSecondary[3])
    end

    if state.livery and state.livery >= 0 then
        SetVehicleLivery(vehicle, state.livery)
    end

    SetVehicleWheelType(vehicle, state.wheelType)
    SetVehicleNumberPlateText(vehicle, state.plateText)
    SetVehicleNumberPlateTextIndex(vehicle, state.plateIndex)
    SetVehicleWindowTint(vehicle, state.windowTint)

    ToggleVehicleMod(vehicle, 18, state.turbo)
    ToggleVehicleMod(vehicle, 22, state.xenonEnabled)
    if state.xenonColor and state.xenonColor >= 0 then
        SetVehicleXenonLightsColor(vehicle, state.xenonColor)
    end
    if state.tyreSmoke ~= nil then ToggleVehicleMod(vehicle, 20, state.tyreSmoke) end
    if state.tyreSmokeColor then
        SetVehicleTyreSmokeColor(vehicle, state.tyreSmokeColor[1], state.tyreSmokeColor[2], state.tyreSmokeColor[3])
    end

    for i = 0, 3 do
        SetVehicleNeonLightEnabled(vehicle, i, state.neonEnabled[i == 0 and "left" or i == 1 and "right" or i == 2 and "front" or "back"])
    end
    SetVehicleNeonLightsColour(vehicle, state.neonColor[1], state.neonColor[2], state.neonColor[3])

    for slot, modIdx in pairs(state.mods) do
        slot = tonumber(slot)
        SetVehicleMod(vehicle, slot, modIdx, slot == 23 and state.customTires or false)
    end

    for extraId, enabled in pairs(state.extras) do
        SetVehicleExtra(vehicle, tonumber(extraId), enabled and 0 or 1)
    end
end

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function GetModLabel(vehicle, modType, modIndex)
    if modIndex == -1 then return "Stock" end
    local name = GetModTextLabel(vehicle, modType, modIndex)
    if name and name ~= "" then
        local text = GetLabelText(name)
        if text and text ~= "NULL" then return text end
    end
    return ("%s %d"):format(MOD_SLOT_NAMES[modType] or "Option", modIndex + 1)
end

local function labelsOf(list)
    local out = {}
    for i, item in ipairs(list) do out[i] = item.label end
    return out
end

local function indexOf(list, key, value)
    for i, item in ipairs(list) do
        if item[key] == value then return i end
    end
    return 1
end

local function price()
    if Config.Tuner.FreeTuning then return 'Free' end
    return ('$%d'):format(Config.Tuner.DefaultModPrice or 0)
end

local function byLabel(a, b) return a.label < b.label end

local function sound(name)
    PlaySoundFrontend(-1, name, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

--- Enter on an option. Tuning is free on this server (Config.Tuner.FreeTuning), so
--- the only refusal is installing what is already there.
local function Install(duplicate, description)
    if duplicate then
        lib.notify({ title = 'Tuner', description = 'Already installed', type = 'error' })
        return false
    end
    lib.notify({ title = 'Installed', description = description, type = 'success', icon = 'wrench' })
    sound('PICK_UP')
    return true
end

-- ── Menu framework ───────────────────────────────────────────────────────────
-- A menu definition: { id, title, parent, build = fn() -> options, empty = msg }
-- An option is one of:
--   value option  { label, description, values, defaultIndex,
--                   set = fn(index) -> duplicate, installedText,
--                   restore = fn() }
--   submenu       { label, description, submenu = <definition> }
--   action        { label, description, action = fn() }
-- `build` runs again after every install, so "original" is always what the car
-- actually has installed right now.

local LastIndex = {}
local SaveToken = 0

--- Save the car's current state to the server (statebag + spz-vehicles).
local function SaveNow()
    if Config.Tuner.SaveToVehicleState and DoesEntityExist(CurrentVehicle) then
        TriggerServerEvent("SPZ:tuner:saveVehicle", VehToNet(CurrentVehicle), SPZ_Tuners.SnapshotVehicle(CurrentVehicle))
    end
end

--- Autosave shortly after the last change (debounced so scrolling doesn't spam).
function SPZ_Tuners.QueueSave()
    SaveToken = SaveToken + 1
    local token = SaveToken
    SetTimeout(1500, function()
        if token == SaveToken then SaveNow() end
    end)
end

--- Menu entry + /save_customs: save the live state, then store the look as the
--- player's saved custom for this model (spz-vehicles' /savecustom).
function SPZ_Tuners.SaveCustoms()
    local veh = DoesEntityExist(CurrentVehicle) and CurrentVehicle or GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        lib.notify({ title = 'Tuner', description = 'Get in a vehicle first', type = 'error' })
        return
    end
    CurrentVehicle = veh
    SaveToken = SaveToken + 1
    SaveNow()
    ExecuteCommand('savecustom')
    lib.notify({ title = 'Customs saved', description = 'Saved for this car model', type = 'success', icon = 'floppy-disk' })
end

-- ── NUI renderer ─────────────────────────────────────────────────────────────

local isOpen = false
local Defs   = {}      -- [id] = definition, so a submenu can find its parent
local Cur    = nil     -- { def, options, vals = { [row] = value index } }

function SPZ_Tuners.IsOpen() return isOpen end

local function focus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

local function pushTheme()
    local ok, theme = pcall(function() return exports['spz-core']:GetTheme() end)
    if ok and theme then SendNUIMessage({ action = 'theme', theme = theme }) end
end

-- The car card (top-left). Model stats only, read once per open: they describe
-- the car, not the parts on it, so they do not move as mods are installed.
local function pushVehicle()
    local veh = CurrentVehicle
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    local model = GetEntityModel(veh)
    local function lbl(k)
        local t = k and GetLabelText(k)
        return (t and t ~= 'NULL') and t or (k or '')
    end
    local function scale(v, max) return math.max(0.0, math.min(10.0, (v or 0) / max * 10.0)) end
    local p = type(LocalPlayer.state.profile) == 'table' and LocalPlayer.state.profile or {}
    SendNUIMessage({ action = 'vehicle', data = {
        make    = lbl(GetMakeNameFromVehicleModel(model)),
        name    = lbl(GetDisplayNameFromVehicleModel(model)),
        credits = tonumber(p.credits),
        stats   = {
            { label = 'Top Speed',    v = scale(GetVehicleModelEstimatedMaxSpeed(model), 60.0) },
            { label = 'Acceleration', v = scale(GetVehicleModelAcceleration(model), 0.5) },
            { label = 'Braking',      v = scale(GetVehicleModelMaxBraking(model), 1.5) },
            { label = 'Handling',     v = scale(GetVehicleModelMaxTraction(model), 3.5) },
        },
    } })
end

local function render(def, options, selected)
    Cur = { def = def, options = options, vals = {} }
    local rows = {}
    for i, o in ipairs(options) do
        if o.values then Cur.vals[i] = o.defaultIndex or 1 end
        rows[i] = {
            label  = o.label,
            desc   = o.description,
            values = o.values,
            index  = Cur.vals[i],
            kind   = o.submenu and 'submenu' or o.action and 'action' or 'value',
        }
    end
    local crumbs, d = {}, def
    while d do
        table.insert(crumbs, 1, d.title)
        d = d.parent and Defs[d.parent] or nil
    end
    SendNUIMessage({ action = 'menu', data = {
        id = def.id, title = def.title, crumbs = crumbs, options = rows,
        selected = selected or LastIndex[def.id] or 1,
    } })
end

local function closeUI()
    isOpen, Cur = false, nil
    focus(false)
    SendNUIMessage({ action = 'close' })
end

local function restoreAll(options)
    if Config.Tuner.AutoApply then return end   -- every change is already kept
    for _, o in ipairs(options or {}) do
        if o.restore then o.restore() end
    end
end

local Open
Open = function(def, selected)
    Defs[def.id] = def
    EnableTunerCam(CurrentVehicle)   -- no-op when already on

    local options = def.build()
    if #options == 0 then
        lib.notify({ title = 'Tuner', description = def.empty or 'Nothing to change here', type = 'inform' })
        if def.parent and Defs[def.parent] then return Open(Defs[def.parent]) end
        return
    end

    if not isOpen then
        isOpen = true
        pushTheme()
        SendNUIMessage({ action = 'open' })
        pushVehicle()
    end
    focus(true)
    render(def, options, selected)
end

--- Back one level; at the top this closes the tuner (main menu's onClose saves).
local function back()
    if not Cur then return end
    local def = Cur.def
    restoreAll(Cur.options)
    if def.onClose then def.onClose() end
    if def.parent and Defs[def.parent] then Open(Defs[def.parent]) else closeUI() end
end

--- Close the whole tuner from any depth (X button / race start).
local function exitAll()
    if not Cur then closeUI(); return end
    restoreAll(Cur.options)
    local root = Cur.def
    while root.parent and Defs[root.parent] do root = Defs[root.parent] end
    closeUI()
    if root.onClose then root.onClose() end
end

--- Race countdown / grid teleport: shut the tuner and save whatever is on the car.
function SPZ_Tuners.CloseForRace()
    if not isOpen then return end
    exitAll()
end

RegisterNUICallback('hover', function(d, cb)
    cb(1)
    if Cur and d and d.i then
        LastIndex[Cur.def.id] = d.i
        sound('NAV_UP_DOWN')
    end
end)

RegisterNUICallback('scroll', function(d, cb)
    cb(1)
    local o = Cur and d and Cur.options[d.i]
    if not (o and o.set and d.v) then return end
    Cur.vals[d.i] = d.v
    sound('NAV_LEFT_RIGHT')
    o.set(d.v)
    if Config.Tuner.AutoApply then SPZ_Tuners.QueueSave() end
end)

RegisterNUICallback('select', function(d, cb)
    cb(1)
    if not (Cur and d and d.i) then return end
    local def, options = Cur.def, Cur.options
    local o = options[d.i]
    if not o then return end
    LastIndex[def.id] = d.i
    sound('SELECT')

    if o.submenu then
        restoreAll(options)
        LastIndex[o.submenu.id] = 1
        return Open(o.submenu)
    end
    if o.action then return o.action() end

    local v = d.v or Cur.vals[d.i] or 1
    local duplicate, text = o.set(v)
    if Config.Tuner.AutoApply then
        Install(false, text)          -- already on the car from scrolling; Enter confirms
        SPZ_Tuners.QueueSave()
    elseif not Install(duplicate, text) and o.restore then
        o.restore()
    end
    Open(def, d.i)                    -- rebuild: "installed" is now the new value
end)

RegisterNUICallback('back', function(_, cb) cb(1); sound('BACK'); back() end)
RegisterNUICallback('exit', function(_, cb) cb(1); exitAll() end)

RegisterNUICallback('cam', function(d, cb)
    cb(1)
    if not d then return end
    if d.t == 'drag' then TunerCamDrag(d.dx, d.dy)
    elseif d.t == 'zoom' then TunerCamZoom(d.dir or 1)
    elseif d.t == 'doors' then TunerCamDoors()
    elseif d.t == 'view' then TunerCamView() end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and isOpen then focus(false) end
end)

-- Reusable option builders ----------------------------------------------------

--- A vehicle mod slot as a scroll list ("Stock", option 1, option 2 …).
local function modOption(veh, slot, labelFn)
    local count = GetNumVehicleMods(veh, slot)
    if count <= 0 then return nil end

    local original = GetVehicleMod(veh, slot)
    local values = {}
    for i = -1, count - 1 do
        values[#values + 1] = labelFn and labelFn(i) or GetModLabel(veh, slot, i)
    end

    return {
        label = MOD_SLOT_NAMES[slot] or ('Mod %d'):format(slot),
        description = price(),
        values = values,
        close = true,
        defaultIndex = original + 2,
        set = function(index)
            SetVehicleMod(veh, slot, index - 2, false)
            return original == index - 2, ('%s: %s'):format(MOD_SLOT_NAMES[slot] or 'Mod', values[index])
        end,
        restore = function() SetVehicleMod(veh, slot, original, false) end,
    }
end

--- A list of {label, <key>} applied with apply(item); original read by read().
local function listOption(label, list, key, read, apply)
    local original = read()
    return {
        label = label,
        description = price(),
        values = labelsOf(list),
        close = true,
        defaultIndex = indexOf(list, key, original),
        set = function(index)
            apply(list[index][key])
            return list[index][key] == original, ('%s: %s'):format(label, list[index].label)
        end,
        restore = function() apply(original) end,
    }
end

local function toggleOption(label, read, apply, offText, onText)
    local original = read()
    offText, onText = offText or 'Disabled', onText or 'Enabled'
    return {
        label = label,
        description = price(),
        values = { offText, onText },
        close = true,
        defaultIndex = original and 2 or 1,
        set = function(index)
            apply(index == 2)
            return original == (index == 2), ('%s %s'):format(label, (index == 2 and onText or offText):lower())
        end,
        restore = function() apply(original) end,
    }
end

-- ── Performance ──────────────────────────────────────────────────────────────

local PerformanceMenu = {
    id = 'spz_tuner_perf', title = 'Performance', parent = MAIN,
    empty = 'This vehicle has no performance upgrades',
    build = function()
        local veh, options = CurrentVehicle, {}
        for _, slot in ipairs(PERFORMANCE_SLOTS) do
            local o = modOption(veh, slot, function(i)
                return i == -1 and 'Stock' or ('%s %d'):format(MOD_SLOT_NAMES[slot], i + 1)
            end)
            if o then options[#options + 1] = o end
        end
        if GetVehicleClass(veh) ~= 13 then   -- not a bicycle
            options[#options + 1] = toggleOption('Turbo',
                function() return IsToggleModOn(veh, 18) end,
                function(on) ToggleVehicleMod(veh, 18, on) end)
        end
        table.sort(options, byLabel)
        return options
    end,
}

-- ── Wheels (inside Parts) ────────────────────────────────────────────────────

local function wheelTypeAllowed(veh, wheelType)
    local class = GetVehicleClass(veh)
    if class == 13 then return false end                 -- cycles
    if class == 8 then return wheelType == 6 end         -- motorcycles: bike wheels
    if class == 22 then return wheelType == 10 end       -- open wheel
    return true
end

local WheelsMenu = {
    id = 'spz_tuner_wheels', title = 'Wheels', parent = 'spz_tuner_parts',
    build = function()
        local veh, options = CurrentVehicle, {}
        local originalType = GetVehicleWheelType(veh)
        local originalMod  = GetVehicleMod(veh, 23)
        local originalCustom = GetVehicleModVariation(veh, 23)

        local function restore()
            SetVehicleWheelType(veh, originalType)
            SetVehicleMod(veh, 23, originalMod, originalCustom)
        end

        for _, category in ipairs(SPZ_Tuners.WheelTypes) do
            if wheelTypeAllowed(veh, category.type) then
                -- Rim names are only readable with that wheel type set.
                SetVehicleWheelType(veh, category.type)
                local count, labels = GetNumVehicleMods(veh, 23), {}
                for i = 0, count - 1 do labels[i + 1] = GetModLabel(veh, 23, i) end

                if count > 0 then
                    options[#options + 1] = {
                        label = category.label,
                        description = price(),
                        values = labels,
                        close = true,
                        defaultIndex = (originalType == category.type and originalMod >= 0) and originalMod + 1 or 1,
                        set = function(index)
                            SetVehicleWheelType(veh, category.type)
                            SetVehicleMod(veh, 23, index - 1, originalCustom)
                            return originalType == category.type and originalMod == index - 1,
                                ('%s wheels: %s'):format(category.label, labels[index])
                        end,
                        restore = restore,
                    }
                end
            end
        end
        SetVehicleWheelType(veh, originalType)
        table.sort(options, byLabel)

        options[#options + 1] = {
            label = 'Custom Tires',
            description = price(),
            values = { 'Standard', 'Custom' },
            close = true,
            defaultIndex = originalCustom and 2 or 1,
            set = function(index)
                SetVehicleMod(veh, 23, GetVehicleMod(veh, 23), index == 2)
                return originalCustom == (index == 2), index == 2 and 'Custom tires fitted' or 'Standard tires fitted'
            end,
            restore = restore,
        }
        return options
    end,
}

-- ── Parts ────────────────────────────────────────────────────────────────────

local PartsMenu = {
    id = 'spz_tuner_parts', title = 'Parts', parent = MAIN,
    build = function()
        local veh, options = CurrentVehicle, {}
        for _, slot in ipairs(PARTS_SLOTS) do
            local o = modOption(veh, slot)
            if o then options[#options + 1] = o end
        end

        options[#options + 1] = listOption('Plate Style', SPZ_Tuners.PlateStyles, 'index',
            function() return GetVehicleNumberPlateTextIndex(veh) end,
            function(v) SetVehicleNumberPlateTextIndex(veh, v) end)

        if GetVehicleClass(veh) ~= 13 then
            options[#options + 1] = { label = 'Wheels', description = 'Rims by category, custom tires', close = true, submenu = WheelsMenu }
        end

        table.sort(options, byLabel)
        return options
    end,
}

-- ── Cosmetics & Colors ───────────────────────────────────────────────────────

--- Primary / secondary paint: one scroll list per paint family.
local function PaintMenu(primary)
    return {
        id = primary and 'spz_tuner_paint_primary' or 'spz_tuner_paint_secondary',
        title = primary and 'Primary Paint' or 'Secondary Paint',
        parent = 'spz_tuner_colors',
        build = function()
            local veh = CurrentVehicle
            local p1, p2 = GetVehicleColours(veh)
            local current = primary and p1 or p2

            local function paint(v)
                if primary then SetVehicleColours(veh, v, p2) else SetVehicleColours(veh, p1, v) end
            end
            local function restore() SetVehicleColours(veh, p1, p2) end

            local function family(label, list)
                return {
                    label = label,
                    description = price(),
                    values = labelsOf(list),
                    close = true,
                    defaultIndex = indexOf(list, 'index', current),
                    set = function(index)
                        paint(list[index].index)
                        return list[index].index == current, ('%s: %s'):format(primary and 'Primary' or 'Secondary', list[index].label)
                    end,
                    restore = restore,
                }
            end

            local options = { family('Classic', SPZ_Tuners.Colors) }
            local chameleons = SPZ_Tuners.GetChameleonColors and SPZ_Tuners.GetChameleonColors() or {}
            if #chameleons > 0 then
                options[#options + 1] = family('Chameleon', chameleons)
                if primary then
                    -- Chameleon reads properly only when the whole body carries it.
                    options[#options + 1] = {
                        label = 'Chameleon (whole car)',
                        description = price() .. ' · primary + secondary',
                        values = labelsOf(chameleons),
                        close = true,
                        defaultIndex = indexOf(chameleons, 'index', p1),
                        set = function(index)
                            local c = chameleons[index].index
                            SetVehicleColours(veh, c, c)
                            return p1 == c and p2 == c, 'Chameleon: ' .. chameleons[index].label
                        end,
                        restore = restore,
                    }
                end
            end
            return options
        end,
    }
end

local NeonMenu = {
    id = 'spz_tuner_neon', title = 'Neon', parent = 'spz_tuner_colors',
    build = function()
        local veh, options = CurrentVehicle, {}
        for i, side in ipairs({ 'Left', 'Right', 'Front', 'Back' }) do
            options[i] = toggleOption(side .. ' Neon',
                function() return IsVehicleNeonLightEnabled(veh, i - 1) end,
                function(on) SetVehicleNeonLightEnabled(veh, i - 1, on) end)
        end

        local r, g, b = GetVehicleNeonLightsColour(veh)
        local original = 1
        for i, c in ipairs(SPZ_Tuners.NeonColors) do
            if c.rgb[1] == r and c.rgb[2] == g and c.rgb[3] == b then original = i end
        end
        options[5] = {
            label = 'Neon Color',
            description = price(),
            values = labelsOf(SPZ_Tuners.NeonColors),
            close = true,
            defaultIndex = original,
            set = function(index)
                local c = SPZ_Tuners.NeonColors[index].rgb
                SetVehicleNeonLightsColour(veh, c[1], c[2], c[3])
                return index == original, 'Neon color: ' .. SPZ_Tuners.NeonColors[index].label
            end,
            restore = function() SetVehicleNeonLightsColour(veh, r, g, b) end,
        }
        return options
    end,
}

local ColorsMenu
ColorsMenu = {
    id = 'spz_tuner_colors', title = 'Cosmetics & Colors', parent = MAIN,
    build = function()
        local veh = CurrentVehicle
        local options = {
            { label = 'Primary Paint', close = true, submenu = PaintMenu(true) },
            { label = 'Secondary Paint', close = true, submenu = PaintMenu(false) },
            { label = 'Neon', close = true, submenu = NeonMenu },
        }

        -- Xenon: "Disabled", then every colour.
        local xenonOn, xenonColor = IsToggleModOn(veh, 22), GetVehicleXenonLightsColor(veh)
        local xenonValues = { 'Disabled' }
        for _, x in ipairs(SPZ_Tuners.XenonColors) do xenonValues[#xenonValues + 1] = x.label end
        options[#options + 1] = {
            label = 'Xenon Lights',
            description = price(),
            values = xenonValues,
            close = true,
            defaultIndex = xenonOn and (indexOf(SPZ_Tuners.XenonColors, 'index', xenonColor) + 1) or 1,
            set = function(index)
                if index == 1 then
                    ToggleVehicleMod(veh, 22, false)
                    return not xenonOn, 'Xenon lights disabled'
                end
                local c = SPZ_Tuners.XenonColors[index - 1]
                ToggleVehicleMod(veh, 22, true)
                SetVehicleXenonLightsColor(veh, c.index)
                return xenonOn and xenonColor == c.index, 'Xenon: ' .. c.label
            end,
            restore = function()
                ToggleVehicleMod(veh, 22, xenonOn)
                SetVehicleXenonLightsColor(veh, xenonColor)
            end,
        }

        -- Pearlescent accepts chameleons too.
        local pearls = {}
        for _, c in ipairs(SPZ_Tuners.Colors) do pearls[#pearls + 1] = c end
        for _, c in ipairs(SPZ_Tuners.GetChameleonColors and SPZ_Tuners.GetChameleonColors() or {}) do pearls[#pearls + 1] = c end

        options[#options + 1] = listOption('Pearlescent', pearls, 'index',
            function() return (GetVehicleExtraColours(veh)) end,
            function(v) local _, w = GetVehicleExtraColours(veh); SetVehicleExtraColours(veh, v, w) end)

        options[#options + 1] = listOption('Wheel Color', SPZ_Tuners.Colors, 'index',
            function() local _, w = GetVehicleExtraColours(veh); return w end,
            function(v) local p = GetVehicleExtraColours(veh); SetVehicleExtraColours(veh, p, v) end)

        options[#options + 1] = listOption('Window Tint', SPZ_Tuners.WindowTints, 'index',
            function() return GetVehicleWindowTint(veh) end,
            function(v) SetVehicleWindowTint(veh, v) end)

        options[#options + 1] = listOption('Interior', SPZ_Tuners.Colors, 'index',
            function() return GetVehicleInteriorColor(veh) end,
            function(v) SetVehicleInteriorColor(veh, v) end)

        -- Tyre smoke (turns the smoke mod on).
        local sr, sg, sb = GetVehicleTyreSmokeColor(veh)
        local smokeOn = IsToggleModOn(veh, 20)
        local smokeIdx = 1
        for i, c in ipairs(TYRE_SMOKE) do
            if c.rgb[1] == sr and c.rgb[2] == sg and c.rgb[3] == sb then smokeIdx = i end
        end
        options[#options + 1] = {
            label = 'Tyre Smoke',
            description = price(),
            values = labelsOf(TYRE_SMOKE),
            close = true,
            defaultIndex = smokeIdx,
            set = function(index)
                local c = TYRE_SMOKE[index].rgb
                ToggleVehicleMod(veh, 20, true)
                SetVehicleTyreSmokeColor(veh, c[1], c[2], c[3])
                return smokeOn and index == smokeIdx, 'Tyre smoke: ' .. TYRE_SMOKE[index].label
            end,
            restore = function()
                ToggleVehicleMod(veh, 20, smokeOn)
                SetVehicleTyreSmokeColor(veh, sr, sg, sb)
            end,
        }

        -- Livery: mod slot 48 when the car has one, else the old livery system.
        if GetNumVehicleMods(veh, 48) > 0 then
            local o = modOption(veh, 48)
            if o then o.label = 'Livery'; options[#options + 1] = o end
        elseif GetVehicleLiveryCount(veh) > 0 then
            local original, values = GetVehicleLivery(veh), {}
            for i = 1, GetVehicleLiveryCount(veh) do values[i] = ('Livery %d'):format(i) end
            options[#options + 1] = {
                label = 'Livery',
                description = price(),
                values = values,
                close = true,
                defaultIndex = math.max(original, 0) + 1,
                set = function(index)
                    SetVehicleLivery(veh, index - 1)
                    return original == index - 1, 'Livery: ' .. values[index]
                end,
                restore = function() SetVehicleLivery(veh, original) end,
            }
        end

        table.sort(options, byLabel)
        return options
    end,
}

-- ── Extras ───────────────────────────────────────────────────────────────────

local function hasExtras(veh)
    for i = 1, 14 do
        if DoesExtraExist(veh, i) then return true end
    end
    return false
end

local ExtrasMenu = {
    id = 'spz_tuner_extras', title = 'Extras', parent = MAIN,
    empty = 'This vehicle has no extras',
    build = function()
        local veh, options = CurrentVehicle, {}
        for i = 1, 14 do
            if DoesExtraExist(veh, i) then
                options[#options + 1] = toggleOption(('Extra %d'):format(i),
                    function() return IsVehicleExtraTurnedOn(veh, i) end,
                    function(on) SetVehicleExtra(veh, i, on and 0 or 1) end)
            end
        end
        return options
    end,
}

-- ── Main ─────────────────────────────────────────────────────────────────────

local MainMenu
MainMenu = {
    id = MAIN, title = 'Customs',
    build = function()
        local veh = CurrentVehicle

        -- A damaged car has to be repaired before anything else, like qbx.
        if GetVehicleBodyHealth(veh) < 1000.0 then
            return {{
                label = 'Repair Vehicle',
                description = price(),
                close = true,
                action = function()
                    SetVehicleFixed(veh)
                    SetVehicleDeformationFixed(veh)
                    SetVehicleEngineHealth(veh, 1000.0)
                    SetVehicleBodyHealth(veh, 1000.0)
                    SetVehicleDirtLevel(veh, 0.0)
                    Install(false, 'Vehicle repaired')
                    Open(MainMenu)
                end,
            }}
        end

        local options = {
            { label = 'Performance', close = true, submenu = PerformanceMenu },
            { label = 'Parts', close = true, submenu = PartsMenu },
            { label = 'Cosmetics & Colors', close = true, submenu = ColorsMenu },
        }
        if hasExtras(veh) then
            options[#options + 1] = { label = 'Extras', close = true, submenu = ExtrasMenu }
        end
        options[#options + 1] = {
            label = 'Save Customs',
            description = '/save_customs · keep this look for this car model',
            close = true,
            action = function()
                SPZ_Tuners.SaveCustoms()
                Open(MainMenu)
            end,
        }
        return options
    end,
    onClose = function()
        DisableTunerCam()
        SaveToken = SaveToken + 1
        SaveNow()
    end,
}

function SPZ_Tuners.OpenTunerMenu(vehicle)
    if not DoesEntityExist(vehicle) then return end
    if isOpen then return end   -- already in the tuner

    CurrentVehicle = vehicle
    SetVehicleModKit(vehicle, 0)
    LastIndex = {}
    Open(MainMenu)
end
