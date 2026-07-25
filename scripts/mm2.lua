-- Script purpose: be a usable dev menu with stuff like ExtraSensoryPerception, teleport to gun, etc.
-- current problems:
-- 1 - the 1 per time dosent work
-- 2 - ExtraSensoryPerception blinks for some frames
-- 3 - names ESP (shortenend) is buggy
-- 4 - Toggles,Sliders,etc is not like, the "Text" is not being applied
-- bye, please get this finished, use claude or whatever
-- see ya
-- CARREGAR OBSIDIAN E SAVEMANAGER
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "DEV MENU",
    SubTitle = "developer fun",
    Theme = "Dark",
    Size = UDim2.new(0, 580, 0, 500),
})

Window:SetFooter("DEV ONLY - if you re seeing this, please report to the devs.")

-- ABAS
local EspTab = Window:AddTab("ESP", "eye")
local MovementTab = Window:AddTab("Movement", "run")
local TeleportTab = Window:AddTab("Teleport", "map-pin")
local MiscTab = Window:AddTab("Misc", "cog")
local ConfigTab = Window:AddTab("Config", "settings")
local KeybindTab = Window:AddTab("Keybinds", "keyboard")

SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("VynixuMM2Script/Configs")
SaveManager:BuildConfigSection(ConfigTab)
SaveManager:LoadAutoloadConfig()

local Player = game.Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Highlights = {}
local Outlines = {}
local flying = false
local noclip = false
local autoGun = false
local aimbotAtivo = false
local aimbotLoop = nil
local dialogoAtivo = nil

-- ESTADOS DOS ESPs
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
    AimbotPrediction = 2.8,
}

local function fecharDialogoAtual()
    if dialogoAtivo then
        dialogoAtivo:Destroy()
        dialogoAtivo = nil
    end
end

local function criarDialogoUnico(titulo, descricao, botoes)
    fecharDialogoAtual()
    
    local dialog = Instance.new("Frame")
    dialog.Name = "DialogoUnico"
    dialog.Parent = Library.ScreenGui
    dialog.AnchorPoint = Vector2.new(0.5, 0.5)
    dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
    dialog.Size = UDim2.new(0, 320, 0, 160)
    dialog.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    dialog.BorderSizePixel = 0
    dialog.ZIndex = 999
    dialog.ClipsDescendants = true
    
    local corner = Instance.new("UICorner", dialog)
    corner.CornerRadius = UDim.new(0, 12)
    
    local stroke = Instance.new("UIStroke", dialog)
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 2
    
    local titleLabel = Instance.new("TextLabel", dialog)
    titleLabel.Size = UDim2.new(1, -20, 0, 35)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = titulo
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local descLabel = Instance.new("TextLabel", dialog)
    descLabel.Size = UDim2.new(1, -20, 0, 55)
    descLabel.Position = UDim2.new(0, 10, 0, 50)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = descricao
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.TextSize = 14
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextWrapped = true
    
    local buttonFrame = Instance.new("Frame", dialog)
    buttonFrame.Size = UDim2.new(1, -20, 0, 40)
    buttonFrame.Position = UDim2.new(0, 10, 1, -50)
    buttonFrame.BackgroundTransparency = 1
    
    local layout = Instance.new("UIListLayout", buttonFrame)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    layout.Padding = UDim.new(0, 8)
    
    for _, btnText in ipairs(botoes) do
        local btn = Instance.new("TextButton", buttonFrame)
        btn.Size = UDim2.new(0, 80, 1, 0)
        btn.Text = btnText
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        
        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 6)
        
        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        end)
        
        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end)
        
        btn.MouseButton1Click:Connect(function()
            fecharDialogoAtual()
        end)
    end
    
    dialogoAtivo = dialog
    return dialog
end

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
local function getPredictedPosition(plr, offset)
    if not plr or not plr.Character then return nil end
    
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    local hum = plr.Character:FindFirstChild("Humanoid")
    
    if not hrp or not hum then return nil end
    
    local velocity = hrp.AssemblyLinearVelocity
    local moveDirection = hum.MoveDirection
    
    local predictedPos = hrp.Position + 
        ((velocity * Vector3.new(0.75, 0.5, 0.75))) * (offset / 15) +
        moveDirection * offset
    
    return predictedPos
end

