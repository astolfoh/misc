--// Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

--// Variables
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

--// Optimizations
local math_huge = math.huge
local math_random = math.random
local tick = tick
local os_clock = os.clock

--// Internal State
local CurrentTarget = nil
local Holding = false
local ExpanderActive = false 
local LastShotTime = 0
local LastThrottleTime = 0

--// Prebuilt Raycast Params
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Blacklist
RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}

--// Wall Check
local function WallCheck(part)
    if not part then return false end

    local result = Workspace:Raycast(
        Camera.CFrame.Position,
        (part.Position - Camera.CFrame.Position).Unit * 1000,
        RayParams
    )

    return result and result.Instance and result.Instance:IsDescendantOf(part.Parent)
end

--// Perform Checks
local function PerformChecks(player, character, isSelecting)
    if not player or not character then
        return false
    end

    local checks = isSelecting and Config['Main']['Checks']['Selecting'] or Config['Main']['Checks']['Target']
    if not checks then
        return false
    end

    if checks['Knocked'] then
        local bodyEffects = character:FindFirstChild("BodyEffects")
        local ko = bodyEffects and bodyEffects:FindFirstChild("K.O")
        if ko and ko.Value then
            return false
        end
    end

    if checks['SelfKnocked'] then
        local selfCharacter = LocalPlayer.Character
        local selfBodyEffects = selfCharacter and selfCharacter:FindFirstChild("BodyEffects")
        local selfKo = selfBodyEffects and selfBodyEffects:FindFirstChild("K.O")
        if selfKo and selfKo.Value then
            return false
        end
    end

    if checks['Visible'] then
        local root = character:FindFirstChild("HumanoidRootPart")
        if root and not WallCheck(root) then
            return false
        end
    end

    if checks['CrewCheck'] then
        local localData = LocalPlayer:FindFirstChild("DataFolder")
        local targetData = player:FindFirstChild("DataFolder")
        if localData and targetData then
            local localCrew = localData:FindFirstChild("Information") and localData.Information:FindFirstChild("Crew")
            local targetCrew = targetData:FindFirstChild("Information") and targetData.Information:FindFirstChild("Crew")
            if localCrew and targetCrew and localCrew.Value ~= "" and targetCrew.Value ~= "" then
                if localCrew.Value == targetCrew.Value then
                    return false
                end
            end
        end
    end

    return true
end

--// Target System
local function GetClosestPlayer()
    local closestPlayer = nil
    local closestDistance = math_huge
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = player.Character.HumanoidRootPart
            local screenPoint, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local playerPos = Vector2.new(screenPoint.X, screenPoint.Y)
                local distance = (mousePos - playerPos).Magnitude
                if distance < closestDistance then
                    if PerformChecks(player, player.Character, true) then
                        closestDistance = distance
                        closestPlayer = player
                    end
                end
            end
        end
    end

    return closestPlayer
end

local function ValidateTarget()
    if not CurrentTarget or not CurrentTarget.Character or not CurrentTarget.Character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    return PerformChecks(CurrentTarget, CurrentTarget.Character, false)
end

local function SelectTarget()
    CurrentTarget = GetClosestPlayer()

    if Config['Main']['Debug'] then
        if CurrentTarget then
            print("[Triggerbot] Targeted:", CurrentTarget.Name)
        else
            print("[Triggerbot] No valid target found. Press the key again.")
        end
    end

    if not CurrentTarget then
        Holding = false -- stop trying to fire when no target
    end
end

local function UnselectTarget()
    if Config['Main']['Debug'] and CurrentTarget then
        print("[Triggerbot] Untargeted:", CurrentTarget.Name)
    end
    CurrentTarget = nil
end

--// Firing System
local function FireTrigger()
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool and tool.Name == "[Knife]" then
        return 
    end

    if Config['Main']['Debug'] then
        print("[Triggerbot] Fired Shot")
    end

    if Config['Triggerbot']['Method'] == "MouseClick" then
        mouse1press()
        task.wait(0.005)
        mouse1release()
    elseif Config['Triggerbot']['Method'] == "VirtualInput" then
        VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, true, game, 0)
        task.wait(0.005)
        VirtualInputManager:SendMouseButtonEvent(Mouse.X, Mouse.Y, 0, false, game, 0)
    end
end

--// Throttle System
local function IsThrottled()
    local now = os_clock()
    if now - LastThrottleTime >= 0.01 then 
        LastThrottleTime = now
        return false
    end
    return true
end

--// Delay System
local function CanShoot()
    if not Config['Triggerbot']['Delay']['Enabled'] then
        return true
    end

    local now = tick()
    local min = Config['Triggerbot']['Delay']['Min']
    local max = Config['Triggerbot']['Delay']['Max']
    local delay = math_random() * (max - min) + min

    if now - LastShotTime >= delay then
        LastShotTime = now
        return true
    end

    return false
