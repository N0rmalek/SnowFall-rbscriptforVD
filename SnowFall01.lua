-- Snowfall
-- by N0rmalek

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local settings = {
    aimbot = false,
    silentAim = true,
    fov = 150,
    fovCircle = false,
    autoParry = true,
    instantHeal = false,
    selfHeal = false,
    esp = true,
    espBox = true,
    espHealth = true,
    espGenerators = true,
    espPallets = true,
    espHooks = true,
    killerAlert = true,
    tracer = false,
    fullbright = false,
    noclip = false,
    speedEnabled = false,
    speed = 28,
    jumpEnabled = false,
    jumpPower = 80,
    infiniteJump = false,
    vaultSpeed = false,
    antiAfk = true,
    antiWiggle = false,
    noStun = false,
    forceMatchMode = true,
    generatorName = "Generator",
    palletName = "Pallet",
    hookName = "Hook",
    espPosRefresh = 0.10,
    espNameRefresh = 0.50,
    espDistRefresh = 0.25,
    espHpRefresh = 0.15,
    genRefresh = 0.30,
    genScanInterval = 8,
    objScanInterval = 7,
    roleCacheTime = 3,
    parryRefresh = 0.15,
    matchCheckInterval = 0.5,
}

-- ============ KEYBINDS ============
local keybinds = {
    { id = "menu",   name = "Toggle Menu",   type = "key",   value = Enum.KeyCode.RightControl },
    { id = "cursor", name = "Toggle Cursor", type = "key",   value = Enum.KeyCode.RightAlt },
    { id = "aimbot", name = "Toggle Aimbot", type = "mouse", value = Enum.UserInputType.MouseButton3 },
}

local rebindingId = nil

local function getBindDisplay(bind)
    if bind.type == "key" then
        return bind.value.Name
    elseif bind.type == "mouse" then
        return bind.value.Name:gsub("UserInputType%.", "")
    end
    return "?"
end

local function findBindById(id)
    for _, b in ipairs(keybinds) do
        if b.id == id then return b end
    end
end

local function matchesBind(input, bind)
    if bind.type == "key" then
        return input.KeyCode == bind.value
    elseif bind.type == "mouse" then
        return input.UserInputType == bind.value
    end
    return false
end

local gui, mainFrame, tabContainer, contentContainer
local watermark, watermarkStatus, fovCircleGui
local blurEffect
local tabButtons = {}
local toggleButtons = {}
local currentTab = "Combat"
local connections = {}
local unloaded = false
local cursorFree = false

local genCache, genCacheTime = {}, 0
local palletCache, palletCacheTime = {}, 0
local hookCache, hookCacheTime = {}, 0
local roleCache = {}
local rootCache = {}
local lastESPPos, lastESPName, lastESPDist, lastESPHp = 0, 0, 0, 0
local lastGenUpdate, lastParry, lastMatchCheck = 0, 0, 0
local lastHealCheck, lastWiggleCheck = 0, 0
local inMatch = true
local espCleared, genESPCleared, palletESPCleared, hookESPCleared = true, true, true, true

local savedLighting = { Ambient = nil, OutdoorAmbient = nil, Brightness = nil, FogEnd = nil, FogStart = nil }

local function addConn(conn) table.insert(connections, conn); return conn end

local KILLER_KEYWORDS = {"killer", "murder", "killerteam", "murd", "slasher"}
local SURVIVOR_KEYWORDS = {"survivor", "surv", "innocent", "runner"}
local REPAIR_ATTRS = {"Progress","progress","Repair","repair","RepairProgress","repairprogress","Percent","percent","Percentage","percentage","Health","health","Durability","durability","Fixed","fixed"}
local USED_KEYWORDS = {"used","dropped","broken","destroyed","down","consumed"}
local MATCH_ATTRS = {"GameState","gamestate","RoundState","roundstate","State","state","MatchState","matchstate","Round","round","InRound","inround"}
local IN_MATCH_VALUES = {"playing","game","match","ingame","in_game","active","started","running","combat"}
local IN_LOBBY_VALUES = {"lobby","waiting","intermission","menu","idle","ended","finished","postgame","pregame","countdown"}
local LOBBY_MARKERS = {"Lobby","LobbyFolder","LobbyMap","LobbyArea","Waiting","WaitingRoom","Menu"}
local OUR_NAMES = {ESP=true, GenESP=true, PalletESP=true, HookESP=true, ESPBox=true, GenESPBox=true, PalletESPBox=true, HookESPBox=true, SnowfallBlur=true}

local COLORS = {
    bgTop = Color3.fromRGB(24, 24, 32),
    bgBottom = Color3.fromRGB(16, 16, 22),
    bg = Color3.fromRGB(20, 20, 25),
    panel = Color3.fromRGB(28, 28, 36),
    panelLight = Color3.fromRGB(34, 34, 44),
    tab = Color3.fromRGB(32, 32, 40),
    tabActive = Color3.fromRGB(90, 120, 255),
    stroke = Color3.fromRGB(52, 52, 64),
    strokeAccent = Color3.fromRGB(90, 120, 255),
    text = Color3.fromRGB(240, 240, 245),
    textDim = Color3.fromRGB(180, 180, 195),
    sub = Color3.fromRGB(140, 140, 155),
    on = Color3.fromRGB(60, 190, 110),
    off = Color3.fromRGB(55, 55, 65),
    accent = Color3.fromRGB(90, 120, 255),
    accentLight = Color3.fromRGB(120, 150, 255),
    accentDark = Color3.fromRGB(60, 90, 220),
    slider = Color3.fromRGB(60, 60, 72),
    sliderFill = Color3.fromRGB(90, 120, 255),
    listItem = Color3.fromRGB(38, 38, 48),
    listHover = Color3.fromRGB(58, 58, 74),
    genColor = Color3.fromRGB(255, 210, 90),
    palletColor = Color3.fromRGB(180, 255, 120),
    hookColor = Color3.fromRGB(255, 130, 200),
    matchColor = Color3.fromRGB(60, 220, 100),
    lobbyColor = Color3.fromRGB(230, 200, 60),
    killerColor = Color3.fromRGB(255, 60, 60),
    bindBg = Color3.fromRGB(45, 45, 58),
    bindBgHover = Color3.fromRGB(60, 60, 78),
}

local DEFAULT_SPEED = 16
local DEFAULT_JUMP = 50

-- ============ HELPERS ============
local function getHumanoid(plr)
    local c = plr and plr.Character
    if c then return c:FindFirstChildOfClass("Humanoid") end
end

local function getRoot(plr)
    local cached = rootCache[plr]
    if cached and cached.Parent then return cached end
    local c = plr and plr.Character
    if c then
        local r = c:FindFirstChild("HumanoidRootPart")
        if r then rootCache[plr] = r end
        return r
    end
    return nil
end

local function isAlive(plr)
    local h = getHumanoid(plr)
    return h and h.Health > 0
end

local function containsKeyword(str, keywords)
    if not str then return false end
    local lower = string.lower(str)
    for _, k in ipairs(keywords) do
        if string.find(lower, k, 1, true) then return true end
    end
    return false
end

local function matchAnyKeyword(name, keywordsStr)
    if not name then return false end
    local lower = string.lower(name)
    for kw in string.gmatch(keywordsStr, "([^,]+)") do
        local trimmed = kw:gsub("^%s+", ""):gsub("%s+$", "")
        if #trimmed >= 3 and string.find(lower, string.lower(trimmed), 1, true) then
            return true
        end
    end
    return false
end

local function isOurObject(obj)
    if OUR_NAMES[obj.Name] then return true end
    local cls = obj.ClassName
    if cls == "BillboardGui" or cls == "ScreenGui" or cls == "SurfaceGui" or cls == "Highlight"
       or cls == "LineHandleAdornment" or cls == "BlurEffect"
       or cls == "TextLabel" or cls == "TextButton" or cls == "Frame"
       or cls == "UIStroke" or cls == "UICorner" or cls == "UIGradient" then
        return true
    end
    return false
