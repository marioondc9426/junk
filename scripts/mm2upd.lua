-- vynixu mm2 - obsidian edition v4.0

-- 1 instância por vez: fecha a antiga
if getgenv().VynixuMM2_Destroy then pcall(getgenv().VynixuMM2_Destroy) end
getgenv().VynixuMM2_Running = true
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/SaveManager.lua"))()
local Options, Toggles = Library.Options, Library.Toggles

getgenv().VynixuMM2_Destroy = function()
    pcall(function() Library:Destroy() end)
    getgenv().VynixuMM2_Running = false
end

-- loading
local Loading = Library:CreateLoading({
    Title = "Vynixu MM2 Script",
    Icon = 95816097006870,
    TotalSteps = 8,
    ShowSidebar = true,
})

Loading.Sidebar:AddLabel("v4.0 changelogs:")
Loading.Sidebar:AddLabel("+ highlight sem piscar")
Loading.Sidebar:AddLabel("+ fly nao trava mais")
Loading.Sidebar:AddLabel("+ distancia no renderstep")
Loading.Sidebar:AddLabel("+ hitbox expander + brutal")
Loading.Sidebar:AddLabel("+ view hitbox")
Loading.Sidebar:AddLabel("+ fling com arco aleatorio")
Loading.Sidebar:AddLabel("+ 1 instancia por vez")
Loading.Sidebar:AddLabel("usuario: " .. game.Players.LocalPlayer.Name)

local steps = {
    "verificando instancias...",
    "carregando biblioteca...",
    "carregando roles...",
    "carregando esp...",
    "carregando movimento...",
    "carregando hitbox e fling...",
    "carregando ui...",
    "finalizando...",
}
Loading:SetMessage("inicializando...")
for i, desc in ipairs(steps) do
    Loading:SetCurrentStep(i)
    Loading:SetDescription(desc)
    task.wait(0.4)
end
Loading:Continue()

-- window
local Window = Library:CreateWindow({
    Title = "Vynixu MM2 Script",
    SubTitle = "Obsidian Edition",
    Theme = "Dark",
    Size = UDim2.new(0, 580, 0, 500),
    Animations = { ToggleWindow = true, TabSwitch = true, Groupbox = true, Dropdown = true, KeyPicker = true },
})
Window:SetFooter("Obsidian Edition v4.0")

local EspTab      = Window:AddTab("ESP", "eye")
local MovementTab = Window:AddTab("Movimento", "zap")
local TeleportTab = Window:AddTab("Teleporte", "map-pin")
local MiscTab     = Window:AddTab("Misc", "cog")
local ConfigTab   = Window:AddTab("Config", "settings")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("VynixuMM2Script/Configs")
SaveManager:BuildConfigSection(ConfigTab)
SaveManager:LoadAutoloadConfig()

-- vars
local Player = game.Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local RS  = game:GetService("RunService")

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

-- roles via GetPlayerData (método do yarhm, server-side)
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

local function hasTool(plr, name) -- fallback se GetPlayerData falhar
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

-- esp (1 highlight por char, atualiza sem recriar = sem piscar)
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

-- rainbow outline no renderstep
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

local function ativarMurdererESP()  espStates.Murderer = true;  espLoop("Murderer", isMurderer, function() return Settings.MurdererColor end) end
local function desativarMurdererESP() espStates.Murderer = false end
local function ativarSherrifESP()   espStates.Sherrif  = true;  espLoop("Sherrif",  isSherrif,  function() return Settings.SherrifColor end) end
local function desativarSherrifESP()  espStates.Sherrif  = false end

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

-- distância no renderstep = alta taxa de atualização
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

-- fly (wasd + q/e)
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
            hum:ChangeState(Enum.HumanoidStateType.GettingUp) -- desbloqueia o char
        end
        pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
    end
    Library:Notify({ Title="Voo", Description="Desativado!", Time=1 })
end
local function toggleFly() if flying then stopFly() else startFly() end end

