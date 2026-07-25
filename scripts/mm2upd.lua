-- ////////////////////////////////////////////////////////////
--  VYNIXU MM2 SCRIPT - OBSIDIAN EDITION v3.0
-- ////////////////////////////////////////////////////////////

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

-- ////////////////////////////////////////////////////////////
--  LOADING
-- ////////////////////////////////////////////////////////////

local Loading = Library:CreateLoading({
    Title = "Vynixu MM2 Script",
    Icon = 95816097006870,
    TotalSteps = 4,
    ShowSidebar = true,
})

Loading:SetMessage("Inicializando...")
Loading:SetDescription("Carregando script...")
task.wait(0.5)

Loading:SetCurrentStep(1)
Loading:SetDescription("Carregando ESPs...")
task.wait(0.3)

Loading:SetCurrentStep(2)
Loading:SetDescription("Carregando configurações...")
Loading.Sidebar:AddLabel("Usuário: " .. game.Players.LocalPlayer.Name)
Loading.Sidebar:AddLabel("Versão: 3.0")
task.wait(0.3)

Loading:SetCurrentStep(3)
Loading:SetDescription("Pronto!")
task.wait(0.3)

Loading:SetCurrentStep(4)
Loading:Continue()

-- ////////////////////////////////////////////////////////////
--  WINDOW
-- ////////////////////////////////////////////////////////////

local Window = Library:CreateWindow({
    Title = "Vynixu MM2 Script",
    SubTitle = "Obsidian Edition",
    Theme = "Dark",
    Size = UDim2.new(0, 580, 0, 500),
    Animations = {
        ToggleWindow = true,
        TabSwitch = true,
        Groupbox = true,
        Dropdown = true,
        KeyPicker = true
    },
})

Window:SetFooter("Obsidian Edition v3.0")

local EspTab      = Window:AddTab("ESP", "eye")
local MovementTab = Window:AddTab("Movimento", "zap")
local TeleportTab = Window:AddTab("Teleporte", "map-pin")
local MiscTab     = Window:AddTab("Misc", "cog")
local ConfigTab   = Window:AddTab("Config", "settings")

-- ////////////////////////////////////////////////////////////
--  SAVEMANAGER
-- ////////////////////////////////////////////////////////////

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("VynixuMM2Script/Configs")
SaveManager:BuildConfigSection(ConfigTab)
SaveManager:LoadAutoloadConfig()

-- ////////////////////////////////////////////////////////////
--  VARIÁVEIS
-- ////////////////////////////////////////////////////////////

local Player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")

local flying = false
local flySpeed = 50
local flyKeyDown, flyKeyUp, flyBG, flyBV = nil, nil, nil, nil
local noclip = false
local autoGun = false

local Settings = {
    MurdererColor    = Color3.fromRGB(255, 0, 25),
    SherrifColor     = Color3.fromRGB(0, 50, 255),
    InnocentColor    = Color3.fromRGB(0, 255, 50),
    GunColor         = Color3.fromRGB(0, 255, 50),
    EspTransparency  = 0.4,
    OutlineEnabled   = true,
    OutlineColor     = Color3.fromRGB(0, 0, 0),
    OutlineRainbow   = false,
    OutlineTransp    = 0,
}

local espStates = {
    Murderer = false,
    Sherrif  = false,
    Innocent = false,
    Gun      = false,
    Names    = false,
}

-- ////////////////////////////////////////////////////////////
--  DETECÇÃO DE ROLE (MÉTODO DO YARHM - USA GetPlayerData)
--  InvokeServer retorna a role real do servidor, não dá pra falsificar
-- ////////////////////////////////////////////////////////////

local playerRoles = {}
local rolesLoaded = false

local function carregarRoles()
    local ok, result = pcall(function()
        local Remote = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
        if Remote then
            return Remote:InvokeServer()
        end
        return nil
    end)
    if ok and result then
        playerRoles = result
        rolesLoaded = true
    end
end

-- tenta carregar roles, e recarrega quando o round muda
task.spawn(carregarRoles)

