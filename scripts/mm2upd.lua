-- vynixu mm2 - obsidian edition
local VERSAO = "5.1"

-- 1 instância por vez
if getgenv().VynixuMM2_Destroy then pcall(getgenv().VynixuMM2_Destroy) end
getgenv().VynixuMM2_Running = true

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()
local Options, Toggles = Library.Options, Library.Toggles

getgenv().VynixuMM2_Destroy = function()
    pcall(function() Library:Destroy() end)
    getgenv().VynixuMM2_Running = false
end

local Player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RS  = game:GetService("RunService")
local HS  = game:GetService("HttpService")
local username = Player.Name
local placeId = tostring(game.PlaceId)

-- loading com 6 steps
local Loading = Library:CreateLoading({
    Title = "Vynixu MM2 Script",
    Icon = 95816097006870,
    TotalSteps = 6,
    ShowSidebar = true,
})
Loading.Sidebar:AddLabel("v" .. VERSAO .. " changelogs:")
Loading.Sidebar:AddLabel("+ key system")
Loading.Sidebar:AddLabel("+ ranks (owner/co-owner/admin)")
Loading.Sidebar:AddLabel("+ disable feature on the fly")
Loading.Sidebar:AddLabel("+ auto updater")
Loading.Sidebar:AddLabel("+ kill aura")
Loading.Sidebar:AddLabel("+ tabela de usuarios")
Loading.Sidebar:AddLabel("+ rejoin")
Loading.Sidebar:AddLabel("usuario: " .. username)
Loading:SetMessage("inicializando...")
Loading:SetCurrentStep(1)
Loading:SetDescription("verificando instancias...")
task.wait(0.3)

-- firebase
local DB = "https://vynixu-database-default-rtdb.firebaseio.com/"

local function dbGet(path)
    local ok, res = pcall(function()
        return request({ Url = DB .. path .. ".json", Method = "GET" })
    end)
    if ok and res and res.StatusCode == 200 then return res.Body end
    return nil
end

local function dbSet(path, data)
    pcall(function()
        request({
            Url = DB .. path .. ".json",
            Method = "PUT",
            Headers = { ["Content-Type"] = "application/json" },
            Body = data
        })
    end)
end

Loading:SetCurrentStep(1)
Loading:SetDescription("checando versao...")
task.spawn(function()
    -- função reutilizável
    local function checarVersao()
        local verRaw = dbGet("version")
        if verRaw and verRaw ~= "null" then
            local verRemota = verRaw:gsub('"', ''):gsub('%s', '')
            if verRemota ~= VERSAO then
                Library:Notify({
                    Title = "Update Disponivel!",
                    Description = "Versao atual: " .. VERSAO .. " | Nova: " .. verRemota .. "\nRe-execute o script para atualizar.",
                    Time = 20,
                })
                return true
            end
        end
        return false
    end
    
    -- checa imediatamente
    checarVersao()
    
    -- depois checa periodicamente (DENTRO do spawn)
    while task.wait(60) do
        if checarVersao() then
            break
        end
    end
end)
-- step 2: check blacklist de jogos
Loading:SetCurrentStep(2)
Loading:SetDescription("checando blacklist...")
local blacklistMsg = dbGet("blacklistedGames/" .. placeId)
if blacklistMsg and blacklistMsg ~= "null" then
    Loading:SetMessage("failed")
    Loading:SetDescription(blacklistmsg)
    task.wait(5); Library:Destroy(); return
end

-- step 3: key system
Loading:SetCurrentStep(3)
Loading:SetDescription("verificando key...")

local userRole = nil -- nil = sem acesso, "user"/"admin"/"co-owner"/"owner"

-- tenta autenticar pelo nome direto nos admins
local adminRaw = dbGet("admins/" .. username)
if adminRaw and adminRaw ~= "null" then
    local ok, adminData = pcall(function() return HS:JSONDecode(adminRaw) end)
    if ok and type(adminData) == "table" then
        -- estrutura: { boolean = true/false, role = "owner"/"co-owner"/"admin", authmethod = "name"/"key" }
        if adminData.boolean == true then
            userRole = adminData.role or "admin"
        end
    elseif adminRaw == "true" then
        -- compatibilidade com formato antigo
        userRole = "admin"
    end
end

-- se nao é admin, verifica key
if not userRole then
    -- pega key do usuario se tiver salvo, ou pede
    local savedKey = ""
    -- tenta pegar do storage se disponivel
    pcall(function()
        local kf = readfile and readfile("VynixuMM2Script/key.txt")
        if kf and kf ~= "" then savedKey = kf:gsub("%s", "") end
    end)

    if savedKey ~= "" then
        local keyRoleRaw = dbGet("keys/" .. savedKey)
        if keyRoleRaw and keyRoleRaw ~= "null" then
            userRole = keyRoleRaw:gsub('"', '')
        end
    end

    if not userRole then
        -- sem key salva, tenta verificar ban antes de pedir
        local isBanned = dbGet("banned/" .. username)
        if isBanned and isBanned ~= "null" and isBanned ~= "false" then
            Loading:SetMessage("acesso negado")
            Loading:SetDescription("voce foi banido do script.")
            task.wait(5); Library:Destroy(); return
        end

        -- sem key = sem acesso (nao fecha, mas sem features premium)
        userRole = "guest"
    end
end

-- step 4: check ban
Loading:SetCurrentStep(4)
Loading:SetDescription("checando acesso...")
local isBanned = dbGet("banned/" .. username)
if isBanned and isBanned ~= "null" and isBanned ~= "false" then
    Loading:SetMessage("acesso negado")
    Loading:SetDescription("voce foi banido do script.")
    task.wait(5); Library:Destroy(); return
end

-- perms por rank
local isOwner   = userRole == "owner"
local isCoOwner = userRole == "co-owner" or isOwner
local isAdmin   = userRole == "admin" or isCoOwner
-- admin nao tem: ban/delay/disable features/blacklist (so owner/co-owner tem)
local canBan         = isCoOwner
local canSetDelay    = isCoOwner
local canDisableFeat = isCoOwner
local canBlacklist   = isCoOwner

-- step 5: settings
Loading:SetCurrentStep(5)
Loading:SetDescription("carregando permissoes...")