end

local function isTopLevel(obj)
    local p = obj.Parent
    if not p then return false end
    if p == workspace then return true end
    if p:IsA("Folder") then return true end
    return false
end

local function getRole(plr)
    local now = tick()
    local entry = roleCache[plr]
    if entry and (now - entry.time) < settings.roleCacheTime then
        return entry.role
    end

    local role = "UNKNOWN"
    if plr.Team and plr.Team.Name then
        if containsKeyword(plr.Team.Name, KILLER_KEYWORDS) then role = "KILLER"
        elseif containsKeyword(plr.Team.Name, SURVIVOR_KEYWORDS) then role = "SURVIVOR" end
    end
    if role == "UNKNOWN" then
        for _, c in ipairs({plr, plr.Character}) do
            if c then
                for _, attr in ipairs({"Role","role","Team","team","Type","type"}) do
                    local val = c:GetAttribute(attr)
                    if type(val) == "string" then
                        if containsKeyword(val, KILLER_KEYWORDS) then role = "KILLER"; break
                        elseif containsKeyword(val, SURVIVOR_KEYWORDS) then role = "SURVIVOR"; break end
                    end
                end
                if role ~= "UNKNOWN" then break end
            end
        end
    end
    if role == "UNKNOWN" and plr.Character then
        for _, obj in ipairs(plr.Character:GetChildren()) do
            if containsKeyword(obj.Name, KILLER_KEYWORDS) then role = "KILLER"; break end
            if containsKeyword(obj.Name, SURVIVOR_KEYWORDS) then role = "SURVIVOR"; break end
        end
    end

    roleCache[plr] = {role = role, time = now}
    return role
end

local function getRoleColor(role)
    if role == "KILLER" then return COLORS.killerColor end
    if role == "SURVIVOR" then return Color3.fromRGB(60, 200, 255) end
    return Color3.fromRGB(230, 230, 230)
end

-- ============ MATCH STATE ============
local function computeInMatch()
    if settings.forceMatchMode then return true end
    for _, container in ipairs({workspace, ReplicatedStorage, LocalPlayer}) do
        for _, attr in ipairs(MATCH_ATTRS) do
            local val = container:GetAttribute(attr)
            if val ~= nil then
                if type(val) == "boolean" then return val end
                if type(val) == "string" then
                    local lv = string.lower(val)
                    if containsKeyword(lv, IN_MATCH_VALUES) then return true end
                    if containsKeyword(lv, IN_LOBBY_VALUES) then return false end
                end
                if type(val) == "number" then return val > 0 end
            end
        end
    end
    for _, nm in ipairs(LOBBY_MARKERS) do
        if workspace:FindFirstChild(nm) then return false end
    end
    if LocalPlayer.Team and LocalPlayer.Team.Name and #LocalPlayer.Team.Name > 0 then return true end
    if getRole(LocalPlayer) ~= "UNKNOWN" then return true end
    return false
end

-- ============ MENU BLUR ============
local function createBlur()
    if blurEffect and blurEffect.Parent then return blurEffect end
    local existing = Lighting:FindFirstChild("SnowfallBlur")
    if existing then blurEffect = existing; return blurEffect end
    blurEffect = Instance.new("BlurEffect")
    blurEffect.Name = "SnowfallBlur"
    blurEffect.Size = 0
    blurEffect.Parent = Lighting
    return blurEffect
end

local function setMenuBlur(active)
    local blur = createBlur()
    TweenService:Create(blur, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
        Size = active and 18 or 0,
    }):Play()
end

-- ============ CURSOR ============
local function applyCursorState()
    if cursorFree then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
        UserInputService.ModalEnabled = true
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.ModalEnabled = false
    end
end

local function toggleCursor()
    cursorFree = not cursorFree
    applyCursorState()
end

-- ============ TELEPORT ============
local function groundY(position)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local result = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -200, 0), params)
    if result then return result.Position.Y end
    return position.Y
end

