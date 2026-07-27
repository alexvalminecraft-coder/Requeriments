local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Connections = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local espObjects = {}
local playerHighlights = {}
local playerNameLabels = {}
local characterConnections = {}
local originalTransparency = {}
local xrayEnabled = false
local animalESPThreshold = 35000000

-- ============================================================
-- ANIMALS DATA
-- ============================================================
local AnimalsData = {}
local success, result = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
end)
if success then
    AnimalsData = result
else
    warn("Lava Hub: No se pudo cargar AnimalsData.")
end

local allAnimalsCache = {}
local PromptMemoryCache = {}
local InternalStealCache = {}
local LastTargetUID = nil
local AUTO_STEAL_PROX_RADIUS = 1000
local IsStealing = false
local StealProgress = 0
local CurrentStealTarget = nil
local autoStealEnabled = false
local stealConnection = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Lava Hub"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ============================================================
-- LAVA COLORS
-- ============================================================
local ACCENT_KEYS = {
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(255, 60, 0)),
    ColorSequenceKeypoint.new(0.2,  Color3.fromRGB(255, 120, 30)),
    ColorSequenceKeypoint.new(0.4,  Color3.fromRGB(255, 180, 60)),
    ColorSequenceKeypoint.new(0.6,  Color3.fromRGB(255, 140, 40)),
    ColorSequenceKeypoint.new(0.85, Color3.fromRGB(255, 80, 20)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(200, 40, 0)),
}

local BG_KEYS = {
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(40, 15, 8)),
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(60, 25, 12)),
    ColorSequenceKeypoint.new(0.7,  Color3.fromRGB(80, 35, 16)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(50, 20, 10)),
}

local COL_DARK  = Color3.fromRGB(40, 15, 8)
local COL_MID   = Color3.fromRGB(80, 35, 16)
local COL_WHITE = Color3.fromRGB(255, 255, 255)
local COL_DIM   = Color3.fromRGB(180, 100, 60)

local allGradients = {}

local function addGradient(parent, keys)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(keys or ACCENT_KEYS)
    g.Rotation = 0
    g.Parent = parent
    table.insert(allGradients, g)
    return g
end

local function addStrokeWithGradient(parent, thickness)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 2
    s.Color = COL_WHITE
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    addGradient(s)
    return s
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 10)
    c.Parent = parent
    return c
end

-- ============================================================
-- HUD FRAME
-- ============================================================
local hudFrame = Instance.new("Frame")
hudFrame.Name = "HUDFrame"
hudFrame.Size = UDim2.new(0, 310, 0, 74)
hudFrame.Position = UDim2.new(0.5, -155, 0, 80)
hudFrame.BackgroundColor3 = COL_DARK
hudFrame.BackgroundTransparency = 0.8
hudFrame.BorderSizePixel = 0
hudFrame.Parent = screenGui
corner(hudFrame, 14)
addGradient(hudFrame, BG_KEYS)
addStrokeWithGradient(hudFrame)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🌋 Lava Hub"
titleLabel.TextColor3 = COL_WHITE
titleLabel.TextSize = 22
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.ZIndex = 2
titleLabel.Parent = hudFrame
addGradient(titleLabel)

local madeByLabel = Instance.new("TextLabel")
madeByLabel.Size = UDim2.new(1, 0, 0, 18)
madeByLabel.Position = UDim2.new(0, 0, 0, 30)
madeByLabel.BackgroundTransparency = 1
madeByLabel.Text = "By 0ctavius_05"
madeByLabel.TextColor3 = COL_DIM
madeByLabel.TextScaled = false
madeByLabel.TextSize = 13
madeByLabel.Font = Enum.Font.GothamBold
madeByLabel.TextXAlignment = Enum.TextXAlignment.Center
madeByLabel.ZIndex = 2
madeByLabel.Parent = hudFrame

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, 0, 0, 18)
statsLabel.Position = UDim2.new(0, 0, 0, 50)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "FPS: --  PING: --ms"
statsLabel.TextColor3 = COL_WHITE
statsLabel.TextScaled = false
statsLabel.TextSize = 15
statsLabel.Font = Enum.Font.GothamBold
statsLabel.TextXAlignment = Enum.TextXAlignment.Center
statsLabel.ZIndex = 2
statsLabel.Parent = hudFrame

-- ============================================================
-- TOP BUTTONS (1 2 3) + MENU TOGGLE BUTTON
-- ============================================================
local BTN_SIZE = 44
local BTN_GAP  = 8
local NUM_BTNS = 3
local totalBW  = NUM_BTNS * BTN_SIZE + (NUM_BTNS - 1) * BTN_GAP
local startX   = -155 + (310 - totalBW) / 2

local topButtons = {}

for i = 1, NUM_BTNS do
    local btn = Instance.new("TextButton")
    btn.Name = "Btn" .. i
    btn.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
    btn.Position = UDim2.new(0.5, startX + (i-1)*(BTN_SIZE+BTN_GAP), 0, 80 - BTN_SIZE - 6)
    btn.BackgroundColor3 = COL_DARK
    btn.BackgroundTransparency = 0.6
    btn.BorderSizePixel = 0
    btn.Text = tostring(i)
    btn.TextColor3 = COL_WHITE
    btn.TextSize = 22
    btn.Font = Enum.Font.GothamBold
    btn.ZIndex = 2
    btn.AutoButtonColor = false
    btn.Active = true
    btn.Visible = true
    btn.Parent = screenGui
    corner(btn, 7)
    addStrokeWithGradient(btn)
    topButtons[i] = btn
end

local menuToggleBtn = Instance.new("TextButton")
menuToggleBtn.Name = "MenuToggleBtn"
menuToggleBtn.Size = UDim2.new(0, 44, 0, 24)
menuToggleBtn.Position = UDim2.new(0.5, -22, 0, 80 + 74 + 4)
menuToggleBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
menuToggleBtn.BackgroundTransparency = 0.3
menuToggleBtn.BorderSizePixel = 0
menuToggleBtn.Text = "Menu"
menuToggleBtn.TextColor3 = COL_WHITE
menuToggleBtn.TextSize = 13
menuToggleBtn.Font = Enum.Font.GothamBold
menuToggleBtn.ZIndex = 3
menuToggleBtn.AutoButtonColor = false
menuToggleBtn.Active = true
menuToggleBtn.Parent = screenGui
corner(menuToggleBtn, 6)
addStrokeWithGradient(menuToggleBtn, 1)

-- ============================================================
-- MAIN PANEL
-- ============================================================
local PANEL_W = 340
local PANEL_H = 420

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
panel.Position = UDim2.new(0.5, -PANEL_W/2, 0.5, -PANEL_H/2)
panel.BackgroundColor3 = COL_DARK
panel.BackgroundTransparency = 0.6
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 10
panel.Parent = screenGui
corner(panel, 14)
addStrokeWithGradient(panel, 2)

local panelTitle = Instance.new("TextLabel")
panelTitle.Size = UDim2.new(1, -20, 0, 30)
panelTitle.Position = UDim2.new(0, 10, 0, 4)
panelTitle.BackgroundTransparency = 1
panelTitle.Text = "🌋 Lava Hub"
panelTitle.TextColor3 = COL_WHITE
panelTitle.TextSize = 20
panelTitle.Font = Enum.Font.GothamBold
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.ZIndex = 11
panelTitle.Parent = panel
addGradient(panelTitle)

local panelSubtitle = Instance.new("TextLabel")
panelSubtitle.Size = UDim2.new(1, -20, 0, 14)
panelSubtitle.Position = UDim2.new(0, 10, 0, 30)
panelSubtitle.BackgroundTransparency = 1
panelSubtitle.Text = "By 0ctavius_05"
panelSubtitle.TextColor3 = COL_DIM
panelSubtitle.TextSize = 12
panelSubtitle.Font = Enum.Font.GothamBold
panelSubtitle.TextXAlignment = Enum.TextXAlignment.Left
panelSubtitle.ZIndex = 11
panelSubtitle.Parent = panel

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 0, 48)
divider.BackgroundColor3 = COL_WHITE
divider.BorderSizePixel = 0
divider.ZIndex = 11
divider.Parent = panel

-- Draggable main panel
do
    local dragging, dragStart, startPos = false, nil, nil
    local function beginDrag(pos)
        dragging = true; dragStart = pos; startPos = panel.Position
    end
    local function endDrag() dragging = false end
    local function moveDrag(pos)
        if not dragging then return end
        local d = pos - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
    panelTitle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then beginDrag(i.Position) end
    end)
    panelTitle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then endDrag() end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then moveDrag(i.Position) end
    end)
end

local tabNames = {"Main", "Visual"}
local tabWidth = (PANEL_W - 20) / #tabNames - 4
local tabHeight = 30
local tabY = 54

local tabButtons = {}
local tabContents = {}

local function setTabActive(btn, isActive)
    if isActive then
        btn.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    else
        btn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    end
end

for i, name in ipairs(tabNames) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = "Tab_" .. name
    tabBtn.Size = UDim2.new(0, tabWidth, 0, tabHeight)
    tabBtn.Position = UDim2.new(0, 10 + (i-1)*(tabWidth+4), 0, tabY)
    tabBtn.BorderSizePixel = 0
    tabBtn.Text = name
    tabBtn.TextColor3 = COL_WHITE
    tabBtn.TextSize = 13
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.ZIndex = 11
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = panel
    corner(tabBtn, 8)
    setTabActive(tabBtn, i == 1)

    local content = Instance.new("ScrollingFrame")
    content.Name = "Content_" .. name
    content.Size = UDim2.new(1, -20, 1, -(tabY + tabHeight + 14))
    content.Position = UDim2.new(0, 10, 0, tabY + tabHeight + 8)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.ScrollBarImageColor3 = Color3.fromRGB(255, 120, 0)
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.Visible = i == 1
    content.ZIndex = 11
    content.Parent = panel

    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = content

    tabButtons[i] = tabBtn
    tabContents[i] = content

    tabBtn.MouseButton1Click:Connect(function()
        for j, tb in ipairs(tabButtons) do
            setTabActive(tb, j == i)
            tabContents[j].Visible = j == i
        end
    end)
