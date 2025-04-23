local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local userWantsCamlock = Vnlyisanigger['Camlock']['Enabled']
local actualCamlockActive = false
local currentTarget = nil

local function isInFirstPerson()
    return (Camera.CFrame.Position - Camera.Focus.Position).Magnitude < 1
end

local function toggleCamlock()
    userWantsCamlock = not userWantsCamlock
    Vnlyisanigger['Camlock']['Enabled'] = userWantsCamlock
    if not userWantsCamlock then
        currentTarget = nil
    else
        currentTarget = nil
    end
end

UserInputService.InputBegan:Connect(function(i, p)
    if p then return end
    if i.KeyCode == Enum.KeyCode[Vnlyisanigger['Camlock']['Keybind']:upper()] then
        toggleCamlock()
    end
end)

local easingFunctions = {
    Linear = function(a) return a end,
    Sine = function(a) return 1 - math.cos((a * math.pi) / 2) end,
    Quad = function(a) return a ^ 2 end,
    Cubic = function(a) return a ^ 3 end,
    Quart = function(a) return a ^ 4 end,
    Quint = function(a) return a ^ 5 end,
    Exponential = function(a) return (a == 0) and 0 or (2 ^ (10 * (a - 1))) end,
    Circular = function(a) return 1 - math.sqrt(1 - a ^ 2) end,
    Back = function(a) local s = 1.70158 return a ^ 2 * ((s + 1) * a - s) end,
    Bounce = function(a)
        if a < 1 / 2.75 then
            return 7.5625 * a * a
        elseif a < 2 / 2.75 then
            a = a - 1.5 / 2.75
            return 7.5625 * a * a + 0.75
        elseif a < 2.5 / 2.75 then
            a = a - 2.25 / 2.75
            return 7.5625 * a * a + 0.9375
        else
            a = a - 2.625 / 2.75
            return 7.5625 * a * a + 0.984375
        end
    end,
    Elastic = function(a)
        local p = 0.3
        return -(2 ^ (10 * (a - 1))) * math.sin((a - 1 - p / 4) * (2 * math.pi) / p)
    end
}

local function applyEasing(alpha, style)
    local f = easingFunctions[style.Name]
    return f and f(alpha) or alpha
end

local function WallCheck(pos, ignore)
    local o = Camera.CFrame.Position
    local r = Ray.new(o, pos - o)
    local h = workspace:FindPartOnRayWithIgnoreList(r, ignore)
    return h == nil
end

local function isValidTarget(p)
    if not p or p == LocalPlayer then return false end
    local c = p.Character
    if not c then return false end
    local bp = false
    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then bp = true break end
    end
    if not bp then return false end
    if Vnlyisanigger['Camlock']['CrewCheck'] then
        local d = p:FindFirstChild("DataFolder")
        local m = LocalPlayer:FindFirstChild("DataFolder")
        if d and m then
            local t = d:FindFirstChild("Information") and d.Information:FindFirstChild("Crew")
            local l = m:FindFirstChild("Information") and m.Information:FindFirstChild("Crew")
            if t and l and (t.Value == l.Value) then return false end
        end
    end
    if Vnlyisanigger['Camlock']['KnockCheck'] then
        local b = c:FindFirstChild("BodyEffects")
        local k = b and b:FindFirstChild("K.O") and b["K.O"].Value
        if k then return false end
    end
    if Vnlyisanigger['Camlock']['GrabbedCheck'] then
        if c:FindFirstChild("GRABBING_CONSTRAINT") then return false end
    end
    if Vnlyisanigger['Camlock']['VisibleCheck'] then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hd = c:FindFirstChild("Head")
        local t = c:FindFirstChild("Torso")
        local up = c:FindFirstChild("UpperTorso")
        local cp = hrp or hd or up or t
        if cp then
            local _, s = Camera:WorldToViewportPoint(cp.Position)
            if not s then return false end
        end
    end
    if Vnlyisanigger['Camlock']['WallCheck'] then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hd = c:FindFirstChild("Head")
        local t = c:FindFirstChild("Torso")
        local up = c:FindFirstChild("UpperTorso")
        local cp = hrp or hd or up or t
        if cp then
            if not WallCheck(cp.Position, {LocalPlayer.Character, c}) then return false end
        end
    end
    return true
end