-- ouve mudança de round para recarregar
game:GetService("ReplicatedStorage").DescendantAdded:Connect(function(obj)
    if obj.Name == "GetPlayerData" then
        task.wait(1)
        carregarRoles()
    end
end)

local function getRole(plr)
    if not plr then return nil end
    if not rolesLoaded then return nil end
    local data = playerRoles[plr.Name]
    if data then return data.Role end
    return nil
end

local function isMurderer(plr)
    local role = getRole(plr)
    if role then return role == "Murderer" end
    -- fallback: checar backpack se GetPlayerData falhar
    local bp = plr:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Knife") then return true end
    if plr.Character then
        for _, v in pairs(plr.Character:GetChildren()) do
            if v:IsA("Tool") and v.Name == "Knife" then return true end
        end
    end
    return false
end

local function isSherrif(plr)
    local role = getRole(plr)
    if role then return role == "Sheriff" end
    -- fallback
    local bp = plr:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Gun") then return true end
    if plr.Character then
        for _, v in pairs(plr.Character:GetChildren()) do
            if v:IsA("Tool") and v.Name == "Gun" then return true end
        end
    end
    return false
end

local function isInnocent(plr)
    if not plr or plr == Player then return false end
    local role = getRole(plr)
    if role then return role == "Innocent" end
    return not isMurderer(plr) and not isSherrif(plr)
end

-- recarrega roles a cada round (quando alguém morre/muda)
task.spawn(function()
    while true do
        task.wait(5)
        carregarRoles()
    end
end)

-- ////////////////////////////////////////////////////////////
--  ESP (sem piscar - destrói só quando necessário)
-- ////////////////////////////////////////////////////////////

local ESP = { Highlights = {} }

function ESP:getExisting(tipo, char)
    if self.Highlights[tipo] and self.Highlights[tipo][char] then
        local h = self.Highlights[tipo][char]
        -- verifica se ainda existe no workspace
        if h.fill and h.fill.Parent then
            return h
        end
    end
    return nil
end

function ESP:remove(tipo, char)
    if not char then return end
    if self.Highlights[tipo] and self.Highlights[tipo][char] then
        local h = self.Highlights[tipo][char]
        if h.fill and h.fill.Parent then h.fill:Destroy() end
        if h.outline and h.outline.Parent then h.outline:Destroy() end
        self.Highlights[tipo][char] = nil
    end
end

function ESP:create(tipo, char, cor)
    if not char or not char.Parent then return end

    -- se já existe e a cor é a mesma, não recria (evita piscar)
    local existing = self:getExisting(tipo, char)
    if existing then
        if existing.fill.FillColor ~= cor then
            existing.fill.FillColor = cor
        end
        -- atualiza transparência se mudou
        if existing.fill.FillTransparency ~= Settings.EspTransparency then
            existing.fill.FillTransparency = Settings.EspTransparency
        end
        return
    end

    -- remove qualquer versão antiga morta
    self:remove(tipo, char)

    local fill = Instance.new("Highlight")
    fill.Name = tipo .. "_Fill"
    fill.Parent = char
    fill.FillColor = cor
    fill.FillTransparency = Settings.EspTransparency
    fill.OutlineTransparency = 1
    fill.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

    local outline = nil
    if Settings.OutlineEnabled then
        outline = Instance.new("Highlight")
        outline.Name = tipo .. "_Outline"
        outline.Parent = char
        outline.FillTransparency = 1
        outline.OutlineColor = Settings.OutlineColor
        outline.OutlineTransparency = Settings.OutlineTransp
        outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    end

    if not self.Highlights[tipo] then self.Highlights[tipo] = {} end
    self.Highlights[tipo][char] = { fill = fill, outline = outline }
end

-- rainbow no renderstep sem piscar
RS.RenderStepped:Connect(function()
    if not Settings.OutlineRainbow then return end
    local color = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)
    for _, charMap in pairs(ESP.Highlights) do
        for _, h in pairs(charMap) do
            if h.outline and h.outline.Parent then
                h.outline.OutlineColor = color
            end
        end
    end
end)