end

local function makeSection(parent, labelText)
    local sec = Instance.new("TextLabel")
    sec.Size = UDim2.new(1, 0, 0, 24)
    sec.BackgroundTransparency = 1
    sec.Text = labelText
    sec.TextColor3 = COL_WHITE
    sec.TextSize = 12
    sec.Font = Enum.Font.GothamBold
    sec.TextXAlignment = Enum.TextXAlignment.Left
    sec.ZIndex = 12
    sec.LayoutOrder = #parent:GetChildren()
    sec.Parent = parent

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = COL_WHITE
    line.BorderSizePixel = 0
    line.ZIndex = 12
    line.Parent = sec
end

local function makeToggle(parent, labelText, default, onToggle)
    local state = default or false

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0
    row.ZIndex = 12
    row.LayoutOrder = #parent:GetChildren()
    row.Parent = parent
    corner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COL_WHITE
    lbl.TextSize = 13
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 13
    lbl.Parent = row

    local trackFrame = Instance.new("Frame")
    trackFrame.Size = UDim2.new(0, 40, 0, 20)
    trackFrame.Position = UDim2.new(1, -50, 0.5, -10)
    trackFrame.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    trackFrame.BorderSizePixel = 0
    trackFrame.ZIndex = 13
    trackFrame.Parent = row
    corner(trackFrame, 10)

    local trackGrad = Instance.new("UIGradient")
    trackGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 35, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 35, 20)),
    }
    trackGrad.Parent = trackFrame

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = COL_WHITE
    knob.BorderSizePixel = 0
    knob.ZIndex = 14
    knob.Parent = trackFrame
    corner(knob, 9)

    local function updateToggle(on, skipCallback)
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = COL_WHITE,
        }):Play()
        if on then
            trackGrad.Color = ColorSequence.new(ACCENT_KEYS)
            table.insert(allGradients, trackGrad)
        else
            trackGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 35, 20)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 35, 20)),
            }
            for idx, g in ipairs(allGradients) do
                if g == trackGrad then table.remove(allGradients, idx) break end
            end
        end
        if not skipCallback and onToggle then onToggle(on) end
    end

    updateToggle(state, true)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 15
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        state = not state
        updateToggle(state)
    end)
end

local mainContent   = tabContents[1]
local visualContent = tabContents[2]

local openIsPanel
local closeIsPanel

makeSection(mainContent, "⚡ Instant Steal")
makeToggle(mainContent, "Instant Steal Panel", false, function(on)
    if on then openIsPanel() else closeIsPanel() end
end)

-- ============================================================
-- HELPERS
-- ============================================================
local function getHRP()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function isMyBase(plotName)
    local plot = workspace.Plots:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") then
            return yourBase.Enabled == true
        end
    end
    return false
end

local function smartInteract(number)
    local hrp = getHRP()
    if not hrp then return end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end

    local closestPlot, minDistance = nil, math.huge
    for _, plot in pairs(plots:GetChildren()) do
        if plot:IsA("Model") and not isMyBase(plot.Name) then
            local pos = (plot.PrimaryPart and plot.PrimaryPart.Position) or plot:GetPivot().Position
            local dist = (hrp.Position - pos).Magnitude
            if dist < minDistance then
                closestPlot = plot
                minDistance = dist
            end
        end
    end

    if closestPlot and closestPlot:FindFirstChild("Unlock") then
        local items = {}
        for _, item in pairs(closestPlot.Unlock:GetChildren()) do
            local pos = item:IsA("Model") and item:GetPivot().Position or item.Position
            table.insert(items, { Obj = item, Y = pos.Y })
        end
        table.sort(items, function(a, b) return a.Y < b.Y end)
        if items[number] then
            for _, pr in pairs(items[number].Obj:GetDescendants()) do
                if pr:IsA("ProximityPrompt") then
                    fireproximityprompt(pr)
                end
            end
        end
    end
end

for i, btn in ipairs(topButtons) do
    btn.MouseButton1Click:Connect(function()
        smartInteract(i)
    end)
end

-- ============================================================
-- BASE SIDE DETECTION
-- ============================================================
local BASE_LEFT_SIGN_POS  = Vector3.new(-342.43927001953125, 10.464665412902832, 6.106575012207031)
local BASE_RIGHT_SIGN_POS = Vector3.new(-342.43939208984375, 10.398869514465332, 113.10681915283203)
local BASE_DETECT_DIST    = 20

local LEFT_FIRST_TP  = Vector3.new(-353.8, 0.5, 6.3)
local LEFT_SECOND_TP = Vector3.new(-350.8, 0.4, 105.4)
local LEFT_THIRD_TP  = Vector3.new(-337.3, -5.1, 101.9)
local LEFT_LAST_TP   = Vector3.new(-353.10198974609375, -7.000002384185791, 41.875308990478516)

local RIGHT_FIRST_TP  = Vector3.new(-347.99346923828125, 0.6147812008857727, 113.73497009277344)
local RIGHT_SECOND_TP = Vector3.new(-347.1276550292969,  0.4199885427951813, 6.275444507598877)
local RIGHT_THIRD_TP  = Vector3.new(-336.80865478515625, -5.101069927215576, 17.750465393066406)
local RIGHT_LAST_TP   = Vector3.new(-355.8482666015625, -7.000002384185791, 42.20612716674805)

local currentBaseSide = "?"
local isTitleSideLabel

local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") and isMyBase(plot.Name) then
            return plot
        end
    end
    return nil
end

local function detectBaseSide()
    local myPlot = getMyPlot()
    if not myPlot then currentBaseSide = "?"; return end
    local sign = myPlot:FindFirstChild("PlotSign")
    if not sign then currentBaseSide = "?"; return end
    local signPos = sign.Position
    local dL = (signPos - BASE_LEFT_SIGN_POS).Magnitude
    local dR = (signPos - BASE_RIGHT_SIGN_POS).Magnitude
    if dL <= BASE_DETECT_DIST then
        currentBaseSide = "Left"
    elseif dR <= BASE_DETECT_DIST then
        currentBaseSide = "Right"
    else
        currentBaseSide = "?"
    end
    if isTitleSideLabel then
        isTitleSideLabel.Text = currentBaseSide
        isTitleSideLabel.TextColor3 = currentBaseSide == "Left" and Color3.fromRGB(255, 100, 50)
            or currentBaseSide == "Right" and Color3.fromRGB(255, 180, 80)
            or COL_DIM
    end
end

task.spawn(function()
    while true do
        task.wait(2)
        pcall(detectBaseSide)
    end
end)

-- ============================================================
-- ANIMAL SCANNER
-- ============================================================
local function scanSinglePlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if isMyBase(plot.Name) then return end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return end
    for _, podium in ipairs(podiums:GetChildren()) do
        if podium:IsA("Model") and podium:FindFirstChild("Base") then
            local animalName = "Unknown"
            local spawn = podium.Base:FindFirstChild("Spawn")
            if spawn then
                for _, child in ipairs(spawn:GetChildren()) do
                    if child:IsA("Model") and child.Name ~= "PromptAttachment" then
                        animalName = child.Name
                        local animalInfo = AnimalsData[animalName]
                        if animalInfo and animalInfo.DisplayName then
                            animalName = animalInfo.DisplayName
                        end
                        break
                    end
                end
            end
            local uid = plot.Name .. "_" .. podium.Name
            for i = #allAnimalsCache, 1, -1 do
                if allAnimalsCache[i].uid == uid then
                    table.remove(allAnimalsCache, i)
                end
            end
            table.insert(allAnimalsCache, {
                name = animalName,
                plot = plot.Name,
                slot = podium.Name,
                worldPosition = podium:GetPivot().Position,
                uid = uid,
            })
        end
    end
end

local function initializeScanner()
    task.wait(2)
    local plots = workspace:WaitForChild("Plots", 10)
    if not plots then return end

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") then scanSinglePlot(plot) end
    end

    plots.ChildAdded:Connect(function(plot)
        if plot:IsA("Model") then
            task.wait(0.5)
            scanSinglePlot(plot)
        end
    end)

    plots.ChildRemoved:Connect(function(plot)
        for i = #allAnimalsCache, 1, -1 do
            if allAnimalsCache[i].plot == plot.Name then
                table.remove(allAnimalsCache, i)
            end
        end
    end)

    local function watchPlot(plot)
        if not plot or not plot:IsA("Model") then return end
        local podiums = plot:WaitForChild("AnimalPodiums", 5)
        if not podiums then return end
        podiums.ChildAdded:Connect(function(podium)
            task.wait(0.3)
            scanSinglePlot(plot)
        end)
        podiums.ChildRemoved:Connect(function(podium)
            local uid = plot.Name .. "_" .. podium.Name
            for i = #allAnimalsCache, 1, -1 do
                if allAnimalsCache[i].uid == uid then
                    table.remove(allAnimalsCache, i)
                    PromptMemoryCache[uid] = nil
                end
            end
        end)
        for _, podium in ipairs(podiums:GetChildren()) do
            if podium:IsA("Model") and podium:FindFirstChild("Base") then
                local spawnFolder = podium.Base:FindFirstChild("Spawn")
                if spawnFolder then
                    spawnFolder.ChildAdded:Connect(function() task.wait(0.1); scanSinglePlot(plot) end)
                    spawnFolder.ChildRemoved:Connect(function() task.wait(0.1); scanSinglePlot(plot) end)
                end
            end
        end
    end

    for _, plot in ipairs(plots:GetChildren()) do
        task.spawn(watchPlot, plot)
    end
    plots.ChildAdded:Connect(function(plot)
        task.spawn(watchPlot, plot)
    end)
