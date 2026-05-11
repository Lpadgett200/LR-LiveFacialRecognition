---@class PedNetId
---@field netId number
---@field model number
---@field distance number

---@class ScanResultServer
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

-- UK style first names
local firstNames = {
    male = { 'James', 'Oliver', 'George', 'Harry', 'Jack', 'Noah', 'Leo', 'Arthur', 'Muhammad', 'Thomas',
              'Oscar', 'Henry', 'Freddie', 'Charlie', 'Theo', 'Alfie', 'Jacob', 'Lucas', 'William', 'Archie' },
    female = { 'Olivia', 'Amelia', 'Isla', 'Ava', 'Ivy', 'Freya', 'Lily', 'Charlotte', 'Willow', 'Mia',
                'Florence', 'Harper', 'Sofia', 'Evie', 'Grace', 'Elsie', 'Ruby', 'Ella', 'Alice', 'Poppy' }
}

-- UK style last names
local lastNames = {
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller', 'Davis', 'Wilson', 'Anderson', 'Taylor',
    'Thomas', 'Moore', 'Jackson', 'Martin', 'Lee', 'Thompson', 'White', 'Harris', 'Clark', 'Lewis',
    'Robinson', 'Walker', 'Young', 'Allen', 'King', 'Wright', 'Scott', 'Green', 'Baker', 'Adams',
    'Nelson', 'Hill', 'Campbell', 'Mitchell', 'Roberts', 'Carter', 'Phillips', 'Evans', 'Turner', 'Khan',
    'Patel', 'Singh', 'Shah', 'Ahmed', 'Ali', 'Begum', 'Hussain', 'Khan', 'Malik', 'Nawaz'
}

-- Physical descriptions
local hairColors = { 'Black', 'Brown', 'Blonde', 'Dark Brown', 'Grey', 'Auburn', 'Ginger', 'Dark' }
local eyeColors = { 'Brown', 'Blue', 'Green', 'Hazel', 'Grey' }
local buildTypes = { 'Slim', 'Average', 'Athletic', 'Heavy', 'Muscular' }

-- Generate a unique citizen ID
local citizenIdCounter = 100000
local function generateCitizenId()
    citizenIdCounter = citizenIdCounter + math.random(1, 5)
    return string.format('UK-%d-MET', citizenIdCounter)
end

-- Generate fake citizen data
local function generateCitizenData(pedData)
    local gender = math.random() > 0.5 and 'male' or 'female'
    local firstName = firstNames[gender][math.random(1, #firstNames[gender])]
    local lastName = lastNames[math.random(1, #lastNames)]
    
    local age = math.random(18, 65)
    local region = Config.Regions[math.random(1, #Config.Regions)]
    local postcodePrefix = Config.PostcodeAreas[math.random(1, #Config.PostcodeAreas)]
    local postcodeSuffix = string.format('%d %s', math.random(1, 9), string.char(math.random(65, 90)) .. string.char(math.random(65, 90)))
    
    -- Determine if person has an alert
    local alertType = nil
    local hasAlert = math.random() < Config.AlertChance
    
    if hasAlert then
        alertType = Config.AlertTypes[math.random(1, #Config.AlertTypes)]
    end
    
    local confidence = math.random(78, 99)
    local hair = hairColors[math.random(1, #hairColors)]
    local eyes = eyeColors[math.random(1, #eyeColors)]
    local build = buildTypes[math.random(1, #buildTypes)]
    local height = gender == 'male' and math.random(165, 195) or math.random(155, 180)
    
    return {
        id = generateCitizenId(),
        name = string.format('%s %s', firstName, lastName),
        age = age,
        region = region,
        postcode = string.format('%s %s', postcodePrefix, postcodeSuffix),
        alertType = alertType,
        gender = gender,
        description = string.format('%s, %dcm, %s hair, %s eyes, %s build', 
            gender == 'male' and 'Male' or 'Female', height, hair, eyes, build),
        confidence = confidence,
        distance = pedData.distance or 0
    }
end

-- Store for player data (in a real system this would be database)
local playerDatabase = {}

-- Get or create player citizen data
local function getPlayerCitizenData(serverId)
    if playerDatabase[serverId] then
        return playerDatabase[serverId]
    end
    
    -- Generate new citizen data for player
    local gender = math.random() > 0.5 and 'male' or 'female'
    local firstName = firstNames[gender][math.random(1, #firstNames[gender])]
    local lastName = lastNames[math.random(1, #lastNames)]
    
    local data = {
        id = generateCitizenId(),
        name = string.format('%s %s', firstName, lastName),
        age = math.random(18, 45),
        region = Config.Regions[math.random(1, #Config.Regions)],
        postcode = string.format('%s %d %s', 
            Config.PostcodeAreas[math.random(1, #Config.PostcodeAreas)],
            math.random(1, 9),
            string.char(math.random(65, 90)) .. string.char(math.random(65, 90))),
        alertType = nil,
        gender = gender,
        description = 'Local resident',
        confidence = 95,
        distance = 0
    }
    
    playerDatabase[serverId] = data
    return data
end

-- Handle scan request from client
RegisterNetEvent('facialrec:server:scan', function(pedNetIds, playerServerIds)
    local src = source
    local results = {}
    local count = 0
    
    -- Process AI peds
    for _, pedData in ipairs(pedNetIds) do
        if count >= Config.MaxResults then break end
        
        local entity = NetworkGetEntityFromNetworkId(pedData.netId)
        if entity and entity ~= 0 then
            local citizenData = generateCitizenData(pedData)
            citizenData.distance = pedData.distance
            citizenData.netId = pedData.netId -- Include netId for lock-on
            results[#results + 1] = citizenData
            count = count + 1
        end
    end
    
    -- Process players
    for _, serverId in ipairs(playerServerIds) do
        if count >= Config.MaxResults then break end
        
        local playerData = getPlayerCitizenData(serverId)
        playerData.distance = GetEntityCoords(NetworkGetEntityFromNetworkId(serverId))
        results[#results + 1] = playerData
        count = count + 1
    end
    
    -- Send results back to client
    TriggerClientEvent('facialrec:client:results', src, results)
end)

-- Clear player data on resource stop (optional cleanup)
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        playerDatabase = {}
    end
end)