end

--// Main Triggerbot Logic
       RunService.RenderStepped:Connect(function()
    if not Config['Main']['Enabled'] or not Config['Triggerbot']['Enabled'] then
        return
    end

    if not Holding then
        return
    end

    if IsThrottled() then
        return
    end

    if not CurrentTarget then
        return
    end

    if not ValidateTarget() then
        UnselectTarget()
        return
    end

    local targetPart = Mouse.Target

    if Config['Main']['TargetMode'] then
        if CurrentTarget and CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart") then
            if Mouse.Target and Mouse.Target:IsDescendantOf(CurrentTarget.Character) then
                if CanShoot() then
                    FireTrigger()
                end
            end
        end
    else
        if targetPart then
            local player = Players:GetPlayerFromCharacter(targetPart:FindFirstAncestorOfClass("Model"))
            if player and player ~= LocalPlayer and PerformChecks(player, player.Character, false) then
                if CanShoot() then
                    FireTrigger()
                end
            end
        end
    end
end)

--// Camlock State
local CamlockHolding = false
local CamlockEnabled = false
local CamlockLockedTarget = nil

--// Camlock Apply Smooth
local function ApplyCamlockSmoothing(targetPos)
    local mode = Config['Camlock']['Smoothness']['Mode']
    local smoothX = Config['Camlock']['Smoothness']['X']
    local smoothY = Config['Camlock']['Smoothness']['Y']

    local camPos = Camera.CFrame.Position
    local direction = (targetPos - camPos).Unit
    local currentLook = Camera.CFrame.LookVector

    if mode == "None" then
        local blended = Vector3.new(
            currentLook.X + (direction.X - currentLook.X) * smoothX,
            currentLook.Y + (direction.Y - currentLook.Y) * smoothY,
            currentLook.Z + (direction.Z - currentLook.Z) * ((smoothX + smoothY) / 2)
        ).Unit
        return CFrame.new(camPos, camPos + blended)
    else
        local blended = currentLook:Lerp(direction, (smoothX + smoothY) / 2)
        return CFrame.new(camPos, camPos + blended)
    end
end

--// Camlock Main Logic
RunService.RenderStepped:Connect(function()
    if not Config['Main']['Enabled'] or not Config['Camlock']['Enabled'] then
        return
    end

    local bindMode = Config['Main']['BindMode']
    local active = (bindMode == "Hold" and CamlockHolding) or (bindMode == "Toggle" and CamlockEnabled)
    if not active then
        return
    end

    if not CurrentTarget then
        return
    end

    if not ValidateTarget() then
        UnselectTarget()
        return
    end

    local character = CurrentTarget and CurrentTarget.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        UnselectTarget()
        return
    end

    if not PerformChecks(CurrentTarget, character, false) then
        UnselectTarget()
        return
    end

    local isFirstPerson = (Camera.Focus.Position - Camera.CFrame.Position).Magnitude < 1
    if isFirstPerson and not Config['Camlock']['Toggle']['FirstPerson'] then
        return
    end
    if not isFirstPerson and not Config['Camlock']['Toggle']['ThirdPerson'] then
        return
    end

    local hitPart = character:FindFirstChild(Config['Camlock']['HitPart'])
    if not hitPart then
        return
    end

    Camera.CFrame = ApplyCamlockSmoothing(hitPart.Position)
end)

--// Hitbox Expander

local HitboxAdornment = nil

local function CreateAdornment(part)
    local adornment = Instance.new("BoxHandleAdornment")
    adornment.Name = "HitboxAdornment"
    adornment.Adornee = part
    adornment.AlwaysOnTop = true
    adornment.ZIndex = 5
    adornment.Size = part.Size
    adornment.Color3 = Color3.new(1, 1, 1) -- Grey
    adornment.Transparency = 0.5
    adornment.Parent = part
    return adornment
end