-- ////////////////////////////////////////////////////////////
--  LOOPS ESP
-- ////////////////////////////////////////////////////////////

local function espLoop(tipo, checkFn, colorFn)
    task.spawn(function()
        while espStates[tipo] do
            task.wait(0.2)
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player or not plr.Character then continue end
                if checkFn(plr) then
                    ESP:create(tipo, plr.Character, colorFn())
                else
                    ESP:remove(tipo, plr.Character)
                end
            end
        end
        -- limpa ao desativar
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr.Character then ESP:remove(tipo, plr.Character) end
        end
    end)
end

local function ativarMurdererESP()
    espStates.Murderer = true
    espLoop("Murderer", isMurderer, function() return Settings.MurdererColor end)
end
local function desativarMurdererESP()
    espStates.Murderer = false
end

local function ativarSherrifESP()
    espStates.Sherrif = true
    espLoop("Sherrif", isSherrif, function() return Settings.SherrifColor end)
end
local function desativarSherrifESP()
    espStates.Sherrif = false
end

local function ativarInnocentESP()
    espStates.Innocent = true
    espLoop("Innocent", function(plr)
        if not isInnocent(plr) then return false end
        -- não sobrepõe murderer/sherrif
        local c = plr.Character
        if ESP.Highlights["Murderer"] and ESP.Highlights["Murderer"][c] then return false end
        if ESP.Highlights["Sherrif"]  and ESP.Highlights["Sherrif"][c]  then return false end
        return true
    end, function() return Settings.InnocentColor end)
end
local function desativarInnocentESP()
    espStates.Innocent = false
end

local function ativarGunESP()
    espStates.Gun = true
    local gunHighlights = {}
    task.spawn(function()
        while espStates.Gun do
            task.wait(0.5)
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name == "GunDrop" and not gunHighlights[obj] then
                    local h = Instance.new("Highlight")
                    h.Name = "GunHighlight"
                    h.Parent = obj
                    h.FillColor = Settings.GunColor
                    h.FillTransparency = 0.4
                    h.OutlineColor = Color3.fromRGB(0, 0, 0)
                    h.OutlineTransparency = 0
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    gunHighlights[obj] = h
                end
            end
        end
        for _, h in pairs(gunHighlights) do pcall(function() h:Destroy() end) end
    end)
end
local function desativarGunESP() espStates.Gun = false end

-- ////////////////////////////////////////////////////////////
--  NAMES ESP
-- ////////////////////////////////////////////////////////////

local namesBillboards = {}

local function removerNome(plr)
    if namesBillboards[plr] then
        namesBillboards[plr]:Destroy()
        namesBillboards[plr] = nil
    end
end

local function criarNome(plr)
    if not plr or not plr.Character then return end
    local head = plr.Character:FindFirstChild("Head")
    if not head then return end
    removerNome(plr)

    local bb = Instance.new("BillboardGui")
    bb.Name = "NameESP"
    bb.Parent = head
    bb.Adornee = head
    bb.Size = UDim2.new(0, 150, 0, 40)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 5000

    local nomeLabel = Instance.new("TextLabel")
    nomeLabel.Name = "Nome"
    nomeLabel.Parent = bb
    nomeLabel.BackgroundTransparency = 1
    nomeLabel.Size = UDim2.new(1, 0, 0.6, 0)
    nomeLabel.Font = Enum.Font.GothamBold
    nomeLabel.Text = plr.Name
    nomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nomeLabel.TextSize = 14
    nomeLabel.TextStrokeTransparency = 0
    nomeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "Dist"
    distLabel.Parent = bb
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position = UDim2.new(0, 0, 0.6, 0)
    distLabel.Font = Enum.Font.Gotham
    distLabel.Text = "0m"
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextSize = 12
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

    namesBillboards[plr] = bb

    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if espStates.Names then criarNome(plr) end
    end)
end

