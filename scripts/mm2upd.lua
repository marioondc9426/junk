-- ////////////////////////////////////////////////////////////
--  VYNIXU'S MM2 SCRIPT - OBSIDIAN EDITION
--  COM AUTO GUN GRABBER
-- ////////////////////////////////////////////////////////////

-- CARREGAR OBSIDIAN
local Obsidian = loadstring(game:HttpGet("https://raw.githubusercontent.com/mspaint-obsidian/obsidian/main/source.lua"))()

-- ////////////////////////////////////////////////////////////
--  CRIAÇÃO DA UI
-- ////////////////////////////////////////////////////////////

local Window = Obsidian:CreateWindow({
    Title = "Vynixu's MM2 Script",
    SubTitle = "Obsidian Edition",
    Theme = "Dark",
    Size = UDim2.new(0, 580, 0, 500),
})

-- ABAS
local EspTab = Window:AddTab({ Title = "ESP", Icon = "eye" })
local MovementTab = Window:AddTab({ Title = "Movement", Icon = "run" })
local TeleportTab = Window:AddTab({ Title = "Teleport", Icon = "map-marker" })
local MiscTab = Window:AddTab({ Title = "Misc", Icon = "cog" })

-- ////////////////////////////////////////////////////////////
--  VARIÁVEIS GLOBAIS
-- ////////////////////////////////////////////////////////////

local Player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Tracers = {}
local Highlights = {}
local Outlines = {}
local flying = false
local noclip = false
local autoGun = false

-- ESTADOS DOS ESPs (TODOS ATIVADOS POR PADRÃO)
local espStates = {
    Murderer = true,
    Sherrif = true,
    Innocent = true,
    Gun = true,
    Names = true,
}

-- CONFIGS
local Settings = {
    EspColor = Color3.fromRGB(255, 0, 0),
    EspTransparency = 0.4,
    EspRainbow = false,
    OutlineEnabled = true,
    OutlineColor = Color3.fromRGB(0, 0, 0),
    OutlineRainbow = false,
    OutlineTransparency = 0,
}

-- ////////////////////////////////////////////////////////////
--  FUNÇÕES AUXILIARES
-- ////////////////////////////////////////////////////////////