local function teleportCharacter(targetCF)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")

    pcall(function() char:PivotTo(targetCF) end)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = targetCF
        hrp.Velocity = Vector3.new(0, 0, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    end
    if hum then hum:MoveTo(targetCF.Position) end

    task.spawn(function()
        for i = 1, 40 do
            task.wait(0.05)
            if unloaded or not char.Parent then break end
            local h = char:FindFirstChild("HumanoidRootPart")
            if h then
                h.CFrame = targetCF
                h.Velocity = Vector3.new(0, 0, 0)
                h.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
        end
    end)
end

local function scanFor(keywordsStr)
    local list = {}
    local seen = {}

    local function checkContainer(container)
        local children = container:GetChildren()
        for _, obj in ipairs(children) do
            if not isOurObject(obj) then
                local matched = false
                if obj:IsA("Model") and matchAnyKeyword(obj.Name, keywordsStr) then
                    matched = true
                elseif obj:IsA("BasePart") and isTopLevel(obj) and matchAnyKeyword(obj.Name, keywordsStr) then
                    matched = true
                end

                if matched then
                    local ref = obj
                    if obj:IsA("Model") then
                        ref = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    end
                    if ref and not seen[obj] then
                        seen[obj] = true
                        table.insert(list, {model = obj, part = ref, label = obj.Name})
                    end
                elseif obj:IsA("Folder") then
                    checkContainer(obj)
                end
            end
        end
    end
    checkContainer(workspace)
    return list
end

local function filterAlive(list)
    local alive = {}
    for _, g in ipairs(list) do
        if g.part and g.part.Parent then table.insert(alive, g) end
    end
    return alive
end

local function getGenerators()
    local now = tick()
    if (now - genCacheTime) > settings.genScanInterval or #genCache == 0 then
        genCache = scanFor(settings.generatorName)
        genCacheTime = now
        return genCache
    end
    local alive = filterAlive(genCache)
    if #alive ~= #genCache then genCache = alive end
    return genCache
end

local function getPallets()
    local now = tick()
    if (now - palletCacheTime) > settings.objScanInterval or #palletCache == 0 then
        palletCache = scanFor(settings.palletName)
        palletCacheTime = now
        return palletCache
    end
    local alive = filterAlive(palletCache)
    if #alive ~= #palletCache then palletCache = alive end
    return palletCache
end

local function getHooks()
    local now = tick()
    if (now - hookCacheTime) > settings.objScanInterval or #hookCache == 0 then
        hookCache = scanFor(settings.hookName)
        hookCacheTime = now
        return hookCache
    end
    local alive = filterAlive(hookCache)
    if #alive ~= #hookCache then hookCache = alive end
    return hookCache
end

local function isPalletUsed(pallet)
    if not pallet or not pallet.model then return false end
    local m = pallet.model
    for _, attr in ipairs({"Used","used","Dropped","dropped","Broken","broken","Down","down","State","state"}) do
        local val = m:GetAttribute(attr)
        if val ~= nil then
            if type(val) == "boolean" then return val end
            if type(val) == "string" and containsKeyword(val, USED_KEYWORDS) then return true end
            if type(val) == "number" and val > 0 then return true end
        end
    end
    for _, obj in ipairs(m:GetChildren()) do
        if obj:IsA("BoolValue") and containsKeyword(obj.Name, USED_KEYWORDS) then return obj.Value end
        if (obj:IsA("NumberValue") or obj:IsA("IntValue")) and containsKeyword(obj.Name, USED_KEYWORDS) then
            return obj.Value > 0
        end
    end
    if pallet.part then
        local _, y, _ = pallet.part.CFrame:ToEulerAnglesYXZ()
        if math.abs(y) > math.rad(45) then return true end
    end
    return false
end

local function teleportToGenerator(gen)
    if not gen or not gen.part or not gen.part.Parent then return end
    local targetPos = gen.part.Position
    local size = gen.part.Size
    local basePos = targetPos + Vector3.new(size.X / 2 + 5, 0, 0)
    local y = groundY(basePos)
    teleportCharacter(CFrame.new(Vector3.new(basePos.X, y + 3, basePos.Z)))
end

local function teleportToPlayer(target)
    if not target or not target.Character then return end
    local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    teleportCharacter(CFrame.new(targetRoot.Position + Vector3.new(0, 3, 0)))
end

local function nearestTarget()
    local closest, shortest = nil, math.huge
    local myRoot = getRoot(LocalPlayer); if not myRoot then return nil end
    local myPos = myRoot.Position
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            local r = getRoot(plr)
            if r then
                local d = (r.Position - myPos).Magnitude
                if d < shortest then shortest = d; closest = plr end
            end
        end
    end
    return closest
end

local function isInFOV(plr)
    if not settings.fovCircle or settings.fov <= 0 then return true end
    local root = getRoot(plr); if not root then return false end
    local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
    if not onScreen then return false end
    local vp = Camera.ViewportSize
    local dx = screenPos.X - vp.X / 2
    local dy = screenPos.Y - vp.Y / 2
    local r = settings.fov / 2
    return (dx * dx + dy * dy) <= (r * r)
end

-- ============ GENERATOR REPAIR ============
local function getGeneratorRepair(gen)
    if not gen or not gen.model then return nil end
    local model = gen.model
    local function tryVal(v)
        if type(v) == "number" then
            if v >= 0 and v <= 1 then return v * 100 end
            if v >= 0 and v <= 100 then return v end
        end
        return nil
    end
    for _, container in ipairs({model, gen.part}) do
        if container then
            for _, attr in ipairs(REPAIR_ATTRS) do
                local val = container:GetAttribute(attr)
                local n = tryVal(val)
                if n then return math.floor(n + 0.5) end
            end
        end
    end
    for _, obj in ipairs(model:GetChildren()) do
        if obj:IsA("NumberValue") or obj:IsA("IntValue") then
            if containsKeyword(obj.Name, REPAIR_ATTRS) then
                local n = tryVal(obj.Value)
                if n then return math.floor(n + 0.5) end
            end
        end
    end
    return nil
end

local function getRepairColor(pct)
    if pct == nil then return Color3.fromRGB(180, 180, 180) end
    if pct >= 90 then return Color3.fromRGB(60, 220, 100) end
    if pct >= 60 then return Color3.fromRGB(230, 220, 70) end
    if pct >= 30 then return Color3.fromRGB(255, 150, 60) end
    return Color3.fromRGB(255, 70, 70)
end

-- ============ FEATURES ============
local function applySpeed()
    if unloaded then return end
    local h = getHumanoid(LocalPlayer)
    if not h then return end
    if settings.speedEnabled then
        if h.WalkSpeed ~= settings.speed then h.WalkSpeed = settings.speed end
    else
        if h.WalkSpeed ~= DEFAULT_SPEED then h.WalkSpeed = DEFAULT_SPEED end
    end
end

local function applyJump()
    if unloaded then return end
    local h = getHumanoid(LocalPlayer)
    if not h then return end
    h.UseJumpPower = true
    if settings.jumpEnabled then
        if h.JumpPower ~= settings.jumpPower then h.JumpPower = settings.jumpPower end
        if h.JumpHeight ~= 0 then h.JumpHeight = 0 end
        if h:GetStateEnabled(Enum.HumanoidStateType.Jumping) == false then
            h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
        end
    else
        if h.JumpPower ~= 0 then h.JumpPower = 0 end
        if h.JumpHeight ~= 0 then h.JumpHeight = 0 end
        if h:GetStateEnabled(Enum.HumanoidStateType.Jumping) ~= false then
            h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        end
    end
end

local function applyNoclip()
    if unloaded or not settings.noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

local function silentAim()
    if unloaded or not settings.silentAim then return end
    local t = nearestTarget()
    if t and isInFOV(t) then
        local tr = getRoot(t)
        if tr then Camera.CFrame = CFrame.new(Camera.CFrame.Position, tr.Position) end
    end
end

local function autoParry()
    if unloaded or not settings.autoParry then return end
    if nearestTarget() then
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
    end
end

local function instantHeal()
    if unloaded or not settings.instantHeal then return end
    local h = getHumanoid(LocalPlayer)
    if h then h.Health = h.MaxHealth end
end

local function selfHeal()
    if unloaded or not settings.selfHeal then return end
    local now = tick()
    if (now - lastHealCheck) < 0.5 then return end
    lastHealCheck = now
    local h = getHumanoid(LocalPlayer)
    if h and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
end

local function antiWiggle()
    if unloaded or not settings.antiWiggle then return end
    local now = tick()
    if (now - lastWiggleCheck) < 0.1 then return end
    lastWiggleCheck = now
    local h = getHumanoid(LocalPlayer)
    if h then
        h.PlatformStand = false
        h.Sit = false
    end
end

local function applyFullbright()
    if unloaded then return end
    if settings.fullbright then
        if savedLighting.Ambient == nil then
            savedLighting.Ambient = Lighting.Ambient
            savedLighting.OutdoorAmbient = Lighting.OutdoorAmbient
            savedLighting.Brightness = Lighting.Brightness
            savedLighting.FogEnd = Lighting.FogEnd
            savedLighting.FogStart = Lighting.FogStart
        end
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 3
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    else
        if savedLighting.Ambient ~= nil then
            Lighting.Ambient = savedLighting.Ambient
            Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient
            Lighting.Brightness = savedLighting.Brightness
            Lighting.FogEnd = savedLighting.FogEnd
            Lighting.FogStart = savedLighting.FogStart
            savedLighting.Ambient = nil
        end
    end
end

-- ============ FOV CIRCLE ============
local function createFOVCircle()
    if fovCircleGui then fovCircleGui:Destroy() end
    fovCircleGui = Instance.new("ScreenGui")
    fovCircleGui.Name = "FOVCircle"
    fovCircleGui.ResetOnSpawn = false
    fovCircleGui.IgnoreGuiInset = true
    fovCircleGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local circle = Instance.new("Frame")
    circle.Name = "Circle"
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.Position = UDim2.new(0.5, 0, 0.5, 0)
    circle.BackgroundTransparency = 1
    circle.Parent = fovCircleGui
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.fromRGB(90, 120, 255)
    uiStroke.Thickness = 1.5
    uiStroke.Transparency = 0.2
    uiStroke.Parent = circle
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = circle
end

local function updateFOVCircle()
    if not fovCircleGui then return end
    local circle = fovCircleGui:FindFirstChild("Circle")
    if not circle then return end
    if settings.fovCircle and settings.silentAim and inMatch then
        circle.Visible = true
        circle.Size = UDim2.new(0, settings.fov, 0, settings.fov)
    elseif circle.Visible then
        circle.Visible = false
    end
end

-- ============ WATERMARK ============
local function createWatermark()
    if watermark then watermark:Destroy() end
    local wm = Instance.new("ScreenGui")
    wm.Name = "SnowfallWatermark"
    wm.ResetOnSpawn = false
    wm.IgnoreGuiInset = true
    wm.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 26)
    frame.AnchorPoint = Vector2.new(1, 0)
    frame.Position = UDim2.new(1, -12, 0, 12)
    frame.BackgroundColor3 = COLORS.bg
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = wm
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = frame
    local stroke = Instance.new("UIStroke"); stroke.Color = COLORS.accent; stroke.Thickness = 1; stroke.Transparency = 0.3; stroke.Parent = frame
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.bgTop),
        ColorSequenceKeypoint.new(1, COLORS.accentDark),
    })
    grad.Rotation = 45
    grad.Parent = frame

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -10, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextColor3 = COLORS.text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "❄ Snowfall  |  by N0rmalek"
    label.Parent = frame

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.BackgroundTransparency = 1
    status.AnchorPoint = Vector2.new(1, 0)
    status.Size = UDim2.new(0, 70, 1, 0)
    status.Position = UDim2.new(1, -8, 0, 0)
    status.Font = Enum.Font.GothamBold
    status.TextSize = 12
    status.TextColor3 = COLORS.lobbyColor
    status.TextXAlignment = Enum.TextXAlignment.Right
    status.Text = "LOBBY"
    status.Parent = frame

    watermark = wm
    watermarkStatus = status