local function ativarNamesESP()
    espStates.Names = true
    task.spawn(function()
        while espStates.Names do
            task.wait(0.5)
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player then removerNome(plr); continue end
                if plr.Character and plr.Character:FindFirstChild("Head") then
                    if not namesBillboards[plr] then criarNome(plr) end
                    local bb = namesBillboards[plr]
                    if bb then
                        local nl = bb:FindFirstChild("Nome")
                        if nl then
                            nl.TextColor3 = isMurderer(plr) and Color3.fromRGB(255, 0, 25)
                                or isSherrif(plr) and Color3.fromRGB(0, 50, 255)
                                or Color3.fromRGB(0, 255, 50)
                        end
                        local dl = bb:FindFirstChild("Dist")
                        local lc = Player.Character
                        if dl and lc and lc:FindFirstChild("HumanoidRootPart")
                            and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                            local d = (lc.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                            dl.Text = math.floor(d) .. "m"
                        end
                    end
                else
                    removerNome(plr)
                end
            end
        end
        for _, plr in pairs(game.Players:GetPlayers()) do removerNome(plr) end
    end)
end

local function desativarNamesESP()
    espStates.Names = false
    for _, plr in pairs(game.Players:GetPlayers()) do removerNome(plr) end
end

game.Players.PlayerRemoving:Connect(function(plr)
    removerNome(plr)
    if plr.Character then
        for tipo, _ in pairs(ESP.Highlights) do
            ESP:remove(tipo, plr.Character)
        end
    end
end)

-- ////////////////////////////////////////////////////////////
--  FLY (W = frente, S = trás, A = esquerda, D = direita)
-- ////////////////////////////////////////////////////////////

local function startFly()
    if flying then return end
    local char = Player.Character or Player.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildWhichIsA("Humanoid")
    if not root or not hum then return end

    if flyKeyDown then flyKeyDown:Disconnect() end
    if flyKeyUp   then flyKeyUp:Disconnect()   end

    flying = true
    -- W=frente S=trás A=esquerda D=direita Q=desce E=sobe
    local CTRL = {F=0, B=0, L=0, R=0, Up=0, Down=0}

    flyBG = Instance.new("BodyGyro", root)
    flyBG.P = 9e4
    flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.CFrame = root.CFrame

    flyBV = Instance.new("BodyVelocity", root)
    flyBV.Velocity = Vector3.new(0, 0, 0)
    flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    task.spawn(function()
        while flying do
            task.wait()
            hum.PlatformStand = true
            local cam = workspace.CurrentCamera
            -- look = frente/trás, right = esquerda/direita, up = cima/baixo
            local look  = cam.CFrame.LookVector
            local right = cam.CFrame.RightVector
            local up    = Vector3.new(0, 1, 0)

            local vel = Vector3.zero
            vel = vel + look  * (CTRL.F - CTRL.B)
            vel = vel + right * (CTRL.R - CTRL.L)
            vel = vel + up    * (CTRL.Up - CTRL.Down)

            if vel.Magnitude > 0 then
                flyBV.Velocity = vel.Unit * flySpeed
            else
                flyBV.Velocity = Vector3.zero
            end

            flyBG.CFrame = cam.CFrame
        end
    end)

    flyKeyDown = UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        local k = input.KeyCode
        if     k == Enum.KeyCode.W then CTRL.F    = 1
        elseif k == Enum.KeyCode.S then CTRL.B    = 1
        elseif k == Enum.KeyCode.A then CTRL.L    = 1
        elseif k == Enum.KeyCode.D then CTRL.R    = 1
        elseif k == Enum.KeyCode.E then CTRL.Up   = 1
        elseif k == Enum.KeyCode.Q then CTRL.Down = 1
        end
    end)

    flyKeyUp = UIS.InputEnded:Connect(function(input, gp)
        if gp then return end
        local k = input.KeyCode
        if     k == Enum.KeyCode.W then CTRL.F    = 0
        elseif k == Enum.KeyCode.S then CTRL.B    = 0
        elseif k == Enum.KeyCode.A then CTRL.L    = 0
        elseif k == Enum.KeyCode.D then CTRL.R    = 0
        elseif k == Enum.KeyCode.E then CTRL.Up   = 0
        elseif k == Enum.KeyCode.Q then CTRL.Down = 0
        end
    end)

    Library:Notify({ Title = "Voo", Description = "Ativado! WASD + Q/E", Time = 2 })