-- noclip
RS.Stepped:Connect(function()
    if noclip and Player.Character then
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

-- gun grabber
local function findGunDrop()
    for _,obj in pairs(workspace:GetDescendants()) do
        if obj.Name=="GunDrop" then local p=obj.Parent; if p and not p:FindFirstChild("Humanoid") then return obj end end
    end
end
local function gunGrabber()
    local c=Player.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local gun=findGunDrop()
    if gun then local pos=hrp.CFrame; hrp.CFrame=gun.CFrame; task.wait(); hrp.CFrame=pos; Library:Notify({Title="Gun Grabber",Description="Arma pega!",Time=2})
    else Library:Notify({Title="Gun Grabber",Description="Nenhuma arma no chão!",Time=2}) end
end
local function iniciarAutoGun()
    autoGun=true
    task.spawn(function()
        while autoGun do
            task.wait(0.5)
            local c=Player.Character; local hrp=c and c:FindFirstChild("HumanoidRootPart")
            if hrp then local gun=findGunDrop(); if gun then local pos=hrp.CFrame; hrp.CFrame=gun.CFrame; task.wait(); hrp.CFrame=pos; Library:Notify({Title="Auto Gun",Description="Arma pega!",Time=1}) end end
        end
    end)
end

-- hitbox expander
local hitboxAtivo, hitboxBrutal, hitboxSize = false, false, 10
local hitboxOriginais, hitboxHighlights = {}, {}

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
                part.Size=Vector3.new(hitboxSize,hitboxSize,hitboxSize)
            end
        end
    end
end
local function removerHitbox()
    for _,parts in pairs(hitboxOriginais) do
        for part,size in pairs(parts) do pcall(function() part.Size=size end) end
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

-- fling com arco aleatório
local flingAtivo, flingConn = false, nil

local function ativarFling()
    flingAtivo=true
    Library:Notify({Title="Fling",Description="Clique em um ponto!",Time=3})
    flingConn=UIS.InputBegan:Connect(function(input,gp)
        if gp or not flingAtivo then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local char=Player.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum then return end
        local ray=workspace.CurrentCamera:ScreenPointToRay(input.Position.X,input.Position.Y)
        local params=RaycastParams.new()
        params.FilterDescendantsInstances={char}; params.FilterType=Enum.RaycastFilterType.Exclude
        local result=workspace:Raycast(ray.Origin,ray.Direction*5000,params)
        if not result then return end
        local target=result.Position
        local dir=(target-hrp.Position); local dist=dir.Magnitude; if dist<1 then return end
        -- arco: speed, altura e desvio lateral todos aleatorios
        local speed=math.random(60,120)
        local arc=math.random(15,50)
        local lateral=math.random(-20,20)
        local spin=math.random(-200,200)
        local du=dir.Unit
        local lv=Vector3.new(-du.Z,0,du.X).Unit
        hum.PlatformStand=true
        local bv=Instance.new("BodyVelocity",hrp)
        bv.MaxForce=Vector3.new(9e9,9e9,9e9)
        bv.Velocity=du*speed+Vector3.new(0,arc,0)+lv*lateral
        local ba=Instance.new("BodyAngularVelocity",hrp)
        ba.MaxTorque=Vector3.new(9e9,9e9,9e9)
        ba.AngularVelocity=Vector3.new(math.random(-spin,spin)*0.05,math.random(-spin,spin)*0.05,math.random(-spin,spin)*0.05)
        task.spawn(function()
            local t0=tick(); local maxT=math.clamp(dist/speed*1.5,0.5,4)
            while tick()-t0<maxT do
                task.wait(0.05)
                local v=bv.Velocity
                bv.Velocity=Vector3.new(v.X*0.98,v.Y-2,v.Z*0.98)
                if (hrp.Position-target).Magnitude<6 then break end
            end
            bv:Destroy(); ba:Destroy()
            hum.PlatformStand=false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end)
end
local function desativarFling()
    flingAtivo=false; if flingConn then flingConn:Disconnect(); flingConn=nil end
end

-- ui esp
local EspLeft    = EspTab:AddLeftGroupbox("Controles ESP", "eye")
local EspRight   = EspTab:AddRightGroupbox("Cores ESP", "palette")
local OutlineBox = EspTab:AddRightGroupbox("Borda", "square")

EspLeft:AddToggle("MurdererESP", { Text="ESP Assassino", Default=false, Callback=function(v) if v then ativarMurdererESP() else desativarMurdererESP() end end })
EspLeft:AddToggle("SherrifESP",  { Text="ESP Xerife",    Default=false, Callback=function(v) if v then ativarSherrifESP()  else desativarSherrifESP()  end end })
EspLeft:AddToggle("InnocentESP", { Text="ESP Inocentes", Default=false, Callback=function(v) if v then ativarInnocentESP() else desativarInnocentESP() end end })
EspLeft:AddToggle("GunESP",      { Text="ESP Arma",      Default=false, Callback=function(v) if v then ativarGunESP()      else desativarGunESP()      end end })
EspLeft:AddToggle("NamesESP",    { Text="Nomes ESP",      Default=false, Callback=function(v) if v then ativarNamesESP()    else desativarNamesESP()    end end })
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

-- ui movimento
local MovBox = MovementTab:AddLeftGroupbox("Movimento", "zap")
local FlyToggle = MovBox:AddToggle("FlyToggle", { Text="Voar", Default=false, Callback=function(v) if v then startFly() else stopFly() end end })
FlyToggle:AddKeyPicker("FlyKeybind", { Text="Tecla Voar", Default="L", Mode="Toggle", SyncToggleState=true, Callback=function() toggleFly() end })
MovBox:AddInput("FlySpeedInput", { Text="Velocidade de Voo", Default="50", Callback=function(v) flySpeed=tonumber(v) or 50 end })
local NoclipToggle = MovBox:AddToggle("NoclipToggle", { Text="Noclip", Default=false, Callback=function(v) noclip=v; Library:Notify({Title="Noclip",Description=v and "Ativado!" or "Desativado!",Time=1}) end })
NoclipToggle:AddKeyPicker("NoclipKeybind", { Text="Tecla Noclip", Default="B", Mode="Toggle", SyncToggleState=true, Callback=function() noclip=not noclip end })
MovBox:AddInput("WalkSpeedInput", { Text="Velocidade", Default="16", Callback=function(v) setWalkSpeed(v) end })
MovBox:AddButton({ Text="Resetar Velocidade", Func=resetWalkSpeed })
MovBox:AddInput("JumpPowerInput", { Text="Força de Pulo", Default="50", Callback=function(v) setJumpPower(v) end })
MovBox:AddButton({ Text="Resetar Pulo", Func=resetJumpPower })

-- ui teleporte
local TpBox = TeleportTab:AddLeftGroupbox("Teleportes", "map-pin")
TpBox:AddButton({ Text="TP para Lobby",    Func=tpToLobby })
TpBox:AddButton({ Text="TP para Mapa",     Func=tpToMap })
TpBox:AddButton({ Text="TP para Assassino", Func=tpToMurderer })
TpBox:AddButton({ Text="TP para Xerife",   Func=tpToSherrif })
TpBox:AddInput("TpPlayerInput", { Text="Nome do Jogador", Default="", Callback=function(v) _G.TpTarget=v end })
TpBox:AddButton({ Text="TP para Jogador", Func=function()
    if _G.TpTarget and _G.TpTarget~="" then tpToPlayer(_G.TpTarget)
    else Library:Notify({Title="Erro",Description="Digite um nome primeiro!",Time=2}) end
end })

-- ui misc
local MiscBox    = MiscTab:AddLeftGroupbox("Misc", "cog")
local HitboxBox  = MiscTab:AddRightGroupbox("Hitbox", "maximize")
local FlingBox   = MiscTab:AddRightGroupbox("Fling", "send")

MiscBox:AddButton({ Text="Pegar Arma (Manual)", Func=gunGrabber })
MiscBox:AddToggle("AutoGunGrabber", { Text="Auto Pegar Arma", Default=false, Callback=function(v)
    if v then autoGun=true; iniciarAutoGun(); Library:Notify({Title="Auto Gun",Description="Ativado!",Time=2})
    else autoGun=false; Library:Notify({Title="Auto Gun",Description="Desativado!",Time=1}) end
end })
MiscBox:AddButton({ Text="Recarregar Roles", Func=function() carregarRoles(); Library:Notify({Title="Roles",Description="Recarregadas!",Time=2}) end })

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

FlingBox:AddToggle("FlingToggle", { Text="Fling (clique no chão)", Default=false, Callback=function(v)
    if v then ativarFling() else desativarFling() end
end })

-- init
task.wait(0.5)
Library:Notify({ Title="Vynixu MM2", Description="Pronto! Ative os ESPs na aba ESP.", Time=4 })