local globalSettingsRaw = dbGet("globalSettings")
local globalSettings = {
    defaultGunDelay = 0.2,
    allowedFeatures = { fly=true, noclip=true, esp=true, autoGun=true, hitbox=true, speedHack=true, jumpHack=true }
}
if globalSettingsRaw and globalSettingsRaw ~= "null" then
    pcall(function()
        local gs = HS:JSONDecode(globalSettingsRaw)
        if gs.defaultGunDelay then globalSettings.defaultGunDelay = gs.defaultGunDelay end
        if gs.allowedFeatures then globalSettings.allowedFeatures = gs.allowedFeatures end
    end)
end

-- disabled features on the fly (polling 15s)
local disabledFeaturesGlobal = {}
local function fetchDisabledFeatures()
    local raw = dbGet("disabledFeatures")
    if raw and raw ~= "null" then
        local ok, data = pcall(function() return HS:JSONDecode(raw) end)
        if ok and type(data) == "table" then
            disabledFeaturesGlobal = data
        end
    end
end
fetchDisabledFeatures()

task.spawn(function()
    while getgenv().VynixuMM2_Running do
        task.wait(15)
        fetchDisabledFeatures()
        -- atualiza toggles desabilitados
        for feat, disabled in pairs(disabledFeaturesGlobal) do
            if disabled == true then
                -- marca Disabled nos toggles correspondentes
                local toggleMap = {
                    fly = "FlyToggle",
                    noclip = "NoclipToggle",
                    esp = "MurdererESP",
                    autoGun = "AutoGunGrabber",
                    hitbox = "HitboxToggle",
                    speedHack = "WSToggle",
                    jumpHack = "JPToggle",
                    killAura = "KillAuraToggle",
                }
                local tid = toggleMap[feat]
                if tid and Toggles[tid] then
                    if Toggles[tid].Value then
                        Toggles[tid]:SetValue(false)
                    end
                    -- marca visualmente como desabilitado
                    pcall(function()
                        Toggles[tid].Disabled = true
                    end)
                end
            end
        end
    end
end)

local userSettingsRaw = dbGet("userSettings/" .. username)
local userSettings = {}
if userSettingsRaw and userSettingsRaw ~= "null" then
    pcall(function() userSettings = HS:JSONDecode(userSettingsRaw) end)
end

-- registra online em background
task.spawn(function()
    dbSet("users/" .. username, HS:JSONEncode({
        online = true,
        placeId = placeId,
        time = os.time(),
        role = userRole or "guest"
    }))
end)
game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function()
    dbSet("users/" .. username .. "/online", "false")
end)

if isAdmin then Loading.Sidebar:AddLabel("[" .. (userRole or "ADMIN"):upper() .. "]") end

local function featureAllowed(name)
    -- check global disabled features (on the fly)
    if disabledFeaturesGlobal[name] == true then return false end
    if userSettings.disabledFeatures then
        for _, f in pairs(userSettings.disabledFeatures) do
            if f == name then return false end
        end
    end
    if globalSettings.allowedFeatures[name] == false then return false end
    return true
end

local isBuga = username == "bugagamesreal"
local gunDelay = userSettings.gunDelay or globalSettings.defaultGunDelay

-- step 6: finalizando
Loading:SetCurrentStep(6)
Loading:SetDescription("carregando ui...")
task.wait(0.4)
Loading:Continue()

-- window
local Window = Library:CreateWindow({
    Title = "Vynixu MM2 Script",
    SubTitle = "Obsidian Edition" .. (isAdmin and (" [" .. (userRole or "admin"):upper() .. "]") or ""),
    Theme = "Dark",
    Size = UDim2.new(0, 580, 0, 500),
    Animations = { ToggleWindow=true, TabSwitch=true, Groupbox=true, Dropdown=true, KeyPicker=true },
})
Window:SetFooter("Obsidian Edition v" .. VERSAO .. (isAdmin and (" | " .. (userRole or "admin"):upper()) or ""))

local EspTab      = Window:AddTab("ESP", "eye")
local MovementTab = Window:AddTab("Movimento", "zap")
local TeleportTab = Window:AddTab("Teleporte", "map-pin")
local MiscTab     = Window:AddTab("Misc", "cog")
local AdminTab    = isAdmin and Window:AddTab("Admin", "shield") or nil
local ConfigTab   = Window:AddTab("Config", "settings")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("VynixuMM2Script/Configs")

local flying, flySpeed = false, 50
local flyKeyDown, flyKeyUp, flyBG, flyBV
local noclip, autoGun = false, false

local Settings = {
    MurdererColor   = Color3.fromRGB(255, 0, 25),
    SherrifColor    = Color3.fromRGB(0, 50, 255),
    InnocentColor   = Color3.fromRGB(0, 255, 50),
    GunColor        = Color3.fromRGB(0, 255, 50),
    EspTransparency = 0.4,
    OutlineEnabled  = true,
    OutlineColor    = Color3.fromRGB(0, 0, 0),
    OutlineRainbow  = false,
    OutlineTransp   = 0,
}

local espStates = { Murderer=false, Sherrif=false, Innocent=false, Gun=false, Names=false }

-- roles via GetPlayerData
local playerRoles, rolesLoaded = {}, false

local function carregarRoles()
    local ok, result = pcall(function()
        local r = game:GetService("ReplicatedStorage"):FindFirstChild("GetPlayerData", true)
        return r and r:InvokeServer()
    end)
    if ok and result then playerRoles = result; rolesLoaded = true end
end
task.spawn(carregarRoles)
game:GetService("ReplicatedStorage").DescendantAdded:Connect(function(obj)
    if obj.Name == "GetPlayerData" then task.wait(1); carregarRoles() end
end)
task.spawn(function() while true do task.wait(5); carregarRoles() end end)

local function getRole(plr)
    if not plr or not rolesLoaded then return nil end
    local d = playerRoles[plr.Name]
    return d and d.Role
end

local function hasTool(plr, name)
    local bp = plr:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild(name) then return true end
    if plr.Character then
        for _, v in pairs(plr.Character:GetChildren()) do
            if v:IsA("Tool") and v.Name == name then return true end
        end
    end
end