RunService.RenderStepped:Connect(function()
    if not Config['Main']['Enabled'] or not Config['HitboxExpander']['Enabled'] then
        if HitboxAdornment then
            HitboxAdornment:Destroy()
            HitboxAdornment = nil
        end
        return
    end

    if not ExpanderActive then
        if HitboxAdornment then
            HitboxAdornment:Destroy()
            HitboxAdornment = nil
        end

        -- Restore ALL players to default
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.Material = Enum.Material.Plastic
            end
        end

        return
    end

    if Config['Main']['TargetMode'] then
        if CurrentTarget and CurrentTarget.Character and CurrentTarget.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = CurrentTarget.Character.HumanoidRootPart

            hrp.Size = Vector3.new(
                Config['HitboxExpander']['Size']['X'],
                Config['HitboxExpander']['Size']['Y'],
                Config['HitboxExpander']['Size']['Z']
            )

            if Config['HitboxExpander']['Visible'] then
                hrp.Transparency = 1 -- Visible box
                if not HitboxAdornment then
                    HitboxAdornment = CreateAdornment(hrp)
                end
                HitboxAdornment.Adornee = hrp
                HitboxAdornment.Size = hrp.Size
            else
                hrp.Transparency = 1 -- Fully invisible HRP
                if HitboxAdornment then
                    HitboxAdornment:Destroy()
                    HitboxAdornment = nil
                end
            end
        end
    else
        -- Free Aim Mode
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = player.Character.HumanoidRootPart
                hrp.Size = Vector3.new(
                    Config['HitboxExpander']['Size']['X'],
                    Config['HitboxExpander']['Size']['Y'],
                    Config['HitboxExpander']['Size']['Z']
                )
                hrp.Transparency = Config['HitboxExpander']['Visible'] and 0 or 1
            end
        end
    end
end)

    --// Spread Modifier Hook
local function GetWeaponSpreadReduction(weaponName)
    if not Config['SpreadModifier']['Enabled'] then
        return 0
    end
    local spreadSettings = Config['SpreadModifier']['Weapons']
    return spreadSettings[weaponName] and (spreadSettings[weaponName]['Multiplier'] * 100) or 0
end

local OriginalRandom
OriginalRandom = hookfunction(math.random, function(...)
    -- Only intercept if spread modifier is enabled
    if not Config['Main']['Enabled'] or not Config['SpreadModifier']['Enabled'] then
        return OriginalRandom(...)
    end

    -- Get the calling script directly from debug info
    local info = debug.getinfo(2, "f")
    if not info or not info.func then
        return OriginalRandom(...)
    end

    local caller = getfenv(info.func).script
    if not caller or not caller.Parent then
        return OriginalRandom(...)
    end

    -- Check if caller weapon is registered
    local weaponName = caller.Parent.Name
    if Config['SpreadModifier']['Weapons'][weaponName] and select("#", ...) == 0 then
        local reduction = GetWeaponSpreadReduction(weaponName)
        return OriginalRandom(...) * (1 - (reduction / 100))
    end

    return OriginalRandom(...)
end)

--// Bind Handling
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode[Config['Main']['Bind']] then
        if Config['Main']['BindMode'] == "Hold" then
            Holding = true
            CamlockHolding = true
            Config['SpreadModifier']['Enabled'] = true
            ExpanderActive = true

            if Config['Main']['TargetMode'] and not CurrentTarget then
                SelectTarget()
            end

        elseif Config['Main']['BindMode'] == "Toggle" then
            Holding = not Holding
            CamlockEnabled = not CamlockEnabled
            Config['SpreadModifier']['Enabled'] = CamlockEnabled
            ExpanderActive = CamlockEnabled

            if Holding and Config['Main']['TargetMode'] and not CurrentTarget then
                SelectTarget()
            elseif not Holding then
                UnselectTarget()
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode[Config['Main']['Bind']] then
        if Config['Main']['BindMode'] == "Hold" then
            Holding = false
            CamlockHolding = false
            Config['SpreadModifier']['Enabled'] = false
            ExpanderActive = false
            UnselectTarget()
        end
    end
end)

--- ESP


--// ESP Internal Settings
local ESPSettings = {
    NameOffset = Vector3.new(0, 3, 0), -- Name above head
    DistanceOffset = Vector3.new(0, -3, 0), -- Distance below feet
    Font = 2, -- Plex font
    Size = 13, -- Text size
    TracerThickness = 1, -- Tracer line thickness
    TracerFromMouse = true, -- true = From mouse, false = From bottom center
    TracerOffset = Vector2.new(0, 60),
}

--// ESP Folder
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ESPFolder"
ESPFolder.Parent = game:GetService("CoreGui")

local ESPObjects = {}
local ESPEnabled = Config['ESP']['Main']['Enabled']

--// ESP Checks
local function ESPChecks(player, character)
    local checks = Config['ESP']['Main']['Checks']['Players']
    if not checks then
        return false
    end

    if checks['Knocked'] then
        local bodyEffects = character:FindFirstChild("BodyEffects")
        local ko = bodyEffects and bodyEffects:FindFirstChild("K.O")
        if ko and ko.Value then
            return false
        end
    end

    if checks['CrewCheck'] then
        local localData = LocalPlayer:FindFirstChild("DataFolder")
        local targetData = player:FindFirstChild("DataFolder")
        if localData and targetData then
            local localCrew = localData:FindFirstChild("Information") and localData.Information:FindFirstChild("Crew")
            local targetCrew = targetData:FindFirstChild("Information") and targetData.Information:FindFirstChild("Crew")
            if localCrew and targetCrew and localCrew.Value ~= "" and targetCrew.Value ~= "" then
                if localCrew.Value == targetCrew.Value then
                    return false
                end
            end
        end
    end

    return true