end

local function stopFly()
    if not flying then return end
    flying = false
    if flyKeyDown then flyKeyDown:Disconnect(); flyKeyDown = nil end
    if flyKeyUp   then flyKeyUp:Disconnect();   flyKeyUp   = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    local char = Player.Character
    if char then
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then hum.PlatformStand = false end
        pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
    end
    Library:Notify({ Title = "Voo", Description = "Desativado!", Time = 1 })
end

local function toggleFly() if flying then stopFly() else startFly() end end

-- ////////////////////////////////////////////////////////////
--  NOCLIP
-- ////////////////////////////////////////////////////////////

RS.Stepped:Connect(function()
    if noclip and Player.Character then
        for _, p in pairs(Player.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

-- ////////////////////////////////////////////////////////////
--  MOVIMENTO
-- ////////////////////////////////////////////////////////////

local function setWalkSpeed(v)
    local c = Player.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = tonumber(v) or 16 end
end
local function setJumpPower(v)
    local c = Player.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower = tonumber(v) or 50 end
end
local function resetWalkSpeed() setWalkSpeed(16) end
local function resetJumpPower() setJumpPower(50) end

-- ////////////////////////////////////////////////////////////
--  TELEPORTES
-- ////////////////////////////////////////////////////////////

local function tpToLobby()
    local c = Player.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = CFrame.new(-108.5, 145, 0.6)
    end
end

local function tpToMap()
    local c = Player.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    for _, thing in pairs(workspace:GetChildren()) do
        for _, child in pairs(thing:GetChildren()) do
            if child.Name == "Spawns" and child:FindFirstChild("Spawn") then
                c.HumanoidRootPart.CFrame = child.Spawn.CFrame
                return
            end
        end
    end
end

local function tpTo(plr)
    local c = Player.Character
    if c and c:FindFirstChild("HumanoidRootPart")
        and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
    end
end

local function tpToMurderer()
    for _, plr in pairs(game.Players:GetPlayers()) do
        if isMurderer(plr) then tpTo(plr); return end
    end
    Library:Notify({ Title = "TP", Description = "Nenhum assassino encontrado!", Time = 2 })
end

local function tpToSherrif()
    for _, plr in pairs(game.Players:GetPlayers()) do
        if isSherrif(plr) then tpTo(plr); return end
    end
    Library:Notify({ Title = "TP", Description = "Nenhum xerife encontrado!", Time = 2 })
end

local function tpToPlayer(nome)
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr.Name == nome then tpTo(plr); return end
    end
    Library:Notify({ Title = "TP", Description = "Jogador '" .. nome .. "' não encontrado!", Time = 2 })
end

-- ////////////////////////////////////////////////////////////
--  GUN GRABBER
-- ////////////////////////////////////////////////////////////

local function findGunDrop()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "GunDrop" then
            local p = obj.Parent
            if p and not p:FindFirstChild("Humanoid") then return obj end
        end
    end
    return nil
end

local function gunGrabber()
    local c = Player.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local gun = findGunDrop()
    if gun then
        local pos = hrp.CFrame
        hrp.CFrame = gun.CFrame
        task.wait()
        hrp.CFrame = pos
        Library:Notify({ Title = "Gun Grabber", Description = "Arma pega!", Time = 2 })
    else
        Library:Notify({ Title = "Gun Grabber", Description = "Nenhuma arma no chão!", Time = 2 })
    end
end

local function iniciarAutoGun()
    autoGun = true
    task.spawn(function()
        while autoGun do
            task.wait(0.5)
            local c = Player.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local gun = findGunDrop()
                if gun then
                    local pos = hrp.CFrame
                    hrp.CFrame = gun.CFrame
                    task.wait()
                    hrp.CFrame = pos
                    Library:Notify({ Title = "Auto Gun", Description = "Arma pega automaticamente!", Time = 1 })
                end
            end
        end
    end)
end

-- ////////////////////////////////////////////////////////////
--  UI - ABA ESP
-- ////////////////////////////////////////////////////////////

local EspLeft  = EspTab:AddLeftGroupbox("Controles ESP", "eye")
local EspRight = EspTab:AddRightGroupbox("Cores ESP", "palette")
local OutlineBox = EspTab:AddRightGroupbox("Borda", "square")

local MurdESPToggle = EspLeft:AddToggle("MurdererESP", {
    Text = "ESP Assassino",
    Default = false,
    Callback = function(v) if v then ativarMurdererESP() else desativarMurdererESP() end end
})

local SherESPToggle = EspLeft:AddToggle("SherrifESP", {
    Text = "ESP Xerife",
    Default = false,
    Callback = function(v) if v then ativarSherrifESP() else desativarSherrifESP() end end
})

local InnoESPToggle = EspLeft:AddToggle("InnocentESP", {
    Text = "ESP Inocentes",
    Default = false,
    Callback = function(v) if v then ativarInnocentESP() else desativarInnocentESP() end end
})

local GunESPToggle = EspLeft:AddToggle("GunESP", {
    Text = "ESP Arma",
    Default = false,
    Callback = function(v) if v then ativarGunESP() else desativarGunESP() end end
})

local NamesESPToggle = EspLeft:AddToggle("NamesESP", {
    Text = "Nomes ESP",
    Default = false,
    Callback = function(v) if v then ativarNamesESP() else desativarNamesESP() end end
})

EspLeft:AddSlider("EspTransparency", {
    Text = "Transparência ESP",
    Default = 0.4,
    Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Settings.EspTransparency = v end
})

-- color pickers (pendurados em toggle, jeito certo da obsidian)
local MurdColorToggle = EspRight:AddToggle("MurdColorT", { Text = "Cor Assassino", Default = false })
MurdColorToggle:AddColorPicker("MurdererColorPicker", {
    Default = Settings.MurdererColor,
    Title = "Cor do Assassino",
    Transparency = 0,
    Callback = function(c) Settings.MurdererColor = c end
})

local SherColorToggle = EspRight:AddToggle("SherColorT", { Text = "Cor Xerife", Default = false })
SherColorToggle:AddColorPicker("SherrifColorPicker", {
    Default = Settings.SherrifColor,
    Title = "Cor do Xerife",
    Transparency = 0,
    Callback = function(c) Settings.SherrifColor = c end
})

local InnoColorToggle = EspRight:AddToggle("InnoColorT", { Text = "Cor Inocentes", Default = false })
InnoColorToggle:AddColorPicker("InnocentColorPicker", {
    Default = Settings.InnocentColor,
    Title = "Cor dos Inocentes",
    Transparency = 0,
    Callback = function(c) Settings.InnocentColor = c end
})

local GunColorToggle = EspRight:AddToggle("GunColorT", { Text = "Cor Arma", Default = false })
GunColorToggle:AddColorPicker("GunColorPicker", {
    Default = Settings.GunColor,
    Title = "Cor da Arma",
    Transparency = 0,
    Callback = function(c) Settings.GunColor = c end
})

-- borda
OutlineBox:AddToggle("EnableOutline", {
    Text = "Ativar Borda",
    Default = true,
    Callback = function(v) Settings.OutlineEnabled = v end
})

local OutlineColorToggle = OutlineBox:AddToggle("OutlineColorT", { Text = "Cor da Borda", Default = false })
OutlineColorToggle:AddColorPicker("OutlineColorPicker", {
    Default = Settings.OutlineColor,
    Title = "Cor da Borda",
    Transparency = 0,
    Callback = function(c) Settings.OutlineColor = c end
})

OutlineBox:AddToggle("RainbowOutline", {
    Text = "Borda Rainbow",
    Default = false,
    Callback = function(v) Settings.OutlineRainbow = v end
})

OutlineBox:AddSlider("OutlineTransparency", {
    Text = "Transparência Borda",
    Default = 0,
    Min = 0, Max = 1, Rounding = 2,
    Callback = function(v) Settings.OutlineTransp = v end
})

-- ////////////////////////////////////////////////////////////
--  UI - ABA MOVIMENTO
-- ////////////////////////////////////////////////////////////

local MovBox = MovementTab:AddLeftGroupbox("Movimento", "zap")

local FlyToggle = MovBox:AddToggle("FlyToggle", {
    Text = "Voar",
    Default = false,
    Callback = function(v) if v then startFly() else stopFly() end end
})

FlyToggle:AddKeyPicker("FlyKeybind", {
    Text = "Tecla Voar",
    Default = "L",
    Mode = "Toggle",
    SyncToggleState = true,
    Callback = function() toggleFly() end
})

MovBox:AddInput("FlySpeedInput", {
    Text = "Velocidade de Voo",
    Default = "50",
    Callback = function(v) flySpeed = tonumber(v) or 50 end
})

local NoclipToggle = MovBox:AddToggle("NoclipToggle", {
    Text = "Noclip",
    Default = false,
    Callback = function(v)
        noclip = v
        Library:Notify({ Title = "Noclip", Description = v and "Ativado!" or "Desativado!", Time = 1 })
    end
})

NoclipToggle:AddKeyPicker("NoclipKeybind", {
    Text = "Tecla Noclip",
    Default = "B",
    Mode = "Toggle",
    SyncToggleState = true,
    Callback = function() noclip = not noclip end
})

MovBox:AddInput("WalkSpeedInput", {
    Text = "Velocidade",
    Default = "16",
    Callback = function(v) setWalkSpeed(v) end
})

MovBox:AddButton({ Text = "Resetar Velocidade", Func = resetWalkSpeed })

MovBox:AddInput("JumpPowerInput", {
    Text = "Força de Pulo",
    Default = "50",
    Callback = function(v) setJumpPower(v) end
})

MovBox:AddButton({ Text = "Resetar Pulo", Func = resetJumpPower })

-- ////////////////////////////////////////////////////////////
--  UI - ABA TELEPORTE
-- ////////////////////////////////////////////////////////////

local TpBox = TeleportTab:AddLeftGroupbox("Teleportes", "map-pin")

TpBox:AddButton({ Text = "TP para Lobby",    Func = tpToLobby })
TpBox:AddButton({ Text = "TP para Mapa",     Func = tpToMap })
TpBox:AddButton({ Text = "TP para Assassino", Func = tpToMurderer })
TpBox:AddButton({ Text = "TP para Xerife",   Func = tpToSherrif })

TpBox:AddInput("TpPlayerInput", {
    Text = "Nome do Jogador",
    Default = "",
    Callback = function(v) _G.TpTarget = v end
})

TpBox:AddButton({
    Text = "TP para Jogador",
    Func = function()
        if _G.TpTarget and _G.TpTarget ~= "" then
            tpToPlayer(_G.TpTarget)
        else
            Library:Notify({ Title = "Erro", Description = "Digite um nome primeiro!", Time = 2 })
        end
    end
})

-- ////////////////////////////////////////////////////////////
--  UI - ABA MISC
-- ////////////////////////////////////////////////////////////

local MiscBox = MiscTab:AddLeftGroupbox("Misc", "cog")

MiscBox:AddButton({ Text = "Pegar Arma (Manual)", Func = gunGrabber })

MiscBox:AddToggle("AutoGunGrabber", {
    Text = "Auto Pegar Arma",
    Default = false,
    Callback = function(v)
        if v then
            autoGun = true
            iniciarAutoGun()
            Library:Notify({ Title = "Auto Gun", Description = "Ativado!", Time = 2 })
        else
            autoGun = false
            Library:Notify({ Title = "Auto Gun", Description = "Desativado!", Time = 1 })
        end
    end
})

MiscBox:AddButton({
    Text = "Recarregar Roles",
    Func = function()
        carregarRoles()
        Library:Notify({ Title = "Roles", Description = "Roles recarregadas!", Time = 2 })
    end
})

-- ////////////////////////////////////////////////////////////
--  INIT
-- ////////////////////////////////////////////////////////////

task.wait(0.5)
Library:Notify({
    Title = "Vynixu MM2 Script",
    Description = "Pronto! Ative os ESPs na aba ESP.",
    Time = 4,
})