local function isMurderer(plr)
    local r = getRole(plr); if r then return r == "Murderer" end
    return hasTool(plr, "Knife")
end
local function isSherrif(plr)
    local r = getRole(plr); if r then return r == "Sheriff" end
    return hasTool(plr, "Gun")
end
local function isInnocent(plr)
    if not plr or plr == Player then return false end
    local r = getRole(plr); if r then return r == "Innocent" end
    return not isMurderer(plr) and not isSherrif(plr)
end

-- esp
local ESP = { Highlights = {} }

function ESP:remove(tipo, char)
    if not char then return end
    local h = self.Highlights[tipo] and self.Highlights[tipo][char]
    if h and h.Parent then h:Destroy() end
    if self.Highlights[tipo] then self.Highlights[tipo][char] = nil end
end

function ESP:create(tipo, char, cor)
    if not char or not char.Parent then return end
    local existing = self.Highlights[tipo] and self.Highlights[tipo][char]
    if existing and existing.Parent then
        existing.FillColor = cor
        existing.FillTransparency = Settings.EspTransparency
        existing.OutlineColor = Settings.OutlineRainbow
            and Color3.fromHSV((tick() * 0.3) % 1, 1, 1) or Settings.OutlineColor
        existing.OutlineTransparency = Settings.OutlineEnabled and Settings.OutlineTransp or 1
        return
    end
    self:remove(tipo, char)
    local h = Instance.new("Highlight")
    h.Name = tipo .. "_ESP"; h.Parent = char
    h.FillColor = cor; h.FillTransparency = Settings.EspTransparency
    h.OutlineColor = Settings.OutlineColor
    h.OutlineTransparency = Settings.OutlineEnabled and Settings.OutlineTransp or 1
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    if not self.Highlights[tipo] then self.Highlights[tipo] = {} end
    self.Highlights[tipo][char] = h
end

RS.RenderStepped:Connect(function()
    if not Settings.OutlineRainbow then return end
    local c = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)
    for _, map in pairs(ESP.Highlights) do
        for _, h in pairs(map) do if h and h.Parent then h.OutlineColor = c end end
    end
end)

local function espLoop(tipo, checkFn, colorFn)
    task.spawn(function()
        while espStates[tipo] do
            task.wait(0.2)
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player or not plr.Character then continue end
                if checkFn(plr) then ESP:create(tipo, plr.Character, colorFn())
                else ESP:remove(tipo, plr.Character) end
            end
        end
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr.Character then ESP:remove(tipo, plr.Character) end
        end
    end)
end

local function ativarMurdererESP()   espStates.Murderer = true;  espLoop("Murderer", isMurderer, function() return Settings.MurdererColor end) end
local function desativarMurdererESP() espStates.Murderer = false end
local function ativarSherrifESP()    espStates.Sherrif  = true;  espLoop("Sherrif",  isSherrif,  function() return Settings.SherrifColor end) end
local function desativarSherrifESP() espStates.Sherrif  = false end

local function ativarInnocentESP()
    espStates.Innocent = true
    espLoop("Innocent", function(plr)
        if not isInnocent(plr) then return false end
        local c = plr.Character
        if ESP.Highlights["Murderer"] and ESP.Highlights["Murderer"][c] then return false end
        if ESP.Highlights["Sherrif"]  and ESP.Highlights["Sherrif"][c]  then return false end
        return true
    end, function() return Settings.InnocentColor end)
end
local function desativarInnocentESP() espStates.Innocent = false end

local function ativarGunESP()
    espStates.Gun = true
    local gunH = {}
    task.spawn(function()
        while espStates.Gun do
            task.wait(0.5)
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name == "GunDrop" and not gunH[obj] then
                    local h = Instance.new("Highlight")
                    h.Name = "GunHighlight"; h.Parent = obj
                    h.FillColor = Settings.GunColor; h.FillTransparency = 0.4
                    h.OutlineColor = Color3.fromRGB(0,0,0); h.OutlineTransparency = 0
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    gunH[obj] = h
                end
            end
        end
        for _, h in pairs(gunH) do pcall(function() h:Destroy() end) end
    end)
end
local function desativarGunESP() espStates.Gun = false end

-- names esp
local namesBillboards = {}

local function removerNome(plr)
    if namesBillboards[plr] then namesBillboards[plr]:Destroy(); namesBillboards[plr] = nil end
end

local function criarNome(plr)
    if not plr or not plr.Character then return end
    local head = plr.Character:FindFirstChild("Head"); if not head then return end
    removerNome(plr)
    local bb = Instance.new("BillboardGui")
    bb.Name = "NameESP"; bb.Parent = head; bb.Adornee = head
    bb.Size = UDim2.new(0,150,0,40); bb.StudsOffset = Vector3.new(0,2.5,0)
    bb.AlwaysOnTop = true; bb.MaxDistance = 5000

    local nome = Instance.new("TextLabel")
    nome.Name = "Nome"; nome.Parent = bb; nome.BackgroundTransparency = 1
    nome.Size = UDim2.new(1,0,0.6,0); nome.Font = Enum.Font.GothamBold
    nome.Text = plr.Name; nome.TextColor3 = Color3.fromRGB(255,255,255)
    nome.TextSize = 14; nome.TextStrokeTransparency = 0

    local dist = Instance.new("TextLabel")
    dist.Name = "Dist"; dist.Parent = bb; dist.BackgroundTransparency = 1
    dist.Size = UDim2.new(1,0,0.4,0); dist.Position = UDim2.new(0,0,0.6,0)
    dist.Font = Enum.Font.Gotham; dist.Text = "0m"
    dist.TextColor3 = Color3.fromRGB(200,200,200); dist.TextSize = 12
    dist.TextStrokeTransparency = 0

    namesBillboards[plr] = bb
    plr.CharacterAdded:Connect(function()
        task.wait(0.5); if espStates.Names then criarNome(plr) end
    end)
end

