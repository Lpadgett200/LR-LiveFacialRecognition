---@class FaceData
---@field ped number
---@field coords vector3
---@field distance number
---@field model number
---@field isPlayer boolean
---@field serverId number|nil

---@class ScanResult
---@field id number
---@field name string
---@field age number
---@field region string
---@field postcode string
---@field alertType table|nil
---@field gender string
---@field description string
---@field confidence number
---@field distance number

-- Camera state
local cameraActive = false
local cameraHandle = nil
local cameraYaw = 0.0
local cameraPitch = 0.0
local manualMode = false
local lastSnapTime = 0
local activeHeadshots = {} -- Track headshots for cleanup

-- Settings
local SNAP_COOLDOWN = 1000
local FOV_SCAN = 50.0

-- Get vehicle camera position
local function getCameraOrigin(vehicle)
    local vehCoords = GetEntityCoords(vehicle)
    local vehRot = GetEntityRotation(vehicle, 2)
    local forward = GetEntityForwardVector(vehicle)
    
    -- Camera mounted on roof, slightly forward
    local camPos = vehCoords + vector3(0, 0, Config.CameraHeightOffset) + (forward * Config.CameraForwardOffset)
    
    return camPos, vehRot.z
end

-- Get camera forward direction based on yaw and pitch
local function getCameraDirection(yaw, pitch)
    local radYaw = math.rad(yaw)
    local radPitch = math.rad(pitch)
    
    local x = -math.sin(radYaw) * math.cos(radPitch)
    local y = math.cos(radYaw) * math.cos(radPitch)
    local z = math.sin(radPitch)
    
    return vector3(x, y, z)
end

-- Create the camera
local function createCamera(vehicle)
    local camPos, vehYaw = getCameraOrigin(vehicle)
    
    cameraHandle = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", 
        camPos.x, camPos.y, camPos.z,
        cameraPitch, 0, cameraYaw + vehYaw,
        FOV_SCAN, false, 0)
    
    SetCamActive(cameraHandle, true)
    RenderScriptCams(true, true, 500, true, false)
    
    return cameraHandle
end

-- Update camera position and rotation
local function updateCamera(vehicle)
    if not cameraHandle then return end
    
    local camPos, vehYaw = getCameraOrigin(vehicle)
    local totalYaw = cameraYaw + vehYaw
    
    -- Update camera position
    SetCamCoord(cameraHandle, camPos.x, camPos.y, camPos.z)
    SetCamRot(cameraHandle, cameraPitch, 0.0, totalYaw, 2)
end

-- Destroy the camera
local function destroyCamera()
    if cameraHandle then
        SetCamActive(cameraHandle, false)
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(cameraHandle, false)
        cameraHandle = nil
    end
    
    -- Cleanup headshots
    for _, handle in ipairs(activeHeadshots) do
        UnregisterPedheadshot(handle)
    end
    activeHeadshots = {}
    
    cameraActive = false
    manualMode = false
end