end

local function findProximityPromptForAnimal(animalData)
    if not animalData then return nil end
    local cachedPrompt = PromptMemoryCache[animalData.uid]
    if cachedPrompt and cachedPrompt.Parent then return cachedPrompt end
    local plot = workspace.Plots:FindFirstChild(animalData.plot)
    if not plot then return nil end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    local podium = podiums:FindFirstChild(animalData.slot)
    if not podium then return nil end
    local base = podium:FindFirstChild("Base")
    if not base then return nil end
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    local attach = spawn:FindFirstChild("PromptAttachment")
    if not attach then return nil end
    for _, p in ipairs(attach:GetChildren()) do
        if p:IsA("ProximityPrompt") then
            PromptMemoryCache[animalData.uid] = p
            return p
        end
    end
    return nil
end

local function shouldSteal(animalData)
    if not animalData or not animalData.worldPosition then return false end
    local hrp = getHRP()
    if not hrp then return false end
    return (hrp.Position - animalData.worldPosition).Magnitude <= AUTO_STEAL_PROX_RADIUS
end

local function buildStealCallbacks(prompt)
    if InternalStealCache[prompt] then return end
    local data = { holdCallbacks = {}, triggerCallbacks = {}, ready = true }
    local ok1, conns1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
    if ok1 and type(conns1) == "table" then
        for _, conn in ipairs(conns1) do
            if type(conn.Function) == "function" then table.insert(data.holdCallbacks, conn.Function) end
        end
    end
    local ok2, conns2 = pcall(getconnections, prompt.Triggered)
    if ok2 and type(conns2) == "table" then
        for _, conn in ipairs(conns2) do
            if type(conn.Function) == "function" then table.insert(data.triggerCallbacks, conn.Function) end
        end
    end
    if (#data.holdCallbacks > 0) or (#data.triggerCallbacks > 0) then
        InternalStealCache[prompt] = data
    end
end

local function executeInternalStealAsync(prompt, animalData)
    local data = InternalStealCache[prompt]
    if not data or not data.ready then return false end
    data.ready = false
    IsStealing = true
    StealProgress = 0
    CurrentStealTarget = animalData
    task.spawn(function()
        if #data.holdCallbacks > 0 then
            for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
        end
        local startTime = tick()
        while tick() - startTime < 1.3 do
            StealProgress = (tick() - startTime) / 1.3
            task.wait(0.05)
        end
        StealProgress = 1
        if #data.triggerCallbacks > 0 then
            for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
        end
        task.wait(0.1)
        data.ready = true
        task.wait(0.3)
        IsStealing = false
        StealProgress = 0
        CurrentStealTarget = nil
    end)
    return true
end

local function attemptSteal(prompt, animalData)
    if not prompt or not prompt.Parent then return false end
    buildStealCallbacks(prompt)
    if not InternalStealCache[prompt] then return false end
    return executeInternalStealAsync(prompt, animalData)
end

local function getNearestAnimalFromPos(pos)
    local nearest, minDist = nil, math.huge
    for _, animalData in ipairs(allAnimalsCache) do
        if not isMyBase(animalData.plot) and animalData.worldPosition then
            local dist = (pos - animalData.worldPosition).Magnitude
            if dist < minDist then minDist = dist; nearest = animalData end
        end
    end
    return nearest
end

local function getNearestAnimal()
    local nearest, minDist = nil, math.huge
    local hrp = getHRP()
    if not hrp then return nil end
    for _, animalData in ipairs(allAnimalsCache) do
        if not isMyBase(animalData.plot) and animalData.worldPosition then
            local dist = (hrp.Position - animalData.worldPosition).Magnitude
            if dist < minDist then minDist = dist; nearest = animalData end
        end
    end
    return nearest
end

local function startAutoSteal()
    if stealConnection then stealConnection:Disconnect() end
    stealConnection = RunService.Heartbeat:Connect(function()
        if not autoStealEnabled or IsStealing then return end
        local target = getNearestAnimal()
        if not target or not shouldSteal(target) then return end
        if LastTargetUID ~= target.uid then LastTargetUID = target.uid end
        local prompt = PromptMemoryCache[target.uid]
        if not prompt or not prompt.Parent then prompt = findProximityPromptForAnimal(target) end
        if prompt then attemptSteal(prompt, target) end
    end)
end

local function stopAutoSteal()
    if stealConnection then stealConnection:Disconnect(); stealConnection = nil end
    IsStealing = false
    StealProgress = 0
end

-- ============================================================
-- STEAL BAR
-- ============================================================
local stealBarGui = Instance.new("ScreenGui")
stealBarGui.Name = "StealBarGui"
stealBarGui.ResetOnSpawn = false
stealBarGui.DisplayOrder = 998
stealBarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
stealBarGui.Parent = playerGui

local stealBarHolder = Instance.new("Frame")
stealBarHolder.Size = UDim2.new(0, 320, 0, 48)
stealBarHolder.Position = UDim2.new(0.5, -160, 1, -130)
stealBarHolder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
stealBarHolder.BackgroundTransparency = 0.6
stealBarHolder.BorderSizePixel = 0
stealBarHolder.Visible = true
stealBarHolder.ZIndex = 20
stealBarHolder.Parent = stealBarGui
corner(stealBarHolder, 12)
addStrokeWithGradient(stealBarHolder, 2)

local stealBarLabel = Instance.new("TextLabel")
stealBarLabel.Size = UDim2.new(1, 0, 0, 16)
stealBarLabel.Position = UDim2.new(0, 0, 0, 6)
stealBarLabel.BackgroundTransparency = 1
stealBarLabel.Text = "🔥 Stealing..."
stealBarLabel.TextColor3 = COL_WHITE
stealBarLabel.TextSize = 12
stealBarLabel.Font = Enum.Font.GothamBold
stealBarLabel.TextXAlignment = Enum.TextXAlignment.Center
stealBarLabel.ZIndex = 21
stealBarLabel.Parent = stealBarHolder

local stealBarBg = Instance.new("Frame")
stealBarBg.Size = UDim2.new(1, -24, 0, 10)
stealBarBg.Position = UDim2.new(0, 12, 0, 28)
stealBarBg.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
stealBarBg.BorderSizePixel = 0
stealBarBg.ZIndex = 21
stealBarBg.Parent = stealBarHolder
corner(stealBarBg, 5)

local stealBarFill = Instance.new("Frame")
stealBarFill.Size = UDim2.new(0, 0, 1, 0)
stealBarFill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
stealBarFill.BorderSizePixel = 0
stealBarFill.ZIndex = 22
stealBarFill.Parent = stealBarBg
corner(stealBarFill, 5)

task.spawn(function()
    while true do
        task.wait(0.03)
        TweenService:Create(stealBarFill, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {
            Size = UDim2.new(StealProgress, 0, 1, 0)
        }):Play()
    end
end)

task.spawn(initializeScanner)

makeSection(mainContent, "🦊 Auto Steal")
makeToggle(mainContent, "Auto Steal", false, function(on)
    autoStealEnabled = on
    if on then startAutoSteal() else stopAutoSteal() end
end)
makeToggle(mainContent, "Unlock Base", true, function(on)
    for _, b in ipairs(topButtons) do
        b.Visible = on
    end
end)

-- ============================================================
-- SHARED PANEL HELPERS
-- ============================================================
local function makePanelToggle(parent, labelText, defaultState, onToggleFn)
    local state = defaultState or false
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 30)
    row.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    row.BackgroundTransparency = 0.2
    row.BorderSizePixel = 0
    row.ZIndex = 11
    row.Parent = parent
    corner(row, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COL_WHITE
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 12
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 36, 0, 18)
    track.Position = UDim2.new(1, -44, 0.5, -9)
    track.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    track.BorderSizePixel = 0
    track.ZIndex = 12
    track.Parent = row
    corner(track, 9)

    local tGrad = Instance.new("UIGradient")
    tGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 35, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 35, 20)),
    }
    tGrad.Parent = track

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = COL_WHITE
    knob.BorderSizePixel = 0
    knob.ZIndex = 13
    knob.Parent = track
    corner(knob, 7)

    local function update(on, skipCallback)
        TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
        }):Play()
        if on then
            tGrad.Color = ColorSequence.new(ACCENT_KEYS)
            table.insert(allGradients, tGrad)
        else
            tGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 35, 20)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 35, 20)),
            }
            for idx, g in ipairs(allGradients) do
                if g == tGrad then table.remove(allGradients, idx) break end
            end
        end
        if not skipCallback and onToggleFn then onToggleFn(on) end
    end

    update(state, true)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 14
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        state = not state
        update(state)
    end)
end