RS.RenderStepped:Connect(function()
    if not espStates.Names then return end
    local lc = Player.Character
    local lhrp = lc and lc:FindFirstChild("HumanoidRootPart"); if not lhrp then return end
    for plr, bb in pairs(namesBillboards) do
        local dl = bb:FindFirstChild("Dist")
        if dl and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            dl.Text = math.floor((lhrp.Position - plr.Character.HumanoidRootPart.Position).Magnitude) .. "m"
        end
    end
end)

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
                    local nl = bb and bb:FindFirstChild("Nome")
                    if nl then
                        nl.TextColor3 = isMurderer(plr) and Color3.fromRGB(255,0,25)
                            or isSherrif(plr) and Color3.fromRGB(0,50,255)
                            or Color3.fromRGB(0,255,50)
                    end
                else removerNome(plr) end
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
        for tipo in pairs(ESP.Highlights) do ESP:remove(tipo, plr.Character) end
    end
end)

-- fly
local function restaurarColisoes()
    local char = Player.Character; if not char then return end
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
    end
end

local function startFly()
    if flying then return end
    local char = Player.Character or Player.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildWhichIsA("Humanoid")
    if not root or not hum then return end
    if flyKeyDown then flyKeyDown:Disconnect() end
    if flyKeyUp   then flyKeyUp:Disconnect()   end
    flying = true
    local CTRL = {F=0,B=0,L=0,R=0,Up=0,Down=0}
    flyBG = Instance.new("BodyGyro", root)
    flyBG.P = 9e4; flyBG.MaxTorque = Vector3.new(9e9,9e9,9e9); flyBG.CFrame = root.CFrame
    flyBV = Instance.new("BodyVelocity", root)
    flyBV.Velocity = Vector3.zero; flyBV.MaxForce = Vector3.new(9e9,9e9,9e9)
    task.spawn(function()
        while flying do
            task.wait(); hum.PlatformStand = true
            local cam = workspace.CurrentCamera
            local vel = cam.CFrame.LookVector  * (CTRL.F - CTRL.B)
                      + cam.CFrame.RightVector * (CTRL.R - CTRL.L)
                      + Vector3.new(0,1,0)     * (CTRL.Up - CTRL.Down)
            flyBV.Velocity = vel.Magnitude > 0 and vel.Unit * flySpeed or Vector3.zero
            flyBG.CFrame = cam.CFrame
        end
    end)
    flyKeyDown = UIS.InputBegan:Connect(function(i,gp)
        if gp then return end; local k = i.KeyCode
        if k==Enum.KeyCode.W then CTRL.F=1 elseif k==Enum.KeyCode.S then CTRL.B=1
        elseif k==Enum.KeyCode.A then CTRL.L=1 elseif k==Enum.KeyCode.D then CTRL.R=1
        elseif k==Enum.KeyCode.E then CTRL.Up=1 elseif k==Enum.KeyCode.Q then CTRL.Down=1 end
    end)
    flyKeyUp = UIS.InputEnded:Connect(function(i,gp)
        if gp then return end; local k = i.KeyCode
        if k==Enum.KeyCode.W then CTRL.F=0 elseif k==Enum.KeyCode.S then CTRL.B=0
        elseif k==Enum.KeyCode.A then CTRL.L=0 elseif k==Enum.KeyCode.D then CTRL.R=0
        elseif k==Enum.KeyCode.E then CTRL.Up=0 elseif k==Enum.KeyCode.Q then CTRL.Down=0 end
    end)
    Library:Notify({ Title="Voo", Description="Ativado! WASD+Q/E", Time=2 })
end

local function stopFly()
    if not flying then return end
    flying = false
    if flyKeyDown then flyKeyDown:Disconnect(); flyKeyDown=nil end
    if flyKeyUp   then flyKeyUp:Disconnect();   flyKeyUp=nil   end
    if flyBG then flyBG:Destroy(); flyBG=nil end
    if flyBV then flyBV:Destroy(); flyBV=nil end
    local char = Player.Character
    if char then
        local hum = char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
        if not noclip then restaurarColisoes() end
    end
    Library:Notify({ Title="Voo", Description="Desativado!", Time=1 })
end
local function toggleFly() if flying then stopFly() else startFly() end end

