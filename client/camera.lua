local _print = print
local print = function(...)
    if Config.Debug then _print(...) end
end

local Camera = {}
Camera.handle = nil
Camera.isActive = false
Camera.initialRot = vec3(0, 0, 0)
Camera.currentRot = vec3(0, 0, 0)
Camera.targetATM = nil
Camera.currentATMModel = nil
Camera.atmCoords = nil
Camera.atmHeadingQuat = nil
Camera.debugMode = false

Camera.cachedButtonCoords = {}

local function Clamp(value, min, max)
    return math.max(min, math.min(value, max))
end

local function QuatFromHeading(heading)
    return quat(heading, vector3(0, 0, 1))
end

local function RotateVectorByQuaternion(vec, rotQuat)
    local vecQuat = quat(0, vec.x, vec.y, vec.z)
    local rotatedQuat = rotQuat * vecQuat * inv(rotQuat)
    return vector3(rotatedQuat.x, rotatedQuat.y, rotatedQuat.z)
end

local function ComputeButtonWorldPositions(atmEntity, atmModel)
    Camera.cachedButtonCoords = {}

    local buttons = Config.ButtonOffsets[atmModel]
    if not buttons then return end

    local atmCoords = GetEntityCoords(atmEntity)
    local atmHeading = GetEntityHeading(atmEntity)
    local headingQuat = QuatFromHeading(atmHeading)

    Camera.atmCoords = atmCoords
    Camera.atmHeadingQuat = headingQuat

    for _, btn in ipairs(buttons) do
        local rotatedOffset = RotateVectorByQuaternion(btn.offset, headingQuat)
        local worldPos = vector3(
            atmCoords.x + rotatedOffset.x,
            atmCoords.y + rotatedOffset.y,
            atmCoords.z + rotatedOffset.z
        )
        Camera.cachedButtonCoords[#Camera.cachedButtonCoords + 1] = {
            id = btn.id,
            worldPos = worldPos
        }
    end

    print('^2[atm-dui] Computed ' .. #Camera.cachedButtonCoords .. ' button world positions for ' .. atmModel .. '^0')
end

local function GetButtonAtScreenCenter()
    local proximity = Config.ButtonProximity or 0.027
    local closestDist = proximity
    local closestButton = nil

    for _, btn in ipairs(Camera.cachedButtonCoords) do
        local visible, screenX, screenY = GetScreenCoordFromWorldCoord(btn.worldPos.x, btn.worldPos.y, btn.worldPos.z)

        if visible then

            local dx = screenX - 0.5
            local dy = screenY - 0.5
            local dist = math.sqrt(dx * dx + dy * dy)

            if dist < proximity and dist < closestDist then
                closestDist = dist
                closestButton = btn.id
            end
        end
    end

    return closestButton
end

function Camera.TransitionTo(atmEntity)
    if Camera.isActive then return end

    Camera.targetATM = atmEntity
    local atmHeading = GetEntityHeading(atmEntity)

    local model = GetEntityModel(atmEntity)
    Camera.currentATMModel = nil
    for _, modelName in ipairs(Config.ATMModels) do
        if GetHashKey(modelName) == model then
            Camera.currentATMModel = modelName
            break
        end
    end

    if Camera.currentATMModel then
        ComputeButtonWorldPositions(atmEntity, Camera.currentATMModel)
    end

    local sideOffset = Config.Camera.sideOffset or 0.0
    local camOffset = GetOffsetFromEntityInWorldCoords(atmEntity, sideOffset, -Config.Camera.distance, Config.Camera.heightOffset)

    Camera.handle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(Camera.handle, camOffset.x, camOffset.y, camOffset.z)

    local initialPitch = Config.Camera.initialPitch or -15.0
    Camera.initialRot = vec3(initialPitch, 0.0, atmHeading)
    Camera.currentRot = Camera.initialRot

    SetCamRot(Camera.handle, Camera.initialRot.x, Camera.initialRot.y, Camera.initialRot.z, 2)
    SetCamFov(Camera.handle, Config.Camera.fov)
    SetCamActive(Camera.handle, true)

    RenderScriptCams(true, true, Config.Camera.transitionTime, true, true)

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)

    Whip.core:SetScreenOpen(true, 'atm')

    Camera.isActive = true

    print('^2[atm-dui] Camera transitioned - Model: ' .. tostring(Camera.currentATMModel) .. ' | Heading: ' .. atmHeading .. '^0')

    Camera.StartControlThread()