local function makeSlider(parent, labelText, minVal, maxVal, defaultVal, onChangeFn)
    local sliderRow = Instance.new("Frame")
    sliderRow.Size = UDim2.new(1, -20, 0, 46)
    sliderRow.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    sliderRow.BackgroundTransparency = 0.2
    sliderRow.BorderSizePixel = 0
    sliderRow.ZIndex = 11
    sliderRow.Parent = parent
    corner(sliderRow, 6)

    local sLbl = Instance.new("TextLabel")
    sLbl.Size = UDim2.new(0.65, 0, 0, 22)
    sLbl.Position = UDim2.new(0, 8, 0, 2)
    sLbl.BackgroundTransparency = 1
    sLbl.Text = labelText
    sLbl.TextColor3 = COL_WHITE
    sLbl.TextSize = 12
    sLbl.Font = Enum.Font.GothamBold
    sLbl.TextXAlignment = Enum.TextXAlignment.Left
    sLbl.ZIndex = 12
    sLbl.Parent = sliderRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.3, -8, 0, 22)
    valLbl.Position = UDim2.new(0.7, 0, 0, 2)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(defaultVal)
    valLbl.TextColor3 = COL_WHITE
    valLbl.TextSize = 12
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex = 12
    valLbl.Parent = sliderRow

    local trackBg = Instance.new("Frame")
    trackBg.Size = UDim2.new(1, -16, 0, 4)
    trackBg.Position = UDim2.new(0, 8, 0, 32)
    trackBg.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    trackBg.BorderSizePixel = 0
    trackBg.ZIndex = 12
    trackBg.Parent = sliderRow
    corner(trackBg, 2)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
    fill.BorderSizePixel = 0
    fill.ZIndex = 13
    fill.Parent = trackBg
    corner(fill, 2)

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 12, 0, 12)
    thumb.AnchorPoint = Vector2.new(0.5, 0.5)
    thumb.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
    thumb.BackgroundColor3 = COL_WHITE
    thumb.BorderSizePixel = 0
    thumb.Text = ""
    thumb.ZIndex = 14
    thumb.AutoButtonColor = false
    thumb.Parent = trackBg
    corner(thumb, 6)

    local dragging = false
    thumb.MouseButton1Down:Connect(function() dragging = true end)
    thumb.TouchLongPress:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((inp.Position.X - trackBg.AbsolutePosition.X) / trackBg.AbsoluteSize.X, 0, 1)
            local val = math.floor(minVal + rel * (maxVal - minVal))
            fill.Size = UDim2.new(rel, 0, 1, 0)
            thumb.Position = UDim2.new(rel, 0, 0.5, 0)
            valLbl.Text = tostring(val)
            if onChangeFn then onChangeFn(val) end
        end
    end)
end

local function makeDraggable(panelFrame, titleLabel)
    local dragging, dragStart, startPos = false, nil, nil
    titleLabel.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = inp.Position; startPos = panelFrame.Position
        end
    end)
    titleLabel.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - dragStart
            panelFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ============================================================
-- BOOSTER PANEL
-- ============================================================
local BP_W = 200
local BP_H = 235

local boosterPanel = Instance.new("Frame")
boosterPanel.Name = "BoosterPanel"
boosterPanel.Size = UDim2.new(0, BP_W, 0, BP_H)
boosterPanel.Position = UDim2.new(1, -BP_W - 20, 0.5, -BP_H / 2)
boosterPanel.BackgroundColor3 = COL_DARK
boosterPanel.BackgroundTransparency = 0.6
boosterPanel.BorderSizePixel = 0
boosterPanel.Visible = false
boosterPanel.ZIndex = 10
boosterPanel.Active = true
boosterPanel.Parent = screenGui
corner(boosterPanel, 14)
addStrokeWithGradient(boosterPanel, 2)

local bpTitle = Instance.new("TextLabel")
bpTitle.Size = UDim2.new(1, -12, 0, 28)
bpTitle.Position = UDim2.new(0, 10, 0, 6)
bpTitle.BackgroundTransparency = 1
bpTitle.Text = "⚡ Booster"
bpTitle.TextColor3 = COL_WHITE
bpTitle.TextSize = 16
bpTitle.Font = Enum.Font.GothamBold
bpTitle.TextXAlignment = Enum.TextXAlignment.Left
bpTitle.ZIndex = 11
bpTitle.Parent = boosterPanel

local bpDivider = Instance.new("Frame")
bpDivider.Size = UDim2.new(1, -20, 0, 1)
bpDivider.Position = UDim2.new(0, 10, 0, 36)
bpDivider.BackgroundColor3 = COL_WHITE
bpDivider.BorderSizePixel = 0
bpDivider.ZIndex = 11
bpDivider.Parent = boosterPanel

local bpContent = Instance.new("Frame")
bpContent.Size = UDim2.new(1, 0, 1, -44)
bpContent.Position = UDim2.new(0, 0, 0, 44)
bpContent.BackgroundTransparency = 1
bpContent.ZIndex = 11
bpContent.Parent = boosterPanel

local bpLayout = Instance.new("UIListLayout")
bpLayout.SortOrder = Enum.SortOrder.LayoutOrder
bpLayout.Padding = UDim.new(0, 6)
bpLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bpLayout.Parent = bpContent

local bpPadding = Instance.new("UIPadding")
bpPadding.PaddingTop = UDim.new(0, 6)
bpPadding.Parent = bpContent

makeDraggable(boosterPanel, bpTitle)

local wsEnabled = false
local ssEnabled = true
local wsValue = 59
local ssValue = 29

local function getMovementDirection()
    local c = player.Character
    if not c then return Vector3.new(0,0,0) end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return Vector3.new(0,0,0) end
    local md = hum.MoveDirection
    if md.Magnitude < 0.05 then return Vector3.new(0,0,0) end
    return md
end

local function startSpeedBooster()
    if Connections.speedBooster then return end
    Connections.speedBooster = RunService.Heartbeat:Connect(function()
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local isStealing = player:GetAttribute("Stealing")
        if isStealing and ssEnabled then
            local md = getMovementDirection()
            if md.Magnitude > 0.05 then
                h.AssemblyLinearVelocity = Vector3.new(md.X * ssValue, h.AssemblyLinearVelocity.Y, md.Z * ssValue)
            end
        elseif wsEnabled then
            local md = getMovementDirection()
            if md.Magnitude > 0.05 then
                h.AssemblyLinearVelocity = Vector3.new(md.X * wsValue, h.AssemblyLinearVelocity.Y, md.Z * wsValue)
            end
        end
    end)
end

local function stopSpeedBooster()
    if Connections.speedBooster then
        Connections.speedBooster:Disconnect()
        Connections.speedBooster = nil
    end
end

local function refreshBooster()
    if wsEnabled or ssEnabled then
        startSpeedBooster()
    else
        stopSpeedBooster()
    end
end

makePanelToggle(bpContent, "Walk Speed", false, function(on)
    wsEnabled = on
    refreshBooster()
end)

makeSlider(bpContent, "Walk Speed", 0, 59, 59, function(val)
    wsValue = val
end)

makePanelToggle(bpContent, "Steal Speed", true, function(on)
    ssEnabled = on
    refreshBooster()
end)

makeSlider(bpContent, "Steal Speed", 0, 29, 29, function(val)
    ssValue = val
end)

local function openBoosterPanel()
    boosterPanel.Visible = true
    boosterPanel.Size = UDim2.new(0, BP_W, 0, 0)
    boosterPanel.BackgroundTransparency = 1
    TweenService:Create(boosterPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, BP_W, 0, BP_H),
        BackgroundTransparency = 0.6,
    }):Play()
end

local function closeBoosterPanel()
    local t = TweenService:Create(boosterPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, BP_W, 0, 0),
        BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function() boosterPanel.Visible = false end)
end

-- ============================================================
-- SERVER PANEL
-- ============================================================
local SP_W = 200
local SP_BTN_H = 34
local SP_BTNS = {"Rejoin Server", "Kick Self", "Force Reset"}
local SP_H = 44 + #SP_BTNS * (SP_BTN_H + 6) + 6

local serverPanel = Instance.new("Frame")
serverPanel.Name = "ServerPanel"
serverPanel.Size = UDim2.new(0, SP_W, 0, SP_H)
serverPanel.Position = UDim2.new(1, -SP_W - 20, 0.5, BP_H / 2 + 10)
serverPanel.BackgroundColor3 = COL_DARK
serverPanel.BackgroundTransparency = 0.6
serverPanel.BorderSizePixel = 0
serverPanel.Visible = false
serverPanel.ZIndex = 10
serverPanel.Active = true
serverPanel.Parent = screenGui
corner(serverPanel, 14)
addStrokeWithGradient(serverPanel, 2)

local spTitle = Instance.new("TextLabel")
spTitle.Size = UDim2.new(1, -12, 0, 28)
spTitle.Position = UDim2.new(0, 10, 0, 6)
spTitle.BackgroundTransparency = 1
spTitle.Text = "🌐 Server"
spTitle.TextColor3 = COL_WHITE
spTitle.TextSize = 16
spTitle.Font = Enum.Font.GothamBold
spTitle.TextXAlignment = Enum.TextXAlignment.Left
spTitle.ZIndex = 11
spTitle.Parent = serverPanel

local spDivider = Instance.new("Frame")
spDivider.Size = UDim2.new(1, -20, 0, 1)
spDivider.Position = UDim2.new(0, 10, 0, 36)
spDivider.BackgroundColor3 = COL_WHITE
spDivider.BorderSizePixel = 0
spDivider.ZIndex = 11
spDivider.Parent = serverPanel

local spContent = Instance.new("Frame")
spContent.Size = UDim2.new(1, 0, 1, -44)
spContent.Position = UDim2.new(0, 0, 0, 44)
spContent.BackgroundTransparency = 1
spContent.ZIndex = 11
spContent.Parent = serverPanel