local function isMurderer(plr)
    if not plr then return false end
    for _, item in pairs(plr:GetChildren()) do
        if item.Name == "Backpack" then
            for _, tool in pairs(item:GetChildren()) do
                if tool.Name == "Knife" then return true end
            end
        end
    end
    if plr.Character then
        for _, tool in pairs(plr.Character:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Knife" then return true end
        end
    end
    return false
end

local function isSherrif(plr)
    if not plr then return false end
    for _, item in pairs(plr:GetChildren()) do
        if item.Name == "Backpack" then
            for _, tool in pairs(item:GetChildren()) do
                if tool.Name == "Gun" then return true end
            end
        end
    end
    if plr.Character then
        for _, tool in pairs(plr.Character:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Gun" then return true end
        end
    end
    return false
end

local function isInnocent(plr)
    if not plr or plr == Player then return false end
    if isMurderer(plr) or isSherrif(plr) then return false end
    return true
end

local function removerHighlight(tipo, alvo)
    if not alvo then return end
    if Highlights[tipo] and Highlights[tipo][alvo] then
        Highlights[tipo][alvo]:Destroy()
        Highlights[tipo][alvo] = nil
    end
    if Outlines[tipo] and Outlines[tipo][alvo] then
        Outlines[tipo][alvo]:Destroy()
        Outlines[tipo][alvo] = nil
    end
end

local function criarHighlight(tipo, alvo, cor, transparencia)
    if not alvo or not alvo.Parent then return end
    
    removerHighlight(tipo, alvo)
    
    local highlight = Instance.new("Highlight")
    highlight.Name = tipo .. "Highlight"
    highlight.Parent = alvo
    highlight.FillColor = cor
    highlight.FillTransparency = transparencia or 0.4
    highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    if not Highlights[tipo] then Highlights[tipo] = {} end
    Highlights[tipo][alvo] = highlight
    
    if Settings.OutlineEnabled then
        local outline = Instance.new("Highlight")
        outline.Name = tipo .. "Outline"
        outline.Parent = alvo
        outline.FillColor = Color3.fromRGB(0, 0, 0)
        outline.FillTransparency = 1
        outline.OutlineColor = Settings.OutlineColor
        outline.OutlineTransparency = Settings.OutlineTransparency
        outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        
        if not Outlines[tipo] then Outlines[tipo] = {} end
        Outlines[tipo][alvo] = outline
    end
end

-- ////////////////////////////////////////////////////////////
--  1. MURDERER ESP
-- ////////////////////////////////////////////////////////////

local function ativarMurdererESP()
    espStates.Murderer = true
    task.spawn(function()
        while espStates.Murderer do
            task.wait(0.1)
            if not Player.Character then task.wait(0.5) continue end
            
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player or not plr.Character then continue end
                if isMurderer(plr) then
                    criarHighlight("Murderer", plr.Character, Color3.fromRGB(255, 0, 25))
                else
                    removerHighlight("Murderer", plr.Character)
                end
            end
        end
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr.Character then removerHighlight("Murderer", plr.Character) end
        end
    end)
end

local function desativarMurdererESP()
    espStates.Murderer = false
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr.Character then removerHighlight("Murderer", plr.Character) end
    end
end

-- ////////////////////////////////////////////////////////////
--  2. SHERRIF ESP
-- ////////////////////////////////////////////////////////////

local function ativarSherrifESP()
    espStates.Sherrif = true
    task.spawn(function()
        while espStates.Sherrif do
            task.wait(0.1)
            if not Player.Character then task.wait(0.5) continue end
            
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player or not plr.Character then continue end
                if isSherrif(plr) then
                    criarHighlight("Sherrif", plr.Character, Color3.fromRGB(0, 50, 255))
                else
                    removerHighlight("Sherrif", plr.Character)
                end
            end
        end
        for _, plr in pairs(game.Players:GetPlayers()) do
            if plr.Character then removerHighlight("Sherrif", plr.Character) end
        end
    end)
end

local function desativarSherrifESP()
    espStates.Sherrif = false
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr.Character then removerHighlight("Sherrif", plr.Character) end
    end
end

-- ////////////////////////////////////////////////////////////
--  3. INNOCENT ESP
-- ////////////////////////////////////////////////////////////

local function ativarInnocentESP()
    espStates.Innocent = true
    task.spawn(function()
        while espStates.Innocent do
            task.wait(0.5)
            if not Player.Character then task.wait(1) continue end
            
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player or not plr.Character then continue end
                
                local temPrioridade = false
                if Highlights["Murderer"] and Highlights["Murderer"][plr.Character] then
                    temPrioridade = true
                end
                if Highlights["Sherrif"] and Highlights["Sherrif"][plr.Character] then
                    temPrioridade = true
                end
                
                if isInnocent(plr) and not temPrioridade then
                    criarHighlight("Innocent", plr.Character, Color3.fromRGB(0, 255, 50), 0.4)
                else
                    removerHighlight("Innocent", plr.Character)
                end
            end
        end
    end)
end

local function desativarInnocentESP()
    espStates.Innocent = false
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr.Character then removerHighlight("Innocent", plr.Character) end
    end
end

-- ////////////////////////////////////////////////////////////
--  4. GUN ESP
-- ////////////////////////////////////////////////////////////

local function ativarGunESP()
    espStates.Gun = true
    task.spawn(function()
        local gunHighlights = {}
        while espStates.Gun do
            task.wait(0.5)
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj.Name == "GunDrop" then
                    local parent = obj.Parent
                    if parent and not parent:FindFirstChild("Humanoid") then
                        if not gunHighlights[obj] then
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "GunHighlight"
                            highlight.Parent = obj
                            highlight.FillColor = Color3.fromRGB(0, 255, 50)
                            highlight.FillTransparency = 0.4
                            highlight.OutlineColor = Color3.fromRGB(0, 0, 0)
                            highlight.OutlineTransparency = 0
                            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            gunHighlights[obj] = highlight
                        end
                    end
                end
            end
        end
        for _, highlight in pairs(gunHighlights) do
            highlight:Destroy()
        end
    end)
end

local function desativarGunESP()
    espStates.Gun = false
end

-- ////////////////////////////////////////////////////////////
--  5. NAMES ESP
-- ////////////////////////////////////////////////////////////

local function ativarNamesESP()
    espStates.Names = true
    local names = {}
    
    local function criarNome(plr)
        if not plr or not plr.Character then return end
        local head = plr.Character:FindFirstChild("Head")
        if not head then return end
        
        if names[plr] then names[plr]:Destroy() end
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "NameESP"
        billboard.Parent = head
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 150, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.MaxDistance = 5000
        billboard.ClipsDescendants = false
        
        local nome = Instance.new("TextLabel")
        nome.Name = "Nome"
        nome.Parent = billboard
        nome.BackgroundTransparency = 1
        nome.Size = UDim2.new(1, 0, 0.6, 0)
        nome.Font = Enum.Font.GothamBold
        nome.Text = plr.Name
        nome.TextColor3 = Color3.fromRGB(255, 255, 255)
        nome.TextSize = 14
        nome.TextStrokeTransparency = 0
        nome.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        nome.TextScaled = false
        
        local distancia = Instance.new("TextLabel")
        distancia.Name = "Distancia"
        distancia.Parent = billboard
        distancia.BackgroundTransparency = 1
        distancia.Size = UDim2.new(1, 0, 0.4, 0)
        distancia.Position = UDim2.new(0, 0, 0.6, 0)
        distancia.Font = Enum.Font.Gotham
        distancia.Text = "0m"
        distancia.TextColor3 = Color3.fromRGB(200, 200, 200)
        distancia.TextSize = 12
        distancia.TextStrokeTransparency = 0
        distancia.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        
        names[plr] = billboard
    end
    
    local function removerNome(plr)
        if names[plr] then names[plr]:Destroy(); names[plr] = nil end
    end
    
    task.spawn(function()
        while espStates.Names do
            task.wait(10)
            for _, plr in pairs(game.Players:GetPlayers()) do
                if plr == Player then
                    removerNome(plr)
                    continue
                end
                if plr.Character and plr.Character:FindFirstChild("Head") then
                    if not names[plr] then criarNome(plr) end
                    
                    local distLabel = names[plr] and names[plr]:FindFirstChild("Distancia")
                    if distLabel and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (Player.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                        distLabel.Text = math.floor(dist) .. "m"
                    end
                    
                    local nomeLabel = names[plr] and names[plr]:FindFirstChild("Nome")
                    if nomeLabel then
                        if isMurderer(plr) then
                            nomeLabel.TextColor3 = Color3.fromRGB(255, 0, 25)
                        elseif isSherrif(plr) then
                            nomeLabel.TextColor3 = Color3.fromRGB(0, 50, 255)
                        else
                            nomeLabel.TextColor3 = Color3.fromRGB(0, 255, 50)
                        end
                    end
                else
                    removerNome(plr)
                end
            end
        end
        for _, plr in pairs(game.Players:GetPlayers()) do
            removerNome(plr)
        end
    end)
end

local function desativarNamesESP()
    espStates.Names = false
end

-- ////////////////////////////////////////////////////////////
--  6. GUN GRABBER (MANUAL)
-- ////////////////////////////////////////////////////////////

local function gunGrabber()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local currentPos = hrp.CFrame
    local gunDrop = nil
    
    local mapas = {
        "Bank2", "BioLab", "Factory", "Hospital3", "Hotel",
        "House2", "Mansion2", "MilBase", "Office3", "PoliceStation",
        "ResearchFacility", "Workplace"
    }
    
    for _, nome in pairs(mapas) do
        local mapa = workspace:FindFirstChild(nome)
        if mapa then
            gunDrop = mapa:FindFirstChild("GunDrop")
            if gunDrop then break end
        end
    end
    
    if not gunDrop then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == "GunDrop" then
                local parent = obj.Parent
                if parent and not parent:FindFirstChild("Humanoid") then
                    gunDrop = obj
                    break
                end
            end
        end
    end
    
    if gunDrop then
        hrp.CFrame = gunDrop.CFrame
        task.wait()
        hrp.CFrame = currentPos
        Obsidian:Notify({
            Title = "🔫 Gun Grabber",
            Content = "Arma pegada com sucesso!",
            Duration = 2,
        })
    else
        Obsidian:Notify({
            Title = "❌ Gun Grabber",
            Content = "Nenhuma arma no chão!",
            Duration = 2,
        })
    end
end

-- ////////////////////////////////////////////////////////////
--  7. AUTO GUN GRABBER (NOVO!)
-- ////////////////////////////////////////////////////////////

local function autoGunGrabber()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local currentPos = hrp.CFrame
    local gunDrop = nil
    
    local mapas = {
        "Bank2", "BioLab", "Factory", "Hospital3", "Hotel",
        "House2", "Mansion2", "MilBase", "Office3", "PoliceStation",
        "ResearchFacility", "Workplace"
    }
    
    for _, nome in pairs(mapas) do
        local mapa = workspace:FindFirstChild(nome)
        if mapa then
            gunDrop = mapa:FindFirstChild("GunDrop")
            if gunDrop then break end
        end
    end
    
    if not gunDrop then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj.Name == "GunDrop" then
                local parent = obj.Parent
                if parent and not parent:FindFirstChild("Humanoid") then
                    gunDrop = obj
                    break
                end
            end
        end
    end
    
    if gunDrop then
        hrp.CFrame = gunDrop.CFrame
        task.wait()
        hrp.CFrame = currentPos
        return true
    end
    return false
end

-- LOOP DO AUTO GUN GRABBER
local function iniciarAutoGun()
    autoGun = true
    task.spawn(function()
        while autoGun do
            task.wait(0.5)
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                local success = autoGunGrabber()
                if success then
                    Obsidian:Notify({
                        Title = "🤖 Auto Gun",
                        Content = "Arma pegada automaticamente!",
                        Duration = 1,
                    })
                end
            end
        end
    end)
end

-- ////////////////////////////////////////////////////////////
--  8. FLY
-- ////////////////////////////////////////////////////////////

local function toggleFly()
    flying = not flying
    
    if flying then
        Obsidian:Notify({
            Title = "✈️ Fly",
            Content = "Ativado! (WASD + Espaço)",
            Duration = 2,
        })
        
        local char = Player.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local bg = Instance.new("BodyGyro", hrp)
        bg.P = 9e4
        bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.cframe = hrp.CFrame
        
        local bv = Instance.new("BodyVelocity", hrp)
        bv.velocity = Vector3.new(0, 0.1, 0)
        bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
        
        hrp._flyGyro = bg
        hrp._flyVelocity = bv
        
        task.spawn(function()
            local keys = {W = false, A = false, S = false, D = false, Space = false}
            
            local function onKeyDown(key)
                if key == "w" then keys.W = true end
                if key == "a" then keys.A = true end
                if key == "s" then keys.S = true end
                if key == "d" then keys.D = true end
                if key == " " then keys.Space = true end
            end
            
            local function onKeyUp(key)
                if key == "w" then keys.W = false end
                if key == "a" then keys.A = false end
                if key == "s" then keys.S = false end
                if key == "d" then keys.D = false end
                if key == " " then keys.Space = false end
            end
            
            game:GetService("UserInputService").InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    onKeyDown(string.lower(input.KeyCode.Name))
                end
            end)
            
            game:GetService("UserInputService").InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    onKeyUp(string.lower(input.KeyCode.Name))
                end
            end)
            
            while flying and hrp and hrp.Parent do
                task.wait()
                
                local cam = workspace.CurrentCamera
                local moveDirection = Vector3.new()
                
                if keys.W then moveDirection = moveDirection + cam.CFrame.LookVector end
                if keys.S then moveDirection = moveDirection - cam.CFrame.LookVector end
                if keys.A then moveDirection = moveDirection - cam.CFrame.RightVector end
                if keys.D then moveDirection = moveDirection + cam.CFrame.RightVector end
                if keys.Space then moveDirection = moveDirection + Vector3.new(0, 1, 0) end
                
                if moveDirection.Magnitude > 0 then
                    moveDirection = moveDirection.Unit * 50
                    hrp._flyVelocity.velocity = moveDirection
                else
                    hrp._flyVelocity.velocity = Vector3.new(0, 0.1, 0)
                end
                
                hrp._flyGyro.cframe = cam.CFrame
            end
        end)
    else
        Obsidian:Notify({
            Title = "✈️ Fly",
            Content = "Desativado!",
            Duration = 1,
        })
        
        local char = Player.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            if hrp:FindFirstChild("_flyGyro") then
                hrp._flyGyro:Destroy()
            end
            if hrp:FindFirstChild("_flyVelocity") then
                hrp._flyVelocity:Destroy()
            end
        end
    end
end

-- ////////////////////////////////////////////////////////////
--  9. NOCLIP
-- ////////////////////////////////////////////////////////////

local function toggleNoclip()
    noclip = not noclip
    
    if noclip then
        Obsidian:Notify({
            Title = "🚀 Noclip",
            Content = "Ativado! (Tecla B)",
            Duration = 2,
        })
    else
        Obsidian:Notify({
            Title = "🚀 Noclip",
            Content = "Desativado!",
            Duration = 2,
        })
    end
end

game:GetService("RunService").Stepped:Connect(function()
    if noclip and Player.Character then
        for _, part in pairs(Player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.B then
        toggleNoclip()
    end
end)

-- ////////////////////////////////////////////////////////////
--  10. WALKSPEED E JUMPPOWER
-- ////////////////////////////////////////////////////////////

local function setWalkSpeed(value)
    local char = Player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = tonumber(value) or 16
    end
end

local function setJumpPower(value)
    local char = Player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.JumpPower = tonumber(value) or 50
    end
end

local function resetWalkSpeed()
    local char = Player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = 16
    end
end

local function resetJumpPower()
    local char = Player.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.JumpPower = 50
    end
end

-- ////////////////////////////////////////////////////////////
--  11. TELEPORTS
-- ////////////////////////////////////////////////////////////

local function tpToLobby()
    local char = Player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(-108.5, 145, 0.6)
    end
end

local function tpToMap()
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    for _, thing in pairs(workspace:GetChildren()) do
        for _, child in pairs(thing:GetChildren()) do
            if child.Name == "Spawns" and child:FindFirstChild("Spawn") then
                char.HumanoidRootPart.CFrame = child.Spawn.CFrame
                return
            end
        end
    end
end

local function tpToMurderer()
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    for _, plr in pairs(game.Players:GetPlayers()) do
        if isMurderer(plr) and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
            return
        end
    end
    Obsidian:Notify({
        Title = "❌ TP",
        Content = "Nenhum assassino encontrado!",
        Duration = 2,
    })
end

local function tpToSherrif()
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    for _, plr in pairs(game.Players:GetPlayers()) do
        if isSherrif(plr) and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
            return
        end
    end
    Obsidian:Notify({
        Title = "❌ TP",
        Content = "Nenhum xerife encontrado!",
        Duration = 2,
    })
end

local function tpToPlayer(nome)
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr.Name == nome and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame
            return
        end
    end
    Obsidian:Notify({
        Title = "❌ TP",
        Content = "Jogador '" .. nome .. "' não encontrado!",
        Duration = 2,
    })
end

-- ////////////////////////////////////////////////////////////
--  CONSTRUÇÃO DA UI
-- ////////////////////////////////////////////////////////////

-- ESP SECTION
local EspSection = EspTab:AddSection({ Title = "ESP Controls" })

EspSection:AddToggle({
    Title = "Murderer ESP",
    Description = "Mostra o assassino em vermelho",
    Default = true,
    Callback = function(Value)
        if Value then ativarMurdererESP() else desativarMurdererESP() end
    end
})

EspSection:AddToggle({
    Title = "Sherrif ESP",
    Description = "Mostra o xerife em azul",
    Default = true,
    Callback = function(Value)
        if Value then ativarSherrifESP() else desativarSherrifESP() end
    end
})

EspSection:AddToggle({
    Title = "Innocent ESP",
    Description = "Mostra os inocentes em verde",
    Default = true,
    Callback = function(Value)
        if Value then ativarInnocentESP() else desativarInnocentESP() end
    end
})

EspSection:AddToggle({
    Title = "Gun ESP",
    Description = "Mostra a arma no chão em verde",
    Default = true,
    Callback = function(Value)
        if Value then ativarGunESP() else desativarGunESP() end
    end
})

EspSection:AddToggle({
    Title = "Names ESP",
    Description = "Mostra o nome dos jogadores",
    Default = true,
    Callback = function(Value)
        if Value then ativarNamesESP() else desativarNamesESP() end
    end
})

-- ESP CONFIGS
local ConfigSection = EspTab:AddSection({ Title = "ESP Configs" })

ConfigSection:AddColorpicker({
    Title = "ESP Color",
    Description = "Cor do ESP",
    Default = Settings.EspColor,
    Callback = function(Value)
        Settings.EspColor = Value
    end
})

ConfigSection:AddSlider({
    Title = "ESP Transparency",
    Description = "Transparência do ESP",
    Default = 0.4,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        Settings.EspTransparency = Value
    end
})

ConfigSection:AddToggle({
    Title = "Rainbow ESP",
    Description = "ESP com cores do arco-íris",
    Default = false,
    Callback = function(Value)
        Settings.EspRainbow = Value
    end
})

-- OUTLINE SECTION
local OutlineSection = EspTab:AddSection({ Title = "Outline (Borda)" })

OutlineSection:AddToggle({
    Title = "Enable Outline",
    Description = "Ativa a borda preta separada do ESP",
    Default = true,
    Callback = function(Value)
        Settings.OutlineEnabled = Value
    end
})

OutlineSection:AddColorpicker({
    Title = "Outline Color",
    Description = "Cor da borda",
    Default = Settings.OutlineColor,
    Callback = function(Value)
        Settings.OutlineColor = Value
    end
})

OutlineSection:AddToggle({
    Title = "Rainbow Outline",
    Description = "Borda com cores do arco-íris",
    Default = false,
    Callback = function(Value)
        Settings.OutlineRainbow = Value
    end
})

OutlineSection:AddSlider({
    Title = "Outline Transparency",
    Description = "Transparência da borda",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        Settings.OutlineTransparency = Value
    end
})

-- MOVEMENT SECTION
local MovementSection = MovementTab:AddSection({ Title = "Movement" })

MovementSection:AddToggle({
    Title = "Fly",
    Description = "Ativa o fly (WASD + Espaço)",
    Default = false,
    Callback = function(Value)
        if Value then toggleFly() end
    end
})

MovementSection:AddToggle({
    Title = "Noclip",
    Description = "Ativa o noclip (Tecla B)",
    Default = false,
    Callback = function(Value)
        if Value then
            noclip = true
            Obsidian:Notify({
                Title = "🚀 Noclip",
                Content = "Ativado! (Tecla B)",
                Duration = 2,
            })
        else
            noclip = false
            Obsidian:Notify({
                Title = "🚀 Noclip",
                Content = "Desativado!",
                Duration = 2,
            })
        end
    end
})

MovementSection:AddInput({
    Title = "WalkSpeed",
    Description = "Digite o valor (padrão: 16)",
    Default = "16",
    Callback = function(Value)
        setWalkSpeed(Value)
    end
})

MovementSection:AddButton({
    Title = "Reset WalkSpeed",
    Description = "Volta para 16",
    Callback = resetWalkSpeed
})

MovementSection:AddInput({
    Title = "JumpPower",
    Description = "Digite o valor (padrão: 50)",
    Default = "50",
    Callback = function(Value)
        setJumpPower(Value)
    end
})

MovementSection:AddButton({
    Title = "Reset JumpPower",
    Description = "Volta para 50",
    Callback = resetJumpPower
})

-- TELEPORT SECTION
local TeleportSection = TeleportTab:AddSection({ Title = "Teleports" })

TeleportSection:AddButton({
    Title = "TP to Lobby",
    Description = "Teleporta para o lobby",
    Callback = tpToLobby
})

TeleportSection:AddButton({
    Title = "TP to Map",
    Description = "Teleporta para o mapa",
    Callback = tpToMap
})

TeleportSection:AddButton({
    Title = "TP to Murderer",
    Description = "Teleporta para o assassino",
    Callback = tpToMurderer
})

TeleportSection:AddButton({
    Title = "TP to Sherrif",
    Description = "Teleporta para o xerife",
    Callback = tpToSherrif
})

-- MISC SECTION
local MiscSection = MiscTab:AddSection({ Title = "Misc" })

-- GUN GRABBER MANUAL
MiscSection:AddButton({
    Title = "🔫 Gun Grabber (Manual)",
    Description = "Teleporta para a arma no chão",
    Callback = gunGrabber
})

-- AUTO GUN GRABBER
MiscSection:AddToggle({
    Title = "🤖 Auto Gun Grabber",
    Description = "Pega a arma automaticamente quando cair",
    Default = false,
    Callback = function(Value)
        if Value then
            autoGun = true
            iniciarAutoGun()
            Obsidian:Notify({
                Title = "🤖 Auto Gun",
                Content = "Ativado! Pegando arma automaticamente.",
                Duration = 2,
            })
        else
            autoGun = false
            Obsidian:Notify({
                Title = "🤖 Auto Gun",
                Content = "Desativado!",
                Duration = 2,
            })
        end
    end
})

-- TP TO PLAYER
MiscSection:AddInput({
    Title = "Player Name",
    Description = "Digite o nome do jogador",
    Default = "",
    Callback = function(Value)
        _G.TargetPlayer = Value
    end
})

MiscSection:AddButton({
    Title = "TP to Player",
    Description = "Teleporta para o jogador digitado",
    Callback = function()
        if _G.TargetPlayer and _G.TargetPlayer ~= "" then
            tpToPlayer(_G.TargetPlayer)
        else
            Obsidian:Notify({
                Title = "❌ Erro",
                Content = "Digite um nome de jogador primeiro!",
                Duration = 2,
            })
        end
    end
})

-- ////////////////////////////////////////////////////////////
--  INICIALIZAÇÃO
-- ////////////////////////////////////////////////////////////

-- ATIVA TODOS OS ESPs
ativarMurdererESP()
ativarSherrifESP()
ativarInnocentESP()
ativarGunESP()
ativarNamesESP()

-- NOTIFICAÇÃO
Obsidian:Notify({
    Title = "🔥 Vynixu's MM2 Script",
    Content = "Todos os ESPs ativados! Use a UI para configurar.",
    Duration = 5,
})

print("✅ SCRIPT COMPLETO CARREGADO - OBSIDIAN EDITION")
print("🔴 Murderer ESP: ATIVADO")
print("🔵 Sherrif ESP: ATIVADO")
print("🟢 Innocent ESP: ATIVADO")
print("🟢 Gun ESP: ATIVADO")
print("📛 Names ESP: ATIVADO")
print("🚀 Noclip: Tecla B")
print("🤖 Auto Gun Grabber: DESATIVADO (toggle na UI)")