local function GetClosestPointOnBox(part, ref)
    local lp = part.CFrame:PointToObjectSpace(ref)
    local hs = part.Size * 0.5
    local cp = Vector3.new(
        math.clamp(lp.X, -hs.X, hs.X),
        math.clamp(lp.Y, -hs.Y, hs.Y),
        math.clamp(lp.Z, -hs.Z, hs.Z)
    )
    return part.CFrame:PointToWorldSpace(cp)
end

local function GetClosestPointOnSphere(part, ref)
    local center = part.CFrame.Position
    local r = part.Size.Magnitude * 0.5
    local dir = (ref - center).Unit
    return center + dir * math.min((ref - center).Magnitude, r)
end

local function GetIntersectionPoint(part, ref)
    local o = Camera.CFrame.Position
    local d = (ref - o).Unit * 5000
    local r = Ray.new(o, d)
    local hit = workspace:FindPartOnRayWithIgnoreList(r, {LocalPlayer.Character})
    if hit and hit:IsDescendantOf(part.Parent) then
        local p = hit.CFrame.Position
        return p
    end
    return part.CFrame.Position
end

local function getAdvancedClosestPoint(part, ref, mode)
    if mode == "Box" then
        return GetClosestPointOnBox(part, ref)
    elseif mode == "Sphere" then
        return GetClosestPointOnSphere(part, ref)
    elseif mode == "Ray" then
        return GetIntersectionPoint(part, ref)
    else
        return part.Position
    end
end

local function getClosestBodyPartAim(plr)
    local c = plr and plr.Character
    if not c then return nil end
    if not Vnlyisanigger['Camlock']['ClosestPoint'] then
        local up = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Head")
        return up and up.Position or nil
    end
    local mode = Vnlyisanigger['Camlock']['ClosestPointMode']
    local mp = UserInputService:GetMouseLocation()
    local cd = math.huge
    local ba = nil
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
            local sp, os = Camera:WorldToViewportPoint(p.Position)
            if os then
                local dx = mp.X - sp.X
                local dy = mp.Y - sp.Y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < cd then
                    cd = dist
                    ba = getAdvancedClosestPoint(p, Camera.CFrame.Position, mode)
                end
            end
        end
    end
    return ba
end

local function smoothLookAt(wp)
    local cc = Camera.CFrame
    local tc = CFrame.lookAt(cc.Position, wp)
    local s = Vnlyisanigger['Camlock']['SmoothnessSettings']
    local rm = math.clamp(s['Smoothness'], s['MinSmoothness'], s['MaxSmoothness'])
    local ea = applyEasing(rm, Vnlyisanigger['Camlock']['EasingStyle'])
    Camera.CFrame = cc:Lerp(tc, ea)
end

local function camlockTarget(plr)
    if not actualCamlockActive or not isValidTarget(plr) then return end
    local aim = getClosestBodyPartAim(plr)
    if aim then
        smoothLookAt(aim)
    end
end

local function getNewTargetFromMouse()
    local mp = UserInputService:GetMouseLocation()
    local bd = math.huge
    local bp = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if isValidTarget(plr) then
            local c = plr.Character
            if not c then continue end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local hd = c:FindFirstChild("Head")
            local t = c:FindFirstChild("Torso")
            local up = c:FindFirstChild("UpperTorso")
            local cp = hrp or hd or up or t
            if cp then
                local sp, os = Camera:WorldToViewportPoint(cp.Position)
                if os then
                    local dx = mp.X - sp.X
                    local dy = mp.Y - sp.Y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist < bd then
                        bd = dist
                        bp = plr
                    end
                end
            end
        end
    end
    return bp
end

RunService.RenderStepped:Connect(function()
    if Vnlyisanigger['Camlock']['FirstPersonOnly'] then
        if isInFirstPerson() then
            actualCamlockActive = userWantsCamlock
        else
            actualCamlockActive = false
        end
    else
        actualCamlockActive = userWantsCamlock
    end
    if not actualCamlockActive then return end
    if (not currentTarget) or (not isValidTarget(currentTarget)) then
        if not Vnlyisanigger['Camlock']['StickyAim'] or not currentTarget then
            currentTarget = getNewTargetFromMouse()
        end
    end
    if currentTarget then
        camlockTarget(currentTarget)
    end
end)