end

local function updateWatermarkStatus()
    if not watermarkStatus then return end
    local wantText
    if settings.forceMatchMode then
        wantText = "FORCED"
        watermarkStatus.TextColor3 = COLORS.accent
    else
        wantText = inMatch and "MATCH" or "LOBBY"
        watermarkStatus.TextColor3 = inMatch and COLORS.matchColor or COLORS.lobbyColor
    end
    if watermarkStatus.Text ~= wantText then
        watermarkStatus.Text = wantText
    end
end

-- ============ ESP ИГРОКОВ ============
local function createESP(plr, root)
    local role = getRole(plr)
    local color = getRoleColor(role)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP"
    bb.Adornee = root
    bb.Size = UDim2.new(0, 200, 0, 60)
    bb.StudsOffset = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.Parent = root

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0, 18)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = plr.Name .. " [" .. role .. "]"
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "DistLabel"
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 0, 18)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.GothamMedium
    distLabel.TextSize = 12
    distLabel.TextColor3 = COLORS.text
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Text = "0m"
    distLabel.Parent = bb

    local hpBg = Instance.new("Frame")
    hpBg.Name = "HpBg"
    hpBg.Size = UDim2.new(0.8, 0, 0, 5)
    hpBg.Position = UDim2.new(0.1, 0, 0, 36)
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hpBg.BorderSizePixel = 0
    hpBg.Visible = settings.espHealth
    hpBg.Parent = bb
    local hpBgC = Instance.new("UICorner"); hpBgC.CornerRadius = UDim.new(0, 3); hpBgC.Parent = hpBg
    local hpBgS = Instance.new("UIStroke"); hpBgS.Color = Color3.new(0,0,0); hpBgS.Thickness = 1; hpBgS.Parent = hpBg

    local hpFill = Instance.new("Frame")
    hpFill.Name = "HpFill"
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg
    local hpFillC = Instance.new("UICorner"); hpFillC.CornerRadius = UDim.new(0, 3); hpFillC.Parent = hpFill

    if plr.Character then
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPBox"
        highlight.Adornee = plr.Character
        highlight.FillColor = color
        highlight.FillTransparency = 0.75
        highlight.OutlineColor = color
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = settings.espBox
        highlight.Parent = plr.Character
    end
end

local function drawESP()
    if unloaded or not settings.esp then return end
    espCleared = false
    local now = tick()
    local doName = (now - lastESPName) >= settings.espNameRefresh
    local doDist = (now - lastESPDist) >= settings.espDistRefresh
    local doHp   = (now - lastESPHp) >= settings.espHpRefresh
    local myRoot = getRoot(LocalPlayer)
    local myPos = myRoot and myRoot.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isAlive(plr) then
            local root = getRoot(plr)
            if root then
                local bb = root:FindFirstChild("ESP")
                if not bb then
                    createESP(plr, root)
                    bb = root:FindFirstChild("ESP")
                end
                if bb then
                    if doName then
                        local role = getRole(plr)
                        local color = getRoleColor(role)
                        local nl = bb:FindFirstChild("NameLabel")
                        if nl then
                            local text = plr.Name .. " [" .. role .. "]"
                            if nl.Text ~= text then
                                nl.Text = text
                                nl.TextColor3 = color
                            end
                        end
                    end
                    if doDist and myPos then
                        local dl = bb:FindFirstChild("DistLabel")
                        if dl then dl.Text = math.floor((root.Position - myPos).Magnitude) .. "m" end
                    end
                    if doHp then
                        local hpBg = bb:FindFirstChild("HpBg")
                        if hpBg then
                            hpBg.Visible = settings.espHealth
                            local hpFill = hpBg:FindFirstChild("HpFill")
                            local hum = getHumanoid(plr)
                            if hpFill and hum then
                                local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                                hpFill.Size = UDim2.new(ratio, 0, 1, 0)
                                if ratio > 0.6 then hpFill.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
                                elseif ratio > 0.3 then hpFill.BackgroundColor3 = Color3.fromRGB(230, 200, 60)
                                else hpFill.BackgroundColor3 = Color3.fromRGB(230, 60, 60) end
                            end
                        end
                    end
                    if plr.Character then
                        local hl = plr.Character:FindFirstChild("ESPBox")
                        if hl and hl.Enabled ~= settings.espBox then hl.Enabled = settings.espBox end
                    end
                end
            end
        end
    end
    if doName then lastESPName = now end
    if doDist then lastESPDist = now end
    if doHp then lastESPHp = now end
end

local function clearESP()
    if espCleared then return end
    espCleared = true
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bb = hrp:FindFirstChild("ESP")
                if bb then bb:Destroy() end
            end
            local hl = char:FindFirstChild("ESPBox")
            if hl then hl:Destroy() end
        end
    end
end

-- ============ ESP GENERATORS ============
local function createGeneratorESP(gen)
    local target = gen.part
    if not target or not target.Parent then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "GenESP"
    bb.Adornee = target
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.Parent = target

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "GenName"
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = COLORS.genColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = gen.label
    nameLabel.Parent = bb

    local repairLabel = Instance.new("TextLabel")
    repairLabel.Name = "GenRepair"
    repairLabel.Size = UDim2.new(1, 0, 0, 16)
    repairLabel.Position = UDim2.new(0, 0, 0, 16)
    repairLabel.BackgroundTransparency = 1
    repairLabel.Font = Enum.Font.GothamBold
    repairLabel.TextSize = 13
    repairLabel.TextStrokeTransparency = 0
    repairLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    repairLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    repairLabel.Text = "Repair: ?"
    repairLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "GenDist"
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 0, 32)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.GothamMedium
    distLabel.TextSize = 12
    distLabel.TextColor3 = COLORS.text
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Text = "0m"
    distLabel.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Name = "GenESPBox"
    hl.Adornee = (gen.model and gen.model:IsA("Model")) and gen.model or target
    hl.FillColor = COLORS.genColor
    hl.FillTransparency = 0.85
    hl.OutlineColor = COLORS.genColor
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = target
end

local function drawGeneratorESP()
    if unloaded or not settings.espGenerators then return end
    genESPCleared = false
    local myRoot = getRoot(LocalPlayer)
    local myPos = myRoot and myRoot.Position
    for _, gen in ipairs(getGenerators()) do
        local target = gen.part
        if target and target.Parent then
            local bb = target:FindFirstChild("GenESP")
            if not bb then
                createGeneratorESP(gen)
                bb = target:FindFirstChild("GenESP")
            end
            if bb then
                local pct = getGeneratorRepair(gen)
                local rl = bb:FindFirstChild("GenRepair")
                if rl then
                    if pct then
                        local text = "Repair: " .. pct .. "%"
                        if rl.Text ~= text then
                            rl.Text = text
                            rl.TextColor3 = getRepairColor(pct)
                        end
                    else
                        if rl.Text ~= "Repair: ?" then
                            rl.Text = "Repair: ?"
                            rl.TextColor3 = Color3.fromRGB(180, 180, 180)
                        end
                    end
                end
                local dl = bb:FindFirstChild("GenDist")
                if dl and myPos then dl.Text = math.floor((target.Position - myPos).Magnitude) .. "m" end
            end
        end
    end
end

local function clearGeneratorESP()
    if genESPCleared then return end
    genESPCleared = true
    for _, gen in ipairs(genCache) do
        local target = gen.part
        if target then
            local bb = target:FindFirstChild("GenESP")
            if bb then bb:Destroy() end
            local hl = target:FindFirstChild("GenESPBox")
            if hl then hl:Destroy() end
        end
    end
end