end

--// ESP Create
local function CreateESPObject(player)
    if ESPObjects[player] then
        ESPObjects[player]['NameLabel']:Destroy()
        ESPObjects[player]['DistanceLabel']:Destroy()
        ESPObjects[player]['Tracer']:Destroy()
    end

    local nameLabel = Drawing.new("Text")
    nameLabel.Size = ESPSettings.Size
    nameLabel.Font = ESPSettings.Font
    nameLabel.Outline = true
    nameLabel.Center = true
    nameLabel.Color = Color3.new(1, 1, 1)
    nameLabel.Visible = false

    local distanceLabel = Drawing.new("Text")
    distanceLabel.Size = ESPSettings.Size
    distanceLabel.Font = ESPSettings.Font
    distanceLabel.Outline = true
    distanceLabel.Center = true
    distanceLabel.Color = Color3.new(1, 1, 1)
    distanceLabel.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = ESPSettings.TracerThickness
    tracer.Color = Color3.new(1, 1, 1)
    tracer.Visible = false

    ESPObjects[player] = {
        ['NameLabel'] = nameLabel,
        ['DistanceLabel'] = distanceLabel,
        ['Tracer'] = tracer,
    }
end

--// ESP Remove
local function RemoveESPObject(player)
    if ESPObjects[player] then
        ESPObjects[player]['NameLabel']:Destroy()
        ESPObjects[player]['DistanceLabel']:Destroy()
        ESPObjects[player]['Tracer']:Destroy()
        ESPObjects[player] = nil
    end
end

Players.PlayerRemoving:Connect(function(player)
    RemoveESPObject(player)
end)

--// ESP Keybind Toggle
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode[Config['ESP']['Main']['Bind']] then
        ESPEnabled = not ESPEnabled
    end
end)

--// ESP Render Update
RunService.RenderStepped:Connect(function()
    if not ESPEnabled then
        for _, objects in pairs(ESPObjects) do
            objects['NameLabel'].Visible = false
            objects['DistanceLabel'].Visible = false
            objects['Tracer'].Visible = false
        end
        return
    end

    local rawMousePos = Vector2.new(Mouse.X, Mouse.Y)
    local mousePos = rawMousePos + ESPSettings.TracerOffset
    local bottomCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if not ESPObjects[player] then
                CreateESPObject(player)
            end

            local objects = ESPObjects[player]
            local character = player.Character
            local root = character.HumanoidRootPart

            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local nameWorldPos = root.Position + ESPSettings.NameOffset
            local distanceWorldPos = root.Position + ESPSettings.DistanceOffset

            local nameScreenPos, nameOnScreen = Camera:WorldToViewportPoint(nameWorldPos)
            local distanceScreenPos, distanceOnScreen = Camera:WorldToViewportPoint(distanceWorldPos)

            if onScreen and ESPChecks(player, character) then
                local distance = (Camera.CFrame.Position - root.Position).Magnitude

                if Config['ESP']['Visuals']['Name'] then
                    objects['NameLabel'].Position = Vector2.new(nameScreenPos.X, nameScreenPos.Y)
                    objects['NameLabel'].Text = player.Name
                    objects['NameLabel'].Visible = nameOnScreen
                else
                    objects['NameLabel'].Visible = false
                end

                if Config['ESP']['Visuals']['Distance'] then
                    objects['DistanceLabel'].Position = Vector2.new(distanceScreenPos.X, distanceScreenPos.Y)
                    objects['DistanceLabel'].Text = string.format("%.0f studs", distance)
                    objects['DistanceLabel'].Visible = distanceOnScreen
                else
                    objects['DistanceLabel'].Visible = false
                end

                if Config['ESP']['Visuals']['Tracers'] then
                    objects['Tracer'].From = ESPSettings.TracerFromMouse and mousePos or bottomCenter
                    objects['Tracer'].To = Vector2.new(screenPos.X, screenPos.Y)
                    objects['Tracer'].Visible = true
                else
                    objects['Tracer'].Visible = false
                end
            else
                objects['NameLabel'].Visible = false
                objects['DistanceLabel'].Visible = false
                objects['Tracer'].Visible = false
            end
        elseif ESPObjects[player] then
            RemoveESPObject(player)
        end
    end
end)