local spLayout = Instance.new("UIListLayout")
spLayout.SortOrder = Enum.SortOrder.LayoutOrder
spLayout.Padding = UDim.new(0, 6)
spLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
spLayout.Parent = spContent

local spPadding = Instance.new("UIPadding")
spPadding.PaddingTop = UDim.new(0, 6)
spPadding.Parent = spContent

makeDraggable(serverPanel, spTitle)

local TeleportService = game:GetService("TeleportService")

local spActions = {
    ["Rejoin Server"] = function()
        TeleportService:Teleport(game.PlaceId, player)
    end,
    ["Kick Self"] = function()
        player:Kick("Lava Hub")
    end,
    ["Force Reset"] = function()
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end,
}

for _, name in ipairs(SP_BTNS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, SP_BTN_H)
    btn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    btn.BackgroundTransparency = 0.2
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.TextColor3 = COL_WHITE
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.ZIndex = 12
    btn.Parent = spContent
    corner(btn, 6)
    addStrokeWithGradient(btn, 1)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        if spActions[name] then pcall(spActions[name]) end
    end)
end

local function openServerPanel()
    serverPanel.Visible = true
    serverPanel.Size = UDim2.new(0, SP_W, 0, 0)
    serverPanel.BackgroundTransparency = 1
    TweenService:Create(serverPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, SP_W, 0, SP_H),
        BackgroundTransparency = 0.6,
    }):Play()
end

local function closeServerPanel()
    local t = TweenService:Create(serverPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, SP_W, 0, 0),
        BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function() serverPanel.Visible = false end)
end

-- ============================================================
-- INSTANT STEAL PANEL
-- ============================================================
local IS_W = 200
local IS_BTN_H = 34
local IS_H = 44 + 30 + 6 + 6 + 2 * (IS_BTN_H + 6) + 6

local isPanel = Instance.new("Frame")
isPanel.Name = "InstantStealPanel"
isPanel.Size = UDim2.new(0, IS_W, 0, IS_H)
isPanel.Position = UDim2.new(1, -IS_W - 20, 0.5, -BP_H / 2 - IS_H - 10)
isPanel.BackgroundColor3 = COL_DARK
isPanel.BackgroundTransparency = 0.6
isPanel.BorderSizePixel = 0
isPanel.Visible = false
isPanel.ZIndex = 10
isPanel.Active = true
isPanel.Parent = screenGui
corner(isPanel, 14)
addStrokeWithGradient(isPanel, 2)

local isTitleRow = Instance.new("Frame")
isTitleRow.Size = UDim2.new(1, 0, 0, 34)
isTitleRow.Position = UDim2.new(0, 0, 0, 4)
isTitleRow.BackgroundTransparency = 1
isTitleRow.ZIndex = 11
isTitleRow.Parent = isPanel

local isTitle = Instance.new("TextLabel")
isTitle.Size = UDim2.new(1, -60, 1, 0)
isTitle.Position = UDim2.new(0, 10, 0, 0)
isTitle.BackgroundTransparency = 1
isTitle.Text = "⚡ Instant Steal V2"
isTitle.TextColor3 = COL_WHITE
isTitle.TextSize = 16
isTitle.Font = Enum.Font.GothamBold
isTitle.TextXAlignment = Enum.TextXAlignment.Left
isTitle.ZIndex = 11
isTitle.Parent = isTitleRow

local isTitleSideLabel_inst = Instance.new("TextLabel")
isTitleSideLabel_inst.Size = UDim2.new(0, 52, 1, 0)
isTitleSideLabel_inst.Position = UDim2.new(1, -58, 0, 0)
isTitleSideLabel_inst.BackgroundTransparency = 1
isTitleSideLabel_inst.Text = "?"
isTitleSideLabel_inst.TextColor3 = COL_DIM
isTitleSideLabel_inst.TextSize = 13
isTitleSideLabel_inst.Font = Enum.Font.GothamBold
isTitleSideLabel_inst.TextXAlignment = Enum.TextXAlignment.Right
isTitleSideLabel_inst.ZIndex = 11
isTitleSideLabel_inst.Parent = isTitleRow
isTitleSideLabel = isTitleSideLabel_inst

local isDivider = Instance.new("Frame")
isDivider.Size = UDim2.new(1, -20, 0, 1)
isDivider.Position = UDim2.new(0, 10, 0, 36)
isDivider.BackgroundColor3 = COL_WHITE
isDivider.BorderSizePixel = 0
isDivider.ZIndex = 11
isDivider.Parent = isPanel

local isContent = Instance.new("Frame")
isContent.Size = UDim2.new(1, 0, 1, -44)
isContent.Position = UDim2.new(0, 0, 0, 44)
isContent.BackgroundTransparency = 1
isContent.ZIndex = 11
isContent.Parent = isPanel

local isLayout = Instance.new("UIListLayout")
isLayout.SortOrder = Enum.SortOrder.LayoutOrder
isLayout.Padding = UDim.new(0, 6)
isLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
isLayout.Parent = isContent

local isPadding = Instance.new("UIPadding")
isPadding.PaddingTop = UDim.new(0, 6)
isPadding.Parent = isContent

makeDraggable(isPanel, isTitleRow)

local giantPotionEnabled = false
makePanelToggle(isContent, "Giant Potion", false, function(on)
    giantPotionEnabled = on
end)

local activateBtn = Instance.new("TextButton")
activateBtn.Size = UDim2.new(1, -20, 0, IS_BTN_H)
activateBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
activateBtn.BackgroundTransparency = 0.2
activateBtn.BorderSizePixel = 0
activateBtn.Text = "🌋 Activate (Reset)"
activateBtn.TextColor3 = COL_WHITE
activateBtn.TextSize = 12
activateBtn.Font = Enum.Font.GothamBold
activateBtn.AutoButtonColor = false
activateBtn.ZIndex = 12
activateBtn.Parent = isContent
corner(activateBtn, 6)
addStrokeWithGradient(activateBtn, 1)
local resetFlyingItems = { "Flying Carpet", "Cupid's Wings", "Broom" }
local isResetting = false

local function findAndEquipFlying(character)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local equipped = humanoid:FindFirstChildOfClass("Tool")
    for _, itemName in ipairs(resetFlyingItems) do
        local item = backpack:FindFirstChild(itemName)
        if item and (item:IsA("Tool") or item:IsA("HopperBin")) then
            if equipped then equipped.Parent = backpack end
            humanoid:EquipTool(item)
            return
        end
    end
end

local function tpAndDie()
    if isResetting then return end
    isResetting = true

    local char = player.Character
    if not char then isResetting = false return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root) then isResetting = false return end

    findAndEquipFlying(char)
    root.CFrame = CFrame.new(0, 5000, 0)

    _G.AntiDieDisabled = true
    humanoid.Health = 0

    pcall(function()
        player.CharacterAdded:Wait()
    end)

    _G.AntiDieDisabled = false
    task.wait()
    isResetting = false
end

activateBtn.MouseButton1Click:Connect(function()
    tpAndDie()
end)

-- Balloon auto-reset
local function hasBalloon(text)
    if typeof(text) ~= "string" then return false end
    return string.lower(text):find('ran "balloon" on you!') ~= nil
end

local function checkText(text)
    if hasBalloon(text) then tpAndDie() end
end

