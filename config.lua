Config = {}

-- Vehicle model for the facial recognition van
Config.VehicleModel = 'speedo'

-- Scan settings
Config.ScanRadius = 25.0           -- Distance camera can see (25m realistic for LFR)
Config.ScanInterval = 2000         -- Milliseconds between scans
Config.MaxResults = 12             -- Maximum faces to display in history

-- Camera settings
Config.CameraConeAngle = 30.0      -- Field of view cone angle (degrees)
Config.CameraHeightOffset = 2.5    -- Camera height above vehicle (meters)
Config.CameraForwardOffset = 1.0   -- Camera position forward on vehicle (meters)
Config.CameraRotationSpeed = 0.8   -- Slow pan/tilt speed (degrees per frame)
Config.CameraZoomSpeed = 0.5       -- Zoom speed multiplier

-- Recognition settings
Config.AlertChance = 0.15          -- Chance a scanned person has an alert (15%)
Config.WantedChance = 0.08         -- Chance person is wanted (8%)

-- Alert types with UK police terminology
Config.AlertTypes = {
    { code = 'WANTED', label = 'Wanted Person', severity = 'high', color = '#dc2626' },
    { code = 'MISSING', label = 'Missing Person', severity = 'medium', color = '#f59e0b' },
    { code = 'PERSON-INT', label = 'Person of Interest', severity = 'medium', color = '#f59e0b' },
    { code = 'KNOWN-LOC', label = 'Known to Police', severity = 'low', color = '#3b82f6' },
    { code = 'INTEL', label = 'Intelligence Flag', severity = 'low', color = '#8b5cf6' },
}

-- UK regions for fake citizen data
Config.Regions = {
    'London', 'Manchester', 'Birmingham', 'Leeds', 'Liverpool',
    'Bristol', 'Sheffield', 'Newcastle', 'Nottingham', 'Glasgow'
}

-- UK style postcodes
Config.PostcodeAreas = {
    'SW1A', 'M1', 'B1', 'LS1', 'L1', 'BS1', 'S1', 'NE1', 'NG1', 'G1'
}