-- Generate ped headshot texture
local function generatePedHeadshot(ped)
    -- Register transparent headshot
    local handle = RegisterPedheadshotTransparent(ped)
    
    if not handle then return nil end
    
    -- Wait for headshot to be ready (max 2 seconds)
    local timeout = 0
    while not IsPedheadshotReady(handle) and timeout < 2000 do
        Wait(50)
        timeout = timeout + 50
    end
    
    if not IsPedheadshotReady(handle) then
        UnregisterPedheadshot(handle)
        return nil
    end
    
    -- Get texture dictionary name
    local txd = GetPedheadshotTxdString(handle)
    
    if not txd then
        UnregisterPedheadshot(handle)
        return nil
    end
    
    -- Store handle for later cleanup
    activeHeadshots[#activeHeadshots + 1] = handle
    
    return {
        handle = handle,
        txd = txd,
        txn = txd -- For nui-img, txd and txn are the same for pedheadshots
    }
end

-- UK Name lists by gender
local maleFirstNames = { 'James', 'Oliver', 'George', 'Harry', 'Jack', 'Thomas', 'William', 'Charlie', 'Daniel', 'Matthew', 'Joshua', 'Samuel', 'Joseph', 'David', 'Andrew' }
local femaleFirstNames = { 'Olivia', 'Amelia', 'Isla', 'Ava', 'Ivy', 'Emily', 'Sophie', 'Grace', 'Ruby', 'Evie', 'Charlotte', 'Lily', 'Mia', 'Isabella', 'Freya' }
local lastNames = { 'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller', 'Davis', 'Wilson', 'Taylor', 'Thomas', 'Martinez', 'Anderson', 'Thompson', 'Garcia', 'Robinson', 'Clark', 'Rodriguez', 'Lewis', 'Lee', 'Walker', 'Hall', 'Allen', 'Young', 'Hill', 'Moore' }
local regions = { 'London', 'Manchester', 'Birmingham', 'Leeds', 'Liverpool', 'Bristol', 'Sheffield', 'Newcastle', 'Nottingham', 'Glasgow' }

-- Notes storage (citizen ID -> note)
local citizenNotes = {}

-- Generate ped data with gender-accurate names
local localCitizenCounter = 500000
local function generatePedData(ped, distance)
    localCitizenCounter = localCitizenCounter + 1
    
    -- Detect actual ped gender
    local gender = 'male'
    if not IsPedMale(ped) then
        gender = 'female'
    end
    
    -- Select name based on gender
    local firstName
    if gender == 'male' then
        firstName = maleFirstNames[math.random(1, #maleFirstNames)]
    else
        firstName = femaleFirstNames[math.random(1, #femaleFirstNames)]
    end
    
    local lastName = lastNames[math.random(1, #lastNames)]
    local age = math.random(18, 65)
    local region = regions[math.random(1, #regions)]
    
    -- Determine if has alert
    local alertType = nil
    if math.random() < Config.AlertChance then
        alertType = Config.AlertTypes[math.random(1, #Config.AlertTypes)]
    end
    
    local confidence = math.random(70, 98)
    local citizenId = string.format('UK-%d', localCitizenCounter)
    
    local result = {
        id = citizenId,
        name = string.format('%s %s', firstName, lastName),
        age = age,
        region = region,
        postcode = string.format('SW%d %s', math.random(1, 9), string.char(math.random(65, 90)) .. string.char(math.random(65, 90))),
        alertType = alertType,
        gender = gender,
        description = string.format('%s, local resident', gender == 'male' and 'Male' or 'Female'),
        confidence = confidence,
        distance = distance,
        note = citizenNotes[citizenId] or ''
    }
    
    -- If networked, include netId
    if NetworkGetEntityIsNetworked(ped) then
        result.netId = NetworkGetNetworkIdFromEntity(ped)
    end
    
    return result
end

-- Snap single ped at camera center (async with screenshot)
local pendingSnap = nil

local function sendSnapResult(result)
    print('[LFR] sendSnapResult called with:', result.name)
    
    -- Set focus so player can interact with snap UI
    SetNuiFocus(true, true)
    
    -- Send single result to UI
    local message = json.encode({ action = 'snapResult', data = { result = result } })
    print('[LFR] Sending NUI message:', message:sub(1, 200))
    SendNuiMessage(message)
    
    print('[LFR] Result sent to UI')
end

local function snapPedAtCenter(vehicle)
    local now = GetGameTimer()
    if now - lastSnapTime < SNAP_COOLDOWN then 
        print('[LFR] Snap on cooldown')
        return 
    end
    
    lastSnapTime = now
    
    local camPos, vehYaw = getCameraOrigin(vehicle)
    local camDir = getCameraDirection(cameraYaw + vehYaw, cameraPitch)
    
    local playerPed = PlayerPedId()
    
    -- Raycast forward from camera
    local maxDist = Config.ScanRadius
    local dest = camPos + (camDir * maxDist)
    
    print('[LFR] Raycasting from camera...')
    print('  CamPos:', camPos.x, camPos.y, camPos.z)
    print('  Direction:', camDir.x, camDir.y, camDir.z)
    
    local rayHandle = StartShapeTestRay(
        camPos.x, camPos.y, camPos.z,
        dest.x, dest.y, dest.z,
        1 + 2 + 4 + 8, -- world, vehicles, peds, objects
        playerPed, 0
    )
    
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    
    print('[LFR] Raycast result - hit:', hit, 'entity:', entityHit)
    
    if hit and DoesEntityExist(entityHit) then
        local isPed = IsEntityAPed(entityHit)
        print('[LFR] Entity exists, isPed:', isPed)
        
        if isPed and not IsPedDeadOrDying(entityHit) and entityHit ~= playerPed then
            local distance = #(camPos - endCoords)
            print('[LFR] Valid ped found! Distance:', distance)
            
            local result = generatePedData(entityHit, distance)
            print('[LFR] Generated data for:', result.name)
            
            -- Generate headshot texture for the ped
            local headshot = generatePedHeadshot(entityHit)
            if headshot then
                result.headshotTxd = headshot.txd
                result.headshotHandle = headshot.handle
                print('[LFR] Headshot generated:', headshot.txd)
            else
                print('[LFR] Headshot generation failed')
            end
            
            -- Capture screenshot using screenshot-basic
            local screenshotReady = GetResourceState('screenshot-basic') == 'started'
            print('[LFR] Screenshot-basic ready:', screenshotReady)
            
            if screenshotReady then
                -- Set a timeout in case screenshot fails
                local sent = false
                SetTimeout(3000, function()
                    if not sent then
                        print('[LFR] Screenshot timeout, sending without image')
                        sendSnapResult(result)
                    end
                end)
                
                exports['screenshot-basic']:requestScreenshot(function(data)
                    sent = true
                    print('[LFR] Screenshot captured, sending result...')
                    -- Add data URL prefix for HTML img tag compatibility
                    result.sceneImage = 'data:image/png;base64,' .. data
                    sendSnapResult(result)
                end)
            else
                -- No screenshot resource, send immediately
                print('[LFR] Sending result without screenshot...')
                sendSnapResult(result)
            end
            return
        end
    end
    
    -- No valid ped found
    print('[LFR] No valid ped found in view')
    TriggerEvent('ox_lib:notify', {
        title = 'LFR',
        description = 'No subject detected',
        type = 'warning'
    })
end

-- Camera control thread
local function cameraControlThread(vehicle)
    CreateThread(function()
        while cameraActive do
            -- Check if player still in vehicle
            local playerPed = PlayerPedId()
            local currentVeh = GetVehiclePedIsIn(playerPed, false)
            
            if currentVeh ~= vehicle then
                destroyCamera()
                SetNuiFocus(false, false)
                SendNuiMessage(json.encode({ action = 'close', data = {} }))
                break
            end
            
            -- Arrow key controls for pan/tilt (slowed down)
            local rotSpeed = Config.CameraRotationSpeed or 0.8
            
            if IsControlPressed(0, 172) then -- Up arrow
                cameraPitch = math.max(-45, cameraPitch - rotSpeed)
            end
            if IsControlPressed(0, 173) then -- Down arrow
                cameraPitch = math.min(15, cameraPitch + rotSpeed)
            end
            if IsControlPressed(0, 174) then -- Left arrow
                cameraYaw = cameraYaw - rotSpeed
            end
            if IsControlPressed(0, 175) then -- Right arrow
                cameraYaw = cameraYaw + rotSpeed
            end
            
            -- ENTER to snap (control 201 = INPUT_FRONTEND_ACCEPT)
            if IsControlJustPressed(0, 201) or IsControlJustPressed(0, 18) then -- ENTER or standard Enter
                if manualMode then
                    -- Visual feedback
                    TriggerEvent('ox_lib:notify', {
                        title = 'Scanning...',
                        description = 'Capturing subject',
                        type = 'inform',
                        duration = 1500
                    })
                    snapPedAtCenter(vehicle)
                end
            end
            
            -- BACKSPACE to exit manual mode (control 194 = INPUT_FRONTEND_RRIGHT)
            if IsControlJustPressed(0, 194) or IsControlJustPressed(0, 200) then -- BACKSPACE or Escape
                if manualMode then
                    destroyCamera()
                    SetNuiFocus(false, false)
                    SendNuiMessage(json.encode({ action = 'close', data = {} }))
                end
            end
            
            -- Update camera
            updateCamera(vehicle)
            
            Wait(0)
        end
    end)
end

-- Start manual mode
local function startManualMode()
    if cameraActive then return end
    
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        TriggerEvent('ox_lib:notify', {
            title = 'Facial Recognition',
            description = 'You must be in the recognition vehicle',
            type = 'error'
        })
        return
    end
    
    local vehicleModel = GetEntityModel(vehicle)
    local configModel = GetHashKey(Config.VehicleModel)
    
    if vehicleModel ~= configModel then
        TriggerEvent('ox_lib:notify', {
            title = 'Facial Recognition',
            description = 'This vehicle is not equipped with facial recognition',
            type = 'error'
        })
        return
    end
    
    cameraActive = true
    manualMode = true
    cameraYaw = 0.0
    cameraPitch = -15.0
    
    -- Release NUI focus FIRST so controls work
    SetNuiFocus(false, false)
    
    -- Create camera
    createCamera(vehicle)
    
    -- Start control thread
    cameraControlThread(vehicle)
    
    -- Send message to UI (overlay only, no focus)
    SendNuiMessage(json.encode({ action = 'open', data = { mode = 'manual' } }))
    
    -- Confirm manual mode is active
    TriggerEvent('ox_lib:notify', {
        title = 'LFR Camera Active',
        description = 'Use arrow keys to aim, ENTER to snap',
        type = 'inform',
        duration = 3000
    })
end

-- Stop camera mode
local function stopCameraMode()
    destroyCamera()
    NUI.Close()
end

-- UI Callbacks
RegisterNuiCallback('startManual', function(_, cb)
    startManualMode()
    cb({ success = true })
end)

RegisterNuiCallback('snap', function(_, cb)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle ~= 0 and cameraActive then
        snapPedAtCenter(vehicle)
    elseif not cameraActive then
        -- If camera not active, try to start it
        local configModel = GetHashKey(Config.VehicleModel)
        if vehicle ~= 0 and GetEntityModel(vehicle) == configModel then
            snapPedAtCenter(vehicle)
        end
    end
    
    cb({ success = true })
end)

RegisterNuiCallback('returnToMenu', function(_, cb)
    -- Destroy camera and return to menu with focus
    destroyCamera()
    SetNuiFocus(true, true) -- Menu needs focus for clicking
    SendNuiMessage(json.encode({ action = 'returnToMenu', data = {} }))
    cb({ success = true })
end)

RegisterNuiCallback('close', function(_, cb)
    stopCameraMode()
    cb({ success = true })
end)

RegisterNuiCallback('rotateCamera', function(data, cb)
    if not cameraActive then
        cb({ success = false })
        return
    end
    
    cameraYaw = math.max(-90, math.min(90, cameraYaw + (data.yaw or 0)))
    cameraPitch = math.max(-45, math.min(15, cameraPitch + (data.pitch or 0)))
    
    cb({ success = true, yaw = cameraYaw, pitch = cameraPitch })
end)

RegisterNuiCallback('markWanted', function(data, cb)
    -- In a real system, this would update a database
    TriggerEvent('ox_lib:notify', {
        title = 'Enforcement',
        description = 'Subject marked as wanted',
        type = 'warning'
    })
    cb({ success = true })
end)

RegisterNuiCallback('saveNote', function(data, cb)
    if not data.id or not data.note then
        cb({ success = false })
        return
    end
    
    -- Store note for this citizen
    citizenNotes[data.id] = data.note
    
    TriggerEvent('ox_lib:notify', {
        title = 'Notes Updated',
        description = 'Note saved successfully',
        type = 'success'
    })
    
    cb({ success = true, note = data.note })
end)

RegisterNuiCallback('getNote', function(data, cb)
    if not data.id then
        cb({ success = false })
        return
    end
    
    cb({ success = true, note = citizenNotes[data.id] or '' })
end)

-- Add ox_target option to vehicle
local function addTargetToVehicle()
    exports.ox_target:addModel(Config.VehicleModel, {
        {
            name = 'facialrec_open',
            icon = 'fa-solid fa-video',
            label = 'Activate LFR Camera',
            distance = 3.0,
            onSelect = function(data)
                local vehicle = data.entity
                local playerPed = PlayerPedId()
                
                -- Check if player is in the vehicle
                local currentVeh = GetVehiclePedIsIn(playerPed, false)
                if currentVeh ~= vehicle then
                    TriggerEvent('ox_lib:notify', {
                        title = 'Facial Recognition',
                        description = 'Enter the vehicle to operate the camera',
                        type = 'warning'
                    })
                    return
                end
                
                startManualMode()
            end
        }
    })
end

-- Initialize on resource start
CreateThread(function()
    Wait(500)
    addTargetToVehicle()
end)

-- Command to open camera mode
RegisterCommand('facialrec', function()
    startManualMode()
end, false)

-- Command to close
RegisterCommand('facialrecclose', function()
    stopCameraMode()
end, false)