-- ============ ESP PALLETS ============
local function createPalletESP(pallet)
    local target = pallet.part
    if not target or not target.Parent then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "PalletESP"
    bb.Adornee = target
    bb.Size = UDim2.new(0, 180, 0, 40)
    bb.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 2.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 1500
    bb.Parent = target

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "PalletName"
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = COLORS.palletColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = pallet.label .. " [UNUSED]"
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "PalletDist"
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 0, 16)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.GothamMedium
    distLabel.TextSize = 12
    distLabel.TextColor3 = COLORS.text
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Text = "0m"
    distLabel.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Name = "PalletESPBox"
    hl.Adornee = (pallet.model and pallet.model:IsA("Model")) and pallet.model or target
    hl.FillColor = COLORS.palletColor
    hl.FillTransparency = 0.85
    hl.OutlineColor = COLORS.palletColor
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = target
end

local function drawPalletESP()
    if unloaded or not settings.espPallets then return end
    palletESPCleared = false
    local myRoot = getRoot(LocalPlayer)
    local myPos = myRoot and myRoot.Position
    for _, p in ipairs(getPallets()) do
        local target = p.part
        if target and target.Parent then
            if isPalletUsed(p) then
                local bb = target:FindFirstChild("PalletESP")
                if bb then bb:Destroy() end
                local hl = target:FindFirstChild("PalletESPBox")
                if hl then hl:Destroy() end
            else
                local bb = target:FindFirstChild("PalletESP")
                if not bb then
                    createPalletESP(p)
                    bb = target:FindFirstChild("PalletESP")
                end
                if bb then
                    local dl = bb:FindFirstChild("PalletDist")
                    if dl and myPos then dl.Text = math.floor((target.Position - myPos).Magnitude) .. "m" end
                end
            end
        end
    end
end

local function clearPalletESP()
    if palletESPCleared then return end
    palletESPCleared = true
    for _, p in ipairs(palletCache) do
        local target = p.part
        if target then
            local bb = target:FindFirstChild("PalletESP")
            if bb then bb:Destroy() end
            local hl = target:FindFirstChild("PalletESPBox")
            if hl then hl:Destroy() end
        end
    end
end

-- ============ ESP HOOKS ============
local function createHookESP(hook)
    local target = hook.part
    if not target or not target.Parent then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "HookESP"
    bb.Adornee = target
    bb.Size = UDim2.new(0, 180, 0, 40)
    bb.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 2.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 1500
    bb.Parent = target

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "HookName"
    nameLabel.Size = UDim2.new(1, 0, 0, 16)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = COLORS.hookColor
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Text = hook.label
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "HookDist"
    distLabel.Size = UDim2.new(1, 0, 0, 14)
    distLabel.Position = UDim2.new(0, 0, 0, 16)
    distLabel.BackgroundTransparency = 1
    distLabel.Font = Enum.Font.GothamMedium
    distLabel.TextSize = 12
    distLabel.TextColor3 = COLORS.text
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distLabel.Text = "0m"
    distLabel.Parent = bb

    local hl = Instance.new("Highlight")
    hl.Name = "HookESPBox"
    hl.Adornee = (hook.model and hook.model:IsA("Model")) and hook.model or target
    hl.FillColor = COLORS.hookColor
    hl.FillTransparency = 0.85
    hl.OutlineColor = COLORS.hookColor
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = target
end

local function drawHookESP()
    if unloaded or not settings.espHooks then return end
    hookESPCleared = false
    local myRoot = getRoot(LocalPlayer)
    local myPos = myRoot and myRoot.Position
    for _, hook in ipairs(getHooks()) do
        local target = hook.part
        if target and target.Parent then
            local bb = target:FindFirstChild("HookESP")
            if not bb then
                createHookESP(hook)
                bb = target:FindFirstChild("HookESP")
            end
            if bb then
                local nl = bb:FindFirstChild("HookName")
                if nl and nl.Text ~= hook.label then nl.Text = hook.label end
                local dl = bb:FindFirstChild("HookDist")
                if dl and myPos then dl.Text = math.floor((target.Position - myPos).Magnitude) .. "m" end
            end
        end
    end
end

local function clearHookESP()
    if hookESPCleared then return end
    hookESPCleared = true
    for _, hook in ipairs(hookCache) do
        local target = hook.part
        if target then
            local bb = target:FindFirstChild("HookESP")
            if bb then bb:Destroy() end
            local hl = target:FindFirstChild("HookESPBox")
            if hl then hl:Destroy() end
        end
    end
end

-- ============ UNLOAD ============
local function unload()
    if unloaded then return end
    unloaded = true

    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    espCleared = false; genESPCleared = false
    palletESPCleared = false; hookESPCleared = false
    pcall(clearESP)
    pcall(clearGeneratorESP)
    pcall(clearPalletESP)
    pcall(clearHookESP)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if (obj:IsA("BillboardGui") and (obj.Name == "ESP" or obj.Name == "GenESP" or obj.Name == "PalletESP" or obj.Name == "HookESP"))
        or (obj:IsA("Highlight") and (obj.Name == "ESPBox" or obj.Name == "GenESPBox" or obj.Name == "PalletESPBox" or obj.Name == "HookESPBox")) then
            obj:Destroy()
        end
    end

    if savedLighting.Ambient ~= nil then
        Lighting.Ambient = savedLighting.Ambient
        Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient
        Lighting.Brightness = savedLighting.Brightness
        Lighting.FogEnd = savedLighting.FogEnd
        Lighting.FogStart = savedLighting.FogStart
    end

    local h = getHumanoid(LocalPlayer)
    if h then
        h.WalkSpeed = DEFAULT_SPEED
        h.UseJumpPower = true
        h.JumpPower = DEFAULT_JUMP
        h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end

    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end

    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.ModalEnabled = false

    if gui then gui:Destroy(); gui = nil end
    if watermark then watermark:Destroy(); watermark = nil end
    if fovCircleGui then fovCircleGui:Destroy(); fovCircleGui = nil end
    if blurEffect then blurEffect:Destroy(); blurEffect = nil end

    genCache = {}; palletCache = {}; hookCache = {}
    roleCache = {}; rootCache = {}
end

-- ============ GUI ============
local function applyButtonStyle(btn)
    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.stroke
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = btn
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
end

local function makeToggle(parent, y, label, key, onChange)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 34)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = settings[key] and COLORS.on or COLORS.off
    btn.BackgroundTransparency = settings[key] and 0 or 0.15
    btn.Text = label
    btn.TextColor3 = COLORS.text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.ZIndex = 20
    btn.Parent = parent
    applyButtonStyle(btn)

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 14)
    padding.Parent = btn

    local dot = Instance.new("Frame")
    dot.Name = "Dot"
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.Position = UDim2.new(1, -22, 0.5, -4)
    dot.BackgroundColor3 = settings[key] and Color3.fromRGB(255,255,255) or COLORS.textDim
    dot.BackgroundTransparency = settings[key] and 0 or 0.5
    dot.BorderSizePixel = 0
    dot.ZIndex = 21
    dot.Parent = btn
    local dotCorner = Instance.new("UICorner"); dotCorner.CornerRadius = UDim.new(1, 0); dotCorner.Parent = dot

    toggleButtons[label] = btn

    addConn(btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundColor3 = (settings[key] and COLORS.on or COLORS.off):Lerp(Color3.new(1,1,1), 0.1)}):Play()
    end))
    addConn(btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.18), {BackgroundColor3 = settings[key] and COLORS.on or COLORS.off}):Play()
    end))
    addConn(btn.MouseButton1Click:Connect(function()
        settings[key] = not settings[key]
        local state = settings[key]
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            BackgroundColor3 = state and COLORS.on or COLORS.off,
            BackgroundTransparency = state and 0 or 0.15,
        }):Play()
        TweenService:Create(dot, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Color3.fromRGB(255,255,255) or COLORS.textDim,
            BackgroundTransparency = state and 0 or 0.5,
        }):Play()
        if key == "esp" and not state then clearESP() end
        if key == "espGenerators" and not state then clearGeneratorESP() end
        if key == "espPallets" and not state then clearPalletESP() end
        if key == "espHooks" and not state then clearHookESP() end
        if key == "noclip" and not state then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = true end
                end
            end
        end
        if key == "jumpEnabled" then
            local h = getHumanoid(LocalPlayer)
            if h then
                if state then
                    h:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                else
                    h:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
                end
            end
        end
        if key == "forceMatchMode" then updateWatermarkStatus() end
        if onChange then onChange(state) end
    end))
    return y + 40