local function iniciarAimbot()
    aimbotAtivo = true
    Library:Notify({
        Title = "Aimbot",
        Description = "Ativado!",
        Time = 2,
    })
    
    aimbotLoop = game:GetService("RunService").RenderStepped:Connect(function()
        if not aimbotAtivo then return end
        
        if not isSherrif(Player) then
            return
        end
        
        local murderer = nil
        for _, plr in pairs(game.Players:GetPlayers()) do
            if isMurderer(plr) then
                murderer = plr
                break
            end
        end
        
        if not murderer then return end
        
        local predictedPos = getPredictedPosition(murderer, Settings.AimbotPrediction)
        if not predictedPos then return end
        -- not finished yet, waiting for dev response if this should be added, while that im going to
		--wait im brazilian NOO
    end)
end

local function pararAimbot()
    aimbotAtivo = false
    if aimbotLoop then
        aimbotLoop:Disconnect()
        aimbotLoop = nil
    end
    Library:Notify({
        Title = "Aimbot",
        Description = "Desativado!",
        Time = 2,
    })
end
local function ativarMurdererESP()
    espStates.Murderer = true
    task.spawn(function()
        while espStates.Murderer do
            task.wait(0.05)
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
local function ativarSherrifESP()
    espStates.Sherrif = true
    task.spawn(function()
        while espStates.Sherrif do
            task.wait(0.05)
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
        Library:Notify({
            Title = "Gun Grabber",
            Description = "Arma pegada com sucesso!",
            Time = 2,
        })
    else
        Library:Notify({
            Title = "Gun Grabber",
            Description = "Nenhuma arma no chão!",
            Time = 2,
        })
    end
end

local function autoGunGrabber()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

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

local function iniciarAutoGun()
    autoGun = true
    task.spawn(function()
        while autoGun do
            task.wait(0.5)
            if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
                local success = autoGunGrabber()
                if success then
                    Library:Notify({
                        Title = "Auto Gun",
                        Description = "Arma pegada automaticamente!",
                        Time = 1,
                    })
                end
            end
        end
    end)
end
local function toggleFly()
    flying = not flying

    if flying then
        Library:Notify({
            Title = "Fly",
            Description = "Ativado! (WASD + Espaço)",
            Time = 2,
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

            UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    onKeyDown(string.lower(input.KeyCode.Name))
                end
            end)

            UserInputService.InputEnded:Connect(function(input)
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
        Library:Notify({
            Title = "Fly",
            Description = "Desativado!",
            Time = 1,
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
local function toggleNoclip()
    noclip = not noclip

    if noclip then
        Library:Notify({
            Title = "Noclip",
            Description = "Ativado!",
            Time = 2,
        })
    else
        Library:Notify({
            Title = "Noclip",
            Description = "Desativado!",
            Time = 1,
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
    Library:Notify({
        Title = "TP",
        Description = "Nenhum assassino encontrado!",
        Time = 2,
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
    Library:Notify({
        Title = "TP",
        Description = "Nenhum xerife encontrado!",
        Time = 2,
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
    Library:Notify({
        Title = "TP",
        Description = "Jogador '" .. nome .. "' não encontrado!",
        Time = 2,
    })
end
local EspGroupbox = EspTab:AddLeftGroupbox("ESP Controls", "eye")
-- TODOS OS TOGGLES COM "Text" DEFINIDO
EspGroupbox:AddToggle({
    Text = "Murderer ESP",
    Description = "Mostra o assassino em vermelho",
    Default = true,
    Callback = function(Value)
        if Value then ativarMurdererESP() else desativarMurdererESP() end
    end
})
EspGroupbox:AddToggle({
    Text = "Sherrif ESP",
    Description = "Mostra o xerife em azul",
    Default = true,
    Callback = function(Value)
        if Value then ativarSherrifESP() else desativarSherrifESP() end
    end
})
EspGroupbox:AddToggle({
    Text = "Innocent ESP",
    Description = "Mostra os inocentes em verde",
    Default = true,
    Callback = function(Value)
        if Value then ativarInnocentESP() else desativarInnocentESP() end
    end
})
EspGroupbox:AddToggle({
    Text = "Gun ESP",
    Description = "Mostra a arma no chão em verde",
    Default = true,
    Callback = function(Value)
        if Value then ativarGunESP() else desativarGunESP() end
    end
})
EspGroupbox:AddToggle({
    Text = "Names ESP",
    Description = "Mostra o nome dos jogadores",
    Default = true,
    Callback = function(Value)
        if Value then ativarNamesESP() else desativarNamesESP() end
    end
})
local ConfigGroupbox = EspTab:AddRightGroupbox("ESP Configs", "settings")
local EspColorToggle = ConfigGroupbox:AddToggle({
    Text = "ESP Color",
    Description = "Clique para abrir o seletor de cores",
    Default = false,
})
local EspColorPicker = EspColorToggle:AddColorPicker("EspColorPicker", {
    Default = Settings.EspColor,
    Transparency = 0,
    Callback = function(color)
        Settings.EspColor = color
    end
})
ConfigGroupbox:AddSlider({
    Text = "ESP Transparency",
    Description = "Transparência do ESP",
    Default = 0.4,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        Settings.EspTransparency = Value
    end
})
ConfigGroupbox:AddToggle({
    Text = "Rainbow ESP",
    Description = "ESP com cores do arco-íris",
    Default = false,
    Callback = function(Value)
        Settings.EspRainbow = Value
    end
})
local OutlineGroupbox = EspTab:AddRightGroupbox("Outline (Borda)", "square")
OutlineGroupbox:AddToggle({
    Text = "Enable Outline",
    Description = "Ativa a borda preta separada do ESP",
    Default = true,
    Callback = function(Value)
        Settings.OutlineEnabled = Value
    end
})
local OutlineColorToggle = OutlineGroupbox:AddToggle({
    Text = "Outline Color",
    Description = "Clique para abrir o seletor de cores",
    Default = false,
})
local OutlineColorPicker = OutlineColorToggle:AddColorPicker("OutlineColorPicker", {
    Default = Settings.OutlineColor,
    Transparency = 0,
    Callback = function(color)
        Settings.OutlineColor = color
    end
})
OutlineGroupbox:AddToggle({
    Text = "Rainbow Outline",
    Description = "Borda com cores do arco-íris",
    Default = false,
    Callback = function(Value)
        Settings.OutlineRainbow = Value
    end
})
OutlineGroupbox:AddSlider({
    Text = "Outline Transparency",
    Description = "Transparência da borda",
    Default = 0,
    Min = 0,
    Max = 1,
    Rounding = 2,
    Callback = function(Value)
        Settings.OutlineTransparency = Value
    end
})
local MovementGroupbox = MovementTab:AddLeftGroupbox("Movement", "run")
MovementGroupbox:AddToggle({
    Text = "Fly",
    Description = "Ativa o fly (WASD + Espaço)",
    Default = false,
    Callback = function(Value)
        if Value then toggleFly() end
    end
})
MovementGroupbox:AddToggle({
    Text = "Noclip",
    Description = "Ativa o noclip",
    Default = false,
    Callback = function(Value)
        if Value then
            noclip = true
            Library:Notify({
                Title = "Noclip",
                Description = "Ativado!",
                Time = 2,
            })
        else
            noclip = false
            Library:Notify({
                Title = "Noclip",
                Description = "Desativado!",
                Time = 1,
            })
        end
    end
})
MovementGroupbox:AddInput({
    Text = "WalkSpeed",
    Description = "Digite o valor (padrão: 16)",
    Default = "16",
    Callback = function(Value)
        setWalkSpeed(Value)
    end
})
MovementGroupbox:AddButton({
    Text = "Reset WalkSpeed",
    Description = "Volta para 16",
    Callback = resetWalkSpeed
})
MovementGroupbox:AddInput({
    Text = "JumpPower",
    Description = "Digite o valor (padrão: 50)",
    Default = "50",
    Callback = function(Value)
        setJumpPower(Value)
    end
})
MovementGroupbox:AddButton({
    Text = "Reset JumpPower",
    Description = "Volta para 50",
    Callback = resetJumpPower
})
local TeleportGroupbox = TeleportTab:AddLeftGroupbox("Teleports", "map-pin")
TeleportGroupbox:AddButton({
    Text = "TP to Lobby",
    Description = "Teleporta para o lobby",
    Callback = tpToLobby
})
TeleportGroupbox:AddButton({
    Text = "TP to Map",
    Description = "Teleporta para o mapa",
    Callback = tpToMap
})
TeleportGroupbox:AddButton({
    Text = "TP to Murderer",
    Description = "Teleporta para o assassino",
    Callback = tpToMurderer
})
TeleportGroupbox:AddButton({
    Text = "TP to Sherrif",
    Description = "Teleporta para o xerife",
    Callback = tpToSherrif
})
local MiscGroupbox = MiscTab:AddLeftGroupbox("Misc", "cog")
MiscGroupbox:AddButton({
    Text = "Gun Grabber (Manual)",
    Description = "Teleporta para a arma no chão",
    Callback = gunGrabber
})
MiscGroupbox:AddToggle({
    Text = "Auto Gun Grabber",
    Description = "Pega a arma automaticamente quando cair",
    Default = false,
    Callback = function(Value)
        if Value then
            autoGun = true
            iniciarAutoGun()
            Library:Notify({
                Title = "Auto Gun",
                Description = "Ativado! Pegando arma automaticamente.",
                Time = 2,
            })
        else
            autoGun = false
            Library:Notify({
                Title = "Auto Gun",
                Description = "Desativado!",
                Time = 1,
            })
        end
    end
})
MiscGroupbox:AddToggle({
    Text = "Aimbot Xerife",
    Description = "Atira automaticamente no assassino com predição",
    Default = false,
    Callback = function(Value)
        if Value then
            iniciarAimbot()
        else
            pararAimbot()
        end
    end
})
MiscGroupbox:AddSlider({
    Text = "Aimbot Prediction",
    Description = "Offset da predição (padrão: 2.8)",
    Default = 2.8,
    Min = 0,
    Max = 10,
    Rounding = 1,
    Callback = function(Value)
        Settings.AimbotPrediction = Value
    end
})
MiscGroupbox:AddInput({
    Text = "Player Name",
    Description = "Digite o nome do jogador",
    Default = "",
    Callback = function(Value)
        _G.TargetPlayer = Value
    end
})
MiscGroupbox:AddButton({
    Text = "TP to Player",
    Description = "Teleporta para o jogador digitado",
    Callback = function()
        if _G.TargetPlayer and _G.TargetPlayer ~= "" then
            tpToPlayer(_G.TargetPlayer)
        else
            Library:Notify({
                Title = "Erro",
                Description = "Digite um nome de jogador primeiro!",
                Time = 2,
            })
        end
    end
})
local KeybindGroupbox = KeybindTab:AddLeftGroupbox("Keybinds", "keyboard")
-- KEYBIND: Toggle UI
local ToggleUIToggle = KeybindGroupbox:AddToggle({
    Text = "Toggle UI",
    Description = "Tecla para mostrar/esconder a UI",
    Default = false,
})
local ToggleUIKeybind = ToggleUIToggle:AddKeyPicker("MenuKeybind", {
    Text = "UI Key",
    Default = "RightControl",
    Mode = "Toggle",
    Callback = function()
        Window:Toggle()
    end
})
-- KEYBIND: Noclip
local NoclipToggle = KeybindGroupbox:AddToggle({
    Text = "Noclip Key",
    Description = "Tecla para ativar/desativar o noclip",
    Default = false,
})
local NoclipKeybind = NoclipToggle:AddKeyPicker("NoclipKeybind", {
    Text = "Noclip Key",
    Default = "B",
    Mode = "Toggle",
    SyncToggleState = true,
    Callback = function()
        toggleNoclip()
    end
})
-- KEYBIND: Fly
local FlyToggle = KeybindGroupbox:AddToggle({
    Text = "Fly Key",
    Description = "Tecla para ativar/desativar o fly",
    Default = false,
})
local FlyKeybind = FlyToggle:AddKeyPicker("FlyKeybind", {
    Text = "Fly Key",
    Default = "L",
    Mode = "Toggle",
    SyncToggleState = true,
    Callback = function()
        toggleFly()
    end
})
-- KEYBIND: Aimbot
local AimbotToggleKey = KeybindGroupbox:AddToggle({
    Text = "Aimbot Key",
    Description = "Tecla para ativar/desativar o aimbot",
    Default = false,
})
local AimbotKeybind = AimbotToggleKey:AddKeyPicker("AimbotKeybind", {
    Text = "Aimbot Key",
    Default = "F",
    Mode = "Toggle",
    SyncToggleState = true,
    Callback = function()
        if aimbotAtivo then
            pararAimbot()
        else
            iniciarAimbot()
        end
    end
})
ativarMurdererESP()
ativarSherrifESP()
ativarInnocentESP()
ativarGunESP()
ativarNamesESP()
task.wait(0.5)
Library:Notify({
    Title = "Dev Menu",
    Description = "loaded.",
    Time = 5,
})