-- client/tuner_cam.lua — tuner camera.
-- Moved from spz-tunners/client/cam.lua when it was merged into spz-vehicles.

-- client/cam.lua
-- Tuner camera — behaves like qbx_customs' drag cam.
--
--   * One camera for the whole tuner session. It opens with the main menu and
--     closes with it; moving between submenus does not reframe it.
--   * The tuner is an NUI page (ui/), which owns the mouse and keyboard while
--     open, so the page sends camera input here: drag anywhere off the panel to
--     orbit, scroll to zoom (2.5 – 10 m), D opens / shuts every door, V toggles
--     first-person view (TunerCamDrag / Zoom / Doors / View below).
--   * While the tuner is open the car cannot be driven: throttle, brake,
--     steering and the radio are disabled.
--
-- Angles are world-space degrees around the car: yaw around Z, pitch 0 – 89
-- above the ground plane (90 would flip the camera, below 0 goes underground).

local cam         = nil
local currentVeh  = nil
local isCamActive = false
local firstPerson = false

local yaw, pitch = 0.0, 0.0
local radius     = 5.0

local RADIUS_MIN, RADIUS_MAX, ZOOM_STEP = 2.5, 10.0, 0.5

local function place()
    local c = GetEntityCoords(currentVeh)
    local ry, rp = math.rad(yaw), math.rad(pitch)
    SetCamCoord(cam,
        c.x + math.cos(ry) * math.cos(rp) * radius,
        c.y + math.sin(ry) * math.cos(rp) * radius,
        c.z + math.sin(rp) * radius)
    PointCamAtCoord(cam, c.x, c.y, c.z + 0.5)
end

local function toggleDoors()
    for door = 0, GetNumberOfVehicleDoors(currentVeh) do
        if GetVehicleDoorAngleRatio(currentVeh, door) > 0.0 then
            SetVehicleDoorShut(currentVeh, door, false)
        else
            SetVehicleDoorOpen(currentVeh, door, false, false)
        end
    end
end

-- ── Input ────────────────────────────────────────────────────────────────────

-- On foot / combat inputs that would fire while you click around the car.
local PLAYER_CONTROLS = { 21, 24, 25, 30, 31, 36, 47, 58, 69, 75, 140, 141, 142, 143, 257, 263, 264 }
-- Mouse look + weapon wheel + pause-alternate (the cursor owns the mouse).
local CAM_CONTROLS    = { 1, 2, 3, 4, 5, 6, 12, 13, 200 }
-- The car stays put: throttle, brake, radio, steering.
local DRIVE_CONTROLS  = { 71, 72, 81, 82, 83, 84, 85, 106 }

local function disableAll(list)
    for _, c in ipairs(list) do DisableControlAction(0, c, true) end
end

local function inputLoop()
    CreateThread(function()
        while isCamActive do
            disableAll(PLAYER_CONTROLS)
            disableAll(DRIVE_CONTROLS)
            disableAll(CAM_CONTROLS)
            Wait(0)
        end
    end)
end

-- ── Driven by the NUI page (client/menu.lua forwards these) ──────────────────

function TunerCamDrag(dx, dy)
    if not isCamActive or firstPerson then return end
    yaw   = yaw - (tonumber(dx) or 0) * 0.25
    pitch = math.max(0.0, math.min(89.0, pitch + (tonumber(dy) or 0) * 0.25))
    place()
end

function TunerCamZoom(dir)
    if not isCamActive then return end
    radius = math.max(RADIUS_MIN, math.min(RADIUS_MAX, radius + (dir > 0 and ZOOM_STEP or -ZOOM_STEP)))
    place()
end

function TunerCamDoors()
    if isCamActive and currentVeh then toggleDoors() end
end

function TunerCamView()
    if not isCamActive then return end
    firstPerson = not firstPerson
    if firstPerson then
        SetCamViewModeForContext(1, 4)
        RenderScriptCams(false, true, 0, true, false)
    else
        RenderScriptCams(true, true, 0, true, false)
    end
end

-- ── API (used by client/menu.lua) ────────────────────────────────────────────

--- Starts the session camera the first time; later calls (submenus) keep the
--- camera where the player left it, as qbx_customs does. `targetFocus` is
--- accepted for compatibility and ignored.
-- The car is stopped and held for the whole session. Opening the tuner on the
-- move used to leave it rolling off while the camera stayed behind.
local heldVeh = nil

local function holdVehicle(vehicle)
    if heldVeh or not vehicle or not DoesEntityExist(vehicle) then return end
    heldVeh = vehicle
    SetVehicleForwardSpeed(vehicle, 0.0)
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    FreezeEntityPosition(vehicle, true)
end

local function releaseVehicle()
    if heldVeh and DoesEntityExist(heldVeh) then FreezeEntityPosition(heldVeh, false) end
    heldVeh = nil
end

function EnableTunerCam(vehicle, targetFocus)
    holdVehicle(vehicle)
    if not Config.Tuner.EnableDynamicCamera then return end
    if isCamActive or not DoesEntityExist(vehicle) then return end

    currentVeh  = vehicle
    yaw, pitch  = 0.0, 0.0
    radius      = 5.0
    firstPerson = false

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, true, 0, true, false)
    isCamActive = true

    place()          -- otherwise the cam sits on the player until the first drag
    inputLoop()      -- key hints live in the NUI page now (no scaleform buttons)
end

function DisableTunerCam()
    releaseVehicle()
    if not isCamActive then return end
    isCamActive = false
    RenderScriptCams(false, true, 0, true, false)
    if cam then DestroyCam(cam, true) end
    cam = nil
    SetCamViewModeForContext(1, 1)
    currentVeh = nil
end

-- Safety watchdog: whatever closes the menu (ESC, or an Enter/select that slips
-- past the reopen), if NO tuner menu is open the camera must come down — this is
-- what stops you getting stuck in the tuner camera.
CreateThread(function()
    local misses = 0
    while true do
        Wait(400)
        if isCamActive or heldVeh then
            if SPZ_Tuners and SPZ_Tuners.IsOpen and SPZ_Tuners.IsOpen() then
                misses = 0
            else
                misses = misses + 1              -- ~0.8s grace for menu-to-menu hops
                if misses >= 2 then DisableTunerCam(); misses = 0 end
            end
        else
            misses = 0
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then DisableTunerCam() end
end)