end

local function makeSlider(parent, y, label, key, minVal, maxVal, step, onChange)
    step = step or 1
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 44)
    container.Position = UDim2.new(0, 10, 0, y)
    container.BackgroundColor3 = COLORS.panelLight
    container.BackgroundTransparency = 0.1
    container.BorderSizePixel = 0
    container.ZIndex = 20
    container.Parent = parent
    applyButtonStyle(container)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -20, 0, 16)
    title.Position = UDim2.new(0, 10, 0, 3)
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 13
    title.TextColor3 = COLORS.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 21
    title.Text = label
    title.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Val"
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0, 60, 0, 16)
    valueLabel.Position = UDim2.new(1, -70, 0, 3)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 13
    valueLabel.TextColor3 = COLORS.accentLight
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.ZIndex = 21
    valueLabel.Text = tostring(settings[key])
    valueLabel.Parent = container

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 6)
    bar.Position = UDim2.new(0, 10, 0, 27)
    bar.BackgroundColor3 = COLORS.slider
    bar.BorderSizePixel = 0
    bar.ZIndex = 21
    bar.Parent = container
    local bC = Instance.new("UICorner"); bC.CornerRadius = UDim.new(1, 0); bC.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((settings[key] - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = COLORS.sliderFill
    fill.BorderSizePixel = 0
    fill.ZIndex = 22
    fill.Parent = bar
    local fC = Instance.new("UICorner"); fC.CornerRadius = UDim.new(1, 0); fC.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((settings[key] - minVal) / (maxVal - minVal), 0, 0.5, 0)
    knob.BackgroundColor3 = COLORS.text
    knob.BorderSizePixel = 0
    knob.ZIndex = 23
    knob.Parent = bar
    local kC = Instance.new("UICorner"); kC.CornerRadius = UDim.new(1, 0); kC.Parent = knob
    local kS = Instance.new("UIStroke"); kS.Color = COLORS.accent; kS.Thickness = 2; kS.Parent = knob

    local dragging = false
    local function updateFromMouse(x)
        local relX = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local raw = minVal + (maxVal - minVal) * relX
        local value = math.floor(raw / step + 0.5) * step
        settings[key] = value
        fill.Size = UDim2.new(relX, 0, 1, 0)
        knob.Position = UDim2.new(relX, 0, 0.5, 0)
        valueLabel.Text = tostring(value)
        if onChange then onChange(value) end
    end
    addConn(bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; updateFromMouse(input.Position.X)
        end
    end))
    addConn(bar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    addConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromMouse(input.Position.X)
        end
    end))
    return y + 50
end

local function makeList(parent, y, title, height, getItems, onSelect)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, height + 24)
    container.Position = UDim2.new(0, 10, 0, y)
    container.BackgroundColor3 = COLORS.panelLight
    container.BackgroundTransparency = 0.1
    container.BorderSizePixel = 0
    container.ZIndex = 20
    container.Parent = parent
    applyButtonStyle(container)

    local header = Instance.new("TextLabel")
    header.BackgroundTransparency = 1
    header.Size = UDim2.new(1, -70, 0, 18)
    header.Position = UDim2.new(0, 10, 0, 3)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 13
    header.TextColor3 = COLORS.text
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 21
    header.Text = title
    header.Parent = container

    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "Count"
    countLabel.BackgroundTransparency = 1
    countLabel.Size = UDim2.new(0, 30, 0, 18)
    countLabel.Position = UDim2.new(1, -60, 0, 3)
    countLabel.Font = Enum.Font.GothamMedium
    countLabel.TextSize = 12
    countLabel.TextColor3 = COLORS.sub
    countLabel.ZIndex = 21
    countLabel.Text = "0"
    countLabel.Parent = container

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0, 24, 0, 18)
    refreshBtn.Position = UDim2.new(1, -28, 0, 3)
    refreshBtn.BackgroundColor3 = COLORS.accent
    refreshBtn.TextColor3 = COLORS.text
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 11
    refreshBtn.Text = "R"
    refreshBtn.AutoButtonColor = false
    refreshBtn.ZIndex = 21
    refreshBtn.Parent = container
    local rC = Instance.new("UICorner"); rC.CornerRadius = UDim.new(0, 4); rC.Parent = refreshBtn

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -12, 0, height)
    scroll.Position = UDim2.new(0, 6, 0, 24)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = COLORS.accent
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ZIndex = 21
    scroll.Parent = container

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 4)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = scroll

    local function rebuild()
        if unloaded then return end
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local items = getItems()
        countLabel.Text = tostring(#items)
        for i, item in ipairs(items) do
            local ib = Instance.new("TextButton")
            ib.Size = UDim2.new(1, -6, 0, 26)
            ib.BackgroundColor3 = COLORS.listItem
            ib.BackgroundTransparency = 0.1
            ib.TextColor3 = COLORS.text
            ib.Font = Enum.Font.GothamMedium
            ib.TextSize = 12
            ib.Text = (type(item) == "table" and item.text) or tostring(item)
            ib.TextXAlignment = Enum.TextXAlignment.Left
            ib.AutoButtonColor = false
            ib.ZIndex = 22
            ib.Parent = scroll
            local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 4); ic.Parent = ib
            addConn(ib.MouseEnter:Connect(function()
                TweenService:Create(ib, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.listHover}):Play()
            end))
            addConn(ib.MouseLeave:Connect(function()
                TweenService:Create(ib, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.listItem}):Play()
            end))
            addConn(ib.MouseButton1Click:Connect(function() onSelect(item) end))
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 6)
    end
    addConn(refreshBtn.MouseButton1Click:Connect(function()
        genCacheTime = 0
        rebuild()
    end))
    rebuild()
    return y + height + 32
end