local function scanGuiObjects(parent)
    for _, obj in ipairs(parent:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            checkText(obj.Text)
            obj:GetPropertyChangedSignal("Text"):Connect(function()
                checkText(obj.Text)
            end)
        end
    end
end

local function setupGuiWatcher(gui)
    gui.DescendantAdded:Connect(function(desc)
        if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
            checkText(desc.Text)
            desc:GetPropertyChangedSignal("Text"):Connect(function()
                checkText(desc.Text)
            end)
        end
    end)
end

for _, gui in ipairs(playerGui:GetChildren()) do
    scanGuiObjects(gui)
    setupGuiWatcher(gui)
end
playerGui.ChildAdded:Connect(function(gui)
    setupGuiWatcher(gui)
    scanGuiObjects(gui)
end)

local executeBtn = Instance.new("TextButton")
executeBtn.Size = UDim2.new(1, -20, 0, IS_BTN_H)
executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
executeBtn.BackgroundTransparency = 0.2
executeBtn.BorderSizePixel = 0
executeBtn.Text = "🔥 Execute (F)"
executeBtn.TextColor3 = COL_WHITE
executeBtn.TextSize = 12
executeBtn.Font = Enum.Font.GothamBold
executeBtn.AutoButtonColor = false
executeBtn.ZIndex = 12
executeBtn.Parent = isContent
corner(executeBtn, 6)
addStrokeWithGradient(executeBtn, 1)

local semiInstantActive = false

local function executeSemiInstant()
    if semiInstantActive then return end
    if not isPanel.Visible then return end
    semiInstantActive = true

    executeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 0)
    executeBtn.Text = "🔥 EXECUTING..."

    local char = player.Character
    if not char then
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")

    if not hrp or not hum then
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    local FIRST_TP, SECOND_TP, THIRD_TP, LAST_TP
    if currentBaseSide == "Right" then
        FIRST_TP = RIGHT_FIRST_TP; SECOND_TP = RIGHT_SECOND_TP
        THIRD_TP = RIGHT_THIRD_TP; LAST_TP   = RIGHT_LAST_TP
    else
        FIRST_TP = LEFT_FIRST_TP; SECOND_TP = LEFT_SECOND_TP
        THIRD_TP = LEFT_THIRD_TP; LAST_TP   = LEFT_LAST_TP
    end

    local targetAnimal = getNearestAnimalFromPos(THIRD_TP)
    if not targetAnimal then
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    local prompt = PromptMemoryCache[targetAnimal.uid]
    if not prompt or not prompt.Parent then
        prompt = findProximityPromptForAnimal(targetAnimal)
    end
    if not prompt then
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    InternalStealCache[prompt] = nil
    buildStealCallbacks(prompt)
    local data = InternalStealCache[prompt]
    if not data or not data.ready then
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    data.ready = false

    local grabDuration = 1.3
    if prompt and prompt.HoldDuration then
        grabDuration = prompt.HoldDuration
    end

    if #data.holdCallbacks > 0 then
        for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
    end
    local holdStart = tick()

    task.wait(0.9)

    if not hrp or not hrp.Parent or not hum or not hum.Parent then
        data.ready = true
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    local carpet = player.Backpack:FindFirstChild("Flying Carpet") or char:FindFirstChild("Flying Carpet")
    if carpet then hum:EquipTool(carpet) end

    if giantPotionEnabled then
        local potion = player.Backpack:FindFirstChild("Giant Potion")
        if potion then potion.Parent = char end
    end

    hrp.CFrame = CFrame.new(FIRST_TP)
    task.wait(0.15)

    if not hrp or not hrp.Parent then
        data.ready = true
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    hrp.CFrame = CFrame.new(SECOND_TP)
    task.wait(0.15)

    if not hrp or not hrp.Parent then
        data.ready = true
        semiInstantActive = false
        executeBtn.Text = "Execute (F)"
        executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
        return
    end

    local lookDir
    if currentBaseSide == "Right" then
        lookDir = Vector3.new(0.00599244050681591, -0.3006192445755005, 0.9537254571914673)
        hrp.CFrame = CFrame.new(THIRD_TP) * CFrame.fromEulerAnglesYXZ(0, math.pi, 0)
    else
        lookDir = Vector3.new(-0.00599244050681591, -0.3006192445755005, -0.9537254571914673)
        hrp.CFrame = CFrame.new(THIRD_TP)
    end
    workspace.CurrentCamera.CFrame = CFrame.lookAt(
        workspace.CurrentCamera.CFrame.Position,
        workspace.CurrentCamera.CFrame.Position + lookDir
    )

    local remainingTime = grabDuration - (tick() - holdStart) - 0.03
    if remainingTime > 0 then task.wait(remainingTime) end

    if hrp and hrp.Parent then
        hrp.CFrame = CFrame.new(LAST_TP)
    end

    task.wait(0.03)

    if #data.triggerCallbacks > 0 then
        for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
    end

    task.wait(0.2)
    data.ready = true
    semiInstantActive = false
    executeBtn.Text = "🔥 Execute (F)"
    executeBtn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
end

executeBtn.MouseButton1Click:Connect(executeSemiInstant)

openIsPanel = function()
    isPanel.Visible = true
    isPanel.Size = UDim2.new(0, IS_W, 0, 0)
    isPanel.BackgroundTransparency = 1
    TweenService:Create(isPanel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, IS_W, 0, IS_H),
        BackgroundTransparency = 0.6,
    }):Play()
end

closeIsPanel = function()
    local t = TweenService:Create(isPanel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, IS_W, 0, 0),
        BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function() isPanel.Visible = false end)
end

openIsPanel()

-- ============================================================
-- MAIN PANEL TOGGLES
-- ============================================================
makeSection(mainContent, "📁 Panels")
makeToggle(mainContent, "Booster Panel", false, function(on)
    if on then openBoosterPanel() else closeBoosterPanel() end
end)
makeToggle(mainContent, "Server Panel", false, function(on)
    if on then openServerPanel() else closeServerPanel() end
end)

-- ============================================================
-- VISUAL TAB (ESP)
-- ============================================================
do
makeSection(visualContent, "👁️ Player ESP")

local espGui = Instance.new("ScreenGui")
espGui.Name = "LavaESPGui"
espGui.ResetOnSpawn = false
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 99
espGui.Parent = playerGui

local ESPConfig = {
    Box       = { Enabled = false, Color = Color3.fromRGB(255, 100, 0) },
    CornerBox = { Enabled = false, Color = Color3.fromRGB(255, 140, 40) },
    HealthBar = { Enabled = false },
    NameTag   = { Enabled = false },
    DistTag   = { Enabled = false },
    MaxDist   = 500,
}

local ESPstore = {}

local function mkFrame(props)
    local f = Instance.new("Frame", espGui)
    f.BorderSizePixel = 0
    for k, v in pairs(props or {}) do f[k] = v end
    return f
end

local function mkText(props)
    local t = Instance.new("TextLabel", espGui)
    t.BackgroundTransparency = 1
    t.AutoLocalize = false
    t.Font = Enum.Font.GothamBold
    t.TextSize = 11
    t.TextStrokeTransparency = 0
    t.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    for k, v in pairs(props or {}) do t[k] = v end
    return t
end

local function removeESP(plr)
    local e = ESPstore[plr]
    if not e then return end
    for _, obj in pairs(e) do
        if typeof(obj) == "Instance" then pcall(function() obj:Destroy() end) end
    end
    ESPstore[plr] = nil
end

local function createESP(plr)
    if plr == player then return end
    task.spawn(function()
        if ESPstore[plr] then removeESP(plr) end
        local char = plr.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not root then
            local t = 0
            repeat task.wait(0.1); t += 0.1
                root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            until root or t >= 5
        end
        if not root then return end
        local hum = char:FindFirstChildOfClass("Humanoid")

        local Box = mkFrame({ BackgroundColor3 = ESPConfig.Box.Color, BackgroundTransparency = 0.85, Visible = false, ZIndex = 3 })
        local BoxStroke = Instance.new("UIStroke", Box)
        BoxStroke.Thickness = 1.5; BoxStroke.Color = ESPConfig.Box.Color; BoxStroke.Transparency = 0

        local function mkCorner()
            return mkFrame({ BackgroundColor3 = ESPConfig.CornerBox.Color, Visible = false, ZIndex = 5 })
        end
        local LT1 = mkCorner(); local LT2 = mkCorner()
        local RT1 = mkCorner(); local RT2 = mkCorner()
        local LB1 = mkCorner(); local LB2 = mkCorner()
        local RB1 = mkCorner(); local RB2 = mkCorner()

        local HBBg = mkFrame({ BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.4, Visible = false, ZIndex = 4 })
        local HBFill = mkFrame({ BackgroundColor3 = Color3.fromRGB(255, 80, 0), BackgroundTransparency = 0, Visible = false, ZIndex = 5 })

        local NameLbl = mkText({ Size = UDim2.fromOffset(160, 16), AnchorPoint = Vector2.new(0.5, 1), TextColor3 = Color3.fromRGB(255, 120, 0), Visible = false, ZIndex = 6 })

        local DistLbl = mkText({ Size = UDim2.fromOffset(100, 14), AnchorPoint = Vector2.new(0.5, 0), TextColor3 = COL_DIM, TextSize = 10, Visible = false, ZIndex = 6 })

        ESPstore[plr] = {
            root = root, hum = hum,
            Box = Box, BoxStroke = BoxStroke,
            LT1=LT1, LT2=LT2, RT1=RT1, RT2=RT2,
            LB1=LB1, LB2=LB2, RB1=RB1, RB2=RB2,
            HBBg = HBBg, HBFill = HBFill,
            NameLbl = NameLbl, DistLbl = DistLbl,
        }

        plr.CharacterRemoving:Connect(function() removeESP(plr) end)
    end)
end