end

function Camera.StartControlThread()
    local prevButtonId = nil

    CreateThread(function()
        while Camera.isActive and DoesCamExist(Camera.handle) do

            DisableAllControlActions(0)

            SetEntityLocallyInvisible(PlayerPedId())

            DrawRect(0.5, 0.5, 0.003, 0.005, 255, 255, 255, 200)

            local xMouse = GetDisabledControlNormal(0, 1) * (Config.Camera.mouseSensitivity or 4.0)
            local yMouse = GetDisabledControlNormal(0, 2) * (Config.Camera.mouseSensitivity or 4.0)

            local pitchUp = Config.Camera.pitchUp or 15.0
            local pitchDown = Config.Camera.pitchDown or 28.0
            local yawRange = Config.Camera.yawRange or 20.0

            Camera.currentRot = vec3(
                Clamp(Camera.currentRot.x - yMouse, Camera.initialRot.x - pitchDown, Camera.initialRot.x + pitchUp),
                Camera.currentRot.y,
                Clamp(Camera.currentRot.z - xMouse, Camera.initialRot.z - yawRange, Camera.initialRot.z + yawRange)
            )

            SetCamRot(Camera.handle, Camera.currentRot.x, Camera.currentRot.y, Camera.currentRot.z, 2)

            local hoveredButton = GetButtonAtScreenCenter()

            if hoveredButton ~= prevButtonId then
                ATM_DUI.HighlightButton(hoveredButton)
                prevButtonId = hoveredButton
            end

            if IsDisabledControlJustPressed(0, 24) and hoveredButton then
                Camera.OnButtonClick(hoveredButton)
            end

            if hoveredButton then
                for _, btn in ipairs(Camera.cachedButtonCoords) do
                    if btn.id == hoveredButton then

                        DrawMarker(28,
                            btn.worldPos.x, btn.worldPos.y, btn.worldPos.z,
                            0, 0, 0, 0, 0, 0,
                            0.015, 0.015, 0.015,
                            0, 201, 167, 200,
                            false, false, 2, false, nil, nil, false
                        )
                        break
                    end
                end
            end

            if Camera.debugMode then
                for _, btn in ipairs(Camera.cachedButtonCoords) do
                    local isHovered = (btn.id == hoveredButton)
                    local r = isHovered and 0 or 255
                    local g = isHovered and 255 or 0
                    local b = isHovered and 0 or 255
                    DrawMarker(28,
                        btn.worldPos.x, btn.worldPos.y, btn.worldPos.z,
                        0, 0, 0, 0, 0, 0,
                        0.015, 0.015, 0.015,
                        r, g, b, 180,
                        false, false, 2, false, nil, nil, false
                    )
                end
            end

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) then
                Camera.TransitionBack()
                break
            end

            Wait(0)
        end
    end)
end

function Camera.OnButtonClick(buttonId)

    if Config.Sounds.enabled then

        if buttonId:match('^side_') then
            PlaySoundFrontend(-1, 'ATM_WINDOW', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        else
            PlaySoundFrontend(-1, 'PIN_BUTTON', 'ATM_SOUNDS', true)
        end
    end

    ATM_DUI.ClickButton(buttonId)

    TriggerEvent('atmdui:client:buttonClicked', buttonId)
end

function Camera.TransitionBack()
    if not Camera.isActive then return end

    Camera.isActive = false

    if DoesCamExist(Camera.handle) then
        RenderScriptCams(false, true, Config.Camera.transitionTime, true, true)
        DestroyCam(Camera.handle, false)
        Camera.handle = nil
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    Whip.core:SetScreenOpen(false, 'atm')

    ATM_DUI.HighlightButton(nil)

    Camera.targetATM = nil
    Camera.currentATMModel = nil
    Camera.atmCoords = nil
    Camera.atmHeadingQuat = nil
    Camera.cachedButtonCoords = {}
    Camera.initialRot = vec3(0, 0, 0)
    Camera.currentRot = vec3(0, 0, 0)

    TriggerEvent('atmdui:client:sessionEnded')
end

_G.ATM_Camera = Camera

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Camera.isActive then
        Camera.TransitionBack()
    end
end)