local function clearContent()
    for _, c in ipairs(contentContainer:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

-- ============ BINDS TAB ============
local function buildBindsTab()
    local y = 10

    local hint = Instance.new("TextLabel")
    hint.BackgroundTransparency = 1
    hint.Size = UDim2.new(1, -20, 0, 20)
    hint.Position = UDim2.new(0, 10, 0, y)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 12
    hint.TextColor3 = COLORS.sub
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 20
    hint.Text = "Click a key to rebind it, then press new key."
    hint.Parent = contentContainer
    y = y + 24

    for _, bind in ipairs(keybinds) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -20, 0, 42)
        row.Position = UDim2.new(0, 10, 0, y)
        row.BackgroundColor3 = COLORS.panelLight
        row.BackgroundTransparency = 0.1
        row.BorderSizePixel = 0
        row.ZIndex = 20
        row.Parent = contentContainer
        applyButtonStyle(row)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
        nameLabel.Position = UDim2.new(0, 14, 0, 0)
        nameLabel.Font = Enum.Font.GothamMedium
        nameLabel.TextSize = 14
        nameLabel.TextColor3 = COLORS.text
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 21
        nameLabel.Text = bind.name
        nameLabel.Parent = row

        local keyBtn = Instance.new("TextButton")
        keyBtn.Size = UDim2.new(0, 110, 0, 28)
        keyBtn.Position = UDim2.new(1, -122, 0.5, -14)
        keyBtn.BackgroundColor3 = COLORS.bindBg
        keyBtn.TextColor3 = COLORS.text
        keyBtn.Font = Enum.Font.GothamBold
        keyBtn.TextSize = 13
        keyBtn.Text = getBindDisplay(bind)
        keyBtn.AutoButtonColor = false
        keyBtn.ZIndex = 21
        keyBtn.Parent = row
        local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(0, 6); kc.Parent = keyBtn
        local ks = Instance.new("UIStroke"); ks.Color = COLORS.stroke; ks.Thickness = 1; ks.Transparency = 0.4; ks.Parent = keyBtn

        addConn(keyBtn.MouseEnter:Connect(function()
            if rebindingId ~= bind.id then
                TweenService:Create(keyBtn, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.bindBgHover}):Play()
            end
        end))
        addConn(keyBtn.MouseLeave:Connect(function()
            if rebindingId ~= bind.id then
                TweenService:Create(keyBtn, TweenInfo.new(0.12), {BackgroundColor3 = COLORS.bindBg}):Play()
            end
        end))
        addConn(keyBtn.MouseButton1Click:Connect(function()
            rebindingId = bind.id
            keyBtn.Text = "[...]"
            keyBtn.BackgroundColor3 = COLORS.accent
            keyBtn.TextColor3 = Color3.new(1,1,1)
        end))

        y = y + 48
    end

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size = UDim2.new(1, -20, 0, 32)
    resetBtn.Position = UDim2.new(0, 10, 0, y + 6)
    resetBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    resetBtn.TextColor3 = COLORS.text
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 13
    resetBtn.Text = "Reset to Defaults"
    resetBtn.AutoButtonColor = false
    resetBtn.ZIndex = 20
    resetBtn.Parent = contentContainer
    applyButtonStyle(resetBtn)
    addConn(resetBtn.MouseButton1Click:Connect(function()
        local menu = findBindById("menu"); if menu then menu.type = "key"; menu.value = Enum.KeyCode.RightControl end
        local cursor = findBindById("cursor"); if cursor then cursor.type = "key"; cursor.value = Enum.KeyCode.RightAlt end
        local aimb = findBindById("aimbot"); if aimb then aimb.type = "mouse"; aimb.value = Enum.UserInputType.MouseButton3 end
        rebindingId = nil
        buildTab("Binds")
    end))
end

local function buildTab(tabName)
    if unloaded then return end
    clearContent()
    currentTab = tabName
    for name, btn in pairs(tabButtons) do
        TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
            BackgroundColor3 = (name == tabName) and COLORS.tabActive or COLORS.tab,
            BackgroundTransparency = (name == tabName) and 0 or 0.2,
        }):Play()
    end

    local y = 10
    if tabName == "Combat" then
        y = makeToggle(contentContainer, y, "Aimbot", "aimbot")
        y = makeToggle(contentContainer, y, "SilentAim", "silentAim", function() updateFOVCircle() end)
        y = makeSlider(contentContainer, y, "FOV", "fov", 20, 600, 10, function() updateFOVCircle() end)
        y = makeToggle(contentContainer, y, "FOV Circle", "fovCircle", function() updateFOVCircle() end)
        y = makeToggle(contentContainer, y, "AutoParry", "autoParry")
        y = makeToggle(contentContainer, y, "Instant Heal", "instantHeal")
        y = makeToggle(contentContainer, y, "Self Heal", "selfHeal")
    elseif tabName == "Visuals" then
        y = makeToggle(contentContainer, y, "ESP", "esp")
        y = makeToggle(contentContainer, y, "ESP Box", "espBox")
        y = makeToggle(contentContainer, y, "ESP Health", "espHealth")
        y = makeToggle(contentContainer, y, "ESP Generators", "espGenerators")
        y = makeToggle(contentContainer, y, "ESP Pallets", "espPallets")
        y = makeToggle(contentContainer, y, "ESP Hooks", "espHooks")
        y = makeToggle(contentContainer, y, "Killer Alert", "killerAlert")
        y = makeToggle(contentContainer, y, "Fullbright", "fullbright", function() applyFullbright() end)
    elseif tabName == "Movement" then
        y = makeToggle(contentContainer, y, "Speed", "speedEnabled")
        y = makeSlider(contentContainer, y, "WalkSpeed", "speed", 16, 200)
        y = makeToggle(contentContainer, y, "Jump", "jumpEnabled")
        y = makeSlider(contentContainer, y, "JumpPower", "jumpPower", 50, 500)
        y = makeToggle(contentContainer, y, "Infinite Jump", "infiniteJump")
        y = makeToggle(contentContainer, y, "Noclip", "noclip")
        y = makeToggle(contentContainer, y, "Vault Speed", "vaultSpeed")
    elseif tabName == "Misc" then
        y = makeToggle(contentContainer, y, "Anti-AFK", "antiAfk")
        y = makeToggle(contentContainer, y, "Anti-Wiggle", "antiWiggle")
        y = makeToggle(contentContainer, y, "No Stun", "noStun")
        y = makeToggle(contentContainer, y, "Force Match Mode", "forceMatchMode")
    elseif tabName == "Teleport" then
        y = makeList(contentContainer, y, "Players", 90, function()
            local out = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    table.insert(out, {text = plr.Name .. " [" .. getRole(plr) .. "]", plr = plr})
                end
            end
            return out
        end, function(item) teleportToPlayer(item.plr) end)
        makeList(contentContainer, y, "Generators", 90, function()
            local out = {}
            for i, gen in ipairs(getGenerators()) do
                local pos = gen.part.Position
                local pct = getGeneratorRepair(gen)
                local pctStr = pct and (pct .. "%") or "?"
                table.insert(out, {text = "#" .. i .. " " .. gen.label .. " [" .. pctStr .. "] (" .. math.floor(pos.X) .. ", " .. math.floor(pos.Z) .. ")", gen = gen})
            end
            return out
        end, function(item) teleportToGenerator(item.gen) end)
    elseif tabName == "Binds" then
        buildBindsTab()
    end
end