RunService.RenderStepped:Connect(function()
    for plr, e in pairs(ESPstore) do
        local char = plr.Character
        if not char or not e.root or not e.root.Parent or not plr.Parent then
            removeESP(plr); continue
        end

        local head = char:FindFirstChild("Head")
        local foot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("HumanoidRootPart")
        local headPos = head and (head.Position + Vector3.new(0, head.Size.Y / 2, 0)) or (e.root.Position + Vector3.new(0, 3, 0))
        local feetPos = foot and (foot.Position - Vector3.new(0, 0.1, 0)) or (e.root.Position - Vector3.new(0, 3, 0))

        local topSP  = workspace.CurrentCamera:WorldToViewportPoint(headPos)
        local botSP  = workspace.CurrentCamera:WorldToViewportPoint(feetPos)
        local rootSP, onScreen = workspace.CurrentCamera:WorldToViewportPoint(e.root.Position)

        local dist = (workspace.CurrentCamera.CFrame.Position - e.root.Position).Magnitude

        local function hideAll()
            e.Box.Visible=false; e.HBBg.Visible=false; e.HBFill.Visible=false
            e.NameLbl.Visible=false; e.DistLbl.Visible=false
            for _, k in ipairs({"LT1","LT2","RT1","RT2","LB1","LB2","RB1","RB2"}) do e[k].Visible=false end
        end

        if not onScreen or rootSP.Z <= 0 or dist > ESPConfig.MaxDist then
            hideAll(); continue
        end

        local bTop = topSP.Y
        local bBot = botSP.Y
        local bH   = bBot - bTop
        local bW   = bH * 0.55
        local bX   = rootSP.X
        local cw   = bW / 4
        local ch   = bH / 4

        e.Box.Visible = ESPConfig.Box.Enabled
        if ESPConfig.Box.Enabled then
            e.Box.Position = UDim2.fromOffset(bX - bW/2, bTop)
            e.Box.Size     = UDim2.fromOffset(bW, bH)
            e.BoxStroke.Color = ESPConfig.Box.Color
        end

        local cc = ESPConfig.CornerBox.Enabled
        for _, k in ipairs({"LT1","LT2","RT1","RT2","LB1","LB2","RB1","RB2"}) do
            e[k].Visible = cc
            e[k].BackgroundColor3 = ESPConfig.CornerBox.Color
        end
        if cc then
            e.LT1.Position=UDim2.fromOffset(bX-bW/2, bTop);       e.LT1.Size=UDim2.fromOffset(cw, 1)
            e.LT2.Position=UDim2.fromOffset(bX-bW/2, bTop);       e.LT2.Size=UDim2.fromOffset(1, ch)
            e.RT1.Position=UDim2.fromOffset(bX+bW/2-cw, bTop);    e.RT1.Size=UDim2.fromOffset(cw, 1)
            e.RT2.Position=UDim2.fromOffset(bX+bW/2-1, bTop);     e.RT2.Size=UDim2.fromOffset(1, ch)
            e.LB1.Position=UDim2.fromOffset(bX-bW/2, bBot);       e.LB1.Size=UDim2.fromOffset(cw, 1); e.LB1.AnchorPoint=Vector2.new(0,1)
            e.LB2.Position=UDim2.fromOffset(bX-bW/2, bBot-ch);    e.LB2.Size=UDim2.fromOffset(1, ch)
            e.RB1.Position=UDim2.fromOffset(bX+bW/2-cw, bBot);    e.RB1.Size=UDim2.fromOffset(cw, 1); e.RB1.AnchorPoint=Vector2.new(0,1)
            e.RB2.Position=UDim2.fromOffset(bX+bW/2-1, bBot-ch);  e.RB2.Size=UDim2.fromOffset(1, ch)
        end

        if ESPConfig.HealthBar.Enabled and e.hum then
            local hp = math.clamp(e.hum.Health / math.max(e.hum.MaxHealth, 1), 0, 1)
            local barX = bX - bW/2 - 5
            e.HBBg.Visible   = true
            e.HBFill.Visible = true
            e.HBBg.Position  = UDim2.fromOffset(barX - 2, bTop)
            e.HBBg.Size      = UDim2.fromOffset(3, bH)
            e.HBFill.Position = UDim2.fromOffset(barX - 2, bTop + bH * (1 - hp))
            e.HBFill.Size     = UDim2.fromOffset(3, bH * hp)
            e.HBFill.BackgroundColor3 = Color3.fromRGB(
                math.floor(255 * (1 - hp)),
                math.floor(255 * hp),
                0
            )
        else
            e.HBBg.Visible = false; e.HBFill.Visible = false
        end

        if ESPConfig.NameTag.Enabled then
            local tag = plr.DisplayName
            if ESPConfig.DistTag.Enabled then
                tag = tag .. string.format("  [%dm]", math.floor(dist))
            end
            e.NameLbl.Text     = tag
            e.NameLbl.Position = UDim2.fromOffset(bX, bTop - 2)
            e.NameLbl.Visible  = true
        else
            e.NameLbl.Visible = false
        end

        if ESPConfig.DistTag.Enabled and not ESPConfig.NameTag.Enabled then
            e.DistLbl.Text     = string.format("%dm", math.floor(dist))
            e.DistLbl.Position = UDim2.fromOffset(bX, bBot + 2)
            e.DistLbl.Visible  = true
        else
            e.DistLbl.Visible = false
        end
    end
end)

makeToggle(visualContent, "Box ESP", false, function(on)
    ESPConfig.Box.Enabled = on
end)

makeToggle(visualContent, "Corner Box", false, function(on)
    ESPConfig.CornerBox.Enabled = on
end)

makeToggle(visualContent, "Health Bar", false, function(on)
    ESPConfig.HealthBar.Enabled = on
end)

makeToggle(visualContent, "Name Tag", false, function(on)
    ESPConfig.NameTag.Enabled = on
end)

makeToggle(visualContent, "Distance", false, function(on)
    ESPConfig.DistTag.Enabled = on
end)

local function setupESPPlayer(plr)
    if plr == player then return end
    plr.CharacterAdded:Connect(function()
        task.wait(0.5); createESP(plr)
    end)
    if plr.Character then createESP(plr) end
end

Players.PlayerAdded:Connect(setupESPPlayer)
Players.PlayerRemoving:Connect(removeESP)
for _, plr in ipairs(Players:GetPlayers()) do setupESPPlayer(plr) end
end

-- ============================================================
-- SKYBOX
-- ============================================================
do
makeSection(visualContent, "🌌 Skybox")

local _lighting = game:GetService("Lighting")
local _currentSky = nil
local _originalSky = nil
for _, v in ipairs(_lighting:GetChildren()) do
    if v:IsA("Sky") then _originalSky = v; break end
end

local _SKIES = {
    { name = "Original", ft = nil },
    { name = "Lava Galaxy",
      ft="rbxassetid://151165228", bk="rbxassetid://151165228",
      lf="rbxassetid://151165228", rt="rbxassetid://151165228",
      tp="rbxassetid://151165228", dn="rbxassetid://151165228" },
}

local _skyBtns = {}

local function _applySky(data)
    for _, v in ipairs(_lighting:GetChildren()) do if v:IsA("Sky") then v:Destroy() end end
    if data.ft == nil then
        if _originalSky then _originalSky:Clone().Parent = _lighting end
        _currentSky = "Original"
    else
        local sky = Instance.new("Sky")
        sky.SkyboxFt=data.ft; sky.SkyboxBk=data.bk
        sky.SkyboxLf=data.lf; sky.SkyboxRt=data.rt
        sky.SkyboxUp=data.tp; sky.SkyboxDn=data.dn
        sky.Parent = _lighting; _currentSky = data.name
    end
    for _, info in ipairs(_skyBtns) do
        local on = (info.name == _currentSky)
        TweenService:Create(info.btn, TweenInfo.new(0.18), {
            BackgroundColor3 = on and Color3.fromRGB(255, 100, 0) or Color3.fromRGB(80, 35, 20),
            BackgroundTransparency = on and 0 or 0.3,
        }):Play()
        info.lbl.TextColor3 = on and COL_WHITE or COL_DIM
        info.lbl.Font = on and Enum.Font.GothamBold or Enum.Font.Gotham
    end
end

local _skyRow = Instance.new("Frame")
_skyRow.Size = UDim2.new(1,0,0,36); _skyRow.BackgroundTransparency=1
_skyRow.BorderSizePixel=0; _skyRow.ZIndex=12
_skyRow.LayoutOrder=#visualContent:GetChildren(); _skyRow.Parent=visualContent

for i, skyData in ipairs(_SKIES) do
    local btn = Instance.new("TextButton", _skyRow)
    btn.Size = UDim2.new(0.5,-3,1,0)
    btn.Position = UDim2.new((i-1)*0.5, i==1 and 0 or 3, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(80, 35, 20)
    btn.BackgroundTransparency = 0.3; btn.BorderSizePixel=0
    btn.Text=""; btn.ZIndex=13
    corner(btn,8); addStrokeWithGradient(btn,1)
    local lbl = Instance.new("TextLabel",btn)
    lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=skyData.name; lbl.TextColor3=COL_DIM
    lbl.TextSize=12; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.ZIndex=14
    table.insert(_skyBtns,{name=skyData.name,btn=btn,lbl=lbl})
    btn.MouseButton1Click:Connect(function() _applySky(skyData) end)
end
_applySky(_SKIES[1])
end

-- ============================================================
-- COLOR DE PAREDES (LAVA THEME)
-- ============================================================
do
makeSection(visualContent, "🎨 Color de Paredes")

local _wallOriginals={}; local _wallConn=nil
local _wallEnabled=false
local _wH,_wS,_wV = 0.08, 0.9, 0.85 -- Más rojo/ naranja

local function _getWallColor() return Color3.fromHSV(_wH,_wS,_wV) end

local function _getMapParts()
    local cs={}
    for _,p in ipairs(Players:GetPlayers()) do if p.Character then cs[p.Character]=true end end
    local parts={}
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local a,ic=v.Parent,false
            while a do if cs[a] then ic=true;break end; a=a.Parent end
            if not ic then parts[#parts+1]=v end
        end
    end
    return parts
end

local function _stopWall()
    _wallEnabled=false
    if _wallConn then _wallConn:Disconnect(); _wallConn=nil end
end

local function _restoreWalls()
    _stopWall()
    for part,orig in pairs(_wallOriginals) do pcall(function() part.Color=orig end) end
    _wallOriginals={}
end

local function _applyWallColor(color)
    _stopWall(); _wallEnabled=true
    local parts=_getMapParts()
    for _,part in ipairs(parts) do
        if not _wallOriginals[part] then _wallOriginals[part]=part.Color end
        pcall(function() part.Color=color end)
    end
end

local _topRow=Instance.new("Frame")
_topRow.Size=UDim2.new(1,0,0,40); _topRow.BackgroundColor3=Color3.fromRGB(80, 35, 20)
_topRow.BackgroundTransparency=0.2; _topRow.BorderSizePixel=0
_topRow.ZIndex=12; _topRow.LayoutOrder=#visualContent:GetChildren()
_topRow.Parent=visualContent; corner(_topRow,8)

local _preview=Instance.new("Frame",_topRow)
_preview.Size=UDim2.fromOffset(28,28); _preview.Position=UDim2.fromOffset(8,6)
_preview.BackgroundColor3=_getWallColor(); _preview.BorderSizePixel=0; _preview.ZIndex=13
corner(_preview,6); addStrokeWithGradient(_preview,1)

local _hexLbl=Instance.new("TextLabel",_topRow)
_hexLbl.Size=UDim2.fromOffset(72,28); _hexLbl.Position=UDim2.fromOffset(42,6)
_hexLbl.BackgroundTransparency=1; _hexLbl.Font=Enum.Font.Code; _hexLbl.TextSize=11
_hexLbl.TextColor3=Color3.fromRGB(255, 120, 0); _hexLbl.TextXAlignment=Enum.TextXAlignment.Left
_hexLbl.ZIndex=13

local function _refreshUI()
    local c=_getWallColor()
    _preview.BackgroundColor3=c
    _hexLbl.Text=string.format("#%02X%02X%02X",math.floor(c.R*255),math.floor(c.G*255),math.floor(c.B*255))
end
_refreshUI()

local function _mkBtn(text,xOff,w,col,fn)
    local b=Instance.new("TextButton",_topRow)
    b.Size=UDim2.fromOffset(w,26); b.Position=UDim2.new(1,xOff,0.5,-13)
    b.BackgroundColor3=col; b.BackgroundTransparency=0.1; b.BorderSizePixel=0
    b.Text=text; b.TextColor3=COL_WHITE; b.TextSize=10; b.Font=Enum.Font.GothamBold; b.ZIndex=14
    corner(b,6)
    b.MouseButton1Click:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0.5}):Play()
        task.delay(0.2,function() TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0.1}):Play() end)
        fn()
    end)