-- noclip
RS.Stepped:Connect(function()
    if noclip and not flying and Player.Character then
        for _, p in pairs(Player.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

-- movimento
local function setWalkSpeed(v) local c=Player.Character; if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed=tonumber(v) or 16 end end
local function setJumpPower(v) local c=Player.Character; if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower=tonumber(v) or 50 end end
local function resetWalkSpeed() setWalkSpeed(16) end
local function resetJumpPower() setJumpPower(50) end

-- teleportes
local function tpToLobby()
    local c=Player.Character; if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame=CFrame.new(-108.5,145,0.6) end
end
local function tpToMap()
    local c=Player.Character; if not c or not c:FindFirstChild("HumanoidRootPart") then return end
    for _,t in pairs(workspace:GetChildren()) do
        for _,ch in pairs(t:GetChildren()) do
            if ch.Name=="Spawns" and ch:FindFirstChild("Spawn") then c.HumanoidRootPart.CFrame=ch.Spawn.CFrame; return end
        end
    end
end
local function tpTo(plr)
    local c=Player.Character
    if c and c:FindFirstChild("HumanoidRootPart") and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
    end
end
local function tpToMurderer()
    for _,plr in pairs(game.Players:GetPlayers()) do if isMurderer(plr) then tpTo(plr); return end end
    Library:Notify({ Title="TP", Description="Nenhum assassino encontrado!", Time=2 })
end
local function tpToSherrif()
    for _,plr in pairs(game.Players:GetPlayers()) do if isSherrif(plr) then tpTo(plr); return end end
    Library:Notify({ Title="TP", Description="Nenhum xerife encontrado!", Time=2 })
end
local function tpToPlayer(nome)
    for _,plr in pairs(game.Players:GetPlayers()) do if plr.Name==nome then tpTo(plr); return end end
    Library:Notify({ Title="TP", Description="Jogador '"..nome.."' não encontrado!", Time=2 })
end

-- rejoin
local function rejoin()
    game:GetService("TeleportService"):Teleport(game.PlaceId, Player)
end

-- gun grabber
local function findGunDrop()
    for _,obj in pairs(workspace:GetDescendants()) do
        if obj.Name=="GunDrop" then local p=obj.Parent; if p and not p:FindFirstChild("Humanoid") then return obj end end
    end
end

local function playerPareceMorto()
    local c=Player.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return true end
    local count, longe = 0, 0
    for _,plr in pairs(game.Players:GetPlayers()) do
        if plr==Player or not plr.Character then continue end
        local ohrp=plr.Character:FindFirstChild("HumanoidRootPart"); if not ohrp then continue end
        count+=1; if (hrp.Position-ohrp.Position).Magnitude>1000 then longe+=1 end
    end
    return count>0 and longe==count
end

local function gunGrabber()
    local c=Player.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not isBuga then task.wait(gunDelay) end
    local gun=findGunDrop()
    if gun then local pos=hrp.CFrame; hrp.CFrame=gun.CFrame; task.wait(); hrp.CFrame=pos; Library:Notify({Title="Gun Grabber",Description="Arma pega!",Time=2})
    else Library:Notify({Title="Gun Grabber",Description="Nenhuma arma no chão!",Time=2}) end
end

local function iniciarAutoGun()
    autoGun=true
    task.spawn(function()
        while autoGun do
            task.wait(0.5)
            if playerPareceMorto() then
                autoGun=false
                Toggles.AutoGunGrabber:SetValue(false)
                Library:Notify({Title="Auto Gun",Description="Desligado: parece que você morreu.",Time=3})
                break
            end
            local c=Player.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local gun=findGunDrop()
                if gun then
                    if not isBuga then task.wait(gunDelay) end
                    local pos=hrp.CFrame; hrp.CFrame=gun.CFrame; task.wait(); hrp.CFrame=pos
                    Library:Notify({Title="Auto Gun",Description="Arma pega!",Time=1})
                end
            end
        end
    end)
end

-- kill aura (murder only, auto desativa sem faca)
local killAuraAtivo = false
local killAuraConn = nil

local function temFaca()
    local char = Player.Character; if not char then return false end
    for _, v in pairs(char:GetChildren()) do
        if v:IsA("Tool") and v.Name == "Knife" then return true end
    end
    local bp = Player:FindFirstChild("Backpack")
    if bp then
        for _, v in pairs(bp:GetChildren()) do
            if v:IsA("Tool") and v.Name == "Knife" then return true end
        end
    end
    return false
end

local function ativarKillAura()
    killAuraAtivo = true
    task.spawn(function()
        while killAuraAtivo do
            task.wait(0.1)
            -- auto desativa se nao tiver faca
            if not temFaca() then
                killAuraAtivo = false
                if Toggles.KillAuraToggle then
                    Toggles.KillAuraToggle:SetValue(false)
                end
                Library:Notify({Title="Kill Aura",Description="Desativado: sem faca!",Time=3})
                break
            end
            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            -- só ataca se for murderer
            if not isMurderer(Player) then continue end
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player or not plr.Character then continue end
                local ohrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if not ohrp then continue end
                local dist = (hrp.Position - ohrp.Position).Magnitude
                if dist <= 8 then
                    -- tp pra cima do player e volta
                    local pos = hrp.CFrame
                    hrp.CFrame = ohrp.CFrame
                    task.wait(0.05)
                    hrp.CFrame = pos
                end
            end
        end
    end)
end

local function desativarKillAura()
    killAuraAtivo = false
end

-- hitbox expander
local hitboxAtivo, hitboxBrutal, hitboxSize = false, false, 10
local hitboxOriginais, hitboxHighlights = {}, {}

local function setPartSize(part, size)
    pcall(function()
        if sethiddenproperty then sethiddenproperty(part, "Size", size)
        else part.Size = size end
    end)
end

local function getHitboxParts(char)
    if hitboxBrutal then
        local p={}; for _,v in pairs(char:GetDescendants()) do if v:IsA("BasePart") then table.insert(p,v) end end; return p
    end
    local hrp=char:FindFirstChild("HumanoidRootPart"); return hrp and {hrp} or {}
end

local function aplicarHitbox()
    for _,plr in pairs(game.Players:GetPlayers()) do
        if plr==Player or not plr.Character then continue end
        if not hitboxOriginais[plr] then hitboxOriginais[plr]={} end
        for _,part in pairs(getHitboxParts(plr.Character)) do
            if not hitboxOriginais[plr][part] then
                hitboxOriginais[plr][part]=part.Size
                setPartSize(part, Vector3.new(hitboxSize,hitboxSize,hitboxSize))
            end
        end
    end
end
local function removerHitbox()
    for _,parts in pairs(hitboxOriginais) do
        for part,size in pairs(parts) do setPartSize(part, size) end
    end; hitboxOriginais={}
end
local function verHitbox()
    for plr in pairs(hitboxOriginais) do
        if plr.Character then
            local h=Instance.new("Highlight"); h.Parent=plr.Character
            h.FillColor=Color3.fromRGB(255,165,0); h.FillTransparency=0.5
            h.OutlineColor=Color3.fromRGB(255,165,0); h.OutlineTransparency=0
            h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            table.insert(hitboxHighlights,h)
        end
    end
    task.delay(2, function()
        for _,h in pairs(hitboxHighlights) do pcall(function() h:Destroy() end) end
        hitboxHighlights={}
    end)
    Library:Notify({Title="View Hitbox",Description="Mostrando por 2s",Time=2})
end
task.spawn(function() while true do task.wait(0.5); if hitboxAtivo then aplicarHitbox() end end end)
game.Players.PlayerRemoving:Connect(function(plr) hitboxOriginais[plr]=nil end)

-- anti fling
local antiFlingAtivo = false
local antiFlingConn = nil

local function ativarAntiFling()
    antiFlingAtivo = true
    antiFlingConn = RS.Stepped:Connect(function()
        for _,plr in pairs(game.Players:GetPlayers()) do
            if plr==Player or not plr.Character then continue end
            for _,p in pairs(plr.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end)
end
local function desativarAntiFling()
    antiFlingAtivo = false
    if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn=nil end
end

-- tabela de usuarios no misc
local function getPlayerTable()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local lines = {}
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr == Player then continue end
        local role = getRole(plr) or (isMurderer(plr) and "Murderer" or isSherrif(plr) and "Sheriff" or "Innocent")
        local dist = "?"
        if hrp and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            dist = tostring(math.floor((hrp.Position - plr.Character.HumanoidRootPart.Position).Magnitude)) .. "m"
        end
        table.insert(lines, plr.Name .. " | " .. role .. " | " .. dist)
    end
    return #lines > 0 and table.concat(lines, "\n") or "nenhum jogador"
end

-- ===== UI =====

-- ESP tab
local EspLeft    = EspTab:AddLeftGroupbox("Controles ESP", "eye")
local EspRight   = EspTab:AddRightGroupbox("Cores ESP", "palette")
local OutlineBox = EspTab:AddRightGroupbox("Borda", "square")

EspLeft:AddToggle("MurdererESP", { Text="ESP Assassino", Default=false, Callback=function(v) if v then ativarMurdererESP() else desativarMurdererESP() end end })
EspLeft:AddToggle("SherrifESP",  { Text="ESP Xerife",    Default=false, Callback=function(v) if v then ativarSherrifESP()  else desativarSherrifESP()  end end })
EspLeft:AddToggle("InnocentESP", { Text="ESP Inocentes", Default=false, Callback=function(v) if v then ativarInnocentESP() else desativarInnocentESP() end end })
EspLeft:AddToggle("GunESP",      { Text="ESP Arma",      Default=false, Callback=function(v) if v then ativarGunESP()      else desativarGunESP()      end end })
EspLeft:AddToggle("NamesESP",    { Text="Nomes ESP",     Default=false, Callback=function(v) if v then ativarNamesESP()    else desativarNamesESP()    end end })
EspLeft:AddSlider("EspTransparency", { Text="Transparência ESP", Default=0.4, Min=0, Max=1, Rounding=2, Callback=function(v) Settings.EspTransparency=v end })

local function addColorToggle(box, id, label, key)
    local t = box:AddToggle(id.."T", { Text=label, Default=false })
    t:AddColorPicker(id.."Picker", { Default=Settings[key], Transparency=0, Callback=function(c) Settings[key]=c end })
end
addColorToggle(EspRight, "Murd", "Cor Assassino", "MurdererColor")
addColorToggle(EspRight, "Sher", "Cor Xerife",    "SherrifColor")
addColorToggle(EspRight, "Inno", "Cor Inocentes", "InnocentColor")
addColorToggle(EspRight, "Gun",  "Cor Arma",      "GunColor")

OutlineBox:AddToggle("EnableOutline", { Text="Ativar Borda", Default=true, Callback=function(v) Settings.OutlineEnabled=v end })
local ot = OutlineBox:AddToggle("OutlineColorT", { Text="Cor da Borda", Default=false })
ot:AddColorPicker("OutlineColorPicker", { Default=Settings.OutlineColor, Transparency=0, Callback=function(c) Settings.OutlineColor=c end })
OutlineBox:AddToggle("RainbowOutline", { Text="Borda Rainbow", Default=false, Callback=function(v) Settings.OutlineRainbow=v end })
OutlineBox:AddSlider("OutlineTransparency", { Text="Transparência Borda", Default=0, Min=0, Max=1, Rounding=2, Callback=function(v) Settings.OutlineTransp=v end })

-- movimento tab
local MovBox = MovementTab:AddLeftGroupbox("Movimento", "zap")
local FlyToggle = MovBox:AddToggle("FlyToggle", { Text="Voar", Default=false, Callback=function(v) if v then startFly() else stopFly() end end })
FlyToggle:AddKeyPicker("FlyKeybind", { Text="Tecla Voar", Default="L", Mode="Toggle", SyncToggleState=true, Callback=function() toggleFly() end })
MovBox:AddInput("FlySpeedInput", { Text="Velocidade de Voo", Default="50", Callback=function(v) flySpeed=tonumber(v) or 50 end })

local NoclipToggle = MovBox:AddToggle("NoclipToggle", { Text="Noclip", Default=false, Callback=function(v) noclip=v; Library:Notify({Title="Noclip",Description=v and "Ativado!" or "Desativado!",Time=1}) end })
NoclipToggle:AddKeyPicker("NoclipKeybind", { Text="Tecla Noclip", Default="B", Mode="Toggle", SyncToggleState=true, Callback=function() noclip=not noclip end })

local wsValor, jpValor = 50, 100

MovBox:AddInput("WalkSpeedInput", { Text="Valor Velocidade", Default="50", Callback=function(v) wsValor=tonumber(v) or 50 end })
local WSToggle = MovBox:AddToggle("WSToggle", { Text="Speed Hack", Default=false,
    Callback=function(v)
        if v then
            task.spawn(function()
                while Toggles.WSToggle.Value do
                    task.wait(0.1)
                    local c=Player.Character
                    if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed=wsValor end
                end
                resetWalkSpeed()
            end)
        end
    end
})
WSToggle:AddKeyPicker("WSKey", { Text="Tecla Speed Hack", Default="LeftBracket", Mode="Toggle", SyncToggleState=true, Callback=function() end })

MovBox:AddInput("JumpPowerInput", { Text="Valor Pulo", Default="100", Callback=function(v) jpValor=tonumber(v) or 100 end })
local JPToggle = MovBox:AddToggle("JPToggle", { Text="Jump Hack", Default=false,
    Callback=function(v)
        if v then
            task.spawn(function()
                while Toggles.JPToggle.Value do
                    task.wait(0.1)
                    local c=Player.Character
                    if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower=jpValor end
                end
                resetJumpPower()
            end)
        end
    end
})
JPToggle:AddKeyPicker("JPKey", { Text="Tecla Jump Hack", Default="RightBracket", Mode="Toggle", SyncToggleState=true, Callback=function() end })

-- teleporte tab
local TpBox = TeleportTab:AddLeftGroupbox("Teleportes", "map-pin")
TpBox:AddButton({ Text="TP para Lobby",     Func=tpToLobby })
TpBox:AddButton({ Text="TP para Mapa",      Func=tpToMap })
TpBox:AddButton({ Text="TP para Assassino", Func=tpToMurderer })
TpBox:AddButton({ Text="TP para Xerife",    Func=tpToSherrif })
TpBox:AddInput("TpPlayerInput", { Text="Nome do Jogador", Default="", Callback=function(v) _G.TpTarget=v end })
TpBox:AddButton({ Text="TP para Jogador", Func=function()
    if _G.TpTarget and _G.TpTarget~="" then tpToPlayer(_G.TpTarget)
    else Library:Notify({Title="Erro",Description="Digite um nome primeiro!",Time=2}) end
end })
TpBox:AddButton({ Text="Rejoin", Func=rejoin })

-- misc tab
local MiscLeft  = MiscTab:AddLeftGroupbox("Misc", "cog")
local MiscRight = MiscTab:AddRightGroupbox("Jogadores", "users")
local HitboxBox = featureAllowed("hitbox") and MiscTab:AddRightGroupbox("Hitbox", "maximize") or nil

MiscLeft:AddButton({ Text="Pegar Arma (Manual)", Func=gunGrabber })

if featureAllowed("autoGun") then
    MiscLeft:AddToggle("AutoGunGrabber", { Text="Auto Pegar Arma", Default=false, Callback=function(v)
        if v then autoGun=true; iniciarAutoGun(); Library:Notify({Title="Auto Gun",Description="Ativado!",Time=2})
        else autoGun=false; Library:Notify({Title="Auto Gun",Description="Desativado!",Time=1}) end
    end })
end

MiscLeft:AddToggle("KillAuraToggle", { Text="Kill Aura (Murderer)", Default=false, Callback=function(v)
    if v then ativarKillAura() else desativarKillAura() end
    Library:Notify({Title="Kill Aura",Description=v and "Ativado!" or "Desativado!",Time=1})
end })

MiscLeft:AddToggle("AntiFling", { Text="Anti Fling", Default=false, Callback=function(v)
    if v then ativarAntiFling() else desativarAntiFling() end
    Library:Notify({Title="Anti Fling",Description=v and "Ativado!" or "Desativado!",Time=1})
end })

MiscLeft:AddButton({ Text="Recarregar Roles", Func=function() carregarRoles(); Library:Notify({Title="Roles",Description="Recarregadas!",Time=2}) end })

-- tabela de jogadores
local playerTableLabel = MiscRight:AddLabel("carregando...")
MiscRight:AddButton({ Text="Atualizar", Func=function()
    playerTableLabel:SetText(getPlayerTable())
end })
-- auto refresh da tabela a cada 3s
task.spawn(function()
    while getgenv().VynixuMM2_Running do
        task.wait(3)
        pcall(function() playerTableLabel:SetText(getPlayerTable()) end)
    end
end)

if HitboxBox then
    HitboxBox:AddToggle("HitboxToggle", { Text="Hitbox Expander", Default=false, Callback=function(v)
        hitboxAtivo=v; if not v then removerHitbox() end
        Library:Notify({Title="Hitbox",Description=v and "Ativado!" or "Desativado!",Time=1})
    end })
    HitboxBox:AddToggle("HitboxBrutal", { Text="Brutal (tudo)", Default=false, Callback=function(v)
        hitboxBrutal=v; if hitboxAtivo then removerHitbox(); aplicarHitbox() end
    end })
    HitboxBox:AddSlider("HitboxSize", { Text="Tamanho", Default=10, Min=2, Max=50, Rounding=0, Callback=function(v)
        hitboxSize=v; if hitboxAtivo then removerHitbox(); aplicarHitbox() end
    end })
    HitboxBox:AddButton({ Text="Ver Hitbox (2s)", Func=verHitbox })
end

-- admin panel
if isAdmin and AdminTab then
    local AdminLeft  = AdminTab:AddLeftGroupbox("Usuarios Online", "users")
    local AdminRight = AdminTab:AddRightGroupbox("Acoes", "shield")
    local AdminGames = isCoOwner and AdminTab:AddRightGroupbox("Blacklist Jogos", "slash") or nil

    local function refreshUsers()
        local raw = dbGet("users")
        if not raw or raw == "null" then return end
        local ok, users = pcall(function() return HS:JSONDecode(raw) end)
        if not ok then return end
        local list = {}
        for name, data in pairs(users) do
            if type(data) == "table" and data.online then
                table.insert(list, name .. " | " .. (data.role or "?") .. " | " .. (data.placeId or "?"))
            end
        end
        return list
    end

    local userListLabel = AdminLeft:AddLabel("carregando...")
    AdminLeft:AddButton({ Text="Atualizar Lista", Func=function()
        local users = refreshUsers()
        if users and #users > 0 then
            userListLabel:SetText(table.concat(users, "\n"))
        else
            userListLabel:SetText("nenhum usuario online")
        end
    end })

    local targetInput = ""
    AdminRight:AddInput("AdminTarget", { Text="Nome do Alvo", Default="", Callback=function(v) targetInput=v end })

    if canBan then
        AdminRight:AddButton({ Text="Banir do Script", Func=function()
            if targetInput == "" then return end
            dbSet("banned/" .. targetInput, "true")
            Library:Notify({Title="Admin",Description=targetInput.." banido!",Time=3})
        end })
        AdminRight:AddButton({ Text="Desbanir", Func=function()
            if targetInput == "" then return end
            dbSet("banned/" .. targetInput, "false")
            Library:Notify({Title="Admin",Description=targetInput.." desbanido!",Time=3})
        end })
    end

    local kickMsgInput = ""
    AdminRight:AddInput("KickMsg", { Text="Mensagem de Kick", Default="voce foi kickado pelo admin", Callback=function(v) kickMsgInput=v end })
    AdminRight:AddButton({ Text="Kickar do Servidor", Func=function()
        if targetInput == "" then return end
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr.Name == targetInput then
                pcall(function() plr:Kick(kickMsgInput ~= "" and kickMsgInput or "voce foi kickado pelo admin") end)
                Library:Notify({Title="Admin",Description="kick enviado para "..targetInput,Time=3})
                return
            end
        end
        Library:Notify({Title="Admin",Description=targetInput.." nao esta neste servidor",Time=2})
    end })

    if canDisableFeat then
        local featureInput = ""
        AdminRight:AddInput("FeatureInput", { Text="Feature (fly/esp/hitbox...)", Default="", Callback=function(v) featureInput=v end })
        AdminRight:AddButton({ Text="Desabilitar Feature (Global)", Func=function()
            if featureInput == "" then return end
            -- atualiza no firebase
            local raw = dbGet("disabledFeatures")
            local data = {}
            if raw and raw ~= "null" then pcall(function() data = HS:JSONDecode(raw) end) end
            data[featureInput] = true
            dbSet("disabledFeatures", HS:JSONEncode(data))
            Library:Notify({Title="Admin",Description=featureInput.." desabilitado globalmente!",Time=3})
        end })
        AdminRight:AddButton({ Text="Reabilitar Feature (Global)", Func=function()
            if featureInput == "" then return end
            local raw = dbGet("disabledFeatures")
            local data = {}
            if raw and raw ~= "null" then pcall(function() data = HS:JSONDecode(raw) end) end
            data[featureInput] = false
            dbSet("disabledFeatures", HS:JSONEncode(data))
            Library:Notify({Title="Admin",Description=featureInput.." reabilitado!",Time=3})
        end })
    end

    if canSetDelay then
        local delayInput = 0.2
        AdminRight:AddInput("DelayInput", { Text="Delay Arma (segundos)", Default="0.2", Callback=function(v) delayInput=tonumber(v) or 0.2 end })
        AdminRight:AddButton({ Text="Setar Delay Arma", Func=function()
            if targetInput=="" then return end
            local raw = dbGet("userSettings/"..targetInput)
            local settings = {}
            if raw and raw~="null" then pcall(function() settings=HS:JSONDecode(raw) end) end
            settings.gunDelay = delayInput
            dbSet("userSettings/"..targetInput, HS:JSONEncode(settings))
            Library:Notify({Title="Admin",Description="delay setado para "..targetInput,Time=3})
        end })
    end

    -- adicionar admin (co-owner+ pode adicionar admins)
    if isCoOwner then
        local newAdminInput, newAdminRole = "", "admin"
        AdminRight:AddInput("NewAdminInput", { Text="Novo Admin (nome)", Default="", Callback=function(v) newAdminInput=v end })
        AdminRight:AddDropdown("NewAdminRole", {
            Values = isOwner and {"admin","co-owner","owner"} or {"admin"},
            Default = "admin",
            Text = "Role",
            Callback = function(v) newAdminRole=v end
        })
        AdminRight:AddButton({ Text="Adicionar Admin", Func=function()
            if newAdminInput == "" then return end
            local adminEntry = HS:JSONEncode({ boolean=true, role=newAdminRole, authmethod="name" })
            dbSet("admins/" .. newAdminInput, adminEntry)
            Library:Notify({Title="Admin",Description=newAdminInput.." adicionado como "..newAdminRole,Time=3})
        end })
        AdminRight:AddButton({ Text="Remover Admin", Func=function()
            if newAdminInput == "" then return end
            dbSet("admins/" .. newAdminInput, HS:JSONEncode({ boolean=false, role="none", authmethod="name" }))
            Library:Notify({Title="Admin",Description=newAdminInput.." removido",Time=3})
        end })
    end

    if canBlacklist and AdminGames then
        local gameIdInput, gameMsgInput = "", ""
        AdminGames:AddInput("GameIdInput", { Text="Place ID", Default="", Callback=function(v) gameIdInput=v end })
        AdminGames:AddInput("GameMsgInput", { Text="Mensagem", Default="jogo bloqueado", Callback=function(v) gameMsgInput=v end })
        AdminGames:AddButton({ Text="Adicionar na Blacklist", Func=function()
            if gameIdInput=="" then return end
            dbSet("blacklistedGames/"..gameIdInput, '"'..(gameMsgInput~="" and gameMsgInput or "jogo bloqueado")..'"')
            Library:Notify({Title="Admin",Description="jogo "..gameIdInput.." bloqueado!",Time=3})
        end })
        AdminGames:AddButton({ Text="Remover da Blacklist", Func=function()
            if gameIdInput=="" then return end
            dbSet("blacklistedGames/"..gameIdInput, "null")
            Library:Notify({Title="Admin",Description="jogo "..gameIdInput.." desbloqueado!",Time=3})
        end })
    end

    -- jump go brr (owner/co-owner only)
    if isCoOwner then
        local jumpBrrAtivo = false
        local jumpBrrWS = 100
        AdminRight:AddToggle("JumpGoBrr", { Text="Jump Go Brr", Default=false, Callback=function(v)
            jumpBrrAtivo = v
            if v then
                task.spawn(function()
                    while jumpBrrAtivo do
                        task.wait(0.05)
                        local c = Player.Character
                        local hum = c and c:FindFirstChildWhichIsA("Humanoid")
                        if hum then
                            if hum.Jump or hum.FloorMaterial == Enum.Material.Air then
                                hum.WalkSpeed = jumpBrrWS
                            else
                                hum.WalkSpeed = 16
                            end
                        end
                    end
                    local c = Player.Character
                    local hum = c and c:FindFirstChildWhichIsA("Humanoid")
                    if hum then hum.WalkSpeed = 16 end
                end)
            end
        end })
        AdminRight:AddSlider("JumpBrrSpeed", { Text="Speed no Ar", Default=100, Min=20, Max=500, Rounding=0, Callback=function(v) jumpBrrWS=v end })
    end
end

-- config tab (sem duplicata)
SaveManager:BuildConfigSection(ConfigTab)
local MenuGroup = ConfigTab:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Abrir Menu de Keybinds",
    Callback = function(v) Library.KeybindFrame.Visible = v end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Cursor Customizado",
    Default = true,
    Callback = function(v) Library.ShowCustomCursor = v end,
})

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Lado das Notificações",
    Callback = function(v) Library:SetNotifySide(v) end,
})

MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(v)
        v = v:gsub("%%", "")
        Library:SetDPIScale(tonumber(v))
    end,
})

MenuGroup:AddSlider("UICornerSlider", {
    Text = "Corner Radius",
    Default = Library.CornerRadius,
    Min = 0, Max = 20, Rounding = 0,
    Callback = function(v) Window:SetCornerRadius(v) end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Tecla do Menu"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Tecla do Menu" })
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton({ Text = "Descarregar Script", Func = function() Library:Unload() end })

SaveManager:LoadAutoloadConfig()

task.wait(0.5)
Library:Notify({ Title="Vynixu MM2", Description="v" .. VERSAO .. " | Pronto!", Time=4 })