local function createMenu()
    if gui then gui:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "SnowfallMenu"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 500, 0, 430)
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -215)
    mainFrame.BackgroundColor3 = COLORS.bg
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.ZIndex = 1
    mainFrame.Parent = gui
    local mainCorner = Instance.new("UICorner"); mainCorner.CornerRadius = UDim.new(0, 12); mainCorner.Parent = mainFrame
    local mainStroke = Instance.new("UIStroke"); mainStroke.Color = COLORS.strokeAccent; mainStroke.Thickness = 1.2; mainStroke.Transparency = 0.5; mainStroke.Parent = mainFrame

    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.bgTop),
        ColorSequenceKeypoint.new(1, COLORS.bgBottom),
    })
    bgGrad.Rotation = 90
    bgGrad.Parent = mainFrame

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 40)
    topBar.BackgroundColor3 = COLORS.panel
    topBar.BackgroundTransparency = 0.1
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 5
    topBar.Parent = mainFrame
    local topCorner = Instance.new("UICorner"); topCorner.CornerRadius = UDim.new(0, 12); topCorner.Parent = topBar

    local topAccent = Instance.new("Frame")
    topAccent.Size = UDim2.new(1, 0, 0, 2)
    topAccent.Position = UDim2.new(0, 0, 1, -2)
    topAccent.BackgroundColor3 = COLORS.accent
    topAccent.BorderSizePixel = 0
    topAccent.ZIndex = 6
    topAccent.Parent = topBar

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -100, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.TextColor3 = COLORS.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 6
    title.Text = "❄ Snowfall"
    title.Parent = topBar

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Size = UDim2.new(0, 120, 1, 0)
    subtitle.Position = UDim2.new(0, 100, 0, 0)
    subtitle.TextColor3 = COLORS.sub
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.ZIndex = 6
    subtitle.Text = "by N0rmalek"
    subtitle.Parent = topBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Text = "×"
    closeBtn.AutoButtonColor = false
    closeBtn.ZIndex = 6
    closeBtn.Parent = topBar
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 8); cc.Parent = closeBtn
    addConn(closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(230, 70, 70)}):Play()
    end))
    addConn(closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(200, 60, 60)}):Play()
    end))
    addConn(closeBtn.MouseButton1Click:Connect(function()
        setMenuBlur(false)
        unload()
    end))

    tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(0, 130, 1, -50)
    tabContainer.Position = UDim2.new(0, 10, 0, 44)
    tabContainer.BackgroundColor3 = COLORS.panel
    tabContainer.BackgroundTransparency = 0.2
    tabContainer.BorderSizePixel = 0
    tabContainer.ZIndex = 2
    tabContainer.Parent = mainFrame
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 8); tc.Parent = tabContainer
    local ts = Instance.new("UIStroke"); ts.Color = COLORS.stroke; ts.Thickness = 1; ts.Transparency = 0.5; ts.Parent = tabContainer

    local tabList = Instance.new("UIListLayout")
    tabList.Padding = UDim.new(0, 6)
    tabList.SortOrder = Enum.SortOrder.LayoutOrder
    tabList.Parent = tabContainer

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = tabContainer

    contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, -160, 1, -50)
    contentContainer.Position = UDim2.new(0, 150, 0, 44)
    contentContainer.BackgroundColor3 = COLORS.panel
    contentContainer.BackgroundTransparency = 0.2
    contentContainer.BorderSizePixel = 0
    contentContainer.ZIndex = 2
    contentContainer.Parent = mainFrame
    local cc2 = Instance.new("UICorner"); cc2.CornerRadius = UDim.new(0, 8); cc2.Parent = contentContainer
    local cs = Instance.new("UIStroke"); cs.Color = COLORS.stroke; cs.Thickness = 1; cs.Transparency = 0.5; cs.Parent = contentContainer

    local tabs = {"Combat", "Visuals", "Movement", "Misc", "Teleport", "Binds"}
    for _, tabName in ipairs(tabs) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(1, 0, 0, 34)
        tb.BackgroundColor3 = COLORS.tab
        tb.BackgroundTransparency = 0.2
        tb.TextColor3 = COLORS.text
        tb.Font = Enum.Font.GothamMedium
        tb.TextSize = 13
        tb.Text = tabName
        tb.AutoButtonColor = false
        tb.ZIndex = 5
        tb.Parent = tabContainer
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = tb
        tabButtons[tabName] = tb
        addConn(tb.MouseEnter:Connect(function()
            if currentTab ~= tabName then
                TweenService:Create(tb, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.tab:Lerp(Color3.new(1,1,1), 0.05), BackgroundTransparency = 0}):Play()
            end
        end))
        addConn(tb.MouseLeave:Connect(function()
            if currentTab ~= tabName then
                TweenService:Create(tb, TweenInfo.new(0.15), {BackgroundColor3 = COLORS.tab, BackgroundTransparency = 0.2}):Play()
            end
        end))
        addConn(tb.MouseButton1Click:Connect(function() buildTab(tabName) end))
    end

    buildTab("Combat")

    mainFrame.BackgroundTransparency = 1
    local tween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0})
    tween:Play()
end

createMenu()
createBlur()
setMenuBlur(true)
createWatermark()
createFOVCircle()
updateFOVCircle()
updateWatermarkStatus()

local function hookPlayer(plr)
    addConn(plr.CharacterAdded:Connect(function(char)
        task.wait(0.2)
        local r = char:FindFirstChild("HumanoidRootPart")
        if r then rootCache[plr] = r end
    end))
    if plr.Character then
        local r = plr.Character:FindFirstChild("HumanoidRootPart")
        if r then rootCache[plr] = r end
    end
end

for _, plr in ipairs(Players:GetPlayers()) do hookPlayer(plr) end
addConn(Players.PlayerAdded:Connect(hookPlayer))
addConn(Players.PlayerRemoving:Connect(function(plr)
    rootCache[plr] = nil
    roleCache[plr] = nil
end))

-- ============ INPUT (keybind-based) ============
addConn(UserInputService.InputBegan:Connect(function(input, processed)
    if unloaded then return end

    if rebindingId then
        local bind = findBindById(rebindingId)
        if bind then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode ~= Enum.KeyCode.Unknown then
                    bind.type = "key"
                    bind.value = input.KeyCode
                    rebindingId = nil
                    buildTab("Binds")
                end
                return
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                bind.type = "mouse"
                bind.value = input.UserInputType
                rebindingId = nil
                buildTab("Binds")
                return
            end
        end
        return
    end

    if processed then return end

    for _, bind in ipairs(keybinds) do
        if matchesBind(input, bind) then
            if bind.id == "menu" then
                settings.menuOpen = not settings.menuOpen
                if gui then gui.Enabled = settings.menuOpen end
                setMenuBlur(settings.menuOpen)
            elseif bind.id == "cursor" then
                toggleCursor()
            elseif bind.id == "aimbot" then
                settings.aimbot = not settings.aimbot
                if toggleButtons["Aimbot"] then
                    local btn = toggleButtons["Aimbot"]
                    local dot = btn:FindFirstChild("Dot")
                    TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        BackgroundColor3 = settings.aimbot and COLORS.on or COLORS.off,
                        BackgroundTransparency = settings.aimbot and 0 or 0.15,
                    }):Play()
                    if dot then
                        TweenService:Create(dot, TweenInfo.new(0.2), {
                            BackgroundColor3 = settings.aimbot and Color3.fromRGB(255,255,255) or COLORS.textDim,
                            BackgroundTransparency = settings.aimbot and 0 or 0.5,
                        }):Play()
                    end
                end
            end
            return
        end
    end
end))

-- ============ ANTI-AFK ============
addConn(LocalPlayer.Idled:Connect(function()
    if unloaded or not settings.antiAfk then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end))

-- ============ LOOPS ============
addConn(RunService.RenderStepped:Connect(function()
    if unloaded then return end
    if settings.aimbot and inMatch then silentAim() end
    applySpeed()
    applyNoclip()
    if settings.instantHeal then instantHeal() end
    if settings.selfHeal then selfHeal() end
    if settings.antiWiggle then antiWiggle() end
end))

addConn(RunService.Stepped:Connect(function()
    if unloaded then return end
    applyJump()
end))

addConn(RunService.Heartbeat:Connect(function()
    if unloaded then return end
    local now = tick()

    if (now - lastMatchCheck) >= settings.matchCheckInterval then
        lastMatchCheck = now
        local prev = inMatch
        inMatch = computeInMatch()
        if prev ~= inMatch then updateWatermarkStatus() end
    end

    if not inMatch then
        clearESP()
        clearGeneratorESP()
        clearPalletESP()
        clearHookESP()
        if fovCircleGui then
            local circle = fovCircleGui:FindFirstChild("Circle")
            if circle and circle.Visible then circle.Visible = false end
        end
        return
    end

    if settings.esp then
        if (now - lastESPPos) >= settings.espPosRefresh then
            drawESP()
            lastESPPos = now
        end
    else
        clearESP()
    end

    if settings.espGenerators then
        if (now - lastGenUpdate) >= settings.genRefresh then
            drawGeneratorESP()
            lastGenUpdate = now
        end
    else
        clearGeneratorESP()
    end

    if settings.espPallets then drawPalletESP() else clearPalletESP() end
    if settings.espHooks then drawHookESP() else clearHookESP() end

    if settings.autoParry then
        if (now - lastParry) > settings.parryRefresh then
            autoParry()
            lastParry = now
        end
    end

    if fovCircleGui then
        local circle = fovCircleGui:FindFirstChild("Circle")
        if circle and circle.Visible ~= (settings.fovCircle and settings.silentAim) then
            updateFOVCircle()
        end
    end
end))

addConn(LocalPlayer.CharacterAdded:Connect(function(char)
    if unloaded then return end
    task.wait(1)
    applySpeed()
    applyJump()
    if settings.fullbright then applyFullbright() end
    local r = char:FindFirstChild("HumanoidRootPart")
    if r then rootCache[LocalPlayer] = r end
end))