end
_mkBtn("Aplicar",  -130,60,Color3.fromRGB(200, 60, 0), function() _applyWallColor(_getWallColor()) end)
_mkBtn("Restaurar", -64,60,Color3.fromRGB(80, 35, 20),   function() _restoreWalls() end)

local _picker=Instance.new("Frame")
_picker.Size=UDim2.new(1,0,0,118); _picker.BackgroundColor3=Color3.fromRGB(80, 35, 20)
_picker.BackgroundTransparency=0.1; _picker.BorderSizePixel=0; _picker.ClipsDescendants=false
_picker.ZIndex=12; _picker.LayoutOrder=#visualContent:GetChildren()
_picker.Visible=true; _picker.Parent=visualContent; corner(_picker,8)

local _expandBtn=Instance.new("TextButton",_topRow)
_expandBtn.Size=UDim2.fromOffset(28,28); _expandBtn.Position=UDim2.fromOffset(8,6)
_expandBtn.BackgroundTransparency=1; _expandBtn.Text=""; _expandBtn.ZIndex=15
local _pickerOpen=true
_expandBtn.MouseButton1Click:Connect(function()
    _pickerOpen=not _pickerOpen
    _picker.Visible=_pickerOpen
end)

local function _makeHSVBar(yPos, gradKeys, onDrag)
    local bar=Instance.new("Frame",_picker)
    bar.Size=UDim2.new(1,-24,0,12); bar.Position=UDim2.fromOffset(16,yPos)
    bar.BackgroundColor3=COL_WHITE; bar.BorderSizePixel=0; bar.ZIndex=13
    corner(bar,6)
    local grad=Instance.new("UIGradient",bar)
    grad.Color=ColorSequence.new(gradKeys)
    local cur=Instance.new("Frame",bar)
    cur.Size=UDim2.fromOffset(10,18); cur.AnchorPoint=Vector2.new(0.5,0.5)
    cur.BackgroundColor3=COL_WHITE; cur.BorderSizePixel=0; cur.ZIndex=14
    corner(cur,3)
    local cs=Instance.new("UIStroke",cur); cs.Color=Color3.fromRGB(0,0,0); cs.Thickness=1.5
    local dragging=false
    local hit=Instance.new("TextButton",bar)
    hit.Size=UDim2.new(1,0,0,22); hit.Position=UDim2.new(0,0,0.5,-11)
    hit.BackgroundTransparency=1; hit.Text=""; hit.ZIndex=15
    hit.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true
            local pct=math.clamp((inp.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
            onDrag(pct,grad,cur); _refreshUI()
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
            local pct=math.clamp((inp.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
            onDrag(pct,grad,cur); _refreshUI()
        end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    return bar, grad, cur
end

local _hBar,_hGrad,_hCur = _makeHSVBar(10,
    {ColorSequenceKeypoint.new(0,Color3.fromRGB(255,0,0)),
     ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,255,0)),
     ColorSequenceKeypoint.new(0.33,Color3.fromRGB(0,255,0)),
     ColorSequenceKeypoint.new(0.5,Color3.fromRGB(0,255,255)),
     ColorSequenceKeypoint.new(0.67,Color3.fromRGB(0,0,255)),
     ColorSequenceKeypoint.new(0.83,Color3.fromRGB(255,0,255)),
     ColorSequenceKeypoint.new(1,Color3.fromRGB(255,0,0))},
    function(p,g,c) _wH=p; c.Position=UDim2.new(p,0,0.5,0) end)

local _sBar,_sGrad,_sCur = _makeHSVBar(34,
    {ColorSequenceKeypoint.new(0,Color3.fromRGB(200,200,200)),
     ColorSequenceKeypoint.new(1,Color3.fromHSV(_wH,1,1))},
    function(p,g,c)
        _wS=p; c.Position=UDim2.new(p,0,0.5,0)
        g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(200,200,200)),ColorSequenceKeypoint.new(1,Color3.fromHSV(_wH,1,1))}
    end)

local _vBar,_vGrad,_vCur = _makeHSVBar(58,
    {ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),
     ColorSequenceKeypoint.new(1,Color3.fromHSV(_wH,_wS,1))},
    function(p,g,c)
        _wV=p; c.Position=UDim2.new(p,0,0.5,0)
        g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(1,Color3.fromHSV(_wH,_wS,1))}
    end)

_hCur.Position=UDim2.new(_wH,0,0.5,0)
_sCur.Position=UDim2.new(_wS,0,0.5,0)
_vCur.Position=UDim2.new(_wV,0,0.5,0)

local _swRow=Instance.new("Frame",_picker)
_swRow.Size=UDim2.new(1,-24,0,20); _swRow.Position=UDim2.fromOffset(16,82)
_swRow.BackgroundTransparency=1; _swRow.BorderSizePixel=0; _swRow.ZIndex=13
local _swLL=Instance.new("UIListLayout",_swRow)
_swLL.FillDirection=Enum.FillDirection.Horizontal; _swLL.Padding=UDim.new(0,3)

for _,sc in ipairs({
    Color3.fromRGB(255,80,80),  Color3.fromRGB(255,160,0),
    Color3.fromRGB(80,220,80),  Color3.fromRGB(0,200,255),
    Color3.fromRGB(0,120,180),  Color3.fromRGB(119,120,255),
    Color3.fromRGB(200,80,255), Color3.fromRGB(255,255,255),
    Color3.fromRGB(20,20,20),   Color3.fromRGB(255,100,180),
}) do
    local sw=Instance.new("TextButton",_swRow)
    sw.Size=UDim2.fromOffset(20,20); sw.BackgroundColor3=sc
    sw.BorderSizePixel=0; sw.Text=""; sw.ZIndex=14; corner(sw,4)
    sw.MouseButton1Click:Connect(function()
        _wH,_wS,_wV=Color3.toHSV(sc)
        _hCur.Position=UDim2.new(_wH,0,0.5,0)
        _sCur.Position=UDim2.new(_wS,0,0.5,0)
        _vCur.Position=UDim2.new(_wV,0,0.5,0)
        _sGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(200,200,200)),ColorSequenceKeypoint.new(1,Color3.fromHSV(_wH,1,1))}
        _vGrad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(1,Color3.fromHSV(_wH,_wS,1))}
        _refreshUI()
    end)
end

RunService.Heartbeat:Connect(function()
    if _wallEnabled then
        _preview.BackgroundColor3 = _getWallColor()
    end
end)

end

-- ============================================================
-- MENU TOGGLE BUTTON
-- ============================================================
local panelOpen = false

local function openPanel()
    panelOpen = true
    panel.Visible = true
    panel.Size = UDim2.new(0, PANEL_W, 0, 0)
    panel.BackgroundTransparency = 1
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, PANEL_W, 0, PANEL_H),
        BackgroundTransparency = 0.6,
    }):Play()
end

local function closePanel()
    panelOpen = false
    local t = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, PANEL_W, 0, 0),
        BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function() panel.Visible = false end)
end

menuToggleBtn.MouseButton1Click:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)

-- ============================================================
-- KEYBIND F -> Execute Instant Steal
-- ============================================================
UserInputService.InputBegan:Connect(function(inp, gameProcessed)
    if gameProcessed then return end
    if inp.KeyCode == Enum.KeyCode.F then
        executeSemiInstant()
    end
end)

-- ============================================================
-- FPS / PING HUD UPDATE
-- ============================================================
task.spawn(function()
    while true do
        task.wait(1)
        local fps = math.floor(1 / RunService.Heartbeat:Wait())
        local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        statsLabel.Text = string.format("FPS: %d  PING: %dms", fps, math.floor(ping))
    end
end)

-- ============================================================
-- GRADIENT ANIMATION LOOP
-- ============================================================
task.spawn(function()
    local t = 0
    while true do
        task.wait(0.05)
        t = t + 0.02
        local offset = t % 1
        for _, g in ipairs(allGradients) do
            if g and g.Parent then
                g.Rotation = (g.Rotation + 1) % 360
            end
        end
    end
end)

refreshBooster()
