if not game:IsLoaded() then game.Loaded:Wait() end
pcall(function() game:GetService("Players").RespawnTime = 0 end)
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService= game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===== FIX REMOTES (meerkoo "is fixing remotes") : resout les vrais remotes hashes =====

local _catResolve
do
    local netFolder = ReplicatedStorage:WaitForChild("Packages", 10) and ReplicatedStorage.Packages:WaitForChild("Net", 10)

    -- Neuter pcall du resolver Net = remotes réels (sinon TP lent / carpet timeout)
    if not getgenv().__vanCatPcallNeutered then
        pcall(function()
            local REM = require(netFolder.Net).RemoteEvent
            getfenv(REM).pcall = function() end
            getgenv().__vanCatPcallNeutered = true
        end)
    end

    local Net = getgenv().__vanCatNet
    local resolving = 0
    local origFire, installed = getgenv().__vanCatOrigFire, getgenv().__vanCatInstalled or false

    local function isNetTable(o)
        return type(rawget(o, "RemoteEvent")) == "function"
            and type(rawget(o, "RemoteFunction")) == "function"
            and type(rawget(o, "UnreliableRemoteEvent")) == "function"
            and type(rawget(o, "Invoke")) == "function"
            and type(rawget(o, "Connect")) == "function"
    end
    local function acquireNet(attempts)
        if type(getgc) ~= "function" then return nil end
        -- max 3 passes (20x getgc(true) = freeze spawn)
        for _ = 1, math.min(attempts or 1, 3) do
            for _, o in ipairs(getgc(true)) do
                if type(o) == "table" then
                    local ok, r = pcall(isNetTable, o)
                    if ok and r then return o end
                end
            end
            task.wait()
        end
        return nil
    end

    -- JAMAIS getgc sync au load (FPS kill spawn) — différé
    if not Net then
        task.delay(2.5, function()
            if not Net then Net = acquireNet(1); getgenv().__vanCatNet = Net end
        end)
    end

    if not installed and hookfunction then
        local ok = pcall(function()
            origFire = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
                if resolving > 0 and typeof(self) == "Instance" and netFolder and self.Parent == netFolder then return end
                return origFire(self, ...)
            end)
        end)
        installed = ok and origFire ~= nil
        getgenv().__vanCatOrigFire = origFire
        getgenv().__vanCatInstalled = installed
    end

    _catResolve = function(kind, name)
        if not Net then Net = acquireNet(2); getgenv().__vanCatNet = Net end
        if not Net then return nil end
        local fn = rawget(Net, kind)
        if type(fn) ~= "function" then return nil end
        resolving = resolving + 1
        local ok, res = pcall(fn, Net, name)
        resolving = resolving - 1
        if ok and typeof(res) == "Instance" then return res end
        return nil
    end
end

local function getRemote(method, name)
    -- Resolve through the game's OWN Net resolver (cat mapper, live Net table
    -- from GC). The pcall-neuter above lets it return the REAL hashed remote --
    -- the friendly "RE/<name>" child is a decoy the server does not listen on.
    return _catResolve(method == "RemoteFunction" and "RemoteFunction"
        or method == "UnreliableRemoteEvent" and "UnreliableRemoteEvent"
        or "RemoteEvent", name)
end
-- ===== fin fix remotes =====

local TweenService    = game:GetService("TweenService")
local HttpService     = game:GetService("HttpService")
local Workspace       = game:GetService("Workspace")
local Lighting        = game:GetService("Lighting")
local SoundService    = game:GetService("SoundService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService      = game:GetService("GuiService")
local LocalPlayer     = Players.LocalPlayer
local PlayerGui       = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
local FileName = "NiggaHubMini.json"
local DefaultConfig = {
    UILocked = false, MenuKey = "LeftControl", CarpetSpeedKey = "Q", CarpetTool = "Flying Carpet", CarpetSpeed = 140,
    InfiniteJump = false, AntiRagdoll = false, XrayEnabled = false, ProximityAPKey = "P", ProximityAPRange = 15,
    AntiBeeEffects = false, AntiBoogieBombEffects = false, AntiBeeDisco = false,
    ProximityAPEnabled = false, CarpetSpeedEnabled = false,
    CarrySpeedEnabled = false, CarrySpeedValue = 30, CleanErrorGUIs=true,
    InstaResetKey = "X", InstaResetDelay = 0.1,
    CloneKey = "V", ClickToAPKey = "Z", ManualTPKey = "T",
    ClickToAPEnabled = false, AutoKickEnabled = false,
    StealMode = "Priority", StealHighest = false, StealPriority = true, StealNearest = false,
    AutoStealEnabled = true, AutoTPPriority = true,
    InvisStealAngle = 225, SinkSliderValue = 7, AutoRecoverLagback = true, AutoInvisDuringSteal = false, InvisAntiDie = true,
    PriorityList = nil, StealTargetUID = nil,
    Visibilities = {["Steal Panel"]=false,["Invisible Steal Panel"]=false,["Steal Target"]=false,["TP Settings"]=false,["Priority List"]=false},
    TpSettings = {GrabbleTPSpeed=230,WalkTPSpeed=190,CloneDelayVal=0.1,TpOnLoad=true,Tool="Flying Carpet"},
    Positions = {Main = {X=0.02, Y=0.3}},
}
local function deepMerge(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then deepMerge(dst[k], v) else dst[k] = v end
    end
end
local Config = {}
deepMerge(Config, DefaultConfig)
if isfile and isfile(FileName) then
    pcall(function()
        local ok, d = pcall(function() return HttpService:JSONDecode(readfile(FileName)) end)
        if ok and type(d) == "table" then deepMerge(Config, d) end
    end)
end
local function SaveConfig()
    if writefile then
        pcall(function() writefile(FileName, HttpService:JSONEncode(Config)) end)
    end
end

-- Config yuklendikten sonra baslatilir. Aksi halde bu blok, local Config'i
-- kapsamadigi icin nil olan global Config'e erismeye calisir.
task.spawn(function()
    local ok, GS = pcall(function()
        return cloneref and cloneref(game:GetService("GuiService")) or game:GetService("GuiService")
    end)
    if not ok or not GS then return end

    while true do
        if Config.CleanErrorGUIs then
            pcall(function() GS:ClearError() end)
        end
        task.wait(0.1)
    end
end)
local player = LocalPlayer
local UIS = UserInputService
local panels = {}
local ToggleState = {}
local Theme = {
    Background=Color3.fromRGB(0,0,0), MainBackground=Color3.fromRGB(0,0,0), Panel=Color3.fromRGB(16,16,16),
    Row=Color3.fromRGB(24,24,24), RowHover=Color3.fromRGB(36,36,36), Accent=Color3.fromRGB(255,255,255),
    AccentLight=Color3.fromRGB(220,220,220), Green=Color3.fromRGB(255,255,255), Red=Color3.fromRGB(70,70,70),
    Text=Color3.fromRGB(255,255,255), Dim=Color3.fromRGB(160,160,160), Stroke=Color3.fromRGB(90,90,90),
    SoftButton=Color3.fromRGB(22,22,22), SoftButtonHover=Color3.fromRGB(38,38,38),
    SoftAccent=Color3.fromRGB(30,30,30), SoftAccentHover=Color3.fromRGB(44,44,44),
    ToggleOff=Color3.fromRGB(18,18,18), ToggleOff2=Color3.fromRGB(18,18,18),
    InputBg=Color3.fromRGB(12,12,12), SliderBg=Color3.fromRGB(45,45,45),
    Surface=Color3.fromRGB(16,16,16), SurfaceHighlight=Color3.fromRGB(24,24,24),
    Accent1=Color3.fromRGB(255,255,255), Accent2=Color3.fromRGB(200,200,200),
    TextPrimary=Color3.fromRGB(255,255,255), TextSecondary=Color3.fromRGB(160,160,160),
    Success=Color3.fromRGB(255,255,255), Error=Color3.fromRGB(70,70,70),
}
local function ShowNotification(title, text)
    local old = PlayerGui:FindFirstChild("MiniNotif"); if old then old:Destroy() end
    local sg = Instance.new("ScreenGui", PlayerGui); sg.Name = "MiniNotif"; sg.ResetOnSpawn = false
    local f = Instance.new("Frame", sg); f.Size = UDim2.new(0,290,0,54); f.Position = UDim2.new(0.5,-145,0,80)
    f.BackgroundColor3 = Color3.fromRGB(8,8,8); f.BackgroundTransparency = 0.08; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,9)
    local t1 = Instance.new("TextLabel", f); t1.Size = UDim2.new(1,-22,0,18); t1.Position = UDim2.new(0,16,0,7)
    t1.BackgroundTransparency = 1; t1.Text = title:upper(); t1.Font = Enum.Font.GothamBlack; t1.TextSize = 11
    t1.TextColor3 = Theme.Accent1; t1.TextXAlignment = Enum.TextXAlignment.Left
    local t2 = Instance.new("TextLabel", f); t2.Size = UDim2.new(1,-22,0,15); t2.Position = UDim2.new(0,16,0,27)
    t2.BackgroundTransparency = 1; t2.Text = text; t2.Font = Enum.Font.GothamMedium; t2.TextSize = 10
    t2.TextColor3 = Theme.TextSecondary; t2.TextXAlignment = Enum.TextXAlignment.Left
    task.delay(2, function() if sg.Parent then sg:Destroy() end end)
end
local function MakeDraggable(handle, target, saveKey)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if Config.UILocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if saveKey then
                        local ps = target.Parent.AbsoluteSize
                        if not Config.Positions then Config.Positions = {} end
                        Config.Positions[saveKey] = {X = target.AbsolutePosition.X / ps.X, Y = target.AbsolutePosition.Y / ps.Y}
                        SaveConfig()
                    end
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local d = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
local function serializePos(pos) return {xs=pos.X.Scale,xo=pos.X.Offset,ys=pos.Y.Scale,yo=pos.Y.Offset} end
local function rememberPosition(name, frame)
    if not name or not frame then return end
    if not Config.SXEPositions then Config.SXEPositions = {} end
    Config.SXEPositions[name] = serializePos(frame.Position)
    SaveConfig()
end
local function applySavedPosition(name, frame)
    if not name or not frame then return end
    local d = Config.SXEPositions and Config.SXEPositions[name]
    if d then frame.Position = UDim2.new(d.xs or 0, d.xo or 0, d.ys or 0, d.yo or 0) end
end
local function regToggle(name, default)
    if not ToggleState[name] then ToggleState[name] = {value = default or false, listeners = {}} end
end
local function getToggle(name) return ToggleState[name] and ToggleState[name].value or false end
local function setToggle(name, val, skipNotify)
    regToggle(name)
    ToggleState[name].value = val
    if not skipNotify then for _, fn in ipairs(ToggleState[name].listeners) do pcall(fn, val) end end
end
local function onToggleChanged(name, fn) regToggle(name); table.insert(ToggleState[name].listeners, fn) end
if Config.StealMode == nil then Config.StealMode = Config.StealNearest and "Nearest" or "Priority" end
Config.StealHighest = (Config.StealMode == "Highest")
Config.StealPriority = (Config.StealMode == "Priority")
Config.StealNearest = (Config.StealMode == "Nearest")
if not Config.TpSettings then Config.TpSettings = {} end
if not Config.Positions then Config.Positions = DefaultConfig.Positions end
if not Config.Visibilities then Config.Visibilities = DefaultConfig.Visibilities end
for _, n in ipairs({"TP Settings","Priority List","Steal Panel","Invisible Steal Panel","Steal Target"}) do
    if Config.Visibilities[n] == nil then Config.Visibilities[n] = DefaultConfig.Visibilities[n] end
end
resetRemote = nil
pcall(function()
    if hookfunction and not _G.__SXEStopTryingHook then
        _G.__SXEStopTryingHook = true
        local old
        old = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
            local a1 = (select("#", ...) >= 1) and (select(1, ...)) or nil
            if not resetRemote and self.Name:sub(1, 3) == "RE/" then
                resetRemote = self
            end
            if #self.Name == 67 and a1 and typeof(a1) == "string" and string.find(a1, "StopTrying") then
                return
            end
            return old(self, ...)
        end)
    end
end)

pcall(function()
    local getupvalue = getupvalue or debug.getupvalue
    local function getInternalTable()
        local Packages = ReplicatedStorage:FindFirstChild("Packages")
        if not Packages then return nil end
        local SynMod = Packages:FindFirstChild("Synchronizer")
        if not SynMod then return nil end
        local ok, syn = pcall(require, SynMod)
        if not ok or not syn then return nil end
        local Get = syn.Get
        if type(Get) ~= "function" then return nil end
        for i = 1, 5 do
            local s, u = pcall(getupvalue, Get, i)
            if s and type(u) == "table" then
                if u.___private or u.___channels or u.___data then return u end
                for k, v in pairs(u) do
                    if (type(k) == "string" and k:match("^Plot_")) or type(v) == "table" then return u end
                end
            end
        end
        return nil
    end
    local SyncInt = {_cache = {}, _data = nil}
    task.spawn(function()
        for i = 1, 10 do
            SyncInt._data = getInternalTable()
            if SyncInt._data then break end
            task.wait(1)
        end
    end)
    local function myCustomGet(self, prop)
        if self[prop] then return self[prop] end
        for _, sub in ipairs({"CacheTable", "Data", "_data", "state", "values"}) do
            if type(self[sub]) == "table" and self[sub][prop] then return self[sub][prop] end
        end
        return nil
    end
    function _G.stealthGet(n)
        if not n or type(n) ~= "string" then return nil end
        if SyncInt._cache[n] == false then return nil end
        local res = nil
        if SyncInt._data then
            for _, k in ipairs({n, "Plot_" .. n, "Plot" .. n, n .. "_Channel", "Channel_" .. n}) do
                if SyncInt._data[k] then res = SyncInt._data[k]; break end
            end
        end
        if res then SyncInt._cache[n] = res; return res end
        SyncInt._cache[n] = false
        return nil
    end
    function _G.sProp(ch, p)
        if not ch or type(ch) ~= "table" then return nil end
        if ch[p] then return ch[p] end
        for _, sub in ipairs({"CacheTable", "Data", "_data", "state", "values"}) do
            if type(ch[sub]) == "table" and ch[sub][p] then return ch[sub][p] end
        end
        if type(ch.Get) == "function" and ch.Get ~= myCustomGet then
            local ok, r = pcall(ch.Get, ch, p)
            if ok then return r end
        end
        local alts = {
            Owner = {"owner", "Owner", "plotOwner", "PlotOwner"},
            AnimalList = {"animalList", "AnimalList", "animals", "Animals", "pets"},
        }
        if alts[p] then
            for _, a in ipairs(alts[p]) do
                if ch[a] then return ch[a] end
                for _, sub in ipairs({"CacheTable", "Data", "_data", "state", "values"}) do
                    if type(ch[sub]) == "table" and ch[sub][a] then return ch[sub][a] end
                end
            end
        end
        return nil
    end
    local Packages = ReplicatedStorage:FindFirstChild("Packages")
    local SynMod = Packages and Packages:FindFirstChild("Synchronizer")
    local okReq, syn = pcall(require, SynMod)
    if okReq and typeof(syn) == "table" and debug and debug.getupvalues and debug.setupvalue then
        local isExec = isexecutorclosure or function() return false end
        local nc = newcclosure or function(f) return f end
        local getUp = getupvalue or debug.getupvalue
        local function HasBoolUpvalue(Fn)
            local OkU, Ups = xpcall(debug.getupvalues, function() end, Fn)
            if not OkU then return false end
            for _, V in pairs(Ups) do
                if typeof(V) == "boolean" then return true end
            end
            return false
        end
        local function synWorks()
            local ok, res = pcall(function()
                local plots = workspace:FindFirstChild("Plots")
                if not plots then return true end
                for _, plot in ipairs(plots:GetChildren()) do
                    local ch = syn:Get(plot.Name)
                    if ch ~= nil then return true end
                end
                return false
            end)
            return ok and res == true
        end
        for _, Fn in pairs(syn) do
            if typeof(Fn) == "function" and not isExec(Fn) then
                local OkU, Ups = xpcall(debug.getupvalues, function() end, Fn)
                if OkU then
                    for Idx, V in pairs(Ups) do
                        if typeof(V) == "function" and not isExec(V) and HasBoolUpvalue(V) then
                            local orig = V
                            local sk, PK = pcall(getUp, V, 3)
                            if sk then
                                pcall(debug.setupvalue, Fn, Idx, nc(function() return PK end))
                                if not synWorks() then
                                    pcall(debug.setupvalue, Fn, Idx, orig)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

local function Strip()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not getconnections or not debug.getinfo then return end
    for _, sig in ipairs({"CFrame", "Position"}) do
        local signal = hrp:GetPropertyChangedSignal(sig)
        if signal then
            for _, c in ipairs(getconnections(signal)) do
                local f = c.Function
                if f and c.Enabled then
                    local ok, info = pcall(debug.getinfo, f)
                    if ok and info and info.source == "=ReplicatedFirst.test" then
                        pcall(function() c:Disable() end)
                    end
                end
            end
        end
    end
end
task.spawn(function()
    -- Strip desactive (coupe une connexion surveillee par la maj)
    -- while true do pcall(Strip); task.wait(0.5) end
end)
local oldSXE = PlayerGui:FindFirstChild("MiniHub_SXE"); if oldSXE then oldSXE:Destroy() end
local gui_sg = Instance.new("ScreenGui")
gui_sg.Name = "MiniHub_SXE"; gui_sg.ResetOnSpawn = false; gui_sg.IgnoreGuiInset = true
gui_sg.DisplayOrder = 9999998; gui_sg.Parent = PlayerGui
local gui = Instance.new("Frame"); gui.Name = "SXE_MasterFrame"; gui.BackgroundTransparency = 1
gui.Size = UDim2.new(1,0,1,0); gui.Parent = gui_sg
local function makeOneWay(plat)
    if not plat then return end
    local rsConn
    local lastY = nil
    rsConn = game:GetService("RunService").Stepped:Connect(function()
        if not plat or not plat.Parent then
            if rsConn then rsConn:Disconnect() end
            return
        end
        local char = game.Players.LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local currentY = hrp.Position.Y
            if not lastY then lastY = currentY end
            local deltaY = currentY - lastY
            local isMovingUp = (hrp.AssemblyLinearVelocity.Y > 1) or (deltaY > 0.01 and deltaY < 5)
            if isMovingUp then
                plat.CanCollide = false
            else
                if currentY > plat.Position.Y + 0.1 then
                    plat.CanCollide = true
                else
                    plat.CanCollide = false
                end
            end
            lastY = currentY
        end
    end)
end
priorityList = {"Strawberry Elephant","Meowl","Skibidi Toilet","Headless Horseman","Dragon Gingerini","Dragon Cannelloni","Ketupat Bros","Hydra Dragon Cannelloni","La Supreme Combinasion","Love Love Bear","Ginger Gerat","Cerberus","Capitano Moby","La Casa Boo","Burguro and Fryuro","Spooky and Pumpky","Cooki and Milki","Rosey and Teddy","Popcuru and Fizzuru","Reinito Sleighito","Fragrama and Chocrama","Garama and Madundung","Ketchuru and Musturu","La Secret Combinasion","Tralaledon","Tictac Sahur","Ketupat Kepat","Tang Tang Keletang","Orcaledon","La Ginger Sekolah","Los Spaghettis","Lavadorito Spinito","Swaggy Bros","La Taco Combinasion","Los Primos","Los Chillis","Chillin Chili","Tuff Toucan","W or L","Chipso and Queso","Signore Carapace","Arcadragon","John Pork","Elefanto Frigo","Antonio","Pancake and Syrup","Griffin","Kalika Bros","Globa Steppa","Fishino Clownino","Rico Dinero","Tirilikalika Tirilikalako","Digi Narwhal","Hydra Bunny","Dug dug dug","Bunny and Eggy","Los Hackers","Duggy Bros","Guest 666","Money Money Reindeer","Foxini Lanternini","Fragola La La La","Quackini Snackini","Los Sekolahs","Los Tacoritas","Los Amigos","Fortunu and Cashuru","Jolly Jolly Sahur","Boppin Bunny","Gym Bros","Los Cupids","Festive 67","Celularcini Viciosini","Cloverat Clapat","La Food Combinasion","Hopilikalika Hopilikalako","Celestial Pegasus","Sammyni Fattini","Money Money Bros","La Spooky Grande","Cash or Card","Swag Soda","Los Planitos","Lovin Rose","Tacorita Bicicleta","Los Jolly Combinasionas","La Romantic Grande","La Easter Grande","Los Hotspotsitos","Rosetti Tualetti","Los Bros","Gobblino Uniciclino","Chicleteira Cupideira","La Extinct Grande","Las Sis","Nacho Spyder","Gold Gold Gold","Los Mariachis","Snailo Clovero","La Jolly Grande","Los Candies","Churrito Bunnito","Bananito","Eviledon","Los 67","Los Sweethearts","Noo my Heart","La Lucky Grande","Ventoliero Pavonero","Baskito","Chimnino","Los Puggies","Camera Ramena","Los 25","Spinny Hammy","Money Money Puggy","Cigno Fulgoro","Los Spooky Combinasionas","Chicleteira Noelteira","Mariachi Corazoni","Tacorillo Crocodillo","Noo my Gold","Los Mobilis","Mieteteira Bicicleteira","DJ Panda","Los Combinasionas","Nuclearo Dinossauro","Bacuru and Egguru","Spaghetti Tualetti","La Grande Combinasion","Esok Sekolah"}
if Config.PriorityList and #Config.PriorityList > 0 then priorityList = Config.PriorityList end
SharedState = {SelectedPetData=nil, AllAnimalsCache={}, InitialScanComplete=false}
task.spawn(function()
    local ok1,Packages=pcall(function() return ReplicatedStorage:WaitForChild("Packages",5) end); if not ok1 or not Packages then return end
    local ok2,Datas=pcall(function() return ReplicatedStorage:WaitForChild("Datas",5) end); if not ok2 or not Datas then return end
    local ok3,Shared=pcall(function() return ReplicatedStorage:WaitForChild("Shared",5) end); if not ok3 or not Shared then return end
    local ok4,Utils=pcall(function() return ReplicatedStorage:WaitForChild("Utils",5) end); if not ok4 or not Utils then return end
    local okS,Synchronizer=pcall(function() return require(Packages:WaitForChild("Synchronizer")) end); if not okS then return end
    local okA,AnimalsData=pcall(function() return require(Datas:WaitForChild("Animals")) end); if not okA then return end
    local okAS,AnimalsShared=pcall(function() return require(Shared:WaitForChild("Animals")) end); if not okAS then return end
    local okN,NumberUtils=pcall(function() return require(Utils:WaitForChild("NumberUtils")) end); if not okN then return end
    local allAnimalsCache={}; local lastAnimalData={}
    local function getAnimalHash(al) if not al then return "" end; local h=""; for slot,d in pairs(al) do if type(d)=="table" then h=h..tostring(slot)..tostring(d.Index)..tostring(d.Mutation) end end; return h end
    local function getChannel(plotName)
        if _G.stealthGet then local ch = _G.stealthGet(plotName); if ch then return ch end end
        local ch; pcall(function() ch = Synchronizer:Get(plotName) end); return ch
    end
    local function scanSinglePlot(plot) pcall(function()
        local ch = getChannel(plot.Name); if not ch then return end
        local sProp = _G.sProp
        local al = sProp and sProp(ch, "AnimalList") or (ch.Get and ch:Get("AnimalList"))
        local owner = sProp and sProp(ch, "Owner") or (ch.Get and ch:Get("Owner"))
        local ownerName
        if typeof(owner) == "Instance" and owner:IsA("Player") then
            ownerName = owner.Name
        elseif type(owner) == "table" and owner.Name then
            ownerName = tostring(owner.Name)
        elseif type(owner) == "string" then
            ownerName = owner
        end
        if not ownerName or not Players:FindFirstChild(ownerName) then
            lastAnimalData[plot.Name]=nil; for i=#allAnimalsCache,1,-1 do if allAnimalsCache[i].plot==plot.Name then table.remove(allAnimalsCache,i) end end; return end
        if not al then lastAnimalData[plot.Name]=nil; for i=#allAnimalsCache,1,-1 do if allAnimalsCache[i].plot==plot.Name then table.remove(allAnimalsCache,i) end end; return end
        local hash=getAnimalHash(al)
        if lastAnimalData[plot.Name]==hash then return end
        for i=#allAnimalsCache,1,-1 do if allAnimalsCache[i].plot==plot.Name then table.remove(allAnimalsCache,i) end end
        for slot,ad in pairs(al) do if type(ad)=="table" then
            local aName,aInfo=ad.Index,AnimalsData[ad.Index]; if aInfo then
                local mut=ad.Mutation or "None"; if mut=="Yin Yang" then mut="YinYang" end
                local traits = "None"
                if type(ad.Traits) == "table" and #ad.Traits > 0 then
                    traits = table.concat(ad.Traits, ", ")
                end
                local gv = 0
                pcall(function() gv = AnimalsShared:GetGeneration(aName, ad.Mutation, ad.Traits, nil) end)
                if type(gv) ~= "number" then gv = tonumber(gv) or 0 end
                local gt="$"..NumberUtils:ToString(gv).."/s"
                local pv=0; pcall(function() pv=AnimalsShared:GetValue(aName,ad.Mutation,ad.Traits,nil) or 0 end)
                if type(pv)~="number" then pv=0 end
                table.insert(allAnimalsCache,{name=aInfo.DisplayName or aName,index=aName,genText=gt,genValue=gv,petValue=pv,mutation=mut,traits=traits,owner=ownerName,plot=plot.Name,slot=tostring(slot),uid=plot.Name.."_"..tostring(slot)})
            end
        end end
        lastAnimalData[plot.Name]=hash
        table.sort(allAnimalsCache,function(a,b) return (tonumber(a.genValue) or 0) > (tonumber(b.genValue) or 0) end)
        SharedState.AllAnimalsCache=allAnimalsCache
    end) end
    local function setupPlotListener(plot) local ch; local retries=0
        while not ch and retries<40 do ch = getChannel(plot.Name); if ch then break else retries=retries+1; task.wait(0.07) end end
        if not ch then return end; scanSinglePlot(plot)
        task.spawn(function() while plot.Parent do task.wait(2); scanSinglePlot(plot) end end)
    end
    local plots=Workspace:WaitForChild("Plots",8)
    if plots then
        for _,p in ipairs(plots:GetChildren()) do task.spawn(setupPlotListener, p) end
        SharedState.InitialScanComplete=true
        plots.ChildAdded:Connect(function(p) task.wait(0.5); task.spawn(setupPlotListener, p) end)
        plots.ChildRemoved:Connect(function(p) lastAnimalData[p.Name]=nil; for i=#allAnimalsCache,1,-1 do if allAnimalsCache[i].plot==p.Name then table.remove(allAnimalsCache,i) end end end)
    end
end)
do
local animPlaying = false
local tracks = {}
local clone, oldRoot, hip, connection
local folderConnections = {}
local function clearAllGhosts()
    pcall(function() for _, c in pairs(Workspace:GetDescendants()) do if c.Name == "LagbackGhost" then c:Destroy() end end end)
end
local function removeFolders()
    local pf = Workspace:FindFirstChild(player.Name)
    if not pf then return end
    local dr = pf:FindFirstChild("DoubleRig")
    if dr then dr:Destroy() end
    local cs = pf:FindFirstChild("Constraints")
    if cs then cs:Destroy() end
    local conn = pf.ChildAdded:Connect(function(child)
        if child.Name == "DoubleRig" then task.defer(function() child:Destroy() end)
        elseif child.Name == "Constraints" then child:Destroy() end
    end)
    table.insert(folderConnections, conn)
end
_G.invisibleStealEnabled = false
_G.InvisStealAngle = Config.InvisStealAngle or 225
_G.SinkSliderValue = Config.SinkSliderValue or 7
_G.AutoRecoverLagback = Config.AutoRecoverLagback ~= nil and Config.AutoRecoverLagback or true
_G.AutoInvisDuringSteal = Config.AutoInvisDuringSteal or false
_G.InvisAntiDie = Config.InvisAntiDie ~= false
local _antiDieConns = {}
local _antiDieFF, _antiDieOrigMax = nil, nil
local function invisStopAntiDie()
    for _, c in ipairs(_antiDieConns) do pcall(function() c:Disconnect() end) end
    _antiDieConns = {}
    if _antiDieFF then pcall(function() _antiDieFF:Destroy() end); _antiDieFF = nil end
    local ch = player.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum and _antiDieOrigMax then
        pcall(function()
            hum.MaxHealth = _antiDieOrigMax
            hum.Health = math.min(hum.Health, _antiDieOrigMax)
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            hum.BreakJointsOnDeath = true
        end)
    end
    _antiDieOrigMax = nil
end
local function invisStartAntiDie()
    invisStopAntiDie()
    if _G.InvisAntiDie == false then return end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.BreakJointsOnDeath = false
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
    _antiDieOrigMax = hum.MaxHealth
    hum.MaxHealth = 999999
    hum.Health = 999999
    pcall(function()
        _antiDieFF = Instance.new("ForceField")
        _antiDieFF.Visible = false
        _antiDieFF.Parent = char
    end)
    _antiDieConns[#_antiDieConns + 1] = RunService.Heartbeat:Connect(function()
        if not animPlaying or _G.InvisAntiDie == false then return end
        if hum and hum.Parent and hum.Health < 1 then hum.Health = 999999 end
    end)
    _antiDieConns[#_antiDieConns + 1] = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if animPlaying and _G.InvisAntiDie ~= false and hum.Health < 1 then hum.Health = 999999 end
    end)
    _antiDieConns[#_antiDieConns + 1] = hum.StateChanged:Connect(function(_, new)
        if not animPlaying or _G.InvisAntiDie == false then return end
        if new == Enum.HumanoidStateType.Dead then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            hum.Health = 999999
        end
    end)
end
local function doClone()
    local character = player.Character
    if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
        hip = character.Humanoid.HipHeight
        oldRoot = character:FindFirstChild("HumanoidRootPart")
        if not oldRoot or not oldRoot.Parent then return false end
        for _, c in pairs(oldRoot:GetChildren()) do
            if c:IsA("Attachment") and (c.Name:find("Beam") or c.Name:find("Attach")) then c:Destroy() end
        end
        for _, c in pairs(oldRoot:GetChildren()) do if c:IsA("Beam") then c:Destroy() end end
        local tmp = Instance.new("Model"); tmp.Parent = game
        character.Parent = tmp
        clone = oldRoot:Clone(); clone.Parent = character
        oldRoot.Parent = Workspace.CurrentCamera
        clone.CFrame = oldRoot.CFrame; character.PrimaryPart = clone
        character.Parent = Workspace
        for _, v in pairs(character:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                if v.Part0 == oldRoot then v.Part0 = clone end
                if v.Part1 == oldRoot then v.Part1 = clone end
            end
        end
        tmp:Destroy(); return true
    end
    return false
end
local function revertClone()
    local character = player.Character
    if not oldRoot or not oldRoot:IsDescendantOf(Workspace) or not character or character.Humanoid.Health <= 0 then return end
    local tmp = Instance.new("Model"); tmp.Parent = game
    character.Parent = tmp
    oldRoot.Parent = character; character.PrimaryPart = oldRoot
    character.Parent = Workspace; oldRoot.CanCollide = true
    for _, v in pairs(character:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("Motor6D") then
            if v.Part0 == clone then v.Part0 = oldRoot end
            if v.Part1 == clone then v.Part1 = oldRoot end
        end
    end
    if clone then local p = clone.CFrame; clone:Destroy(); clone = nil; oldRoot.CFrame = p end
    oldRoot = nil
    if character and character.Humanoid then character.Humanoid.HipHeight = hip end
    clearAllGhosts()
end
local function animationTrickery()
    local character = player.Character
    if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
        local anim = Instance.new("Animation")
        anim.AnimationId = "http://www.roblox.com/asset/?id=18537363391"
        local humanoid = character.Humanoid
        local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
        local animTrack = animator:LoadAnimation(anim)
        animTrack.Priority = Enum.AnimationPriority.Action4
        animTrack:Play(0, 1, 0); anim:Destroy()
        table.insert(tracks, animTrack)
        animTrack.Stopped:Connect(function() if animPlaying then animationTrickery() end end)
        task.delay(0, function()
            animTrack.TimePosition = 0.7
            task.delay(0.3, function() if animTrack then animTrack:AdjustSpeed(math.huge) end end)
        end)
    end
end
local _invisToggleCooldown = 0
local function invisTurnOff()
    clearAllGhosts()
    if not animPlaying then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    animPlaying = false; _G.invisibleStealEnabled = false
    invisStopAntiDie()
    setToggle("Invisible Steal", false)
    for _, t in pairs(tracks) do pcall(function() t:Stop(0) end) end
    tracks = {}
    if connection then connection:Disconnect(); connection = nil end
    for _, c in ipairs(folderConnections) do if c then c:Disconnect() end end
    folderConnections = {}
    revertClone(); clearAllGhosts()
    if humanoid then
        pcall(function()
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if track.Priority == Enum.AnimationPriority.Action4 or track.Priority == Enum.AnimationPriority.Action3 then
                        track:Stop(0)
                    end
                end
            end
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            task.defer(function()
                if humanoid and humanoid.Parent then
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end)
    end
    _invisToggleCooldown = tick()
end
local function invisTurnOn()
    if animPlaying then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    animPlaying = true; _G.invisibleStealEnabled = true
    setToggle("Invisible Steal", true)
    tracks = {}; removeFolders()
    local success = doClone()
    if success then
        invisStartAntiDie()
        task.wait(0.05); animationTrickery()
        local lastSetPosition = nil; local skipFrames = 5
        connection = RunService.PreSimulation:Connect(function()
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 and oldRoot then
                local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                if root then
                    if skipFrames > 0 then skipFrames = skipFrames - 1; lastSetPosition = nil
                    elseif lastSetPosition then
                        local currentPos = oldRoot.Position
                        local jumpDist = (currentPos - lastSetPosition).Magnitude
                        if jumpDist > 6 and not _G.RecoveryInProgress and player:GetAttribute("Stealing") then
                            lastSetPosition = nil
                            if _G.AutoRecoverLagback and _G._forceInvisToggle then
                                _G.RecoveryInProgress = true
                                task.spawn(function()
                                    pcall(_G._forceInvisToggle); task.wait(0.6)
                                    if player:GetAttribute("Stealing") then
                                        pcall(_G._forceInvisToggle)
                                    end
                                    _G.RecoveryInProgress = false
                                end)
                            end
                        end
                    end
                    if clone then clone.CanCollide = true end
                    if oldRoot and oldRoot.Parent then
                        for _, c in pairs(oldRoot:GetChildren()) do
                            if c:IsA("Attachment") or c:IsA("Beam") then c:Destroy() end
                        end
                        local sa = (_G.SinkSliderValue or 7) * 0.5
                        local cf = root.CFrame - Vector3.new(0, sa, 0)
                        oldRoot.CFrame = cf * CFrame.Angles(math.rad(_G.InvisStealAngle or 225), 0, 0)
                        oldRoot.AssemblyLinearVelocity = root.AssemblyLinearVelocity; oldRoot.CanCollide = false
                        lastSetPosition = oldRoot.Position
                    end
                end
            end
        end)
    end
end
_G.toggleInvisibleSteal = function()
    if (tick() - _invisToggleCooldown) < 0.3 then return end
    if animPlaying then invisTurnOff() else invisTurnOn() end
end

-- ===== CARRY SPEED (speed boost while carrying/stealing) — by sammydawg =====
do
    local carryEnabled = false
    local carryConn = nil

    local function csGetSpeed() return Config.CarrySpeedValue or 30 end

    local function csDisable()
        carryEnabled = false
        if carryConn then carryConn:Disconnect(); carryConn = nil end
    end

    local function csEnable()
        carryEnabled = true
        if carryConn then carryConn:Disconnect(); carryConn = nil end
        carryConn = RunService.Heartbeat:Connect(function(dt)
            local char = LocalPlayer.Character
            if not char then return end

            -- only boost while actually carrying/stealing
            if not LocalPlayer:GetAttribute("Stealing") then return end

            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hum or not hrp or hum.Health <= 0 then return end

            local flat = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
            if flat.Magnitude > 1e-3 then
                local extra = csGetSpeed() - hum.WalkSpeed
                if extra > 0 then
                    hrp.CFrame = hrp.CFrame + (flat.Unit * extra * dt)
                end
            end
        end)
    end

    _G.setCarrySpeedEnabled = function(on)
        if on then csEnable() else csDisable() end
    end
    _G.toggleCarrySpeed = function()
        if carryEnabled then csDisable() else csEnable() end
        return carryEnabled
    end
    _G.isCarrySpeedEnabled = function() return carryEnabled end

    -- restore from saved config
    if Config.CarrySpeedEnabled then task.defer(csEnable) end
end
-- ===== fin carry speed =====
_G._forceInvisToggle = function()
    if animPlaying then invisTurnOff() else invisTurnOn() end
end
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.1)
    clearAllGhosts()
    invisStopAntiDie()
    pcall(function() for _, c in pairs(Workspace.CurrentCamera:GetChildren()) do if c:IsA("BasePart") and c.Name == "HumanoidRootPart" then c:Destroy() end end end)
    if oldRoot then pcall(function() oldRoot:Destroy() end); oldRoot = nil end
    if clone then pcall(function() clone:Destroy() end); clone = nil end
    animPlaying = false; _G.invisibleStealEnabled = false
    setToggle("Invisible Steal", false)
    task.wait(0.2)
    local camera = Workspace.CurrentCamera
    if camera and newChar then
        local h = newChar:FindFirstChildOfClass("Humanoid")
        if h then camera.CameraSubject = h; camera.CameraType = Enum.CameraType.Custom end
    end
end)
local function setupDeathListener()
    local ch = player.Character
    if ch then
        local h = ch:FindFirstChildOfClass("Humanoid")
        if h then h.Died:Connect(function() clearAllGhosts() end) end
    end
end
setupDeathListener()
player.CharacterAdded:Connect(function() task.wait(0.1); setupDeathListener() end)
if Config.AutoInvisDuringSteal then
task.spawn(function()
    local wasStealingForInvis = false
    local autoEnabledInvis = false
    while task.wait(0.4) do
            local isStealing = player:GetAttribute("Stealing")
            if isStealing and not wasStealingForInvis then
                if not _G.invisibleStealEnabled and _G._forceInvisToggle then
                    task.defer(function()
                        if player:GetAttribute("Stealing") and not _G.invisibleStealEnabled then
                            pcall(_G._forceInvisToggle)
                            autoEnabledInvis = true
                        end
                    end)
                end
            end
            if not isStealing and autoEnabledInvis and _G.invisibleStealEnabled and _G._forceInvisToggle then
                task.wait(0.3)
                if not player:GetAttribute("Stealing") then
                    pcall(_G._forceInvisToggle)
                    autoEnabledInvis = false
                end
            end
            wasStealingForInvis = isStealing
    end
end)
end
end
selectedTargetUID = nil
manuallySelectedUID = Config.StealTargetUID
if manuallySelectedUID then selectedTargetUID = manuallySelectedUID end
local function saveStealTarget(uid)
    Config.StealTargetUID = uid
    manuallySelectedUID = uid
    selectedTargetUID = uid
    SaveConfig()
end
local function clearStealTarget()
    Config.StealTargetUID = nil
    manuallySelectedUID = nil
    selectedTargetUID = nil
    SharedState.SelectedPetData = nil
    SaveConfig()
end
local function getStealTargetUID()
    return manuallySelectedUID or selectedTargetUID or (SharedState.SelectedPetData and (SharedState.SelectedPetData.uid or (SharedState.SelectedPetData.plot and SharedState.SelectedPetData.slot and (SharedState.SelectedPetData.plot.."_"..tostring(SharedState.SelectedPetData.slot))))) or Config.StealTargetUID
end
local function findPetByUID(pets, uid)
    if not uid then return nil end
    for _, pet in ipairs(pets) do
        if not pet.conveyor and pet.plot and pet.slot then
            if (pet.plot .. "_" .. tostring(pet.slot)) == uid then return pet end
        end
    end
    return nil
end
function setStealMode(mode)
    Config.StealMode = mode
    Config.StealHighest = (mode == "Highest")
    Config.StealPriority = (mode == "Priority")
    Config.StealNearest = (mode == "Nearest")
    SaveConfig()
    setToggle("Steal Highest", Config.StealHighest)
    setToggle("Steal Priority", Config.StealPriority)
    setToggle("Steal Nearest", Config.StealNearest)
end
function get_all_pets()
    local out = {}
    for _, a in ipairs(SharedState.AllAnimalsCache or {}) do
        if a.plot and a.slot then
            out[#out + 1] = {
                uid = a.plot .. "_" .. tostring(a.slot),
                petName = a.name or a.index,
                mpsValue = a.genValue or a.mpsValue or a.mps or 0,
                gen = a.genValue or 0,
                animalData = { plot = a.plot, slot = a.slot, name = a.name or a.index },
            }
        end
    end
    return out
end
local _adorneeCache = setmetatable({}, {__mode="v"})
local _adorneeCacheAt = {}
function findAdorneeGlobal(animalData)
    if not animalData then return nil end
    local _ck = tostring(animalData.plot) .. "_" .. tostring(animalData.slot)
    local _c = _adorneeCache[_ck]
    if _c and _c.Parent and (os.clock() - (_adorneeCacheAt[_ck] or 0)) < 2 then return _c end
    local plot = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild(animalData.plot)
    if plot then
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if podiums then
            local podium = podiums:FindFirstChild(animalData.slot)
            if podium then
                local base = podium:FindFirstChild("Base")
                if base then
                    local spawn = base:FindFirstChild("Spawn")
                    if spawn then _adorneeCache[_ck]=spawn; _adorneeCacheAt[_ck]=os.clock(); return spawn end
                    local _r = base:FindFirstChildWhichIsA("BasePart") or base
                    _adorneeCache[_ck]=_r; _adorneeCacheAt[_ck]=os.clock(); return _r
                end
            end
        end
    end
    return nil
end
corner = function(o,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=o; return c end
tw = function(o,p,t) TweenService:Create(o,TweenInfo.new(t or 0.14,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),p):Play() end
addOutline = function(f) local o=Instance.new("UIStroke"); o.Color=Theme.AccentLight; o.Thickness=1.25; o.Transparency=0.08; o.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; o.Parent=f; return o end
function clearBody(body) for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end end
makeDraggable = function(frame, handle, saveName)
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    local function stopDrag()
        if not dragging then return end
        dragging = false; dragInput = nil
        if saveName then rememberPosition(saveName, frame) end
    end
    handle.InputBegan:Connect(function(input)
        if Config.UILocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            dragInput = input
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if conn then conn:Disconnect() end
                    stopDrag()
                end
            end)
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and not Config.UILocked and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
makeResizable = function(frame, minSize, panelName)
    local h = Instance.new("TextButton")
    h.Size = UDim2.new(0, 16, 0, 16)
    h.Position = UDim2.new(1, -16, 1, -16)
    h.BackgroundTransparency = 1
    h.Text = "+"
    h.TextColor3 = Theme.AccentLight or Color3.new(1, 1, 1)
    h.TextSize = 12
    h.ZIndex = 100
    h.Parent = frame
    local dragging, dragInput, dragStart, startSize = false, nil, nil, nil
    local function stopResize()
        if not dragging then return end
        dragging = false
        dragInput = nil
        if panelName then
            if not Config.sizes then Config.sizes = {} end
            Config.sizes[panelName] = {x = frame.Size.X.Offset, y = frame.Size.Y.Offset}
            SaveConfig()
        end
    end
    h.InputBegan:Connect(function(input)
        if Config.UILocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startSize = frame.AbsoluteSize
            dragInput = input
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if conn then conn:Disconnect() end
                    stopResize()
                end
            end)
        end
    end)
    h.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            stopResize()
        end
    end)
    h.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            stopResize()
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and not Config.UILocked and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - dragStart
            local nx = math.max(minSize.X.Offset, startSize.X + d.X)
            local ny = math.max(minSize.Y.Offset, startSize.Y + d.Y)
            frame.Size = UDim2.new(0, nx, 0, ny)
        end
    end)
end
function makeHeader(f,t,isMain) local h=Instance.new("TextButton"); h.Size=UDim2.new(1,0,0,42); h.BackgroundTransparency=1; h.Text=""; h.AutoButtonColor=false; h.Parent=f
    local parts={}; for s in string.gmatch(t,"([^\n]+)") do table.insert(parts,s) end
    if isMain then local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-50,0,24); l.Position=UDim2.new(0,13,0,8); l.BackgroundTransparency=1; l.Text=parts[1] or "SXE HUB PRIVAT"; l.TextColor3=Theme.Text; l.Font=Enum.Font.GothamBlack; l.TextSize=16; l.TextXAlignment=Enum.TextXAlignment.Left; l.Active=false; l.Parent=h
    else local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-58,0,16); l.Position=UDim2.new(0,12,0,7); l.BackgroundTransparency=1; l.Text=parts[1] or "SXE HUB PRIVAT"; l.TextColor3=Theme.Text; l.Font=Enum.Font.GothamBlack; l.TextSize=12; l.TextXAlignment=Enum.TextXAlignment.Center; l.Active=false; l.Parent=h
        local s=Instance.new("TextLabel"); s.Size=UDim2.new(1,-58,0,13); s.Position=UDim2.new(0,12,0,21); s.BackgroundTransparency=1; s.Text=parts[2] or ""; s.TextColor3=Theme.Dim; s.Font=Enum.Font.GothamMedium; s.TextSize=10; s.TextXAlignment=Enum.TextXAlignment.Center; s.Active=false; s.Parent=h end
    local d=Instance.new("Frame"); d.Size=UDim2.new(1,-24,0,1); d.Position=UDim2.new(0,12,0,40); d.BackgroundColor3=Theme.AccentLight; d.BackgroundTransparency=isMain and 0.25 or 0.04; d.BorderSizePixel=0; d.Parent=f
    makeDraggable(f,h,t); return h end
function makeQuickPanel(t,size,pos) local f=Instance.new("Frame"); f.Size=size; f.Position=pos; f.BackgroundColor3=Theme.Background; f.BackgroundTransparency=0.04; f.BorderSizePixel=0; f.ClipsDescendants=true; f.Parent=gui; corner(f,12); addOutline(f); makeHeader(f,t,false)
    local body=Instance.new("ScrollingFrame"); body.Size=UDim2.new(1,-12,1,-50); body.Position=UDim2.new(0,6,0,46); body.BackgroundTransparency=1; body.BorderSizePixel=0; body.ScrollBarThickness=3; body.ScrollBarImageColor3=Theme.Accent; body.CanvasSize=UDim2.new(0,0,0,0); body.Active=true; body.Parent=f
    local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,6); lay.Parent=body
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() body.CanvasSize=UDim2.new(0,0,0,lay.AbsoluteContentSize.Y+10) end); 
    if Config.sizes and Config.sizes[t] then f.Size = UDim2.new(0, Config.sizes[t].x, 0, Config.sizes[t].y) end
    if not string.find(t, "Admin Command Panel") then makeResizable(f, UDim2.new(0, 150, 0, 150), t) end; return f,body end
function makeSyncStateRow(parent,text,toggleName,callback)
    regToggle(toggleName,getToggle(toggleName))
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,-4,0,34); row.BackgroundTransparency=1; row.Parent=parent
    local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,-84,1,0); label.Position=UDim2.new(0,4,0,0); label.BackgroundTransparency=1; label.Text=text; label.TextColor3=Theme.Text; label.Font=Enum.Font.GothamSemibold; label.TextSize=12; label.TextXAlignment=Enum.TextXAlignment.Left; label.TextTruncate=Enum.TextTruncate.AtEnd; label.Parent=row
    local btn=Instance.new("TextButton"); btn.Name="WhiteTextBtn"; btn.Size=UDim2.new(0,72,0,30); btn.Position=UDim2.new(1,-74,0.5,-15); btn.TextColor3=Color3.new(1,1,1); btn.Font=Enum.Font.GothamBlack; btn.TextSize=12; btn.AutoButtonColor=false; btn.Parent=row; corner(btn,6)
    local function refresh(val) btn.BackgroundColor3=val and Theme.Green or Theme.ToggleOff2; btn.Text=val and "ON" or "OFF" end
    refresh(getToggle(toggleName)); onToggleChanged(toggleName,function(val) refresh(val) end)
    btn.MouseButton1Click:Connect(function() local nv=not getToggle(toggleName); setToggle(toggleName,nv); if callback then callback(nv) end end)
    return function(ns,fire) if typeof(ns)=="boolean" then setToggle(toggleName,ns); if fire~=false and callback then callback(ns) end end end, label
end
function makeQuickButton(parent,text,callback,bg) local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-4,0,36); b.BackgroundColor3=bg or Theme.SoftButton; b.BackgroundTransparency=0.02; b.Text=text; b.TextColor3=Theme.Text; b.Font=Enum.Font.GothamBold; b.TextSize=13; b.AutoButtonColor=false; b.Parent=parent; corner(b,6)
    b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=bg or Theme.SoftButtonHover},0.12) end); b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=bg or Theme.SoftButton},0.12) end)
    b.MouseButton1Click:Connect(function() if callback then callback() end end); return b end
function makeQuickSlider(parent,text,min,max,default,callback,suffix,step) local holder=Instance.new("Frame"); holder.Size=UDim2.new(1,-4,0,50); holder.BackgroundTransparency=1; holder.Parent=parent
    step = step or 0.1
    local stepMult = math.max(1, math.floor((1 / step) + 0.001))
    local function roundVal(v) return math.floor(v * stepMult + 0.5) / stepMult end
    local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,0,0,16); label.Position=UDim2.new(0,4,0,0); label.BackgroundTransparency=1; label.Text=text..": "..tostring(roundVal(default))..(suffix or ""); label.TextColor3=Theme.Text; label.Font=Enum.Font.GothamMedium; label.TextSize=10; label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=holder
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,-10,0,6); bar.Position=UDim2.new(0,4,0,26); bar.BackgroundColor3=Theme.SliderBg; bar.BorderSizePixel=0; bar.Parent=holder; corner(bar,10)
    local fill=Instance.new("Frame"); fill.Size=UDim2.new(math.clamp((default-min)/(max-min),0,1),0,1,0); fill.BackgroundColor3=Theme.Accent; fill.BorderSizePixel=0; fill.Parent=bar; corner(fill,10)
    local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14); knob.AnchorPoint=Vector2.new(0.5,0.5); knob.Position=UDim2.new(math.clamp((default-min)/(max-min),0,1),0,0.5,0); knob.Name = "WhiteSliderKnob"; knob.BackgroundColor3=Color3.fromRGB(255, 255, 255); knob.BorderSizePixel=0; knob.Parent=bar; corner(knob,20)
    local dragging=false
    local function update(x) local rel=math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1); local v=roundVal(min+(max-min)*rel); fill.Size=UDim2.new(rel,0,1,0); knob.Position=UDim2.new(rel,0,0.5,0); label.Text=text..": "..tostring(v)..(suffix or ""); if callback then callback(v) end end
    bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true; update(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then update(i.Position.X) end end)
    local function setVal(v, silent)
        v = roundVal(math.clamp(v, min, max))
        local rel = (v - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        label.Text = text..": "..tostring(v)..(suffix or "")
        if callback and not silent then callback(v) end
    end
    return {Set = setVal}
end
do
    local RS = ReplicatedStorage
    local Synchronizer, AnimalsData, AnimalsShared, NumberUtils
    local function loadModules()
        if Synchronizer then return true end
        local ok = pcall(function()
            local Packages = RS:WaitForChild("Packages", 5)
            local Datas = RS:WaitForChild("Datas", 5)
            local Shared = RS:WaitForChild("Shared", 5)
            local Utils = RS:WaitForChild("Utils", 5)
            Synchronizer = require(Packages:WaitForChild("Synchronizer"))
            AnimalsData = require(Datas:WaitForChild("Animals"))
            AnimalsShared = require(Shared:WaitForChild("Animals"))
            pcall(function() (setupvalue or debug.setupvalue)(AnimalsShared.GetGeneration, 1, function() end) end)
            NumberUtils = require(Utils:WaitForChild("NumberUtils"))
        end)
        return ok and Synchronizer ~= nil
    end
    local NetModule
    local function loadNet()
        if NetModule then return true end
        local ok, mod = pcall(function()
            return require(RS:WaitForChild("Packages", 5):WaitForChild("Net", 5):FindFirstChildWhichIsA("ModuleScript", true))
        end)
        if not ok or type(mod) ~= "table" then return false end
        NetModule = mod
        return true
    end
    local SXESpeed = { CARPET = 400, INBASE = 250 }
    _G.SXESetCarpetSpeed = function(v) v = tonumber(v); if v and v > 0 then SXESpeed.CARPET = v end end
    if Config and Config.TpSettings then
        if tonumber(Config.TpSettings.GrabbleTPSpeed) then SXESpeed.CARPET = tonumber(Config.TpSettings.GrabbleTPSpeed) end
    end
    local CARPET_NAMES = { "Flying Carpet", "Carpet", "Cloud", "Witch's Broom", "Cupid's Wings", "Santa's Sleigh", "Magic Carpet" }
    local function findTool(name)
        local char = player.Character
        local bp = player:FindFirstChild("Backpack")
        return (char and char:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
    end
    local function equipCarpet()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        local preferred = Config and Config.TpSettings and Config.TpSettings.Tool
        if preferred then
            local pt = findTool(preferred)
            if pt and pt:IsA("Tool") then
                if pt.Parent ~= char then pcall(function() hum:EquipTool(pt) end) end
                return preferred
            end
        end
        for _, n in ipairs(CARPET_NAMES) do
            local t = findTool(n)
            if t and t:IsA("Tool") then
                if t.Parent ~= char then pcall(function() hum:EquipTool(t) end) end
                return n
            end
        end
        return nil
    end
    local function carpetEngage()
        if not NetModule then pcall(loadNet) end
        local _t0 = os.clock()
        while not findTool("Grapple Hook") and os.clock() - _t0 < 5 do
            if not NetModule then pcall(loadNet) end
            RunService.Heartbeat:Wait()
        end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum then return nil end
        if not char:FindFirstChild("Grapple Hook") then
            local g = findTool("Grapple Hook")
            if g then pcall(function() hum:EquipTool(g) end) end
        end
        task.wait(0.03)
        if NetModule and player.Character and player.Character:FindFirstChild("Grapple Hook") then
            pcall(function() local _r = getRemote("RemoteEvent","UseItem"); if _r then _r:FireServer(2) end end)
        end
        task.wait(0.06)
        local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:UnequipTools() end) end
        task.wait(0.06)
        local cn
        local _tc = os.clock()
        repeat
            cn = equipCarpet()
            local c = player.Character
            if cn and c and c:FindFirstChild(cn) then break end
            RunService.Heartbeat:Wait()
        until os.clock() - _tc > 1
        return cn
    end
    local PET_PRIORITY_TIERS = {
        [1]  = { pets = {"Headless Horseman"}, threshold = 0 },
        [2]  = { pets = {"Signore Carapace"}, threshold = 0 },
        [3]  = { pets = {"Strawberry Elephant"}, threshold = 0 },
        [4]  = { pets = {"Arcadragon"}, threshold = 0 },
        [5]  = { pets = {"Elefanto Frigo"}, threshold = 5e9 },
        [6]  = { pets = {"John Pork"}, threshold = 10e9 },
        [7]  = { pets = {"Meowl"}, threshold = 5e9 },
        [8]  = { pets = {"Skibidi Toilet"}, threshold = 5e9 },
        [9]  = { pets = {"Love Love Bear"}, threshold = 0 },
        [10] = { pets = {"Antonio"}, threshold = 0 },
        [11] = { pets = {"Pancake and Syrup"}, threshold = 0 },
        [12] = { pets = {"Griffin"}, threshold = 0 },
        [13] = { pets = {"La Supreme Combinasion","Fishino Clownino","Dragon Gingerini","Tirilikalika Tirilikalako"}, threshold = 5e9 },
        [14] = { pets = {"Ginger Gerat","Pet"}, threshold = 10e9 },
        [15] = { pets = {"Hydra Bunny","Digi Narwhal","Kalika Bros"}, threshold = 3e9 },
        [16] = { pets = {"Hydra Dragon Cannelloni","Dragon Cannelloni","Bunny and Eggy"}, threshold = 3e9 },
        [17] = { pets = {"Globa Steppa","Ketupat Bros","Rosey and Teddy","La Casa Boo","Fragola la la"}, threshold = 3e9 },
        [18] = { pets = {"Fragola La La La","Cerberus","Guest 666","Los Hackers"}, threshold = 1e9 },
        [19] = { pets = {"Garama and Madundung","Spooky and Pumpky","Reinito Sleighito","Burguro And Fryuro","Cooki and Milki","Fragrama and Chocrama","La Food Combinasion","Los Amigos","Foxini Lanternini","Capitano Moby","Fortunu and Cashuru","Los Sekolahs","Celestial Pegasus"}, threshold = 750e6 },
        [20] = { pets = {"La Secret Combinasion","Sammyni Fattini","Cloverat Clapat","Popcuru and Fizzuru"}, threshold = 1e9 },
    }
    local TIER_LOOKUP = {}
    for tier, data in pairs(PET_PRIORITY_TIERS) do
        for _, name in ipairs(data.pets) do TIER_LOOKUP[name] = tier end
    end
    local LOCKED_TIERS = { [1]=true,[2]=true,[3]=true,[4]=true }
    local DIRECT_THRESHOLDS = {
        [3] = { [4] = 10e9 },
        [4] = {},
        [5] = { [6] = math.huge },
        [6] = { [9] = math.huge, [10] = math.huge, [12] = 15e9 },
        [10] = { [12] = 20e9 },
        [11] = { [12] = 10e9 },
    }
    local MUTATION_PRIORITY = {
        ["Galaxy"]=1,["Candy"]=1,["Yin Yang"]=1,["YinYang"]=1,["Divine"]=1,
        ["Cursed"]=1,["Lava"]=1,["Radioactive"]=1,["Cyber"]=1,["Rainbow"]=1,["Bloodrot"]=2,
    }
    local MUTATED_BEATS_GRIFFIN = {
        ["Fishino Clownino"]=true,["Globa Steppa"]=true,
        ["La Supreme Combinasion"]=true,["Tirilikalika Tirilikalako"]=true,
    }
    local function getMutPrio(m)
        if not m or m == "" or m == "None" then return 0 end
        if MUTATION_PRIORITY[m] then return MUTATION_PRIORITY[m] end
        local n = tostring(m):lower():gsub("[%s%-_]","")
        if n == "bloodrot" then return 2 end
        if n == "yinyang" or n == "galaxy" or n == "candy" or n == "divine"
            or n == "cursed" or n == "lava" or n == "radioactive" or n == "cyber"
            or n == "rainbow" then return 1 end
        return 0
    end
    local function getCumThreshold(hi, lo)
        if DIRECT_THRESHOLDS[hi] and DIRECT_THRESHOLDS[hi][lo] then return DIRECT_THRESHOLDS[hi][lo] end
        if LOCKED_TIERS[hi] then return math.huge end
        local total = 0
        for t = hi + 1, lo do
            local td = PET_PRIORITY_TIERS[t]
            if td and td.threshold > 0 then total = total + td.threshold end
        end
        return total
    end
    local function petOutranks(aName, bName, aMut, bMut, aMPS, bMPS)
        if aName == "Strawberry Elephant" and bName == "John Pork" then return true end
        if aName == "John Pork" and bName == "Strawberry Elephant" then return false end
        if MUTATED_BEATS_GRIFFIN[aName] and bName == "Griffin" and getMutPrio(aMut) >= 1 then return true end
        if aName == "Griffin" and MUTATED_BEATS_GRIFFIN[bName] and getMutPrio(bMut) >= 1 then return false end
        if aName == "Antonio" and bName == "Elefanto Frigo" and getMutPrio(aMut) >= 1 then return true end
        if aName == "Elefanto Frigo" and bName == "Antonio" and getMutPrio(bMut) >= 1 then return false end
        local tA = TIER_LOOKUP[aName] or 99
        local tB = TIER_LOOKUP[bName] or 99
        if not (TIER_LOOKUP[aName] and TIER_LOOKUP[bName]) then
            if tA == tB then return (aMPS or 0) > (bMPS or 0) end
            return tA < tB
        end
        if tA == tB then
            local pA, pB = getMutPrio(aMut), getMutPrio(bMut)
            if pA ~= pB then return pA > pB end
            return (aMPS or 0) > (bMPS or 0)
        end
        if tA == 4 and tB == 3 then return true end
        if tA == 3 and tB == 4 then return false end
        local hi = math.min(tA, tB)
        local lo = math.max(tA, tB)
        local hiMPS = tA < tB and aMPS or bMPS
        local loMPS = tA < tB and bMPS or aMPS
        local cum = getCumThreshold(hi, lo)
        if cum > 0 and cum ~= math.huge then
            if (loMPS or 0) - (hiMPS or 0) > cum then return tA > tB end
        end
        return tA < tB
    end
    local function getPlotChannel(plotName)
        if _G.stealthGet then local ch = _G.stealthGet(plotName); if ch then return ch end end
        if not Synchronizer then return nil end
        local channel
        pcall(function() channel = Synchronizer:Get(plotName) end)
        if not channel then pcall(function() channel = Synchronizer:Wait(plotName) end) end
        return channel
    end
    local function channelGet(channel, key)
        if not channel then return nil end
        if _G.sProp then local v = _G.sProp(channel, key); if v ~= nil then return v end end
        local v
        pcall(function() if type(channel.Get) == "function" then v = channel:Get(key) end end)
        if v == nil then pcall(function() v = channel.CacheTable and channel.CacheTable[key] end) end
        return v
    end
    local function isMyPlot(channel)
        if not channel then return false end
        local owner = channelGet(channel, "Owner")
        if not owner then return false end
        local result = false
        pcall(function()
            if typeof(owner) == "Instance" and owner:IsA("Player") then
                result = owner.UserId == player.UserId
            elseif type(owner) == "table" and owner.UserId then
                result = owner.UserId == player.UserId
            elseif typeof(owner) == "Instance" then
                result = owner == player
            end
        end)
        return result
    end
    local function ownerInGame(channel)
        if not channel then return false end
        local owner = channelGet(channel, "Owner")
        if not owner then return false end
        local inGame = false
        pcall(function()
            if typeof(owner) == "Instance" and owner:IsA("Player") then
                inGame = Players:FindFirstChild(owner.Name) ~= nil
            elseif type(owner) == "number" then
                inGame = Players:GetPlayerByUserId(owner) ~= nil
            elseif type(owner) == "table" and owner.Name then
                inGame = Players:FindFirstChild(tostring(owner.Name)) ~= nil
            elseif typeof(owner) == "Instance" and owner.Name then
                inGame = Players:FindFirstChild(owner.Name) ~= nil
            end
        end)
        return inGame
    end
    local function isPlotUnlocked(plotName)
        local ok, res = pcall(function()
            local channel = getPlotChannel(plotName)
            if not channel then return false end
            return channelGet(channel, "BlockEndTimeFirstFloor") == nil
        end)
        return ok and (res == true)
    end
    local function getPetPosition(plot, slot)
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then return nil end
        local podium = podiums:FindFirstChild(tostring(slot))
        if not podium then return nil end
        local base = podium:FindFirstChild("Base")
        local spawn = base and base:FindFirstChild("Spawn")
        if spawn and spawn:IsA("BasePart") then return spawn.Position end
        if base then
            local part = base:FindFirstChildWhichIsA("BasePart")
            if part then return part.Position end
        end
        for _, child in ipairs(podium:GetChildren()) do
            if child:IsA("Model") and child.Name ~= "Claim" and child.Name ~= "Base" and child.Name ~= "Decorations" then
                local ok, cf = pcall(function() return child:GetBoundingBox() end)
                if ok then return cf.Position end
            end
        end
        local ok, cf = pcall(function() return podium:GetPivot() end)
        if ok then return cf.Position end
        return podium.Position
    end
    local _BLOCKING_MACHINE_TYPES = { Fuse=true, Duel=true, Trade=true, Crafting=true }
    local function _SXEIsFusing(animalData)
        if type(animalData) ~= "table" then return false end
        local m = animalData.Machine
        if type(m) ~= "table" then return false end
        return _BLOCKING_MACHINE_TYPES[m.Type] == true and m.Active == true
    end
    local _scanCache, _scanCacheAt = nil, 0
    local SCAN_CACHE_TTL = 0.1
    local function scanAllPets(forceRefresh)
        local now = os.clock()
        if not forceRefresh and _scanCache and (now - _scanCacheAt) < SCAN_CACHE_TTL then
            return _scanCache
        end
        local pets = {}
        if not loadModules() then return pets end
        local Plots = workspace:FindFirstChild("Plots")
        if not Plots then return pets end
        for _, plot in ipairs(Plots:GetChildren()) do
            local channel = getPlotChannel(plot.Name)
            if not channel then continue end
            if isMyPlot(channel) then continue end
            if not ownerInGame(channel) then continue end
            local animalList = channelGet(channel, "AnimalList")
            if not animalList then continue end
            for slot, animalData in pairs(animalList) do
                if type(animalData) ~= "table" then continue end
                local animalName = animalData.Index
                if not animalName then continue end
                local animalInfo = AnimalsData and AnimalsData[animalName]
                if not animalInfo then continue end
                if _SXEIsFusing(animalData) then continue end
                local mutation = animalData.Mutation or "None"
                local genValue = 0
                pcall(function()
                    genValue = AnimalsShared:GetGeneration(animalName, animalData.Mutation, animalData.Traits, nil)
                end)
                local displayName = (animalInfo and animalInfo.DisplayName) or animalName
                local pos = getPetPosition(plot, slot)
                if pos then
                    table.insert(pets, {
                        name = displayName, index = animalName, mps = genValue,
                        mutation = mutation, position = pos, plot = plot.Name, slot = tostring(slot),
                    })
                end
            end
        end
        local conveyorFolder = workspace:FindFirstChild("RenderedMovingAnimals")
        if conveyorFolder then
            for _, model in ipairs(conveyorFolder:GetChildren()) do
                pcall(function()
                    if not model:IsA("Model") then return end
                    local animalInfo = AnimalsData and AnimalsData[model.Name]
                    if not animalInfo then return end
                    local mutation = model:GetAttribute("Mutation") or "None"
                    local genValue = 0
                    pcall(function()
                        genValue = AnimalsShared:GetGeneration(model.Name, model:GetAttribute("Mutation"), nil, nil) or 0
                    end)
                    if genValue <= 0 then return end
                    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                    if not part then return end
                    table.insert(pets, {
                        name = animalInfo.DisplayName or model.Name, index = model.Name,
                        mps = genValue, mutation = mutation, position = part.Position,
                        plot = nil, slot = nil, conveyor = true, model = model,
                    })
                end)
            end
        end
        table.sort(pets, function(a, b)
            return petOutranks(a.name, b.name, a.mutation, b.mutation, a.mps, b.mps)
        end)
        _scanCache = pets
        _scanCacheAt = now
        return pets
    end
    local UPPER = {
        B = {{coord=Vector3.new(-487.921448,16.850713,-75.768013),facing="NORTH"},{coord=Vector3.new(-332.379730,16.850722,-75.762100),facing="NORTH"},{coord=Vector3.new(-487.134918,16.850713,-18.094154),facing="SOUTH"},{coord=Vector3.new(-316.300171,16.850713,-17.845898),facing="SOUTH"}},
        C = {{coord=Vector3.new(-330.765381,16.850713,31.424425),facing="NORTH"},{coord=Vector3.new(-502.989349,16.850713,31.172430),facing="NORTH"},{coord=Vector3.new(-489.077087,16.850713,89.010147),facing="SOUTH"},{coord=Vector3.new(-330.908936,16.850713,88.930145),facing="SOUTH"}},
        D = {{coord=Vector3.new(-331.264893,16.850713,138.209167),facing="NORTH"},{coord=Vector3.new(-487.935181,16.850713,138.026321),facing="NORTH"},{coord=Vector3.new(-487.774933,16.850713,195.882538),facing="SOUTH"},{coord=Vector3.new(-330.799133,16.850575,196.022354),facing="SOUTH"}},
    }
    local LOWER = {
        B = {{coord=Vector3.new(-335.725586,-3.048217,-74.984589),facing="NORTH"},{coord=Vector3.new(-503.214233,-3.048217,-75.043137),facing="NORTH"},{coord=Vector3.new(-483.619385,-3.718430,-18.844337),facing="SOUTH"},{coord=Vector3.new(-316.147095,-3.048218,-18.818844),facing="SOUTH"}},
        C = {{coord=Vector3.new(-335.985413,-3.048218,32.051426),facing="NORTH"},{coord=Vector3.new(-503.277008,-3.048217,31.956175),facing="NORTH"},{coord=Vector3.new(-483.749390,-3.048218,88.147003),facing="SOUTH"},{coord=Vector3.new(-315.793823,-3.048217,88.163979),facing="SOUTH"}},
        D = {{coord=Vector3.new(-335.476654,-3.048218,139.001083),facing="NORTH"},{coord=Vector3.new(-503.710083,-3.048218,138.989883),facing="NORTH"},{coord=Vector3.new(-315.654938,-3.048218,195.302444),facing="SOUTH"},{coord=Vector3.new(-483.859253,-3.048218,195.269043),facing="SOUTH"}},
    }
    local UPPER_Y_THRESHOLD = 7
    local TALL_PETS = { ["La Secret Combinasion"]=true, ["La Jolly Grande"]=true }
    local TALL_OFFSET = 3
    local BASES_LOW = {
        [1]=Vector3.new(-476.52,-2,220.94),[2]=Vector3.new(-476.52,-2,113.77),
        [3]=Vector3.new(-476.52,-2,6.18),[4]=Vector3.new(-476.52,-2,-101.07),
        [5]=Vector3.new(-342.66,-2,221.45),[6]=Vector3.new(-342.66,-2,113.41),
        [7]=Vector3.new(-342.66,-2,6.25),[8]=Vector3.new(-342.66,-2,-99.73),
    }
    local BASES_HIGH = {
        [1]=Vector3.new(-479.51,18,220.94),[2]=Vector3.new(-479.51,18,113.77),
        [3]=Vector3.new(-479.51,18,6.18),[4]=Vector3.new(-479.51,18,-101.07),
        [5]=Vector3.new(-339.48,18,221.45),[6]=Vector3.new(-339.48,18,113.41),
        [7]=Vector3.new(-339.48,18,6.25),[8]=Vector3.new(-339.48,18,-99.73),
    }
    local FRONT_Y_LOW = -3.048217
    local FRONT_Y_HIGH = 16.850713
    local COLUMN_SPLIT_X = -410
    local FRONT_Z_CLAMP = 18
    local SIDE_NEAR_Z = 45
    local function getClosestBaseIdx(pos)
        local closest, dist = 1, math.huge
        for i = 1, 8 do
            local b = BASES_LOW[i]
            local d = (pos.X - b.X)^2 + (pos.Z - b.Z)^2
            if d < dist then dist = d; closest = i end
        end
        return closest
    end
    local function buildFrontCandidate(idx, isUpper, playerZ)
        local base = isUpper and BASES_HIGH[idx] or BASES_LOW[idx]
        local frontY = isUpper and FRONT_Y_HIGH or FRONT_Y_LOW
        local frontZ = math.clamp(playerZ - base.Z, -FRONT_Z_CLAMP, FRONT_Z_CLAMP) + base.Z
        local coord = Vector3.new(base.X, frontY, frontZ)
        local faceDir = (idx <= 4) and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
        return coord, faceDir
    end
    local function plotSides(coordTable, idx)
        local base = BASES_LOW[idx]
        local isWest = idx <= 4
        local out = {}
        for _, coords in pairs(coordTable) do
            for _, data in ipairs(coords) do
                if ((data.coord.X < COLUMN_SPLIT_X) == isWest)
                   and math.abs(data.coord.Z - base.Z) < SIDE_NEAR_Z then
                    out[#out + 1] = data
                end
            end
        end
        return out
    end
    local function findClosest(petPos, coordTable)
        local best, bestKey, bestDist = nil, nil, math.huge
        for skyKey, coords in pairs(coordTable) do
            for _, data in ipairs(coords) do
                local c = data.coord
                local d = math.sqrt((petPos.X - c.X)^2 + (petPos.Z - c.Z)^2)
                if d < bestDist then bestDist = d; best = data; bestKey = skyKey end
            end
        end
        return best, bestKey
    end
    local ARRIVE = 3
    local function vZero(hrp)
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero end
    end
    local function setDirectVelocity(hrp, diff, speed)
        local mag = diff.Magnitude
        if mag < 0.1 then return end
        hrp.AssemblyLinearVelocity = (diff / mag) * speed
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    local function velGlideTo(hrp, goal, speed, faceDir, arriveDist)
        if not hrp or not hrp.Parent or not goal then return end
        pcall(equipCarpet)
        vZero(hrp)
        local arrive = arriveDist or 4
        local t0, lastDist, stall = os.clock(), math.huge, 0
        while hrp.Parent and os.clock() - t0 < 12 do
            pcall(equipCarpet)
            local diff = goal - hrp.Position
            local mag = diff.Magnitude
            if mag < arrive then break end
            if faceDir then
                pcall(function() hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + faceDir) end)
            end
            if mag > lastDist - 0.05 then stall = stall + 1 else stall = 0 end
            lastDist = mag
            if stall >= 25 then break end
            setDirectVelocity(hrp, diff, speed)
            RunService.Heartbeat:Wait()
        end
        vZero(hrp)
    end
    local function velMoveThrough(hrp, waypoints, speedOverride, allowJump, quickStart, rampMode)
        if not hrp or not hrp.Parent or #waypoints == 0 then return end
        local _runSpeed = speedOverride or SXESpeed.CARPET
        local wpIdx = 1
        local done = false
        local conn
        local function finish()
            if done then return end
            done = true
            if hrp and hrp.Parent and waypoints[#waypoints] then
                vZero(hrp)
                if not rampMode then
                    local _, y = hrp.CFrame:ToEulerAnglesYXZ()
                    hrp.CFrame = CFrame.new(waypoints[#waypoints]) * CFrame.Angles(0, y, 0)
                end
            end
            if conn then conn:Disconnect() end
        end
        local lastDist, stall = math.huge, 0
        if quickStart and #waypoints > 3 then
            local _hp = RaycastParams.new()
            _hp.FilterType = Enum.RaycastFilterType.Exclude
            _hp.IgnoreWater = true
            local _skip = {}
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Character then _skip[#_skip + 1] = pl.Character end
            end
            _hp.FilterDescendantsInstances = _skip
            for _ = 1, 3 do
                local target = waypoints[wpIdx]
                if not target then break end
                local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
                local mag = flat.Magnitude
                if mag < 1 then break end
                local nextPos = hrp.Position + flat.Unit * math.min(20, mag)
                local _hit = Workspace:Raycast(hrp.Position, nextPos - hrp.Position, _hp)
                if _hit and _hit.Instance and _hit.Instance.CanCollide then break end
                hrp.CFrame = (hrp.CFrame - hrp.CFrame.Position) + nextPos
                vZero(hrp)
                RunService.Heartbeat:Wait()
                if not hrp or not hrp.Parent then return end
            end
        end
        conn = RunService.Heartbeat:Connect(function()
            if not hrp or not hrp.Parent or done then
                if conn then conn:Disconnect() end
                return
            end
            equipCarpet()
            local target = waypoints[wpIdx]
            local diff = target - hrp.Position
            local mag = diff.Magnitude
            local arriveDist = rampMode and 5 or ARRIVE
            if mag < arriveDist then
                wpIdx = wpIdx + 1
                if wpIdx > #waypoints then finish(); return end
                lastDist, stall = math.huge, 0
                target = waypoints[wpIdx]
                diff = target - hrp.Position
                mag = diff.Magnitude
            end
            if mag > lastDist - 0.05 then stall = stall + 1 else stall = 0 end
            lastDist = mag
            if stall >= 18 then finish(); return end
            if mag >= 0.1 then
                if allowJump and diff.Y > 5 and wpIdx < #waypoints then
                    local hum = hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local st = hum:GetState()
                        if st ~= Enum.HumanoidStateType.Jumping and st ~= Enum.HumanoidStateType.Freefall then
                            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
                            pcall(function() hum.Jump = true end)
                        end
                    end
                end
                setDirectVelocity(hrp, diff, _runSpeed)
            end
        end)
        local totalDist = 0
        local prev = hrp.Position
        for _, wp in ipairs(waypoints) do
            totalDist = totalDist + (prev - wp).Magnitude
            prev = wp
        end
        local timeout = totalDist / math.max(_runSpeed, 1) + 2
        local elapsed = 0
        while not done and elapsed < timeout do
            task.wait(0.05)
            elapsed = elapsed + 0.05
        end
        finish()
        vZero(hrp)
    end
    local _DIRS = { Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1) }
    local _STRUCT = { ["structure base home"]=true, ["Wall"]=true, ["Floor"]=true, ["Roof"]=true }
    local _SKIP_NAME = { ["DeliveryHitbox"]=true, ["StealHitbox"]=true, ["LaserHitbox"]=true,
        ["AnimalTarget"]=true, ["Multiplier"]=true, ["Laser"]=true, ["Hitbox"]=true,
        ["Spawn"]=true, ["MainRoot"]=true, ["SecondFloor"]=true, ["ThirdFloor"]=true, ["Slope"]=true }
    local function _blocks(inst)
        if not inst then return false end
        if _SKIP_NAME[inst.Name] then return false end
        if inst.CanCollide then return true end
        if _STRUCT[inst.Name] then return true end
        local s = inst.Size
        if s and math.max(s.X * s.Y, s.X * s.Z, s.Y * s.Z) > 150 then return true end
        return false
    end
    local function _blocksWide(inst)
        if not inst then return false end
        if _SKIP_NAME[inst.Name] then return false end
        if inst.CanCollide then return true end
        if _STRUCT[inst.Name] then return true end
        local s = inst.Size
        if s and math.max(s.X * s.Y, s.X * s.Z, s.Y * s.Z) > 30 then return true end
        return false
    end
    local function _block(origin, target, blockFn)
        blockFn = blockFn or _blocks
        local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude; rp.IgnoreWater = true
        local skip = {}
        for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then skip[#skip + 1] = pl.Character end end
        local o = origin
        for _ = 1, 16 do
            rp.FilterDescendantsInstances = skip
            local d = target - o; if d.Magnitude < 0.05 then return nil end
            local res = workspace:Raycast(o, d, rp)
            if not res then return nil end
            if blockFn(res.Instance) then return res end
            skip[#skip + 1] = res.Instance; o = res.Position + d.Unit * 0.3
        end
        return nil
    end
    local function _clear(a, b) return _block(a, b) == nil end
    local function _clearWideRay(a, b) return _block(a, b, _blocksWide) == nil end
    local function _clearWide(a, b)
        if not _clear(a, b) then return false end
        local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
        if d.Magnitude < 0.1 then return true end
        local _CLEARANCE = 10
        local perp = Vector3.new(-d.Z, 0, d.X).Unit * _CLEARANCE
        local up = Vector3.new(0, _CLEARANCE, 0)
        return _clearWideRay(a + perp, b + perp) and _clearWideRay(a - perp, b - perp)
            and _clearWideRay(a + up, b + up) and _clearWideRay(a - up, b - up)
    end
    local function _pullWide(pts)
        if #pts <= 2 then return pts end
        local out = { pts[1] }; local i = 1
        while i < #pts do
            local j = #pts
            while j > i + 1 and not _clearWide(out[#out], pts[j]) do j = j - 1 end
            out[#out + 1] = pts[j]; i = j
        end
        return out
    end
    local function _pushOffWalls(pts)
        if #pts <= 2 then return pts end
        local MARGIN = 10; local MAX_PUSH = 14
        local out = { pts[1] }
        for i = 2, #pts - 1 do
            local p = pts[i]; local shift = Vector3.zero
            for _, dr in ipairs(_DIRS) do
                local res = _block(p, p + dr * MARGIN, _blocks)
                if res then
                    local dist = (res.Position - p).Magnitude
                    if dist < MARGIN then shift = shift - dr * (MARGIN - dist) end
                end
            end
            if shift.Magnitude > 0.1 then
                if shift.Magnitude > MAX_PUSH then shift = shift.Unit * MAX_PUSH end
                local moved = p + shift
                if _clear(out[#out], moved) then out[#out + 1] = moved else out[#out + 1] = p end
            else
                out[#out + 1] = p
            end
        end
        out[#out + 1] = pts[#pts]
        return out
    end
    local PathfindingService = game:GetService("PathfindingService")
    local function computeRoute(fromPos, toPos, facingDir)
        if _clear(fromPos, toPos) then return { toPos } end
        local entry = facingDir and (toPos - facingDir * 14) or toPos
        local groundTo = Vector3.new(entry.X, fromPos.Y, entry.Z)
        local path = PathfindingService:CreatePath({
            AgentRadius = 12, AgentHeight = 5, AgentCanJump = true, AgentJumpHeight = 10, AgentMaxSlope = 89,
        })
        local FLOAT = 3
        local nav = { fromPos }
        local ok = pcall(function()
            path:ComputeAsync(Vector3.new(fromPos.X, fromPos.Y, fromPos.Z), groundTo)
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            local last = fromPos
            for _, wp in ipairs(path:GetWaypoints()) do
                if (wp.Position - last).Magnitude >= 60 then
                    nav[#nav + 1] = wp.Position + Vector3.new(0, FLOAT, 0); last = wp.Position
                end
            end
        end
        nav[#nav + 1] = entry + Vector3.new(0, FLOAT, 0)
        nav = _pushOffWalls(nav)
        local route = _pullWide(nav)
        route = _pullWide(route)
        route[#route + 1] = toPos
        return route
    end
    local function buildApproachWaypoints(fromPos, destPos, facingDir)
        local startY, destY = fromPos.Y, destPos.Y
        local upperApproach = destY > 10 and startY < destY - 3
        if not upperApproach and _clearWide(fromPos, destPos) then return { destPos }, true end
        local route = _pullWide(computeRoute(fromPos, destPos, facingDir))
        if #route <= 2 and not upperApproach then return route, false end
        if math.abs(destY - startY) < 2 and not upperApproach then return route, false end
        local prev, totalFlat = fromPos, 0
        for _, wp in ipairs(route) do
            totalFlat = totalFlat + (Vector3.new(wp.X, 0, wp.Z) - Vector3.new(prev.X, 0, prev.Z)).Magnitude
            prev = wp
        end
        if totalFlat < 0.01 then totalFlat = 0.01 end
        local stepped, travelled, SEG = {}, 0, upperApproach and 28 or 55
        prev = fromPos
        for _, wp in ipairs(route) do
            local flatVec = Vector3.new(wp.X, 0, wp.Z) - Vector3.new(prev.X, 0, prev.Z)
            local legFlat = flatVec.Magnitude
            if legFlat >= 0.01 then
                local subs = math.max(1, math.ceil(legFlat / SEG))
                for s = 1, subs do
                    local f = s / subs
                    local along = travelled + legFlat * f
                    stepped[#stepped + 1] = Vector3.new(
                        prev.X + (wp.X - prev.X) * f,
                        startY + (destY - startY) * (along / totalFlat),
                        prev.Z + (wp.Z - prev.Z) * f
                    )
                end
            else
                stepped[#stepped + 1] = wp
            end
            travelled = travelled + legFlat
            prev = wp
        end
        if #stepped > 0 then stepped[#stepped] = destPos end
        return stepped, true
    end
    local function doClone()
        if not NetModule then pcall(loadNet) end
        local char = player.Character or player.CharacterAdded:Wait()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum then return false end
        local cloner = (player:FindFirstChild("Backpack") and player.Backpack:FindFirstChild("Quantum Cloner"))
                    or char:FindFirstChild("Quantum Cloner")
        if not cloner then return false end
        if cloner.Parent ~= char then
            pcall(function() hum:EquipTool(cloner) end)
            task.wait()
        end
        if not NetModule then return false end
        local useOk = pcall(function() local _r = getRemote("RemoteEvent","UseItem"); if _r then _r:FireServer() end end)
        task.wait(0.05)
        local telOk = pcall(function() local _r = getRemote("RemoteEvent","QuantumCloner/OnTeleport"); if _r then _r:FireServer() end end)
        return useOk and telOk
    end
    local function carpetGlideTo(targetPos)
        if not targetPos then return end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        pcall(function() hrp.Anchored = false end)
        pcall(equipCarpet)
        local SPEED = (Config.TpSettings and (tonumber(Config.TpSettings.WalkTPSpeed) or tonumber(Config.TpSettings.GrabbleTPSpeed))) or 190
        local FLOAT_OFFSET = (targetPos.Y > 20) and -4 or 0
        local goal = Vector3.new(targetPos.X, targetPos.Y + FLOAT_OFFSET, targetPos.Z)
        local t0 = os.clock()
        local lastDist, stall = math.huge, 0
        while hrp.Parent and (os.clock() - t0) < 8 do
            if player:GetAttribute("Stealing") then break end
            equipCarpet()
            local diff = goal - hrp.Position
            local mag = diff.Magnitude
            if mag < 3 then break end
            if mag > lastDist - 0.05 then stall = stall + 1 else stall = 0 end
            lastDist = mag
            if stall >= 30 then break end
            setDirectVelocity(hrp, diff, SPEED)
            RunService.Heartbeat:Wait()
        end
        vZero(hrp)
    end
    local function brainrotTargetPos(petPos, hrp)
        local h = petPos.Y
        local targetY = hrp and hrp.Position.Y or petPos.Y
        if h >= 19 then targetY = math.clamp(petPos.Y - 2.5, 20.5, 22.5)
        elseif h >= 11 then targetY = 14.5
        elseif h >= -6.9 and h <= 8.9 then targetY = -4 end
        return Vector3.new(petPos.X, targetY, petPos.Z)
    end
    local function goToBrainrot(petPos, afterClone)
        if not petPos then return end
        local char, hrp, hum
        local _t0 = os.clock()
        repeat
            char = player.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            hum = char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum then break end
            RunService.Heartbeat:Wait()
        until os.clock() - _t0 > 3
        if not hrp or not hum then return end
        pcall(function() hrp.Anchored = false end)
        if not afterClone then
        local _equipped = false
        do
            local _e0 = os.clock()
            repeat
                char = player.Character
                for _, _cn in ipairs(CARPET_NAMES) do
                    if char and char:FindFirstChild(_cn) then _equipped = true; break end
                end
                if _equipped then break end
                equipCarpet()
                RunService.Heartbeat:Wait()
            until _equipped or os.clock() - _e0 > 1.5
            if _equipped then task.wait(0.2) end
        end
        char = player.Character
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp then return end
        pcall(function() hrp.Anchored = false end)
        local _plotRad = (petPos.Y <= 8.9) and 26 or 25
        do
            local _t0b = os.clock()
            repeat
                local p = hrp.Position
                local inRad = false
                local plotsFolder = workspace:FindFirstChild("Plots")
                if plotsFolder then
                    for _, plot in ipairs(plotsFolder:GetChildren()) do
                        pcall(function()
                            local pp = plot:GetPivot().Position
                            if math.abs(p.X - pp.X) < _plotRad and math.abs(p.Z - pp.Z) < _plotRad then inRad = true end
                        end)
                        if inRad then break end
                    end
                end
                if inRad then break end
                RunService.Heartbeat:Wait()
            until os.clock() - _t0b > 1.5
        end
        else
            equipCarpet()
            RunService.Heartbeat:Wait()
        end
        local _to = brainrotTargetPos(petPos, hrp)
        local _spd = (Config and Config.TpSettings and (tonumber(Config.TpSettings.WalkTPSpeed) or tonumber(Config.TpSettings.GrabbleTPSpeed))) or SXESpeed.INBASE
        if Config.TpSettings and Config.TpSettings.BrainrotCarpet then
            carpetGlideTo(petPos)
        elseif afterClone then
            velGlideTo(hrp, _to, _spd, nil, 2)
            if hrp and hrp.Parent and _to.Y >= 19 then
                if hrp.Position.Y < _to.Y - 0.4 then
                    hrp.CFrame = CFrame.new(Vector3.new(hrp.Position.X, _to.Y, hrp.Position.Z))
                    vZero(hrp)
                end
            end
            if hrp and hrp.Parent then
                local grabTo = Vector3.new(petPos.X, _to.Y, petPos.Z)
                local flatDist = (Vector3.new(hrp.Position.X, 0, hrp.Position.Z) - Vector3.new(petPos.X, 0, petPos.Z)).Magnitude
                if flatDist > 1.2 then
                    velGlideTo(hrp, grabTo, math.min(_spd, 140), nil, 0.8)
                end
                pcall(function()
                    hrp.CFrame = CFrame.new(grabTo)
                    vZero(hrp)
                end)
            end
        else
            local _route = computeRoute(hrp.Position, _to, nil)
            if not _route or #_route == 0 then _route = { _to } end
            velMoveThrough(hrp, _route, _spd, true, true)
        end
        if hrp and hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        do
            local _platPos = (hrp and hrp.Parent and hrp.Position) or _to
            local _feetY = _platPos.Y - 3
            local _plat = Instance.new("Part")
            _plat.Name = "SXETempPlatform"; _plat.Size = Vector3.new(8, 1, 8)
            _plat.Position = Vector3.new(petPos.X, _feetY - 1.5, petPos.Z)
            _plat.Anchored = true; _plat.CanCollide = false; pcall(makeOneWay, _plat); _plat.Transparency = 1
            _plat.Material = Enum.Material.SmoothPlastic; _plat.Parent = workspace
            task.spawn(function()
                local _s = tick()
                while tick() - _s < 20 do
                    if player:GetAttribute("Stealing") then break end
                    task.wait(0.1)
                end
                if _plat and _plat.Parent then _plat:Destroy() end
            end)
        end
    end
    local InternalStealCache = {}
    local STEAL_HOLD_DURATION = 1.3
    local _stealHoldStart = 0
    local _stealHoldActive = false
    local function buildStealCallbacks(prompt)
        if InternalStealCache[prompt] then return end
        if not prompt or not prompt.Parent then return end
        local data = { holdCallbacks = {}, triggerCallbacks = {}, holdEndCallbacks = {}, ready = true }
        local function grab(sig, into)
            local ok, conns = pcall(getconnections, sig)
            if ok and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    if type(c.Function) == "function" then table.insert(into, c.Function) end
                end
            end
        end
        grab(prompt.PromptButtonHoldBegan, data.holdCallbacks)
        grab(prompt.Triggered, data.triggerCallbacks)
        grab(prompt.PromptButtonHoldEnded, data.holdEndCallbacks)
        if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 or #data.holdEndCallbacks > 0 then
            InternalStealCache[prompt] = data
        end
    end
    local function executeStealAsync(prompt)
        local data = InternalStealCache[prompt]
        if not data or not data.ready then return false end
        data.ready = false
        _stealHoldStart = tick()
        _stealHoldActive = true
        _G.SXE_StealStatus = _G.SXE_StealStatus or {}
        _G.SXE_StealStatus.active = true
        -- continuite de la barre : on garde le fillStart du TP s'il existe
        _G.SXE_StealStatus.start = _G.SXE_StealStatus.fillStart or _stealHoldStart
        _G.SXE_StealStatus.duration = STEAL_HOLD_DURATION
        task.spawn(function()
            for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
            pcall(function()
                local _st = prompt:GetAttribute("State")
                if _st ~= nil and _st ~= "Steal" then
                    if not _G._xenStealRemote then
                        local _net = _G.XenNet or require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Net"):FindFirstChildWhichIsA("ModuleScript", true))
                        _G._xenStealRemote = getRemote("RemoteEvent","f40f7d9e-2f0d-4167-b250-899273f46874")
                    end
                    local r = _G._xenStealRemote
                    if r then
                        local _t = workspace:GetServerTimeNow() + 124
                        r:FireServer(_t, "68c86eb7-eb7e-4b4d-96ae-cf7cd847c5b0")
                        r:FireServer(_t, "07b9cc25-2a1f-4a26-a0ec-f2fab578d8bd")
                    end
                end
            end)
            local remain = STEAL_HOLD_DURATION - (tick() - _stealHoldStart)
            if remain > 0 then task.wait(remain) end
            if prompt and prompt.Parent then
                for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
            end
            for _, fn in ipairs(data.holdEndCallbacks) do task.spawn(fn) end
            _stealHoldActive = false
            if _G.SXE_StealStatus then _G.SXE_StealStatus.active = false end
            task.wait(0.05)
            data.ready = true
        end)
        return true
    end
    local function findStealPrompt(pet)
        if pet.plot and pet.slot then
            local plots = workspace:FindFirstChild("Plots")
            local plot = plots and plots:FindFirstChild(pet.plot)
            local podiums = plot and plot:FindFirstChild("AnimalPodiums")
            local podium = podiums and podiums:FindFirstChild(tostring(pet.slot))
            if podium then
                local base = podium:FindFirstChild("Base")
                local spawn = base and base:FindFirstChild("Spawn")
                local attach = spawn and spawn:FindFirstChild("PromptAttachment")
                if attach then
                    for _, p in ipairs(attach:GetChildren()) do
                        if p:IsA("ProximityPrompt") then return p end
                    end
                end
                for _, d in ipairs(podium:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then return d end
                end
            end
        end
        if pet.model and pet.model.Parent then
            for _, d in ipairs(pet.model:GetDescendants()) do
                if d:IsA("ProximityPrompt") then return d end
            end
        end
        return nil
    end
    local STEAL_PROXIMITY = 60
    local STEAL_ARM_TIMEOUT = 25
    local _stealTarget = nil
    local _stealArmedAt = 0
    local function timeUntilCanSteal()
        if player:GetAttribute("Stealing") or player:GetAttribute("IsTrading")
            or player:GetAttribute("IsDuelSelecting") or player:GetAttribute("Web") then
            return -1
        end
        return 0
    end
    local function _pickByMode(pets)
        if not pets or #pets == 0 then return nil end
        local C = Config or {}
        local priorityMode = C.AutoTPPriority or (C.StealMode == "Priority")
        if priorityMode and priorityList and #priorityList > 0 then
            for _, pName in ipairs(priorityList) do
                local searchName = pName:lower()
                for _, p in ipairs(pets) do
                    if (p.name and p.name:lower() == searchName) or (p.index and p.index:lower() == searchName) then
                        return p
                    end
                end
            end
        end
        if C.AutoTPHighestGen or C.AutoTPHighestValue or (C.StealMode == "Highest") then
            local best, bv
            for _, p in ipairs(pets) do
                local v = p.mps or 0
                if not bv or v > bv then bv, best = v, p end
            end
            return best
        end
        return pets[1]
    end
    local function _samePet(a, b)
        if not a or not b then return false end
        return a.plot == b.plot and tostring(a.slot) == tostring(b.slot)
    end
    local function pickStealPet(allPets, hrp, fallbackFirst, allowConveyorManual)
        local pet
        if manuallySelectedUID then
            for _, p in ipairs(allPets) do
                if p.plot and p.slot and (p.plot .. "_" .. tostring(p.slot)) == manuallySelectedUID then
                    if allowConveyorManual or not p.conveyor then pet = p; break end
                end
            end
        end
        if not pet then pet = findPetByUID(allPets, getStealTargetUID()) end
        if pet then return fallbackFirst and (pet or allPets[1]) or pet end
        local mode = (Config and Config.StealMode) or "Priority"
        if mode == "Nearest" and hrp then
            local bd
            for _, p in ipairs(allPets) do
                if not p.conveyor then
                    local prompt = findStealPrompt(p)
                    if prompt and prompt.Parent then
                        local pp = prompt.Parent
                        local ppPos = (pp:IsA("BasePart") and pp.Position) or (pp.Parent and pp.Parent:IsA("BasePart") and pp.Parent.Position)
                        if ppPos then
                            local d = (hrp.Position - ppPos).Magnitude
                            if not bd or d < bd then bd, pet = d, p end
                        end
                    end
                end
            end
        else
            local nc = {}
            for _, p in ipairs(allPets) do if not p.conveyor then nc[#nc + 1] = p end end
            pet = _pickByMode(nc)
        end
        return fallbackFirst and (pet or allPets[1]) or pet
    end
    local function armSteal(pet)
        if not pet then return end
        _stealTarget = pet; _stealArmedAt = os.clock()
        _G.SXE_StealStatus = _G.SXE_StealStatus or {}
        if _G.SXE_StealStatus.target ~= pet then
            _G.SXE_StealStatus.fillStart = tick()
        end
        _G.SXE_StealStatus.target = pet
    end
    local function disarmSteal()
        _stealTarget = nil
        _G.SXE_StealStatus = _G.SXE_StealStatus or {}
        _G.SXE_StealStatus.target = nil
        _G.SXE_StealStatus.active = false
    end
    local AUTO_STEAL = (Config and Config.AutoStealEnabled) and true or false
    _G.SXEAutoSteal = function(on) AUTO_STEAL = on ~= false end
    local _stealLastScan = 0
    local _autoLastScan = 0
    local isTeleporting = false
    local _tpStartedAt = 0
    local _cloneTP = false
    local _cloneFired = false
    local _started = false
    local _lastTPOk = false
    local function endTP()
        isTeleporting = false
        if _G.SXE_StealStatus then _G.SXE_StealStatus.visualTarget = nil; _G.SXE_StealStatus.fillStart = nil end
        _G.SXEIsTeleporting = false
    end
    RunService.Heartbeat:Connect(function()
        if not (_started or loadModules()) then return end
        local now = os.clock()
        if AUTO_STEAL and not player:GetAttribute("Stealing")
            and not isTeleporting
            and (now - _autoLastScan) >= 0.1 then
            _autoLastScan = now
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local ok, pets = pcall(scanAllPets, false)
                if ok and pets then
                    local best = pickStealPet(pets, hrp, false, false)
                    if best then
                        if not _samePet(best, _stealTarget) then armSteal(best) end
                    elseif _stealTarget and not _stealHoldActive then
                        disarmSteal()
                    end
                end
            end
        end
        local pet = _stealTarget
        if not pet then return end
        local STEAL_MODE = (Config and Config.StealMode) or "Priority"
        if STEAL_MODE == "Nearest" and now - _stealArmedAt > STEAL_ARM_TIMEOUT then
            disarmSteal(); return
        end
        if now - _stealLastScan < 0.067 then return end
        _stealLastScan = now
        local t = timeUntilCanSteal()
        if t == -1 then
            if player:GetAttribute("Stealing") then disarmSteal() end
            return
        end
        if t > 0 and t > STEAL_HOLD_DURATION then return end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local prompt = findStealPrompt(pet)
        if not prompt or not prompt.Parent then return end
        local pp = prompt.Parent
        local ppPos = (pp and pp:IsA("BasePart") and pp.Position)
            or (pp and pp.Parent and pp.Parent:IsA("BasePart") and pp.Parent.Position)
        local _inCloneTP = isTeleporting and _cloneTP and _cloneFired
        if not _inCloneTP and ppPos and (hrp.Position - ppPos).Magnitude > STEAL_PROXIMITY then return end
        local oldMax
        pcall(function() oldMax = prompt.MaxActivationDistance end)
        pcall(function() prompt.MaxActivationDistance = math.huge end)
        buildStealCallbacks(prompt)
        if InternalStealCache[prompt] then executeStealAsync(prompt) end
        pcall(function() if oldMax ~= nil then prompt.MaxActivationDistance = oldMax end end)
    end)
    local function healLock(hum)
        local maxHP = hum.MaxHealth; hum.Health = maxHP
        local conn; conn = RunService.Heartbeat:Connect(function()
            if not hum or not hum.Parent or hum.Health <= 0 then conn:Disconnect(); return end
            hum.Health = maxHP
        end); return conn
    end
    local function doVelocityTP()
        if isTeleporting and (os.clock() - _tpStartedAt) < 30 then return end
        _lastTPOk = false
        isTeleporting = true
        _G.SXEIsTeleporting = true
        _tpStartedAt = os.clock()
        _cloneTP = false
        _cloneFired = false
        if not NetModule then pcall(loadNet) end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then endTP(); return false end
        local allPets = scanAllPets(true)
        if #allPets == 0 then
            local _t0 = os.clock()
            while #allPets == 0 and os.clock() - _t0 < 4 do
                task.wait(0.15)
                allPets = scanAllPets(true)
            end
        end
        if #allPets == 0 then endTP(); return false end
        local pet = pickStealPet(allPets, hrp, true, true)
        if not pet or not pet.position then endTP(); return false end
        if pet then pcall(armSteal, pet) end
        local _tpSpd = (Config and Config.TpSettings and Config.TpSettings.GrabbleTPSpeed) or 400
        local _cloneDelay = (Config and Config.TpSettings and Config.TpSettings.CloneDelayVal) or 0.35
        local petPos = pet.position
        local petName = pet.name
        local adjY = petPos.Y
        if TALL_PETS[petName] then adjY = petPos.Y - TALL_OFFSET end
        local coordTable = adjY > UPPER_Y_THRESHOLD and UPPER or LOWER
        if pet.conveyor then
            local model = pet.model
            local healConn = healLock(hum)
            carpetEngage()
            vZero(hrp)
            local function livePos()
                if not model or not model.Parent then return nil end
                local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
                return part and part.Position or nil
            end
            local _t0 = os.clock()
            local lastDist, stall = math.huge, 0
            while os.clock() - _t0 < 8 do
                if not hrp or not hrp.Parent then break end
                local lp = livePos()
                if not lp then break end
                local diff = lp - hrp.Position
                if diff.Magnitude <= 6 then break end
                equipCarpet()
                if diff.Magnitude > lastDist - 0.05 then stall = stall + 1 else stall = 0 end
                lastDist = diff.Magnitude
                if stall >= 30 then break end
                setDirectVelocity(hrp, diff, _tpSpd)
                RunService.Heartbeat:Wait()
            end
            vZero(hrp)
            healConn:Disconnect()
            _lastTPOk = true
            endTP()
            return true
        end
        if petPos.Y <= 8.9 and isPlotUnlocked(pet.plot) then
            local healConn = healLock(hum)
            carpetEngage()
            vZero(hrp)
            local _to = Vector3.new(petPos.X, -4, petPos.Z)
            local _faceDir
            do
                local idx = getClosestBaseIdx(petPos)
                local _, frontFace = buildFrontCandidate(idx, false, hrp.Position.Z)
                _faceDir = frontFace
            end
            local route = _pullWide(computeRoute(hrp.Position, _to, _faceDir))
            if not route or #route == 0 then route = { _to } end
            if #route == 1 and _clearWide(hrp.Position, _to) then
                velGlideTo(hrp, _to, _tpSpd, _faceDir)
            else
                velMoveThrough(hrp, route, _tpSpd, true, #route > 3, false)
            end
            if hrp and hrp.Parent then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
            healConn:Disconnect()
            _lastTPOk = true
            endTP()
            return true
        end
        _cloneTP = true
        _G.SXE_StealStatus = _G.SXE_StealStatus or {}
        if not _G.SXE_StealStatus.fillStart then _G.SXE_StealStatus.fillStart = tick() end
        _G.SXE_StealStatus.visualTarget = pet
        -- garder la cible armee pendant le clone-TP pour permettre le vol a distance (_inCloneTP)
        _stealTarget = pet
        _G.SXE_StealStatus.target = pet
        local closestData, skyKey = findClosest(petPos, coordTable)
        if not closestData or not skyKey then endTP(); return false end
        local destPos = closestData.coord
        local healConn = healLock(hum)
        carpetEngage()
        vZero(hrp)
        local facingDir = closestData.facing == "NORTH" and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)
        do
            local isUpper = (coordTable == UPPER)
            local idx = getClosestBaseIdx(petPos)
            local frontCoord, frontFace = buildFrontCandidate(idx, isUpper, hrp.Position.Z)
            local bestCoord, bestFace = frontCoord, frontFace
            local bestDist = (hrp.Position - frontCoord).Magnitude
            for _, d in ipairs(plotSides(coordTable, idx)) do
                local dd = (hrp.Position - d.coord).Magnitude
                if dd < bestDist then
                    bestDist = dd
                    bestCoord = d.coord
                    bestFace = d.facing == "NORTH" and Vector3.new(0, 0, -1) or Vector3.new(0, 0, 1)
                end
            end
            destPos = bestCoord
            facingDir = bestFace
        end
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + facingDir)
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
        local _stepped, _useRamp = buildApproachWaypoints(hrp.Position, destPos, facingDir)
        if _useRamp and #_stepped == 1 and destPos.Y <= 10 then
            velGlideTo(hrp, destPos, _tpSpd, facingDir)
        elseif #_stepped <= 2 and _clearWide(hrp.Position, destPos) and destPos.Y <= 10 then
            velGlideTo(hrp, destPos, _tpSpd, facingDir)
        elseif _useRamp then
            velMoveThrough(hrp, _stepped, _tpSpd, true, #_stepped > 4, true)
        else
            velMoveThrough(hrp, _stepped, _tpSpd, true, #_stepped > 3, false)
        end
        if hrp and hrp.Parent and destPos.Y > 10 then
            if hrp.Position.Y < destPos.Y - 0.5 then
                hrp.CFrame = CFrame.new(Vector3.new(hrp.Position.X, destPos.Y, hrp.Position.Z), hrp.Position + facingDir)
                vZero(hrp)
            end
            pcall(function()
                hrp.CFrame = CFrame.new(destPos, destPos + facingDir)
                vZero(hrp)
            end)
        elseif hrp and hrp.Parent then
            local gap = (hrp.Position - destPos).Magnitude
            if gap > 6 then
                velGlideTo(hrp, destPos, _tpSpd, facingDir)
            elseif destPos.Y > 10 and hrp.Position.Y < destPos.Y - 2 then
                hrp.CFrame = CFrame.new(Vector3.new(hrp.Position.X, destPos.Y, hrp.Position.Z), hrp.Position + facingDir)
                vZero(hrp)
            end
            if gap <= 10 then
                pcall(function()
                    hrp.CFrame = CFrame.new(destPos, destPos + facingDir)
                    vZero(hrp)
                end)
            end
        end
        local syncFrames = 2
        local syncConn
        syncConn = RunService.Heartbeat:Connect(function()
            if not hrp or not hrp.Parent then syncConn:Disconnect(); return end
            syncFrames = syncFrames - 1
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if syncFrames <= 0 then syncConn:Disconnect() end
        end)
        for _ = 1, 8 do
            task.wait(0.05)
            if hum.FloorMaterial ~= Enum.Material.Air then break end
        end
        healConn:Disconnect()
        armSteal(pet)
        _cloneFired = true
        local _ahrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local _clonePos = (_ahrp and _ahrp.Parent and _ahrp.Position) or destPos
        local _clonePlat = Instance.new("Part")
        _clonePlat.Name = "SXEClonePlatform"
        _clonePlat.Size = Vector3.new(12, 1, 12)
        _clonePlat.Position = Vector3.new(_clonePos.X, _clonePos.Y - 3, _clonePos.Z)
        _clonePlat.Anchored = true; _clonePlat.CanCollide = false; pcall(makeOneWay, _clonePlat); _clonePlat.Transparency = 1
        _clonePlat.Material = Enum.Material.SmoothPlastic; _clonePlat.Parent = workspace
        if _ahrp and _ahrp.Parent then
            _ahrp.AssemblyLinearVelocity = Vector3.zero
            _ahrp.AssemblyAngularVelocity = Vector3.zero
            pcall(function() _ahrp.Anchored = true end)
            task.delay(1, function()
                if _ahrp and _ahrp.Parent then pcall(function() _ahrp.Anchored = false end) end
            end)
        end
        task.wait(_cloneDelay)
        local _cloneOk = doClone()
        if _clonePlat then pcall(function() _clonePlat:Destroy() end); _clonePlat = nil end
        if _cloneOk then
            task.wait(0.3)
            local _cloneSucceeded = false
            do
                local _c = player.Character
                local _h = _c and _c:FindFirstChild("HumanoidRootPart")
                local plotsFolder = workspace:FindFirstChild("Plots")
                if _h and plotsFolder then
                    local _rad = (petPos.Y <= 8.9) and 26 or 25
                    local p = _h.Position
                    for _, plot in ipairs(plotsFolder:GetChildren()) do
                        pcall(function()
                            local pp = plot:GetPivot().Position
                            if math.abs(p.X - pp.X) < _rad and math.abs(p.Z - pp.Z) < _rad then
                                _cloneSucceeded = true
                            end
                        end)
                        if _cloneSucceeded then break end
                    end
                end
            end
            if _cloneSucceeded then goToBrainrot(petPos, true) end
        end
        _lastTPOk = true
        endTP()
        return true
    end
    _G.SXE_ExecuteManualTP = function()
        task.spawn(function() pcall(doVelocityTP) end)
    end
    task.spawn(function() pcall(loadModules) pcall(loadNet) end)
    task.spawn(function()
        local char = player.Character or player.CharacterAdded:Wait()
        char:WaitForChild("HumanoidRootPart", 10)
        char:WaitForChild("Humanoid", 10)
        pcall(loadModules); pcall(loadNet)
        local _t0 = os.clock()
        repeat
            local ok, pets = pcall(scanAllPets, true)
            if ok and pets and #pets > 0 then break end
            task.wait(0.03)
        until os.clock() - _t0 > 12
        _started = true
        -- on-load: ne pas abandonner au 1er echec (carpet/pets pas encore prets)
        if Config.TpSettings then Config.TpSettings.TpOnLoad = true end
        if Config.TpSettings.TpOnLoad ~= false then
            task.spawn(function()
                local _t0 = os.clock()
                while os.clock() - _t0 < 45 do
                    local ok, pets = pcall(scanAllPets, true)
                    if ok and pets and #pets > 0 and not isTeleporting then
                        pcall(carpetEngage)
                        local okRun, res = pcall(doVelocityTP)
                        if okRun and (res == true or _lastTPOk) then return end
                    end
                    task.wait(0.35)
                end
            end)
        end
    end)
end
task.defer(function()
    local function applyUnwalkAlways(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local animator = hum and hum:FindFirstChildOfClass("Animator")
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        if animator then
            local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
            if ok and tracks then for _, t in ipairs(tracks) do pcall(function() t:Stop(0) end) end end
        end
    end
    local function hook(char)
        task.spawn(function()
            char:WaitForChild("Humanoid", 10); task.wait(0.05)
            for i = 1, 8 do
                if player.Character ~= char then break end
                applyUnwalkAlways(char); task.wait(0.25)
            end
        end)
    end
    if player.Character then hook(player.Character) end
    player.CharacterAdded:Connect(hook)
    local _unwalkLast = 0
    RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - _unwalkLast < 1.5 then return end
        _unwalkLast = now
        local char = player.Character
        if char then applyUnwalkAlways(char) end
    end)
end)
local tpSpeedSettingsPanel, tpSpeedSettingsBody
local priorityPanel, priorityBody
function rebuildTpSpeedSettings()
    if not tpSpeedSettingsBody then return end
    clearBody(tpSpeedSettingsBody)
    makeQuickSlider(tpSpeedSettingsBody, "Grabble TP Speed", 50, 600, Config.TpSettings.GrabbleTPSpeed or 230, function(v)
        Config.TpSettings.GrabbleTPSpeed = v; SaveConfig()
        if _G.SXESetCarpetSpeed then pcall(_G.SXESetCarpetSpeed, v) end
    end)
    makeQuickSlider(tpSpeedSettingsBody, "Walk To Brainrot Speed", 50, 300, Config.TpSettings.WalkTPSpeed or 190, function(v)
        Config.TpSettings.WalkTPSpeed = v; SaveConfig()
    end)
    makeQuickSlider(tpSpeedSettingsBody, "Clone Delay", 0.05, 2.0, Config.TpSettings.CloneDelayVal or 0.1, function(v)
        Config.TpSettings.CloneDelayVal = v; SaveConfig()
    end, "s", 0.05)
end
function refreshPriorityPanel()
    if not priorityBody then return end
    clearBody(priorityBody)
    makePriorityAddRow()
    for i = 1, #priorityList do makePriorityRow(i) end
end
task.defer(function()
task.wait(2.5)
panels["Invisible Steal Panel"], panels["InvisStealBody"] = makeQuickPanel("FlaxyPrivat\nInvisible Steal", UDim2.new(0,230,0,375), UDim2.new(0,80,0.5,-220))
panels["InvisStealBody"].ScrollBarThickness = 0
panels["Steal Panel"], panels["StealBody"] = makeQuickPanel("FlaxyPrivat\nSteal Panel", UDim2.new(0,235,0,300), UDim2.new(1,-300,1,-385))
panels["Steal Target"], panels["TargetBody"] = makeQuickPanel("FlaxyPrivat\nSteal Target", UDim2.new(0,320,0,380), UDim2.new(1,-330,0,85))
tpSpeedSettingsPanel, tpSpeedSettingsBody = makeQuickPanel("FlaxyPrivat\nTP Settings", UDim2.new(0,235,0,200), UDim2.new(0.5,745,1,-440))
tpSpeedSettingsPanel.Visible = false
priorityPanel, priorityBody = makeQuickPanel("FlaxyPrivat\nPriority List", UDim2.new(0,320,0,420), UDim2.new(0.5,-160,0.5,-210))
priorityPanel.Visible = Config.Visibilities["Priority List"] == true
for _, pair in ipairs({
    {"FlaxyPrivat\nInvisible Steal", panels["Invisible Steal Panel"]},
    {"FlaxyPrivat\nSteal Panel", panels["Steal Panel"]},
    {"FlaxyPrivat\nSteal Target", panels["Steal Target"]},
    {"FlaxyPrivat\nTP Settings", tpSpeedSettingsPanel},
    {"FlaxyPrivat\nPriority List", priorityPanel},
}) do applySavedPosition(pair[1], pair[2]) end
for name, panel in pairs(panels) do
    if not string.match(name, "Body$") then
        local vis = Config.Visibilities[name]
        if vis == nil then vis = false end
        panel.Visible = vis
    end
end
regToggle("Auto Recover Lagback", Config.AutoRecoverLagback ~= false)
regToggle("Auto Invis During Steal", Config.AutoInvisDuringSteal or false)
makeSyncStateRow(panels["InvisStealBody"], "Enabled:", "Invisible Steal", function(on)
    if _G.toggleInvisibleSteal then pcall(_G.toggleInvisibleSteal) end
end)
regToggle("Carry Speed", Config.CarrySpeedEnabled == true)
makeSyncStateRow(panels["InvisStealBody"], "Carry Speed:", "Carry Speed", function(on)
    Config.CarrySpeedEnabled = on; SaveConfig()
    if _G.setCarrySpeedEnabled then pcall(_G.setCarrySpeedEnabled, on) end
    ShowNotification("CARRY SPEED", on and ("ON | " .. (Config.CarrySpeedValue or 30) .. " studs/s") or "OFF")
end)
makeQuickSlider(panels["InvisStealBody"], "Carry Speed", 5, 100, Config.CarrySpeedValue or 30, function(v)
    Config.CarrySpeedValue = v; SaveConfig()
end, " studs/s", 1)
makeQuickSlider(panels["InvisStealBody"], "Rotation", 0, 360, Config.InvisStealAngle or 225, function(v)
    _G.InvisStealAngle = v; Config.InvisStealAngle = v; SaveConfig()
end)
makeQuickSlider(panels["InvisStealBody"], "Depth", 0, 18, Config.SinkSliderValue or 7, function(v)
    _G.SinkSliderValue = v; Config.SinkSliderValue = v; SaveConfig()
end)
makeSyncStateRow(panels["InvisStealBody"], "Auto Recover:", "Auto Recover Lagback", function(on)
    _G.AutoRecoverLagback = on; Config.AutoRecoverLagback = on; SaveConfig()
end)
makeSyncStateRow(panels["InvisStealBody"], "Auto Invis:", "Auto Invis During Steal", function(on)
    _G.AutoInvisDuringSteal = on; Config.AutoInvisDuringSteal = on; SaveConfig()
end)
regToggle("Steal Highest", Config.StealHighest == true)
regToggle("Steal Priority", Config.StealPriority ~= false)
regToggle("Steal Nearest", Config.StealNearest == true)
regToggle("Auto Steal", Config.AutoStealEnabled ~= false)
makeSyncStateRow(panels["StealBody"], "Auto Steal:", "Auto Steal", function(on)
    Config.AutoStealEnabled = on; SaveConfig()
    if _G.SXEAutoSteal then pcall(_G.SXEAutoSteal, on) end
end)
makeSyncStateRow(panels["StealBody"], "Steal Highest:", "Steal Highest", function(on) if on then setStealMode("Highest") end end)
makeSyncStateRow(panels["StealBody"], "Steal Priority:", "Steal Priority", function(on) if on then setStealMode("Priority") end end)
makeSyncStateRow(panels["StealBody"], "Steal Nearest:", "Steal Nearest", function(on) if on then setStealMode("Nearest") end end)
makeQuickButton(panels["StealBody"], "Priority Menu", function() priorityPanel.Visible = not priorityPanel.Visible; refreshPriorityPanel() end, Theme.SoftAccent)
makeQuickButton(panels["StealBody"], "TP Settings", function()
    rebuildTpSpeedSettings(); tpSpeedSettingsPanel.Visible = not tpSpeedSettingsPanel.Visible
end, Theme.SoftAccent)
makePriorityRow = function(index)
    local row = Instance.new("Frame"); row.Size = UDim2.new(1,-4,0,31); row.BackgroundColor3 = Theme.Panel
    row.BackgroundTransparency = 0.18; row.Parent = priorityBody; corner(row,6); row.LayoutOrder = index
    local num = Instance.new("TextLabel"); num.Size = UDim2.new(0,24,1,0); num.Position = UDim2.new(0,4,0,0)
    num.BackgroundTransparency = 1; num.Text = tostring(index).."."; num.TextColor3 = Theme.Dim
    num.Font = Enum.Font.GothamBold; num.TextSize = 10; num.TextXAlignment = Enum.TextXAlignment.Left; num.Parent = row
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,-120,1,0); l.Position = UDim2.new(0,28,0,0)
    l.BackgroundTransparency = 1; l.Text = priorityList[index]; l.TextColor3 = Theme.Text
    l.Font = Enum.Font.GothamMedium; l.TextSize = 10; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = row
    local up = Instance.new("TextButton"); up.Size = UDim2.new(0,26,0,22); up.Position = UDim2.new(1,-86,0.5,-11)
    up.BackgroundColor3 = Theme.Accent; up.Text = "^"; up.TextColor3 = Color3.new(1,1,1); up.Font = Enum.Font.GothamBold; up.TextSize = 10; up.Parent = row; corner(up,5)
    local dn = Instance.new("TextButton"); dn.Size = UDim2.new(0,26,0,22); dn.Position = UDim2.new(1,-56,0.5,-11)
    dn.BackgroundColor3 = Theme.Accent; dn.Text = "v"; dn.TextColor3 = Color3.new(1,1,1); dn.Font = Enum.Font.GothamBold; dn.TextSize = 10; dn.Parent = row; corner(dn,5)
    local del = Instance.new("TextButton"); del.Size = UDim2.new(0,26,0,22); del.Position = UDim2.new(1,-26,0.5,-11)
    del.BackgroundColor3 = Theme.Red; del.Text = "X"; del.TextColor3 = Color3.new(1,1,1); del.Font = Enum.Font.GothamBold; del.TextSize = 10; del.Parent = row; corner(del,5)
    up.MouseButton1Click:Connect(function()
        if index > 1 then priorityList[index], priorityList[index-1] = priorityList[index-1], priorityList[index]
            Config.PriorityList = priorityList; SaveConfig(); refreshPriorityPanel() end
    end)
    dn.MouseButton1Click:Connect(function()
        if index < #priorityList then priorityList[index], priorityList[index+1] = priorityList[index+1], priorityList[index]
            Config.PriorityList = priorityList; SaveConfig(); refreshPriorityPanel() end
    end)
    del.MouseButton1Click:Connect(function()
        table.remove(priorityList, index); Config.PriorityList = priorityList; SaveConfig(); refreshPriorityPanel()
    end)
end
makePriorityAddRow = function()
    local holder = Instance.new("Frame"); holder.Size = UDim2.new(1,-4,0,31); holder.BackgroundColor3 = Theme.SoftAccent
    holder.BackgroundTransparency = 0.1; holder.Parent = priorityBody; corner(holder,6); holder.LayoutOrder = -2
    local box = Instance.new("TextBox"); box.Size = UDim2.new(1,-60,1,-6); box.Position = UDim2.new(0,6,0,3)
    box.BackgroundColor3 = Theme.InputBg; box.Text = ""; box.PlaceholderText = "Enter pet name..."
    box.TextColor3 = Theme.Text; box.Font = Enum.Font.GothamMedium; box.TextSize = 10; box.Parent = holder; corner(box,4)
    local addBtn = Instance.new("TextButton"); addBtn.Size = UDim2.new(0,44,0,25); addBtn.Position = UDim2.new(1,-50,0.5,-12.5)
    addBtn.BackgroundColor3 = Theme.Accent; addBtn.Text = "ADD"; addBtn.TextColor3 = Color3.new(1,1,1)
    addBtn.Font = Enum.Font.GothamBlack; addBtn.TextSize = 10; addBtn.Parent = holder; corner(addBtn,5)
    addBtn.MouseButton1Click:Connect(function()
        local trimmed = box.Text:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(priorityList, trimmed); Config.PriorityList = priorityList; SaveConfig()
            box.Text = ""; refreshPriorityPanel()
        end
    end)
end
_G.MiniHubSetPanelVis = function(name, on)
    Config.Visibilities[name] = on; SaveConfig()
    if name == "TP Settings" and tpSpeedSettingsPanel then tpSpeedSettingsPanel.Visible = on; return end
    if panels[name] then panels[name].Visible = on end
    if name == "Priority List" and priorityPanel then priorityPanel.Visible = on end
end
do
function refreshTargetPanel()
    if not panels["TargetBody"] then return end
    if panels["Steal Target"] and not panels["Steal Target"].Visible then return end
    clearBody(panels["TargetBody"])
    local cache = get_all_pets()
    if #cache == 0 then local l=Instance.new("TextLabel",panels["TargetBody"]); l.Size=UDim2.new(1,-4,0,22); l.BackgroundTransparency=1; l.Text="Scanning..."; l.TextColor3=Theme.Dim; l.Font=Enum.Font.GothamSemibold; l.TextSize=11; return end
    local prioSet,prioRank,prioPets,otherPets={},{},{},{}
    for i,n in ipairs(priorityList) do local l=n:lower(); prioSet[l]=true; if prioRank[l]==nil then prioRank[l]=i end end
    for _,pet in ipairs(cache) do if (pet.mpsValue or 0)>=1e7 or (pet.petName and prioSet[pet.petName:lower()]) then prioPets[#prioPets+1]=pet else otherPets[#otherPets+1]=pet end end
    local _rank={} ; for _,pet in ipairs(prioPets) do _rank[pet]=(pet.petName and prioRank[pet.petName:lower()]) or 999 end
    table.sort(prioPets,function(a,b) local ai,bi=_rank[a],_rank[b]; if ai==bi then return (a.mpsValue or 0)>(b.mpsValue or 0) end; return ai<bi end)
    local function row(pet,i)
        local sel,man=selectedTargetUID==pet.uid,manuallySelectedUID==pet.uid
        local f=Instance.new("Frame",panels["TargetBody"]); f.Size=UDim2.new(1,-4,0,36); f.BackgroundColor3=sel and Theme.RowHover or Theme.Panel; f.BackgroundTransparency=.22; corner(f,6)
        if sel or man then local s=Instance.new("UIStroke",f); s.Color=man and Color3.fromRGB(56,214,110) or Theme.Accent; s.Thickness=1.5 end
        local t1=Instance.new("TextLabel",f); t1.Size=UDim2.new(1,-8,0,16); t1.Position=UDim2.new(0,6,0,3); t1.BackgroundTransparency=1; t1.Text="#"..i.." "..(pet.petName or "?"); t1.TextColor3=Theme.Text; t1.Font=Enum.Font.GothamBold; t1.TextSize=11; t1.TextXAlignment=Enum.TextXAlignment.Left; t1.TextTruncate=Enum.TextTruncate.AtEnd
        local t2=Instance.new("TextLabel",f); t2.Size=UDim2.new(1,-8,0,14); t2.Position=UDim2.new(0,6,0,19); t2.BackgroundTransparency=1; t2.Text="$"..tostring(pet.mpsValue or 0).."/s"; t2.TextColor3=Theme.Dim; t2.Font=Enum.Font.GothamMedium; t2.TextSize=10; t2.TextXAlignment=Enum.TextXAlignment.Left
        local b=Instance.new("TextButton",f); b.Size=UDim2.new(1,0,1,0); b.BackgroundTransparency=1; b.Text=""; b.ZIndex=8
        b.MouseButton1Click:Connect(function() if manuallySelectedUID==pet.uid then clearStealTarget() else SharedState.SelectedPetData=pet; saveStealTarget(pet.uid) end; refreshTargetPanel() end)
    end
    local i=0; for _,pet in ipairs(prioPets) do i=i+1; row(pet,i) end; for _,pet in ipairs(otherPets) do i=i+1; row(pet,i) end
end
if panels["Steal Target"] then
    panels["Steal Target"]:GetPropertyChangedSignal("Visible"):Connect(function()
        if panels["Steal Target"].Visible then refreshTargetPanel() end
    end)
end
task.spawn(function() while true do task.wait(1.2); if panels["Steal Target"] and panels["Steal Target"].Visible then refreshTargetPanel() end end end)
task.spawn(function()
    local _lastSig = nil
    while task.wait(0.5) do
        if not Config.AutoStealEnabled then SharedState.SelectedPetData=nil; _lastSig=nil; continue end
        local _cache = SharedState.AllAnimalsCache or {}
        local _sig = #_cache .. "|" .. tostring(_cache[1] and _cache[1].uid) .. "|" .. tostring(Config.StealTargetUID or manuallySelectedUID) .. "|" .. tostring(Config.StealMode)
        if _sig == _lastSig and SharedState.SelectedPetData then continue end
        _lastSig = _sig
        local pets = get_all_pets()
        if #pets == 0 then SharedState.SelectedPetData=nil; _lastSig=nil; continue end
        local uid = Config.StealTargetUID or manuallySelectedUID
        if uid then
            local found
            for _, p in ipairs(pets) do if p.uid == uid then found = p; break end end
            if found then selectedTargetUID=uid; manuallySelectedUID=uid; SharedState.SelectedPetData=found end
        else
            local pick, mode = nil, Config.StealMode or "Priority"
            if mode == "Nearest" then
                local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local bd
                for _, p in ipairs(pets) do
                    local ad = p.animalData and findAdorneeGlobal(p.animalData)
                    if ad and hrp then local d=(hrp.Position-ad.Position).Magnitude; if not bd or d<bd then bd,pick=d,p end end
                end
            elseif mode == "Highest" then
                local bv
                for _, p in ipairs(pets) do local v=p.mpsValue or 0; if not bv or v>bv then bv,pick=v,p end end
            else
                local _pr = {}
                for i, name in ipairs(priorityList) do local l=name:lower(); if _pr[l]==nil then _pr[l]=i end end
                local bestRank
                for _, p in ipairs(pets) do
                    local r = p.petName and _pr[p.petName:lower()]
                    if r and (not bestRank or r < bestRank) then bestRank, pick = r, p end
                end
                pick = pick or pets[1]
            end
            if pick then selectedTargetUID=pick.uid; SharedState.SelectedPetData=pick end
        end
    end
end)
end
end)
if _G.SXEAutoSteal then pcall(_G.SXEAutoSteal, Config.AutoStealEnabled) end
local CARPET_TICK, ANTI_RAG_TICK = 0.066, 0.066
local antiRagdollConn, antiRagdollStateConn, antiRagdollDescendantConn
local function isRagdolled()
    local c = LocalPlayer.Character; if not c then return false end
    local hum = c:FindFirstChildOfClass("Humanoid"); if not hum then return false end
    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then return true end
    local endTime = LocalPlayer:GetAttribute("RagdollEndTime")
    return endTime and (endTime - Workspace:GetServerTimeNow()) > 0
end
local function stopAntiRagdoll()
    for _, connection in ipairs({antiRagdollConn, antiRagdollStateConn, antiRagdollDescendantConn}) do
        if connection then connection:Disconnect() end
    end
    antiRagdollConn, antiRagdollStateConn, antiRagdollDescendantConn = nil, nil, nil
end

local function cleanRagdollCharacter(character)
    for _, obj in ipairs(character:GetDescendants()) do
        if obj:IsA("BallSocketConstraint") or obj:IsA("NoCollisionConstraint") or obj:IsA("HingeConstraint")
            or (obj:IsA("Attachment") and (obj.Name == "A" or obj.Name == "B" or obj.Name:find("RagdollAttachment"))) then
            pcall(function() obj:Destroy() end)
        elseif obj:IsA("Motor6D") then
            pcall(function() obj.Enabled = true end)
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local name = track.Animation and string.lower(track.Animation.Name) or ""
            if name:find("rag") or name:find("fall") or name:find("hurt") or name:find("down") then pcall(function() track:Stop(0) end) end
        end
    end
end
local function startAntiRagdoll(enabled)
    stopAntiRagdoll(); if not enabled then return end
    local character = LocalPlayer.Character; if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local function recover()
        if not Config.AntiRagdoll or not isRagdolled() then return end
        local currentCharacter = LocalPlayer.Character; if not currentCharacter then return end
        local hum, hrp = currentCharacter:FindFirstChildOfClass("Humanoid"), currentCharacter:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        pcall(function() LocalPlayer:SetAttribute("RagdollEndTime", Workspace:GetServerTimeNow()) end)
        hum:ChangeState(Enum.HumanoidStateType.Running)
        hrp.AssemblyLinearVelocity = Vector3.zero
        cleanRagdollCharacter(currentCharacter)
        if Workspace.CurrentCamera.CameraSubject ~= hum then Workspace.CurrentCamera.CameraSubject = hum end
        pcall(function() require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")):GetControls():Enable() end)
    end
    antiRagdollStateConn = humanoid.StateChanged:Connect(function() recover() end)
    antiRagdollDescendantConn = character.DescendantAdded:Connect(function() recover() end)
    local lastTick = 0
    antiRagdollConn = RunService.Heartbeat:Connect(function()
        local now = tick(); if now - lastTick < ANTI_RAG_TICK then return end; lastTick = now
        recover()
    end)
    recover()
end
LocalPlayer.CharacterAdded:Connect(function()
    if Config.AntiRagdoll then task.defer(function() startAntiRagdoll(true) end) end
end)
_G.isCloning = false
local function instantClone()
    if _G.isCloning then return end; _G.isCloning = true
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local cloner = LocalPlayer.Backpack:FindFirstChild("Quantum Cloner") or character:FindFirstChild("Quantum Cloner")
        if cloner then
            if cloner.Parent ~= character then humanoid:EquipTool(cloner); task.wait() end
            local tpButton = PlayerGui:FindFirstChild("ToolsFrames") and PlayerGui.ToolsFrames:FindFirstChild("QuantumCloner") and PlayerGui.ToolsFrames.QuantumCloner:FindFirstChild("TeleportToClone")
            if tpButton then
                cloner:Activate(); task.wait(0.05); tpButton.Visible = true
                if typeof(firesignal) == "function" then firesignal(tpButton.MouseButton1Up)
                else
                    local inset = GuiService:GetGuiInset(); local pos = tpButton.AbsolutePosition + tpButton.AbsoluteSize / 2 + inset
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1); task.wait()
                    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                end
            end
        end
    end
    _G.isCloning = false
end
-- ===== INSTA RESET : recharge le personnage via le remote de reset du jeu =====
local function instaReset()
    if _G.__instaResetting then return end
    _G.__instaResetting = true
    local lp = LocalPlayer
    local oldChar = lp.Character
    task.spawn(function()
        local t0 = os.clock()
        while not resetRemote and (os.clock() - t0) < 3 do task.wait() end
        while resetRemote and lp.Character == oldChar and (os.clock() - t0) < 8 do
            pcall(function() resetRemote:FireServer("randomstring") end)
            task.wait()
        end
        _G.__instaResetting = false
    end)
end
local PS_PLACE_ID, PS_LINK_CODE, KICK_MSG = 109983668079237, "21123234413254755790528116376556", "\nBIR PRO"
local autoKickFired, autoKickConns = false, {}
local function doAutoKick()
    if autoKickFired then return end; autoKickFired = true
    if not pcall(function() game:GetService("ExperienceService"):LaunchExperience({placeId=PS_PLACE_ID,linkCode=PS_LINK_CODE}) end) then
        pcall(function() LocalPlayer:Kick(KICK_MSG) end)
    end
end
local function startAutoKick()
    for _, c in ipairs(autoKickConns) do pcall(function() c:Disconnect() end) end; autoKickConns = {}
    table.insert(autoKickConns, PlayerGui.DescendantAdded:Connect(function(gui)
        if not Config.AutoKickEnabled or autoKickFired then return end
        local txt = (gui:IsA("TextLabel") or gui:IsA("TextButton")) and gui.Text
        if txt and string.find(txt, "You stole") then doAutoKick() end
    end))
end
local function stopAutoKick() for _, c in ipairs(autoKickConns) do pcall(function() c:Disconnect() end) end; autoKickConns = {} end
local ProximityAPActive = Config.ProximityAPEnabled == true
local proxViz, highlight = nil, nil
local ALL_COMMANDS = {"jail","inverse","tiny","morph","rocket","jumpscare","balloon","nightvision","ragdoll"}
local COOLDOWNS = {rocket=120,ragdoll=30,balloon=30,inverse=60,nightvision=60,jail=60,tiny=60,jumpscare=60,morph=60}
local activeCooldowns, clickToAPBusy, clickToAPCommandIndex = {}, false, 0
local function getClickHighlight()
    if highlight then return highlight end
    local holder = Instance.new("ScreenGui"); holder.Name = "UtilitiesMiniHighlight"; holder.ResetOnSpawn = false; holder.Parent = PlayerGui
    highlight = Instance.new("Highlight", holder); highlight.FillColor = Theme.Accent1; highlight.FillTransparency = 0.7
    highlight.OutlineColor = Theme.Accent1; highlight.OutlineTransparency = 0.3; highlight.Adornee = nil
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; return highlight
end
local function findNearestBaseOwner()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    local plots = Workspace:FindFirstChild("Plots"); if not plots then return nil end
    local nearestPlot, nearestDist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yourBase = sign:FindFirstChild("YourBase")
            if yourBase and yourBase.Enabled then continue end
            local signPart = sign:IsA("BasePart") and sign or sign:FindFirstChildWhichIsA("BasePart", true)
            if signPart then local dist = (hrp.Position - signPart.Position).Magnitude; if dist < nearestDist then nearestDist, nearestPlot = dist, plot end end
        end
    end
    if not nearestPlot then return nil end
    local sign = nearestPlot:FindFirstChild("PlotSign")
    local lbl = sign and sign:FindFirstChild("SurfaceGui") and sign.SurfaceGui:FindFirstChild("Frame") and sign.SurfaceGui.Frame:FindFirstChild("TextLabel")
    if not lbl then return nil end
    local nick = lbl.Text:match("^(.-)'") or lbl.Text
    for _, p in ipairs(Players:GetPlayers()) do if p.DisplayName == nick or p.Name == nick then return p end end
end
local cachedNearestOwner
-- (owner recalcule dans la boucle refresh du hub)
local function rayToCubeIntersect(ro, rd, cc, cs)
    local hs = cs / 2; local mn, mx = cc - Vector3.new(hs,hs,hs), cc + Vector3.new(hs,hs,hs)
    if rd.X == 0 then rd = Vector3.new(0.0001, rd.Y, rd.Z) end
    if rd.Y == 0 then rd = Vector3.new(rd.X, 0.0001, rd.Z) end
    if rd.Z == 0 then rd = Vector3.new(rd.X, rd.Y, 0.0001) end
    local tmin, tmax = (mn.X-ro.X)/rd.X, (mx.X-ro.X)/rd.X; if tmin > tmax then tmin, tmax = tmax, tmin end
    local tymin, tymax = (mn.Y-ro.Y)/rd.Y, (mx.Y-ro.Y)/rd.Y; if tymin > tymax then tymin, tymax = tymax, tymin end
    if tmin > tymax or tymin > tmax then return false end
    if tymin > tmin then tmin = tymin end; if tymax < tmax then tmax = tymax end
    local tzmin, tzmax = (mn.Z-ro.Z)/rd.Z, (mx.Z-ro.Z)/rd.Z; if tzmin > tzmax then tzmin, tzmax = tzmax, tzmin end
    return not (tmin > tzmax or tzmin > tmax)
end
local function isOnCooldown(cmd)
    local ag = PlayerGui:FindFirstChild("AdminPanel")
    if ag then
        local sf = ag:FindFirstChild("AdminPanel") and ag.AdminPanel:FindFirstChild("Content") and ag.AdminPanel.Content:FindFirstChild("ScrollingFrame")
        if sf then local b = sf:FindFirstChild(cmd); local tl = b and b:FindFirstChild("Timer"); if tl and tl.Visible then return true end end
    end
    return activeCooldowns[cmd] and (tick() - activeCooldowns[cmd]) < (COOLDOWNS[cmd] or 0)
end
local function getNextAvailableCommand()
    for _ = 1, #ALL_COMMANDS do
        clickToAPCommandIndex = (clickToAPCommandIndex % #ALL_COMMANDS) + 1
        local cmd = ALL_COMMANDS[clickToAPCommandIndex]; if cmd and not isOnCooldown(cmd) then return cmd end
    end
end
local function getBestPlayerUnderMouse()
    local cam, m = Workspace.CurrentCamera, UIS:GetMouseLocation()
    local ray = cam:ViewportPointToRay(m.X, m.Y); local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Parent then
            local hrp = p.Character.HumanoidRootPart
            if rayToCubeIntersect(ray.Origin, ray.Direction, hrp.Position, 20) then
                local dist = (ray.Origin - hrp.Position).Magnitude; if dist < bestDist then best, bestDist = p, dist end
            end
        end
    end
    return best
end
local function fireClick(button)
    if not button then return end
    if firesignal then firesignal(button.MouseButton1Click); firesignal(button.MouseButton1Down); firesignal(button.Activated)
    else
        local x = button.AbsolutePosition.X + button.AbsoluteSize.X/2; local y = button.AbsolutePosition.Y + button.AbsoluteSize.Y/ 2 + 58
        VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,0); VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,0)
    end
end
local function runAdminCommand(targetPlayer, commandName)
    local realAdminGui = PlayerGui:WaitForChild("AdminPanel", 5); if not realAdminGui then return false end
    local contentScroll = realAdminGui.AdminPanel:WaitForChild("Content"):WaitForChild("ScrollingFrame")
    local cmdBtn = contentScroll:FindFirstChild(commandName); if not cmdBtn then return false end
    fireClick(cmdBtn); task.wait(0.05)
    local playerBtn = realAdminGui.AdminPanel:WaitForChild("Profiles"):WaitForChild("ScrollingFrame"):FindFirstChild(targetPlayer.Name)
    if not playerBtn then return false end; fireClick(playerBtn); return true
end
_G.runAdminCommand = runAdminCommand
local carpetSpeedEnabled, carpetConn = false, nil
local function setCarpetSpeed(enabled)
    carpetSpeedEnabled = enabled
    if carpetConn then carpetConn:Disconnect(); carpetConn = nil end; if not enabled then return end
    local lastTick = 0
    carpetConn = RunService.Heartbeat:Connect(function()
        local now = tick(); if now - lastTick < CARPET_TICK then return end; lastTick = now
        local c = LocalPlayer.Character; if not c then return end
        local hum, hrp = c:FindFirstChild("Humanoid"), c:FindFirstChild("HumanoidRootPart"); if not hum or not hrp then return end
        local toolName = Config.CarpetTool
        if not c:FindFirstChild(toolName) then local tb = LocalPlayer.Backpack:FindFirstChild(toolName); if tb then hum:EquipTool(tb) end end
        if c:FindFirstChild(toolName) then
            local md = hum.MoveDirection
            if md.Magnitude > 0 then hrp.AssemblyLinearVelocity = Vector3.new(md.X*Config.CarpetSpeed, hrp.AssemblyLinearVelocity.Y, md.Z*Config.CarpetSpeed)
            else hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
        end
    end)
end
local infJumpConn, lastJump = nil, 0
local function setInfiniteJump(enabled)
    Config.InfiniteJump = enabled
    if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end; if not enabled then return end
    infJumpConn = RunService.Heartbeat:Connect(function()
        if not UIS:IsKeyDown(Enum.KeyCode.Space) then return end
        local now = tick(); if now - lastJump < 0.1 then return end
        local c = LocalPlayer.Character; if not c then return end
        local hrp, hum = c:FindFirstChild("HumanoidRootPart"), c:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end; lastJump = now
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 55, hrp.AssemblyLinearVelocity.Z)
    end)
end
-- ===== X-RAY : copie exacte du systeme SXE =====
local xrayOriginalTransparencies = setmetatable({}, {__mode = "k"})
local xrayConnections = {}
local xrayLoopId = 0
local function setXRayTargetTransparency(instance, alphaPercent, loopId)
    if not instance then return end
    if loopId and loopId ~= xrayLoopId then return end
    local function apply(obj)
        if obj:IsA("BasePart") then
            if xrayOriginalTransparencies[obj] == nil then
                if obj.Transparency == alphaPercent then xrayOriginalTransparencies[obj] = 0
                else xrayOriginalTransparencies[obj] = obj.Transparency end
            end
            local orig = xrayOriginalTransparencies[obj]
            if orig < 1 then
                local target = orig + (1 - orig) * alphaPercent
                if math.abs(obj.Transparency - target) > 0.01 then obj.Transparency = target end
            end
        end
    end
    apply(instance)
    local descendants = instance:GetDescendants()
    for i, child in ipairs(descendants) do
        apply(child)
        if i % 300 == 0 then task.wait(); if loopId and loopId ~= xrayLoopId then return end end
    end
end
local XRAY_FOLDERS = {"Base","PlotSign","FriendPanel","Cash","Laser","Decorations","Skin","Unlock","Purchases"}
local function trackXRaySubtree(root, alphaPercent, loopId)
    if not root then return end
    if loopId ~= xrayLoopId then return end
    setXRayTargetTransparency(root, alphaPercent, loopId)
    if loopId ~= xrayLoopId then return end
    xrayConnections[#xrayConnections+1] = root.DescendantAdded:Connect(function(obj)
        if loopId ~= xrayLoopId then return end
        setXRayTargetTransparency(obj, alphaPercent, loopId)
    end)
end
local function processPlotXRay(plot, alphaPercent, loopId)
    if not plot then return end
    if loopId ~= xrayLoopId then return end
    for _, fname in ipairs(XRAY_FOLDERS) do
        if loopId ~= xrayLoopId then return end
        trackXRaySubtree(plot:FindFirstChild(fname), alphaPercent, loopId)
    end
    if loopId ~= xrayLoopId then return end
    xrayConnections[#xrayConnections+1] = plot.ChildAdded:Connect(function(child)
        if loopId ~= xrayLoopId then return end
        for _, fname in ipairs(XRAY_FOLDERS) do
            if child.Name == fname then trackXRaySubtree(child, alphaPercent, loopId); break end
        end
    end)
    local animalPodiums = plot:FindFirstChild("AnimalPodiums")
    if animalPodiums then
        local function processPodium(podium)
            for _, child in ipairs(podium:GetChildren()) do
                if child.Name == "Claim" then
                    trackXRaySubtree(child, alphaPercent, loopId)
                elseif child.Name == "Base" then
                    trackXRaySubtree(child:FindFirstChild("Decorations"), alphaPercent, loopId)
                elseif child:IsA("Model") and child.Name ~= "Decorations" then
                    trackXRaySubtree(child, alphaPercent, loopId)
                end
            end
        end
        for _, podium in ipairs(animalPodiums:GetChildren()) do processPodium(podium) end
        xrayConnections[#xrayConnections+1] = animalPodiums.ChildAdded:Connect(function(podium)
            if loopId ~= xrayLoopId then return end
            task.wait(0.1)
            if loopId ~= xrayLoopId then return end
            processPodium(podium)
        end)
    end
end
local function applyTransparencyToAllPlotsXRay(alphaPercent, loopId)
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return end
    for _, plot in ipairs(plotsFolder:GetChildren()) do
        if loopId ~= xrayLoopId then return end
        processPlotXRay(plot, alphaPercent, loopId)
        task.wait()
    end
    xrayConnections[#xrayConnections+1] = plotsFolder.ChildAdded:Connect(function(plot)
        if loopId ~= xrayLoopId then return end
        task.wait(0.2)
        processPlotXRay(plot, alphaPercent, loopId)
    end)
end
local function enableXray()
    for _, conn in ipairs(xrayConnections) do if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end end
    xrayConnections = {}
    xrayLoopId = xrayLoopId + 1
    local currentLoopId = xrayLoopId
    local alphaPercent = 0.5
    task.spawn(function()
        while currentLoopId == xrayLoopId and not Workspace:FindFirstChild("Plots") do task.wait(0.5) end
        if currentLoopId ~= xrayLoopId then return end
        pcall(applyTransparencyToAllPlotsXRay, alphaPercent, currentLoopId)
    end)
end
local function disableXray()
    for _, conn in ipairs(xrayConnections) do if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end end
    xrayConnections = {}
    xrayLoopId = xrayLoopId + 1
    local snapshot = xrayOriginalTransparencies
    xrayOriginalTransparencies = setmetatable({}, {__mode = "k"})
    for obj, orig in pairs(snapshot) do
        pcall(function() if obj:IsA("BasePart") then obj.Transparency = orig end end)
    end
end

-- Bee Launcher / Boogie Bomb protection based on the game's known client effects.
local antiBeeDisco = {running = false, connections = {}, originalMoveFunction = nil, controlsProtected = false}
local badLightingNames = {Blue = true, DiscoEffect = true, BeeBlur = true, ColorCorrection = true}
local function antiBeeDiscoActive()
    return Config.AntiBeeEffects or Config.AntiBoogieBombEffects
end
local function clearAntiBeeDiscoConnections()
    for _, connection in ipairs(antiBeeDisco.connections) do pcall(function() connection:Disconnect() end) end
    antiBeeDisco.connections = {}
end
local function removeBadLighting(instance)
    if instance and instance.Parent and badLightingNames[instance.Name] then pcall(function() instance:Destroy() end) end
end
local function setAntiBeeDiscoProtection(enabled)
    if not enabled then
        antiBeeDisco.running = false
        clearAntiBeeDiscoConnections()
        if antiBeeDisco.controlsProtected and antiBeeDisco.originalMoveFunction then
            pcall(function()
                require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")):GetControls().moveFunction = antiBeeDisco.originalMoveFunction
            end)
        end
        antiBeeDisco.controlsProtected = false
        return
    end
    if antiBeeDisco.running then return end
    antiBeeDisco.running = true
    for _, instance in ipairs(Lighting:GetDescendants()) do removeBadLighting(instance) end
    table.insert(antiBeeDisco.connections, Lighting.DescendantAdded:Connect(function(instance)
        if antiBeeDisco.running and antiBeeDiscoActive() then removeBadLighting(instance) end
    end))
    pcall(function()
        local controls = require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
        antiBeeDisco.originalMoveFunction = antiBeeDisco.originalMoveFunction or controls.moveFunction
        local protectedMoveFunction = function(self, moveVector, relativeToCamera)
            return antiBeeDisco.originalMoveFunction(self, moveVector, relativeToCamera)
        end
        controls.moveFunction = protectedMoveFunction
        antiBeeDisco.controlsProtected = true
        table.insert(antiBeeDisco.connections, RunService.Heartbeat:Connect(function()
            if antiBeeDisco.running and antiBeeDiscoActive() and controls.moveFunction ~= protectedMoveFunction then
                controls.moveFunction = protectedMoveFunction
            end
        end))
    end)
    table.insert(antiBeeDisco.connections, RunService.Heartbeat:Connect(function()
        if not antiBeeDisco.running or not antiBeeDiscoActive() then return end
        local beeScript = LocalPlayer.PlayerScripts:FindFirstChild("Bee", true)
        local buzzing = beeScript and beeScript:FindFirstChild("Buzzing")
        if buzzing and buzzing:IsA("Sound") then buzzing:Stop(); buzzing.Volume = 0 end
    end))
end

-- Boogie Bomb can use generic object names, so it also needs to suppress the
-- client dance animation, camera pulse, sound, and its local controller.
local boogieConnections, boogieScriptState, boogieSoundState = {}, setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})
local boogieBaseFov, boogieMuteUntil, boogieLastSoundCapture = nil, 0, 0
local boogieGlobalSoundState = setmetatable({}, {__mode = "k"})
local BOOGIE_ANIMATION_ID = "rbxassetid://109061983885712"
local function isBoogieName(name)
    name = string.lower(name or "")
    return name:find("boogie", 1, true) or name:find("disco", 1, true)
        or name:find("dance", 1, true) or name:find("bomb", 1, true)
end
local function restoreAllBoogieSounds()
    for sound, volume in pairs(boogieGlobalSoundState) do pcall(function() sound.Volume = volume end) end
    boogieGlobalSoundState = setmetatable({}, {__mode = "k"})
end
local function muteBoogieSongCandidates()
    -- This runs once per confirmed Boogie animation, never every frame.
    for _, root in pairs({SoundService, Workspace, LocalPlayer.Character, Workspace.CurrentCamera, PlayerGui}) do
        if root then
            for _, instance in ipairs(root:GetDescendants()) do
                if instance:IsA("Sound") then
                    local ok, playing = pcall(function() return instance.IsPlaying end)
                    if ok and playing and instance.TimePosition <= 3 and not boogieGlobalSoundState[instance] then
                        boogieGlobalSoundState[instance] = instance.Volume
                        pcall(function() instance:Stop(); instance.Volume = 0 end)
                    end
                end
            end
        end
    end
end
local function clearBoogieSuppression()
    pcall(function() RunService:UnbindFromRenderStep("MiniHubAntiBoogieFov") end)
    for _, connection in ipairs(boogieConnections) do pcall(function() connection:Disconnect() end) end
    boogieConnections = {}
    for scriptObject, wasDisabled in pairs(boogieScriptState) do pcall(function() scriptObject.Disabled = wasDisabled end) end
    for sound, volume in pairs(boogieSoundState) do pcall(function() sound.Volume = volume end) end
    boogieScriptState, boogieSoundState = setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})
    if boogieBaseFov and Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = boogieBaseFov end
    restoreAllBoogieSounds()
    boogieBaseFov, boogieMuteUntil, boogieLastSoundCapture = nil, 0, 0
end
local function setBoogieSuppression(enabled)
    clearBoogieSuppression()
    if not enabled then return end
    boogieBaseFov = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70
    for _, instance in ipairs(Lighting:GetDescendants()) do
        if instance:IsA("PostEffect") then pcall(function() instance:Destroy() end) end
    end
    local function suppressInstance(instance)
        if instance:IsA("LocalScript") and isBoogieName(instance.Name) then
            boogieScriptState[instance] = instance.Disabled
            instance.Disabled = true
        elseif instance:IsA("Sound") and (isBoogieName(instance.Name)
            or (LocalPlayer.Character and instance:IsDescendantOf(LocalPlayer.Character))
            or (Workspace.CurrentCamera and instance:IsDescendantOf(Workspace.CurrentCamera))) then
            boogieSoundState[instance] = instance.Volume
            instance:Stop()
            instance.Volume = 0
        end
    end
    for _, root in pairs({LocalPlayer.PlayerScripts, LocalPlayer.Character, Workspace.CurrentCamera}) do
        if root then for _, instance in ipairs(root:GetDescendants()) do pcall(suppressInstance, instance) end end
    end
    table.insert(boogieConnections, game.DescendantAdded:Connect(function(instance)
        if Config.AntiBoogieBombEffects then pcall(suppressInstance, instance) end
    end))
    table.insert(boogieConnections, Lighting.DescendantAdded:Connect(function(instance)
        if Config.AntiBoogieBombEffects and instance:IsA("PostEffect") then pcall(function() instance:Destroy() end) end
    end))
    RunService:BindToRenderStep("MiniHubAntiBoogieFov", Enum.RenderPriority.Last.Value, function()
        if not Config.AntiBoogieBombEffects then return end
        local camera = Workspace.CurrentCamera
        if camera and boogieBaseFov then
            camera.FieldOfView = boogieBaseFov
        end
    end)
    table.insert(boogieConnections, RunService.RenderStepped:Connect(function()
        if not Config.AntiBoogieBombEffects then return end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local animationName = track.Animation and track.Animation.Name or ""
                local animationId = track.Animation and track.Animation.AnimationId or ""
                if animationId == BOOGIE_ANIMATION_ID then
                    boogieMuteUntil = os.clock() + 12
                    if os.clock() - boogieLastSoundCapture > 2 then
                        boogieLastSoundCapture = os.clock()
                        task.spawn(muteBoogieSongCandidates)
                    end
                end
                if animationId == BOOGIE_ANIMATION_ID or isBoogieName(animationName) or track.Priority.Value >= Enum.AnimationPriority.Action.Value then
                    pcall(function() track:Stop(0) end)
                end
            end
        end
        if os.clock() >= boogieMuteUntil and next(boogieGlobalSoundState) then restoreAllBoogieSounds() end
    end))
end

-- Exact Boogie Bomb song source found by the audio diagnostic:
-- ReplicatedStorage.Controllers.ItemController.BoogieBombController.BOOM
local boogieBoomConnections, boogieBoomSound, boogieBoomOriginalVolume = {}, nil, nil
local function clearBoogieBoomMute()
    for _, connection in ipairs(boogieBoomConnections) do pcall(function() connection:Disconnect() end) end
    boogieBoomConnections = {}
    if boogieBoomSound and boogieBoomSound.Parent and boogieBoomOriginalVolume ~= nil then
        pcall(function() boogieBoomSound.Volume = boogieBoomOriginalVolume end)
    end
    boogieBoomSound, boogieBoomOriginalVolume = nil, nil
end
local function attachBoogieBoomMute(sound)
    if boogieBoomSound == sound or not sound:IsA("Sound") then return end
    clearBoogieBoomMute()
    boogieBoomSound, boogieBoomOriginalVolume = sound, sound.Volume
    local function mute()
        if Config.AntiBoogieBombEffects then pcall(function() sound:Stop(); sound.Volume = 0 end) end
    end
    mute()
    table.insert(boogieBoomConnections, sound.Played:Connect(mute))
    table.insert(boogieBoomConnections, sound:GetPropertyChangedSignal("Playing"):Connect(mute))
    table.insert(boogieBoomConnections, sound:GetPropertyChangedSignal("Volume"):Connect(function()
        if Config.AntiBoogieBombEffects and sound.Volume ~= 0 then sound.Volume = 0 end
    end))
end
local function setBoogieBoomMute(enabled)
    clearBoogieBoomMute()
    if not enabled then return end
    local controllers = ReplicatedStorage:FindFirstChild("Controllers")
    local itemController = controllers and controllers:FindFirstChild("ItemController")
    local boogieController = itemController and itemController:FindFirstChild("BoogieBombController")
    local boom = boogieController and boogieController:FindFirstChild("BOOM")
    if boom then attachBoogieBoomMute(boom) end
    table.insert(boogieBoomConnections, ReplicatedStorage.DescendantAdded:Connect(function(instance)
        if instance.Name == "BOOM" and instance:IsA("Sound") and instance.Parent and instance.Parent.Name == "BoogieBombController" then
            attachBoogieBoomMute(instance)
        end
    end))
end

local function applySavedUtilities()
    if Config.InfiniteJump then setInfiniteJump(true) end
    if Config.XrayEnabled then enableXray() end
    if Config.CarpetSpeedEnabled then setCarpetSpeed(true) end
    if Config.AntiRagdoll then startAntiRagdoll(true) end
    if Config.AutoKickEnabled then startAutoKick() end
    if antiBeeDiscoActive() then setAntiBeeDiscoProtection(true) end
    if Config.AntiBoogieBombEffects then setBoogieSuppression(true) end
    if Config.AntiBoogieBombEffects then setBoogieBoomMute(true) end
    ProximityAPActive = Config.ProximityAPEnabled == true
end

-- Read-only Boogie Bomb diagnostic. Run _G.StartBoogieDiagnostic(25), then get hit.
_G.StartBoogieDiagnostic = function(duration)
    duration = tonumber(duration) or 25
    local started, connections, count = os.clock(), {}, 0
    local function pathOf(instance)
        local ok, result = pcall(function() return instance:GetFullName() end)
        return ok and result or tostring(instance)
    end
    local function log(kind, message)
        count = count + 1
        if count <= 300 then
            print(string.format("[BOOGIE %.2fs] %s | %s", os.clock() - started, kind, message))
        end
    end
    local function watchSound(sound)
        log("SOUND+", pathOf(sound) .. " name=" .. sound.Name .. " volume=" .. tostring(sound.Volume))
        table.insert(connections, sound:GetPropertyChangedSignal("Volume"):Connect(function()
            log("SOUND.VOLUME", pathOf(sound) .. " -> " .. tostring(sound.Volume))
        end))
        table.insert(connections, sound:GetPropertyChangedSignal("Playing"):Connect(function()
            log("SOUND.PLAYING", pathOf(sound) .. " -> " .. tostring(sound.Playing))
        end))
    end
    local function watchCharacter(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if humanoid then
            table.insert(connections, humanoid.StateChanged:Connect(function(_, state)
                log("HUMANOID.STATE", tostring(state))
            end))
        end
        if animator then
            table.insert(connections, animator.AnimationPlayed:Connect(function(track)
                local animation = track.Animation
                log("ANIMATION", "name=" .. (animation and animation.Name or "?") .. " id=" .. (animation and animation.AnimationId or "?") .. " priority=" .. tostring(track.Priority))
            end))
        end
    end
    log("START", "duration=" .. duration .. "s; disable Anti Boogie temporarily, then get hit once")
    local camera = Workspace.CurrentCamera
    if camera then
        log("CAMERA", "initial FOV=" .. tostring(camera.FieldOfView))
        table.insert(connections, camera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
            log("CAMERA.FOV", tostring(camera.FieldOfView))
        end))
    end
    table.insert(connections, LocalPlayer.AttributeChanged:Connect(function(attribute)
        log("PLAYER.ATTRIBUTE", attribute .. "=" .. tostring(LocalPlayer:GetAttribute(attribute)))
    end))
    table.insert(connections, Lighting.DescendantAdded:Connect(function(instance)
        if instance:IsA("PostEffect") or instance:IsA("Sound") then
            log("LIGHTING+", instance.ClassName .. " " .. pathOf(instance))
            if instance:IsA("Sound") then watchSound(instance) end
        end
    end))
    table.insert(connections, game.DescendantAdded:Connect(function(instance)
        local character = LocalPlayer.Character
        local cameraNow = Workspace.CurrentCamera
        local localSource = character and instance:IsDescendantOf(character)
            or cameraNow and instance:IsDescendantOf(cameraNow)
            or instance:IsDescendantOf(LocalPlayer.PlayerScripts)
        if localSource and (instance:IsA("Sound") or instance:IsA("ParticleEmitter") or instance:IsA("Trail")
            or instance:IsA("Beam") or instance:IsA("LocalScript") or instance:IsA("Highlight")) then
            log("LOCAL+", instance.ClassName .. " " .. pathOf(instance))
            if instance:IsA("Sound") then watchSound(instance) end
        end
    end))
    watchCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
    task.delay(duration, function()
        for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        warn(string.format("[BOOGIE] Diagnostic complete: %d events logged. Copy all [BOOGIE ...] console lines and send them here.", count))
    end)
end

-- Focused audio-only diagnostic for identifying the Boogie song source.
_G.StartBoogieSoundDiagnostic = function(duration)
    duration = tonumber(duration) or 25
    local started, connections, watched = os.clock(), {}, setmetatable({}, {__mode = "k"})
    local function pathOf(instance)
        local ok, result = pcall(function() return instance:GetFullName() end)
        return ok and result or tostring(instance)
    end
    local function log(kind, sound)
        local playing = pcall(function() return sound.IsPlaying end) and sound.IsPlaying or false
        print(string.format("[BOOGIE-SOUND %.2fs] %s | path=%s | id=%s | playing=%s | volume=%s | time=%.2f",
            os.clock() - started, kind, pathOf(sound), tostring(sound.SoundId), tostring(playing), tostring(sound.Volume), sound.TimePosition))
    end
    local function watch(sound, reason)
        if watched[sound] then return end
        watched[sound] = true
        local ok, playing = pcall(function() return sound.IsPlaying end)
        if reason ~= "EXISTING" or (ok and playing) then log(reason, sound) end
        table.insert(connections, sound:GetPropertyChangedSignal("Playing"):Connect(function() log("PLAYING-CHANGED", sound) end))
        table.insert(connections, sound:GetPropertyChangedSignal("Volume"):Connect(function() log("VOLUME-CHANGED", sound) end))
        table.insert(connections, sound:GetPropertyChangedSignal("TimePosition"):Connect(function()
            local ok, playing = pcall(function() return sound.IsPlaying end)
            if ok and playing and sound.TimePosition < 0.2 then log("STARTED", sound) end
        end))
        pcall(function()
            table.insert(connections, sound.Played:Connect(function() log("PLAYED", sound) end))
        end)
    end
    for _, sound in ipairs(game:GetDescendants()) do if sound:IsA("Sound") then watch(sound, "EXISTING") end end
    table.insert(connections, game.DescendantAdded:Connect(function(instance)
        if instance:IsA("Sound") then watch(instance, "ADDED") end
    end))
    warn("[BOOGIE-SOUND] Recording " .. duration .. " seconds. Turn Anti Boogie OFF, get hit once, then send only the lines that appear near the hit.")
    task.delay(duration, function()
        for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        warn("[BOOGIE-SOUND] Recording complete.")
    end)
end

applySavedUtilities()
local rfCarpet, rfProxAP, rfClickAP, rfSteal, rfInvis, rfTarget
local hubRowRefresh = {}
local hubRefreshStarted = false
local function startHubRefreshLoop()
    if hubRefreshStarted then return end
    hubRefreshStarted = true
    task.spawn(function()
        while true do
            task.wait(1)
            if next(hubRowRefresh) == nil then --[[panneau vide: rien a faire]] else
            pcall(function() cachedNearestOwner = findNearestBaseOwner() end)
            for plr, data in pairs(hubRowRefresh) do
                if data.row and data.row.Parent then
                    data.ownerLabel.Text = (cachedNearestOwner == plr) and "OWNER" or ""
                    for _, bd in ipairs(data.buttons) do
                        if bd.btn and bd.btn.Parent then
                            bd.btn.BackgroundColor3 = isOnCooldown(bd.cmd) and Theme.Error or Color3.fromRGB(35, 37, 43)
                        end
                    end
                else
                    hubRowRefresh[plr] = nil
                end
            end
            end
        end
    end)
end
local function initHub()
    if _G.__NiggaHubMiniLoaded then return end
    _G.__NiggaHubMiniLoaded = true
    table.clear(hubRowRefresh)
    pcall(function() cachedNearestOwner = findNearestBaseOwner() end)
    if not Config.Positions then Config.Positions = {} end
    if not Config.Positions.Main then Config.Positions.Main = {X = 0.02, Y = 0.3} end
    local adminButtonCache, balloonedPlayers, playerRows = {}, {}, {}
    local hubGui = PlayerGui:FindFirstChild("NiggaHubMini")
    if hubGui then hubGui:Destroy() end
    hubGui = Instance.new("ScreenGui")
    hubGui.Name = "NiggaHubMini"; hubGui.ResetOnSpawn = false; hubGui.IgnoreGuiInset = true
    hubGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; hubGui.DisplayOrder = 99999999
    hubGui.Enabled = false; hubGui.Parent = PlayerGui
    local mx = tonumber(Config.Positions.Main.X) or 0.02
    local my = tonumber(Config.Positions.Main.Y) or 0.3
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 884)
    frame.Position = UDim2.new(mx, 0, my, 0)
    frame.BackgroundColor3 = Theme.Background; frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0; frame.Parent = hubGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)
    local header = Instance.new("Frame", frame)
    header.Size = UDim2.new(1, 0, 0, 40); header.BackgroundTransparency = 1
    MakeDraggable(header, frame, "Main")
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -10, 1, 0); title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1; title.Text = "NIGGAHUB MINI"
    title.Font = Enum.Font.GothamBlack; title.TextSize = 16; title.TextColor3 = Theme.TextPrimary
    title.TextXAlignment = Enum.TextXAlignment.Left
    -- ===== KEYBINDS : bouton + panneau de configuration des touches =====
    local KEYBIND_DEFS = {
        {name = "Menu",      key = "MenuKey",        default = "LeftControl"},
        {name = "Reset",     key = "InstaResetKey",  default = "X"},
        {name = "Clone",     key = "CloneKey",       default = "V"},
        {name = "Carpet",    key = "CarpetSpeedKey", default = "Q"},
        {name = "Proximity", key = "ProximityAPKey", default = "P"},
        {name = "ClickAP",   key = "ClickToAPKey",   default = "Z"},
        {name = "ManualTP",  key = "ManualTPKey",    default = "T"},
    }
    local KEY_IDLE = Color3.fromRGB(255, 255, 255)
    local KEY_IDLE_TX = Color3.fromRGB(0, 0, 0)
    local KEY_WAIT = Color3.fromRGB(255, 190, 60)
    local keysBtn = Instance.new("TextButton", header)
    keysBtn.Size = UDim2.new(0, 52, 0, 24); keysBtn.Position = UDim2.new(1, -62, 0.5, -12)
    keysBtn.BackgroundColor3 = Theme.Surface; keysBtn.AutoButtonColor = false
    keysBtn.Text = "KEYS"; keysBtn.Font = Enum.Font.GothamBold; keysBtn.TextSize = 11
    keysBtn.TextColor3 = Theme.TextPrimary; keysBtn.BorderSizePixel = 0
    Instance.new("UICorner", keysBtn).CornerRadius = UDim.new(0, 6)
    local resetPosBtn = Instance.new("TextButton", header)
    resetPosBtn.Size = UDim2.new(0, 52, 0, 24); resetPosBtn.Position = UDim2.new(1, -120, 0.5, -12)
    resetPosBtn.BackgroundColor3 = Theme.Surface; resetPosBtn.AutoButtonColor = false
    resetPosBtn.Text = "RESET"; resetPosBtn.Font = Enum.Font.GothamBold; resetPosBtn.TextSize = 11
    resetPosBtn.TextColor3 = Theme.TextPrimary; resetPosBtn.BorderSizePixel = 0
    Instance.new("UICorner", resetPosBtn).CornerRadius = UDim.new(0, 6)
    local keysPanel = Instance.new("Frame", hubGui)
    keysPanel.Name = "KeybindsPanel"; keysPanel.Visible = false
    keysPanel.Size = UDim2.new(0, 260, 0, 40 + #KEYBIND_DEFS * 38 + 12)
    keysPanel.Position = UDim2.new(mx, 332, my, 0)
    keysPanel.BackgroundColor3 = Theme.Background; keysPanel.BackgroundTransparency = 0.05
    keysPanel.BorderSizePixel = 0
    Instance.new("UICorner", keysPanel).CornerRadius = UDim.new(0, 12)
    local function resetUIPos()
        local dx, dy = 0.02, 0.3
        if not Config.Positions then Config.Positions = {} end
        Config.Positions.Main = {X = dx, Y = dy}
        SaveConfig()
        frame.Position = UDim2.new(dx, 0, dy, 0)
        keysPanel.Position = UDim2.new(dx, 332, dy, 0)
        ShowNotification("UI", "Position reset")
    end
    _G.__NHResetUIPos = resetUIPos
    resetPosBtn.MouseButton1Click:Connect(resetUIPos)
    local kHeader = Instance.new("Frame", keysPanel)
    kHeader.Size = UDim2.new(1, 0, 0, 40); kHeader.BackgroundTransparency = 1
    MakeDraggable(kHeader, keysPanel)
    local kTitle = Instance.new("TextLabel", kHeader)
    kTitle.Size = UDim2.new(1, -50, 1, 0); kTitle.Position = UDim2.new(0, 15, 0, 0)
    kTitle.BackgroundTransparency = 1; kTitle.Text = "KEYBINDS"
    kTitle.Font = Enum.Font.GothamBlack; kTitle.TextSize = 15; kTitle.TextColor3 = Theme.Accent1
    kTitle.TextXAlignment = Enum.TextXAlignment.Left
    local kClose = Instance.new("TextButton", kHeader)
    kClose.Size = UDim2.new(0, 26, 0, 26); kClose.Position = UDim2.new(1, -34, 0.5, -13)
    kClose.BackgroundColor3 = Theme.Surface; kClose.AutoButtonColor = false
    kClose.Text = "X"; kClose.Font = Enum.Font.GothamBold; kClose.TextSize = 12
    kClose.TextColor3 = Theme.TextPrimary; kClose.BorderSizePixel = 0
    Instance.new("UICorner", kClose).CornerRadius = UDim.new(0, 6)
    kClose.MouseButton1Click:Connect(function() keysPanel.Visible = false end)
    local kBody = Instance.new("Frame", keysPanel)
    kBody.Size = UDim2.new(1, -20, 1, -48); kBody.Position = UDim2.new(0, 10, 0, 42)
    kBody.BackgroundTransparency = 1
    local kLayout = Instance.new("UIListLayout", kBody)
    kLayout.Padding = UDim.new(0, 6); kLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local capturing = nil
    for i, def in ipairs(KEYBIND_DEFS) do
        local row = Instance.new("Frame", kBody)
        row.Size = UDim2.new(1, 0, 0, 32); row.BackgroundColor3 = Theme.Surface
        row.BorderSizePixel = 0; row.LayoutOrder = i
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -110, 1, 0); lbl.Position = UDim2.new(0, 12, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Text = def.name
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12; lbl.TextColor3 = Theme.TextPrimary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        local bindBtn = Instance.new("TextButton", row)
        bindBtn.Size = UDim2.new(0, 88, 0, 22); bindBtn.Position = UDim2.new(1, -96, 0.5, -11)
        bindBtn.AutoButtonColor = false; bindBtn.Font = Enum.Font.GothamBold; bindBtn.TextSize = 11
        bindBtn.Text = tostring(Config[def.key] or def.default)
        bindBtn.BackgroundColor3 = KEY_IDLE; bindBtn.TextColor3 = KEY_IDLE_TX
        Instance.new("UICorner", bindBtn).CornerRadius = UDim.new(0, 5)
        bindBtn.MouseButton1Click:Connect(function()
            if capturing then
                capturing.btn.Text = tostring(Config[capturing.def.key] or capturing.def.default)
                capturing.btn.BackgroundColor3 = KEY_IDLE; capturing.btn.TextColor3 = KEY_IDLE_TX
            end
            capturing = {btn = bindBtn, def = def}
            _G.__NHKeyCapturing = true
            bindBtn.Text = "..."; bindBtn.BackgroundColor3 = KEY_WAIT; bindBtn.TextColor3 = KEY_IDLE_TX
        end)
    end
    UIS.InputBegan:Connect(function(input, gp)
        if not capturing then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local kc = input.KeyCode
        if kc == Enum.KeyCode.Unknown then return end
        local cur = capturing
        capturing = nil
        _G.__NHKeyCapturing = false
        if kc ~= Enum.KeyCode.Escape then
            Config[cur.def.key] = kc.Name; SaveConfig()
        end
        cur.btn.Text = tostring(Config[cur.def.key] or cur.def.default)
        cur.btn.BackgroundColor3 = KEY_IDLE; cur.btn.TextColor3 = KEY_IDLE_TX
    end)
    keysBtn.MouseButton1Click:Connect(function() keysPanel.Visible = not keysPanel.Visible end)
    local toggleFrame = Instance.new("Frame", frame)
    toggleFrame.Size = UDim2.new(1, -20, 0, 508); toggleFrame.Position = UDim2.new(0, 10, 0, 44)
    toggleFrame.BackgroundColor3 = Theme.Surface; toggleFrame.BorderSizePixel = 0
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(0, 8)
    local togLayout = Instance.new("UIListLayout", toggleFrame)
    togLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local ON_BG, ON_TX = Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0)
    local OFF_BG, OFF_TX = Color3.fromRGB(40, 40, 40), Color3.fromRGB(200, 200, 200)
    local function makeToggleRow(label, isOn, order, callback)
        local row = Instance.new("Frame", toggleFrame)
        row.Size = UDim2.new(1, 0, 0, 32); row.BackgroundTransparency = 1; row.LayoutOrder = order
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -60, 1, 0); lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1; lbl.Text = label
        lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12; lbl.TextColor3 = Theme.TextPrimary
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        local btn = Instance.new("TextButton", row)
        btn.Size = UDim2.new(0, 44, 0, 22); btn.Position = UDim2.new(1, -52, 0.5, -11)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
        local function refresh(on)
            btn.Text = on and "ON" or "OFF"
            btn.BackgroundColor3 = on and ON_BG or OFF_BG
            btn.TextColor3 = on and ON_TX or OFF_TX
        end
        refresh(isOn)
        btn.MouseButton1Click:Connect(function() refresh(callback()) end)
        return refresh
    end
    makeToggleRow("Infinite Jump", Config.InfiniteJump == true, 1, function()
        Config.InfiniteJump = not Config.InfiniteJump; setInfiniteJump(Config.InfiniteJump); SaveConfig()
        ShowNotification("INF JUMP", Config.InfiniteJump and "ON" or "OFF"); return Config.InfiniteJump
    end)
    makeToggleRow("X-Ray Base", Config.XrayEnabled == true, 2, function()
        Config.XrayEnabled = not Config.XrayEnabled
        if Config.XrayEnabled then enableXray() else disableXray() end
        SaveConfig(); ShowNotification("X-RAY", Config.XrayEnabled and "ON" or "OFF"); return Config.XrayEnabled
    end)
    rfCarpet = makeToggleRow("Carpet Speed", Config.CarpetSpeedEnabled == true, 3, function()
        Config.CarpetSpeedEnabled = not Config.CarpetSpeedEnabled
        setCarpetSpeed(Config.CarpetSpeedEnabled); SaveConfig()
        ShowNotification("CARPET", Config.CarpetSpeedEnabled and "ON" or "OFF"); return Config.CarpetSpeedEnabled
    end)
    makeToggleRow("Anti Ragdoll", Config.AntiRagdoll == true, 4, function()
        Config.AntiRagdoll = not Config.AntiRagdoll
        startAntiRagdoll(Config.AntiRagdoll); SaveConfig()
        ShowNotification("ANTI RAGDOLL", Config.AntiRagdoll and "ON" or "OFF"); return Config.AntiRagdoll
    end)
    makeToggleRow("Auto Kick (PS)", Config.AutoKickEnabled == true, 5, function()
        Config.AutoKickEnabled = not Config.AutoKickEnabled
        if Config.AutoKickEnabled then startAutoKick() else stopAutoKick() end
        SaveConfig()
        ShowNotification("AUTO KICK (PS)", Config.AutoKickEnabled and "ON" or "OFF"); return Config.AutoKickEnabled
    end)
    makeToggleRow("Clear Error Popups", Config.CleanErrorGUIs == true, 6, function()
        Config.CleanErrorGUIs = not Config.CleanErrorGUIs
        SaveConfig()
        ShowNotification("ERROR POPUPS", Config.CleanErrorGUIs and "CLEARED" or "ALLOWED")
        return Config.CleanErrorGUIs
    end)
    rfProxAP = makeToggleRow("Proximity AP", ProximityAPActive, 7, function()
        ProximityAPActive = not ProximityAPActive
        Config.ProximityAPEnabled = ProximityAPActive; SaveConfig()
        ShowNotification("AP PROXIMITY", ProximityAPActive and ("ENABLED (" .. Config.ProximityAPRange .. " studs)") or "DISABLED")
        return ProximityAPActive
    end)
    rfClickAP = makeToggleRow("Click to AP", Config.ClickToAPEnabled == true, 8, function()
        Config.ClickToAPEnabled = not Config.ClickToAPEnabled; SaveConfig()
        ShowNotification("CLICK TO AP", Config.ClickToAPEnabled and "ENABLED" or "DISABLED")
        return Config.ClickToAPEnabled
    end)
    rfSteal = makeToggleRow("Steal Panel", Config.Visibilities["Steal Panel"] ~= false, 9, function()
        local on = not (Config.Visibilities["Steal Panel"] ~= false)
        if _G.MiniHubSetPanelVis then _G.MiniHubSetPanelVis("Steal Panel", on) end
        ShowNotification("PANEL", "Steal Panel " .. (on and "ON" or "OFF")); return on
    end)
    rfInvis = makeToggleRow("Invisible Steal", Config.Visibilities["Invisible Steal Panel"] ~= false, 10, function()
        local on = not (Config.Visibilities["Invisible Steal Panel"] ~= false)
        if _G.MiniHubSetPanelVis then _G.MiniHubSetPanelVis("Invisible Steal Panel", on) end
        ShowNotification("PANEL", "Invisible Steal " .. (on and "ON" or "OFF")); return on
    end)
    rfTarget = makeToggleRow("Steal Target", Config.Visibilities["Steal Target"] ~= false, 11, function()
        local on = not (Config.Visibilities["Steal Target"] ~= false)
        if _G.MiniHubSetPanelVis then _G.MiniHubSetPanelVis("Steal Target", on) end
        ShowNotification("PANEL", "Steal Target " .. (on and "ON" or "OFF")); return on
    end)
    -- Insta Reset : bouton d'action (recharge le personnage)
    local resetRow = Instance.new("Frame", toggleFrame)
    resetRow.Size = UDim2.new(1, 0, 0, 32); resetRow.BackgroundTransparency = 1; resetRow.LayoutOrder = 0
    local resetLbl = Instance.new("TextLabel", resetRow)
    resetLbl.Size = UDim2.new(1, -60, 1, 0); resetLbl.Position = UDim2.new(0, 10, 0, 0)
    resetLbl.BackgroundTransparency = 1; resetLbl.Text = "Insta Reset (" .. tostring(Config.InstaResetKey or "R") .. ")"
    resetLbl.Font = Enum.Font.GothamBold; resetLbl.TextSize = 12; resetLbl.TextColor3 = Theme.TextPrimary
    resetLbl.TextXAlignment = Enum.TextXAlignment.Left
    local resetBtn = Instance.new("TextButton", resetRow)
    resetBtn.Size = UDim2.new(0, 44, 0, 22); resetBtn.Position = UDim2.new(1, -52, 0.5, -11)
    resetBtn.Font = Enum.Font.GothamBold; resetBtn.TextSize = 11; resetBtn.AutoButtonColor = false
    resetBtn.Text = "GO"; resetBtn.BackgroundColor3 = ON_BG; resetBtn.TextColor3 = ON_TX
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 5)
    resetBtn.MouseButton1Click:Connect(function()
        resetBtn.BackgroundColor3 = OFF_BG; resetBtn.TextColor3 = OFF_TX
        instaReset()
        task.delay(0.3, function() if resetBtn.Parent then resetBtn.BackgroundColor3 = ON_BG; resetBtn.TextColor3 = ON_TX end end)
    end)
    makeToggleRow("Anti Bee Effects", Config.AntiBeeEffects == true, 12, function()
        Config.AntiBeeEffects = not Config.AntiBeeEffects
        setAntiBeeDiscoProtection(antiBeeDiscoActive())
        SaveConfig()
        ShowNotification("ANTI BEE", Config.AntiBeeEffects and "EFFECTS HIDDEN" or "EFFECTS SHOWN")
        return Config.AntiBeeEffects
    end)
    makeToggleRow("Anti Boogie Bomb", Config.AntiBoogieBombEffects == true, 13, function()
        Config.AntiBoogieBombEffects = not Config.AntiBoogieBombEffects
        setAntiBeeDiscoProtection(antiBeeDiscoActive())
        setBoogieSuppression(Config.AntiBoogieBombEffects)
        setBoogieBoomMute(Config.AntiBoogieBombEffects)
        SaveConfig()
        ShowNotification("ANTI BOOGIE", Config.AntiBoogieBombEffects and "EFFECTS HIDDEN" or "EFFECTS SHOWN")
        return Config.AntiBoogieBombEffects
    end)
    local proxRangeRow = Instance.new("Frame", toggleFrame)
    proxRangeRow.Size = UDim2.new(1, 0, 0, 60); proxRangeRow.BackgroundTransparency = 1; proxRangeRow.LayoutOrder = 14
    local proxRangeLbl = Instance.new("TextLabel", proxRangeRow)
    proxRangeLbl.Size = UDim2.new(1, -20, 0, 20); proxRangeLbl.Position = UDim2.new(0, 10, 0, 0)
    proxRangeLbl.BackgroundTransparency = 1; proxRangeLbl.Font = Enum.Font.GothamBold; proxRangeLbl.TextSize = 11
    proxRangeLbl.TextColor3 = Theme.Accent1; proxRangeLbl.TextXAlignment = Enum.TextXAlignment.Left
    local proxSliderBg = Instance.new("Frame", proxRangeRow)
    proxSliderBg.Size = UDim2.new(1, -20, 0, 6); proxSliderBg.Position = UDim2.new(0, 10, 0, 24)
    proxSliderBg.BackgroundColor3 = Theme.SliderBg; proxSliderBg.BorderSizePixel = 0
    Instance.new("UICorner", proxSliderBg).CornerRadius = UDim.new(1, 0)
    local proxFill = Instance.new("Frame", proxSliderBg)
    proxFill.BackgroundColor3 = Theme.Accent1; proxFill.BorderSizePixel = 0
    Instance.new("UICorner", proxFill).CornerRadius = UDim.new(1, 0)
    local proxKnob = Instance.new("Frame", proxSliderBg)
    proxKnob.Size = UDim2.new(0, 14, 0, 14); proxKnob.BackgroundColor3 = Theme.TextPrimary
    proxKnob.BorderSizePixel = 0; proxKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    Instance.new("UICorner", proxKnob).CornerRadius = UDim.new(1, 0)
    local function updateProxSlider(val)
        val = math.clamp(val, 5, 50)
        Config.ProximityAPRange = val
        local pct = (val - 5) / 45
        proxFill.Size = UDim2.new(pct, 0, 1, 0)
        proxKnob.Position = UDim2.new(pct, 0, 0.5, 0)
        proxRangeLbl.Text = "Proximity Range: " .. math.floor(val + 0.5) .. " studs"
    end
    updateProxSlider(Config.ProximityAPRange or 15)
    local pDragging = false
    proxSliderBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then pDragging = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            pDragging = false; SaveConfig()
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if pDragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local r, w = proxSliderBg.AbsolutePosition.X, proxSliderBg.AbsoluteSize.X
            updateProxSlider(5 + ((i.Position.X - r) / w * 45))
        end
    end)
    local listLabel = Instance.new("TextLabel", frame)
    listLabel.Size = UDim2.new(1, -20, 0, 18); listLabel.Position = UDim2.new(0, 10, 0, 562)
    listLabel.BackgroundTransparency = 1; listLabel.Text = "PLAYERS"
    listLabel.Font = Enum.Font.GothamBlack; listLabel.TextSize = 11
    listLabel.TextColor3 = Theme.Accent1; listLabel.TextXAlignment = Enum.TextXAlignment.Left
    local listFrame = Instance.new("ScrollingFrame", frame)
    listFrame.Size = UDim2.new(1, -20, 1, -582); listFrame.Position = UDim2.new(0, 10, 0, 582)
    listFrame.BackgroundTransparency = 1; listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 4; listFrame.ScrollBarImageColor3 = Theme.Accent1
    local layout = Instance.new("UIListLayout", listFrame)
    layout.Padding = UDim.new(0, 6); layout.SortOrder = Enum.SortOrder.LayoutOrder
    local function setGlobalVisualCooldown(cmd)
        if not adminButtonCache[cmd] then return end
        for _, b in ipairs(adminButtonCache[cmd]) do
            if b and b.Parent then
                b.BackgroundColor3 = Theme.Error
                task.delay(COOLDOWNS[cmd] or 5, function()
                    if b and b.Parent then b.BackgroundColor3 = Color3.fromRGB(35, 37, 43) end
                end)
            end
        end
    end
    local function triggerAll(plr)
        local count = 0
        for _, cmd in ipairs(ALL_COMMANDS) do
            if not isOnCooldown(cmd) then
                task.delay(count * 0.1, function()
                    if runAdminCommand(plr, cmd) then
                        activeCooldowns[cmd] = tick(); setGlobalVisualCooldown(cmd)
                        if cmd == "balloon" then balloonedPlayers[plr.UserId] = true end
                    end
                end)
                count = count + 1
            end
        end
    end
    local function removePlayer(plr)
        local row = playerRows[plr]
        if row then
            if row.Parent then row:Destroy() end
            playerRows[plr] = nil
            hubRowRefresh[plr] = nil
            balloonedPlayers[plr.UserId] = nil
            listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
        end
    end
    local function createPlayerRow(plr)
        local row = Instance.new("TextButton")
        row.Name = plr.Name; row.Size = UDim2.new(1, -4, 0, 54)
        row.BackgroundColor3 = Color3.fromRGB(20, 22, 28); row.BackgroundTransparency = 0.2
        row.BorderSizePixel = 0; row.AutoButtonColor = false; row.Text = ""; row.Parent = listFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local rowStroke = Instance.new("UIStroke", row)
        rowStroke.Color = Theme.Accent2; rowStroke.Thickness = 1; rowStroke.Transparency = 0.7
        row.MouseEnter:Connect(function() row.BackgroundTransparency = 0.05; rowStroke.Transparency = 0.4 end)
        row.MouseLeave:Connect(function() row.BackgroundTransparency = 0.2; rowStroke.Transparency = 0.7 end)
        local headshot = Instance.new("ImageLabel", row)
        headshot.Size = UDim2.new(0, 40, 0, 40); headshot.Position = UDim2.new(0, 8, 0.5, -20)
        headshot.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
        pcall(function() headshot.Image = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
        Instance.new("UICorner", headshot).CornerRadius = UDim.new(1, 0)
        local dName = Instance.new("TextLabel", row)
        dName.Size = UDim2.new(0, 120, 0, 20); dName.Position = UDim2.new(0, 52, 0, 8)
        dName.BackgroundTransparency = 1; dName.Text = plr.DisplayName
        dName.Font = Enum.Font.GothamBlack; dName.TextSize = 13; dName.TextColor3 = Theme.TextPrimary
        dName.TextXAlignment = Enum.TextXAlignment.Left
        local uName = Instance.new("TextLabel", row)
        uName.Size = UDim2.new(0, 120, 0, 14); uName.Position = UDim2.new(0, 52, 0, 30)
        uName.BackgroundTransparency = 1; uName.Text = "@" .. plr.Name
        uName.Font = Enum.Font.GothamMedium; uName.TextSize = 10; uName.TextColor3 = Theme.TextSecondary
        uName.TextXAlignment = Enum.TextXAlignment.Left
        local ownerLabel = Instance.new("TextLabel", row)
        ownerLabel.Size = UDim2.new(0, 120, 0, 12); ownerLabel.Position = UDim2.new(0, 52, 0, 46)
        ownerLabel.BackgroundTransparency = 1; ownerLabel.Font = Enum.Font.GothamBold; ownerLabel.TextSize = 9
        ownerLabel.TextColor3 = Color3.fromRGB(255, 255, 255); ownerLabel.TextXAlignment = Enum.TextXAlignment.Left
        plr.AncestryChanged:Connect(function(_, parent) if not parent then removePlayer(plr) end end)
        local rowButtons = {}
        for i, def in ipairs({{icon = "R", cmd = "rocket"}, {icon = "G", cmd = "ragdoll"}, {icon = "J", cmd = "jail"}, {icon = "B", cmd = "balloon"}}) do
            local b = Instance.new("TextButton", row)
            b.Size = UDim2.new(0, 28, 0, 28); b.Position = UDim2.new(1, -140 + (i - 1) * 34, 0.5, -14)
            b.AutoButtonColor = false; b.Text = def.icon; b.TextSize = 16
            b.TextColor3 = Theme.TextPrimary; b.Font = Enum.Font.GothamBold; b.ZIndex = 11
            b.BackgroundColor3 = isOnCooldown(def.cmd) and Theme.Error or Color3.fromRGB(35, 37, 43)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            adminButtonCache[def.cmd] = adminButtonCache[def.cmd] or {}
            table.insert(adminButtonCache[def.cmd], b)
            rowButtons[#rowButtons + 1] = { btn = b, cmd = def.cmd }
            b.MouseButton1Click:Connect(function()
                if runAdminCommand(plr, def.cmd) then
                    activeCooldowns[def.cmd] = tick(); setGlobalVisualCooldown(def.cmd)
                    if def.cmd == "balloon" then balloonedPlayers[plr.UserId] = true end
                    ShowNotification("ADMIN", def.cmd .. " -> " .. plr.Name)
                end
            end)
        end
        row.MouseButton1Click:Connect(function()
            if cachedNearestOwner == plr then
                for i = 1, 15 do
                    task.spawn(function()
                        if runAdminCommand(plr, "rocket") then activeCooldowns["rocket"] = tick() end
                    end)
                    task.wait(0.1)
                end
                ShowNotification("SPAM AP", "Owner -> " .. plr.Name)
            else
                local any = false
                for _, cmd in ipairs(ALL_COMMANDS) do if not isOnCooldown(cmd) then any = true; break end end
                if any then triggerAll(plr); ShowNotification("ADMIN", "ALL -> " .. plr.Name) end
            end
        end)
        hubRowRefresh[plr] = { row = row, ownerLabel = ownerLabel, buttons = rowButtons }
        return row
    end
    local function addPlayer(plr)
        if plr == LocalPlayer or playerRows[plr] then return end
        playerRows[plr] = createPlayerRow(plr)
        listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
    end
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then addPlayer(p) end end
    Players.PlayerAdded:Connect(addPlayer)
    Players.PlayerRemoving:Connect(removePlayer)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
    end)
    startHubRefreshLoop()
end
local function toggleHub()
    local gui = PlayerGui:FindFirstChild("NiggaHubMini")
    if gui then gui.Enabled = not gui.Enabled; return end
    _G.__NiggaHubMiniLoaded = false
    initHub()
end
UIS.InputBegan:Connect(function(input, processed)
    if _G.__NHKeyCapturing then return end
    local menuKey = Enum.KeyCode[Config.MenuKey] or Enum.KeyCode.LeftControl
    if input.KeyCode == menuKey or input.KeyCode == Enum.KeyCode.RightControl then toggleHub(); return end
    if processed then return end
    if input.KeyCode == Enum.KeyCode.N then if _G.__NHResetUIPos then _G.__NHResetUIPos() end
    elseif input.KeyCode == (Enum.KeyCode[Config.CloneKey] or Enum.KeyCode.V) then instantClone()
    elseif input.KeyCode == (Enum.KeyCode[Config.InstaResetKey] or Enum.KeyCode.R) then instaReset()
    elseif input.KeyCode == (Enum.KeyCode[Config.CarpetSpeedKey] or Enum.KeyCode.Q) then
        Config.CarpetSpeedEnabled = not Config.CarpetSpeedEnabled
        setCarpetSpeed(Config.CarpetSpeedEnabled); SaveConfig()
        if rfCarpet then rfCarpet(Config.CarpetSpeedEnabled) end
    elseif input.KeyCode == (Enum.KeyCode[Config.ProximityAPKey] or Enum.KeyCode.P) then
        ProximityAPActive = not ProximityAPActive
        Config.ProximityAPEnabled = ProximityAPActive; SaveConfig()
        if rfProxAP then rfProxAP(ProximityAPActive) end
        ShowNotification("AP PROX", ProximityAPActive and ("ON "..Config.ProximityAPRange.."st") or "OFF")
    elseif input.KeyCode == (Enum.KeyCode[Config.ClickToAPKey] or Enum.KeyCode.Z) then
        Config.ClickToAPEnabled = not Config.ClickToAPEnabled; SaveConfig(); if rfClickAP then rfClickAP(Config.ClickToAPEnabled) end
        ShowNotification("CLICK AP", Config.ClickToAPEnabled and "ON" or "OFF")
    elseif input.KeyCode == (Enum.KeyCode[Config.ManualTPKey] or Enum.KeyCode.T) and _G.SXE_ExecuteManualTP then task.spawn(function() pcall(_G.SXE_ExecuteManualTP) end) end
end)
UIS.InputBegan:Connect(function(inp, g)
    if not g and inp.UserInputType == Enum.UserInputType.MouseButton1 and Config.ClickToAPEnabled and not clickToAPBusy then
        local p = getBestPlayerUnderMouse()
        if p and _G.runAdminCommand then
            local cmd = getNextAvailableCommand()
            if not cmd then ShowNotification("CLICK AP", "Aucune commande"); return end
            clickToAPBusy = true; task.spawn(function()
                if runAdminCommand(p, cmd) then activeCooldowns[cmd] = tick(); ShowNotification("CLICK AP", cmd.." -> "..p.Name) end
                clickToAPBusy = false
            end)
        end
    end
end)
local _clickHLLast = 0
RunService.Heartbeat:Connect(function()
    if Config.ClickToAPEnabled then
        local n = os.clock(); if n - _clickHLLast < 0.05 then return end; _clickHLLast = n
        local p = getBestPlayerUnderMouse(); getClickHighlight().Adornee = p and p.Character or nil
    elseif highlight then highlight.Adornee = nil end
    if ProximityAPActive then
        if not proxViz then proxViz = Instance.new("Part"); proxViz.Name = "ProximityAPCircle"; proxViz.Anchored = true; proxViz.CanCollide = false
            proxViz.Shape = Enum.PartType.Cylinder; proxViz.Color = Theme.Accent1; proxViz.Transparency = 0.6; proxViz.CastShadow = false; proxViz.Parent = Workspace end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then local _ws = Vector3.new(0.5, Config.ProximityAPRange*2, Config.ProximityAPRange*2); if proxViz.Size ~= _ws then proxViz.Size = _ws end; proxViz.CFrame = hrp.CFrame * CFrame.Angles(0,0,math.rad(90)) end
    elseif proxViz then proxViz:Destroy(); proxViz = nil end
end)
task.spawn(function()
    while true do
        task.wait(0.2); if not ProximityAPActive or not _G.runAdminCommand then continue end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then continue end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if (p.Character.HumanoidRootPart.Position - myHRP.Position).Magnitude <= Config.ProximityAPRange then
                    for _, cmd in ipairs(ALL_COMMANDS) do pcall(function() if runAdminCommand(p, cmd) then activeCooldowns[cmd] = tick() end end); task.wait(0.1) end
                end
            end
        end
    end
end)
task.defer(function() task.wait(0.5); initHub() end)

-- ===== BARRE DE PROGRESSION DE VOL =====
task.spawn(function()
    task.wait(1)
    local old = PlayerGui:FindFirstChild("SXE_StealBar")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "SXE_StealBar"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    sg.DisplayOrder = 999999; sg.Parent = PlayerGui

    local hud = Instance.new("Frame", sg)
    hud.Size = UDim2.new(0, 240, 0, 46); hud.Position = UDim2.new(0.5, -120, 0, 120)
    hud.BackgroundColor3 = Color3.fromRGB(8, 8, 8); hud.BackgroundTransparency = 0.08
    hud.BorderSizePixel = 0; hud.Visible = false
    Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 9)
    local hs = Instance.new("UIStroke", hud); hs.Color = Theme.Stroke; hs.Thickness = 1; hs.Transparency = 0.4

    local nameLbl = Instance.new("TextLabel", hud)
    nameLbl.Size = UDim2.new(1, -20, 0, 16); nameLbl.Position = UDim2.new(0, 10, 0, 6)
    nameLbl.BackgroundTransparency = 1; nameLbl.Text = "Searching..."
    nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 12
    nameLbl.TextColor3 = Theme.Text; nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local pctLbl = Instance.new("TextLabel", hud)
    pctLbl.Size = UDim2.new(0, 40, 0, 16); pctLbl.Position = UDim2.new(1, -50, 0, 6)
    pctLbl.BackgroundTransparency = 1; pctLbl.Text = "0%"
    pctLbl.Font = Enum.Font.GothamBold; pctLbl.TextSize = 12
    pctLbl.TextColor3 = Theme.Dim; pctLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", hud)
    track.Size = UDim2.new(1, -20, 0, 12); track.Position = UDim2.new(0, 10, 0, 26)
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 30); track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 6)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = Theme.Accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

    local function fmt(n)
        n = tonumber(n) or 0
        if n >= 1e9 then return string.format("%.2fb", n/1e9) end
        if n >= 1e6 then return string.format("%.2fm", n/1e6) end
        if n >= 1e3 then return string.format("%.1fk", n/1e3) end
        return tostring(math.floor(n))
    end

    local _barLast = 0
    RunService.Heartbeat:Connect(function()
        local _n = os.clock()
        if _n - _barLast < 0.03 then return end
        _barLast = _n
        if not Config.AutoStealEnabled then if hud.Visible then hud.Visible = false end; return end
        local st = _G.SXE_StealStatus or {}

        if LocalPlayer:GetAttribute("Stealing") then
            hud.Visible = true
            fill.Size = UDim2.new(1, 0, 1, 0)
            pctLbl.Text = "100%"; nameLbl.Text = "Carrying!"
        elseif st.active then
            hud.Visible = true
            local p = math.clamp((tick() - (st.start or 0)) / (st.duration or 1.3), 0, 1)
            fill.Size = UDim2.new(p, 0, 1, 0)
            pctLbl.Text = math.floor(p * 100) .. "%"; nameLbl.Text = "Stealing..."
        elseif st.target or st.visualTarget then
            local tgt = st.target or st.visualTarget
            hud.Visible = true
            local p = math.clamp((tick() - (st.fillStart or tick())) / (st.duration or 1.3), 0, 1)
            fill.Size = UDim2.new(p, 0, 1, 0)
            pctLbl.Text = math.floor(p * 100) .. "%"
            local nm = tgt.petName or tgt.name or "Brainrot"
            local v = fmt(tgt.mpsValue or tgt.mps or tgt.value or 0)
            nameLbl.Text = (v ~= "0") and (nm .. " - $" .. v) or nm
        else
            if hud.Visible then hud.Visible = false end
        end
    end)
end)

-- Embedded Auto Buy module
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG_FILE = "davdi089autobuy.json"

local Theme = {
    Background = Color3.fromRGB(0, 0, 0),
    Surface = Color3.fromRGB(16, 16, 16),
    SurfaceLight = Color3.fromRGB(22, 22, 22),
    SurfaceHighlight = Color3.fromRGB(24, 24, 24),
    Accent1 = Color3.fromRGB(255, 255, 255),
    Accent2 = Color3.fromRGB(200, 200, 200),
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(160, 160, 160),
}

local GRADIENT_THEMES = {
    Crimson = {
        Accent1 = Color3.fromRGB(255, 255, 255),
        Accent2 = Color3.fromRGB(200, 200, 200),
        PanelTop = Color3.fromRGB(16, 16, 16),
        PanelBottom = Color3.fromRGB(0, 0, 0),
        HeaderTop = Color3.fromRGB(36, 36, 36),
        HeaderBottom = Color3.fromRGB(16, 16, 16),
    },
    Sunset = {
        Accent1 = Color3.fromRGB(255, 255, 255),
        Accent2 = Color3.fromRGB(200, 200, 200),
        PanelTop = Color3.fromRGB(16, 16, 16),
        PanelBottom = Color3.fromRGB(0, 0, 0),
        HeaderTop = Color3.fromRGB(36, 36, 36),
        HeaderBottom = Color3.fromRGB(16, 16, 16),
    },
    Aurora = {
        Accent1 = Color3.fromRGB(255, 255, 255),
        Accent2 = Color3.fromRGB(200, 200, 200),
        PanelTop = Color3.fromRGB(16, 16, 16),
        PanelBottom = Color3.fromRGB(0, 0, 0),
        HeaderTop = Color3.fromRGB(36, 36, 36),
        HeaderBottom = Color3.fromRGB(16, 16, 16),
    },
    Nebula = {
        Accent1 = Color3.fromRGB(255, 255, 255),
        Accent2 = Color3.fromRGB(200, 200, 200),
        PanelTop = Color3.fromRGB(16, 16, 16),
        PanelBottom = Color3.fromRGB(0, 0, 0),
        HeaderTop = Color3.fromRGB(36, 36, 36),
        HeaderBottom = Color3.fromRGB(16, 16, 16),
    },
}
local GRADIENT_THEME_ORDER = {"Crimson", "Sunset", "Aurora", "Nebula"}

local DefaultConfig = {
    Positions = {
        AutoBuy = {X = 0.01, Y = 0.35},
    },
    TpSettings = {
        Tool = "Flying Carpet",
    },
    AutoBuyEnabled = false,
    AutoBuyKey = "K",
    AutoBuyRange = 17,
    GradientTheme = "Crimson",
    AutoBuyColor = {R = 0, G = 220, B = 255},
    HideAutoBuyUI = false,
}

local Config = DefaultConfig
local SharedState = {
    ConveyorAnimals = {},
}

local function deepCopy(tbl)
    local out = {}
    for k, v in pairs(tbl) do
        out[k] = type(v) == "table" and deepCopy(v) or v
    end
    return out
end

local function mergeDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            target[k] = type(target[k]) == "table" and target[k] or {}
            mergeDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

if isfile and isfile(CONFIG_FILE) then
    pcall(function()
        local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(decoded) == "table" then
            mergeDefaults(decoded, DefaultConfig)
            Config = decoded
        end
    end)
end

local function SaveConfig()
    if not writefile then
        return
    end
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
end

local function ShowNotification(title, text)
    return
end

task.spawn(function()
    -- Let the main hub, including TP Settings, finish opening first.
    task.wait(1.5)

    local oldUi = PlayerGui:FindFirstChild("LefaAutoBuyUI")
    if oldUi then
        oldUi:Destroy()
    end

    local oldRing = Workspace:FindFirstChild("LefaAutoBuyRing")
    if oldRing then
        oldRing:Destroy()
    end

    local autoBuyActive = false

    local abGui = Instance.new("ScreenGui")
    abGui.Name = "LefaAutoBuyUI"
    abGui.ResetOnSpawn = false
    abGui.DisplayOrder = 30
    abGui.Parent = PlayerGui

    local PANEL_WIDTH = 236
    local HEADER_HEIGHT = 58
    local PANEL_PADDING = 12

    local abPanel = Instance.new("Frame")
    abPanel.Name = "ABPanel"
    abPanel.Size = UDim2.new(0, PANEL_WIDTH, 0, 180)
    abPanel.Position = UDim2.new(Config.Positions.AutoBuy.X, 0, Config.Positions.AutoBuy.Y, 0)
    abPanel.BackgroundColor3 = Theme.Background
    abPanel.BackgroundTransparency = 0.05
    abPanel.BorderSizePixel = 0
    abPanel.Visible = not (Config.HideAutoBuyUI == true)
    abPanel.Parent = abGui
    Instance.new("UICorner", abPanel).CornerRadius = UDim.new(0, 10)

    local abPanelGradient = Instance.new("UIGradient")
    abPanelGradient.Rotation = 115
    abPanelGradient.Enabled = false
    abPanelGradient.Parent = abPanel

    local abStroke = Instance.new("UIStroke")
    abStroke.Color = Theme.Accent1
    abStroke.Thickness = 1.8
    abStroke.Transparency = 0.1
    abStroke.Parent = abPanel

    do
        local dragging, dragStart, startPos
        local dragHandle = Instance.new("Frame")
        dragHandle.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
        dragHandle.BackgroundTransparency = 1
        dragHandle.Parent = abPanel

        dragHandle.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            dragging = true
            dragStart = input.Position
            startPos = abPanel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    local parentSize = abPanel.Parent.AbsoluteSize
                    Config.Positions.AutoBuy = {
                        X = abPanel.AbsolutePosition.X / parentSize.X,
                        Y = abPanel.AbsolutePosition.Y / parentSize.Y,
                    }
                    SaveConfig()
                end
            end)
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not dragging then
                return
            end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local delta = input.Position - dragStart
            abPanel.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end)
    end

    local abHeader = Instance.new("Frame")
    abHeader.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
    abHeader.BackgroundColor3 = Theme.Surface
    abHeader.BackgroundTransparency = 0.18
    abHeader.BorderSizePixel = 0
    abHeader.Parent = abPanel
    Instance.new("UICorner", abHeader).CornerRadius = UDim.new(0, 12)

    local abHeaderGradient = Instance.new("UIGradient")
    abHeaderGradient.Rotation = 15
    abHeaderGradient.Enabled = false
    abHeaderGradient.Parent = abHeader

    local abBadge = Instance.new("Frame")
    abBadge.Size = UDim2.new(0, 30, 0, 30)
    abBadge.Position = UDim2.new(0, 12, 0.5, -15)
    abBadge.BackgroundColor3 = Theme.SurfaceHighlight
    abBadge.BorderSizePixel = 0
    abBadge.Parent = abHeader
    Instance.new("UICorner", abBadge).CornerRadius = UDim.new(0, 9)

    local abBadgeGradient = Instance.new("UIGradient")
    abBadgeGradient.Rotation = 135
    abBadgeGradient.Enabled = false
    abBadgeGradient.Parent = abBadge

    local abBadgeStroke = Instance.new("UIStroke")
    abBadgeStroke.Color = Theme.Accent1
    abBadgeStroke.Thickness = 1.2
    abBadgeStroke.Transparency = 0.2
    abBadgeStroke.Parent = abBadge

    local abBadgeText = Instance.new("TextLabel")
    abBadgeText.Size = UDim2.new(1, 0, 1, 0)
    abBadgeText.BackgroundTransparency = 1
    abBadgeText.Text = "AB"
    abBadgeText.Font = Enum.Font.GothamBlack
    abBadgeText.TextSize = 11
    abBadgeText.TextColor3 = Theme.TextPrimary
    abBadgeText.Parent = abBadge

    local abTitle = Instance.new("TextLabel")
    abTitle.Size = UDim2.new(1, -108, 0, 18)
    abTitle.Position = UDim2.new(0, 50, 0, 10)
    abTitle.BackgroundTransparency = 1
    abTitle.Text = "AUTO BUY"
    abTitle.Font = Enum.Font.GothamBlack
    abTitle.TextSize = 13
    abTitle.TextColor3 = Theme.TextPrimary
    abTitle.TextXAlignment = Enum.TextXAlignment.Left
    abTitle.Parent = abHeader

    local abSubtitle = Instance.new("TextLabel")
    abSubtitle.Size = UDim2.new(1, -108, 0, 14)
    abSubtitle.Position = UDim2.new(0, 50, 0, 29)
    abSubtitle.BackgroundTransparency = 1
    abSubtitle.Text = ""
    abSubtitle.Font = Enum.Font.GothamBold
    abSubtitle.TextSize = 10
    abSubtitle.TextColor3 = Theme.TextSecondary
    abSubtitle.TextXAlignment = Enum.TextXAlignment.Left
    abSubtitle.Parent = abHeader

    local abStateChip = Instance.new("Frame")
    abStateChip.Size = UDim2.new(0, 64, 0, 24)
    abStateChip.Position = UDim2.new(1, -76, 0.5, -12)
    abStateChip.BackgroundColor3 = Theme.SurfaceHighlight
    abStateChip.BorderSizePixel = 0
    abStateChip.Parent = abHeader
    Instance.new("UICorner", abStateChip).CornerRadius = UDim.new(1, 0)

    local abStateDot = Instance.new("Frame")
    abStateDot.Size = UDim2.new(0, 7, 0, 7)
    abStateDot.Position = UDim2.new(0, 9, 0.5, -3)
    abStateDot.BackgroundColor3 = Theme.TextSecondary
    abStateDot.BorderSizePixel = 0
    abStateDot.Parent = abStateChip
    Instance.new("UICorner", abStateDot).CornerRadius = UDim.new(1, 0)

    local abStateText = Instance.new("TextLabel")
    abStateText.Size = UDim2.new(1, -22, 1, 0)
    abStateText.Position = UDim2.new(0, 18, 0, 0)
    abStateText.BackgroundTransparency = 1
    abStateText.Text = "IDLE"
    abStateText.Font = Enum.Font.GothamBold
    abStateText.TextSize = 10
    abStateText.TextColor3 = Theme.TextSecondary
    abStateText.TextXAlignment = Enum.TextXAlignment.Left
    abStateText.Parent = abStateChip

    local abHeaderGlow = Instance.new("Frame")
    abHeaderGlow.Size = UDim2.new(1, -24, 0, 2)
    abHeaderGlow.Position = UDim2.new(0, 12, 1, -3)
    abHeaderGlow.BackgroundColor3 = Theme.Accent1
    abHeaderGlow.BackgroundTransparency = 0.45
    abHeaderGlow.BorderSizePixel = 0
    abHeaderGlow.Parent = abHeader
    Instance.new("UICorner", abHeaderGlow).CornerRadius = UDim.new(1, 0)

    local abContent = Instance.new("Frame")
    abContent.Size = UDim2.new(1, -(PANEL_PADDING * 2), 0, 0)
    abContent.Position = UDim2.new(0, PANEL_PADDING, 0, HEADER_HEIGHT + 8)
    abContent.BackgroundTransparency = 1
    abContent.AutomaticSize = Enum.AutomaticSize.Y
    abContent.Parent = abPanel

    local abLayout = Instance.new("UIListLayout")
    abLayout.Padding = UDim.new(0, 8)
    abLayout.SortOrder = Enum.SortOrder.LayoutOrder
    abLayout.Parent = abContent

    local panelHeightTween
    local suppressPanelAutoSize = false
    local PANEL_TWEEN_INFO = TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local function refreshPanelHeight(animated, targetContentHeight)
        if suppressPanelAutoSize then
            return
        end
        local targetHeight = HEADER_HEIGHT + 8 + (targetContentHeight or abLayout.AbsoluteContentSize.Y) + PANEL_PADDING
        if animated then
            if panelHeightTween then
                panelHeightTween:Cancel()
            end
            panelHeightTween = TweenService:Create(
                abPanel,
                PANEL_TWEEN_INFO,
                {Size = UDim2.new(0, PANEL_WIDTH, 0, targetHeight)}
            )
            panelHeightTween:Play()
        else
            abPanel.Size = UDim2.new(0, PANEL_WIDTH, 0, targetHeight)
        end
    end

    abLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        refreshPanelHeight(true)
    end)

    local function makeAbRow(height, order)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, height)
        row.BackgroundColor3 = Theme.Surface
        row.BackgroundTransparency = 0.1
        row.BorderSizePixel = 0
        row.LayoutOrder = order
        row.Parent = abContent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
        local rowStroke = Instance.new("UIStroke")
        rowStroke.Color = Theme.SurfaceHighlight
        rowStroke.Thickness = 1
        rowStroke.Transparency = 0.45
        rowStroke.Parent = row
        return row
    end

    local abToggleRow = makeAbRow(42, 1)
    local AUTO_BUY_OFF_BG = Color3.fromRGB(55, 55, 55)
    local abToggleBtn = Instance.new("TextButton")
    abToggleBtn.Size = UDim2.new(1, 0, 1, 0)
    abToggleBtn.BackgroundColor3 = AUTO_BUY_OFF_BG
    abToggleBtn.Text = "AUTO BUY: OFF"
    abToggleBtn.Font = Enum.Font.GothamBlack
    abToggleBtn.TextSize = 14
    abToggleBtn.TextColor3 = Theme.TextPrimary
    abToggleBtn.BorderSizePixel = 0
    abToggleBtn.AutoButtonColor = false
    abToggleBtn.Parent = abToggleRow
    Instance.new("UICorner", abToggleBtn).CornerRadius = UDim.new(0, 9)

    local abToggleStroke = Instance.new("UIStroke")
    abToggleStroke.Color = Theme.Accent1
    abToggleStroke.Thickness = 1.5
    abToggleStroke.Transparency = 0.5
    abToggleStroke.Parent = abToggleBtn

    local abKeyRow = makeAbRow(40, 2)
    local abKeyLbl = Instance.new("TextLabel")
    abKeyLbl.Size = UDim2.new(1, -70, 1, 0)
    abKeyLbl.Position = UDim2.new(0, 10, 0, 0)
    abKeyLbl.BackgroundTransparency = 1
    abKeyLbl.Text = "Keybind"
    abKeyLbl.Font = Enum.Font.GothamBold
    abKeyLbl.TextSize = 12
    abKeyLbl.TextColor3 = Theme.TextPrimary
    abKeyLbl.TextXAlignment = Enum.TextXAlignment.Left
    abKeyLbl.Parent = abKeyRow

    local abKeyBtn = Instance.new("TextButton")
    abKeyBtn.Size = UDim2.new(0, 56, 0, 24)
    abKeyBtn.Position = UDim2.new(1, -62, 0.5, -12)
    abKeyBtn.BackgroundColor3 = Theme.SurfaceHighlight
    abKeyBtn.Text = Config.AutoBuyKey or "K"
    abKeyBtn.Font = Enum.Font.GothamBold
    abKeyBtn.TextSize = 11
    abKeyBtn.TextColor3 = Theme.Accent1
    abKeyBtn.AutoButtonColor = false
    abKeyBtn.BorderSizePixel = 0
    abKeyBtn.Parent = abKeyRow
    Instance.new("UICorner", abKeyBtn).CornerRadius = UDim.new(0, 5)

    abKeyBtn.MouseButton1Click:Connect(function()
        abKeyBtn.Text = "..."
        abKeyBtn.TextColor3 = Theme.TextSecondary
        local conn
        conn = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            Config.AutoBuyKey = input.KeyCode.Name
            abKeyBtn.Text = input.KeyCode.Name
            abKeyBtn.TextColor3 = Theme.Accent1
            SaveConfig()
            conn:Disconnect()
        end)
    end)

    local TELEPORT_TOOLS = {
        "Flying Carpet",
        "Cupid's Wings",
        "Santa's Sleigh",
    }

    local function getSelectedToolIndex()
        local currentTool = Config.TpSettings and Config.TpSettings.Tool or TELEPORT_TOOLS[1]
        for index, toolName in ipairs(TELEPORT_TOOLS) do
            if toolName == currentTool then
                return index
            end
        end
        return 1
    end

    local selectedToolIndex = getSelectedToolIndex()

    local abToolRow = makeAbRow(54, 3)
    local abToolLbl = Instance.new("TextLabel")
    abToolLbl.Size = UDim2.new(1, -20, 0, 16)
    abToolLbl.Position = UDim2.new(0, 10, 0, 5)
    abToolLbl.BackgroundTransparency = 1
    abToolLbl.Text = "Teleport Tool"
    abToolLbl.Font = Enum.Font.GothamBold
    abToolLbl.TextSize = 11
    abToolLbl.TextColor3 = Theme.TextPrimary
    abToolLbl.TextXAlignment = Enum.TextXAlignment.Left
    abToolLbl.Parent = abToolRow

    local abToolBtn = Instance.new("TextButton")
    abToolBtn.Size = UDim2.new(1, -20, 0, 22)
    abToolBtn.Position = UDim2.new(0, 10, 0, 23)
    abToolBtn.BackgroundColor3 = Theme.SurfaceHighlight
    abToolBtn.Text = ""
    abToolBtn.Font = Enum.Font.GothamBold
    abToolBtn.TextSize = 11
    abToolBtn.TextColor3 = Theme.Accent1
    abToolBtn.BorderSizePixel = 0
    abToolBtn.AutoButtonColor = false
    abToolBtn.Parent = abToolRow
    Instance.new("UICorner", abToolBtn).CornerRadius = UDim.new(0, 5)

    local abToolStroke = Instance.new("UIStroke")
    abToolStroke.Color = Theme.Accent1
    abToolStroke.Thickness = 1
    abToolStroke.Transparency = 0.65
    abToolStroke.Parent = abToolBtn

    local abToolArrow = Instance.new("TextLabel")
    abToolArrow.Size = UDim2.new(0, 18, 1, 0)
    abToolArrow.Position = UDim2.new(1, -22, 0, 0)
    abToolArrow.BackgroundTransparency = 1
    abToolArrow.Text = "v"
    abToolArrow.Font = Enum.Font.GothamBold
    abToolArrow.TextSize = 10
    abToolArrow.TextColor3 = Theme.TextSecondary
    abToolArrow.Parent = abToolBtn

    local abToolValue = Instance.new("TextLabel")
    abToolValue.Size = UDim2.new(1, -28, 1, 0)
    abToolValue.Position = UDim2.new(0, 8, 0, 0)
    abToolValue.BackgroundTransparency = 1
    abToolValue.Text = ""
    abToolValue.Font = Enum.Font.GothamBold
    abToolValue.TextSize = 11
    abToolValue.TextColor3 = Theme.Accent1
    abToolValue.TextXAlignment = Enum.TextXAlignment.Left
    abToolValue.Parent = abToolBtn

    local abToolDropdown = Instance.new("Frame")
    abToolDropdown.Size = UDim2.new(1, -20, 0, #TELEPORT_TOOLS * 24 + 6)
    abToolDropdown.Position = UDim2.new(0, 10, 0, 47)
    abToolDropdown.BackgroundColor3 = Theme.SurfaceHighlight
    abToolDropdown.BorderSizePixel = 0
    abToolDropdown.ClipsDescendants = true
    abToolDropdown.Visible = false
    abToolDropdown.ZIndex = 5
    abToolDropdown.Parent = abToolRow
    Instance.new("UICorner", abToolDropdown).CornerRadius = UDim.new(0, 5)

    local abToolDropStroke = Instance.new("UIStroke")
    abToolDropStroke.Color = Theme.Accent1
    abToolDropStroke.Thickness = 1
    abToolDropStroke.Transparency = 0.7
    abToolDropStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    abToolDropStroke.Parent = abToolDropdown

    local abToolList = Instance.new("UIListLayout")
    abToolList.Padding = UDim.new(0, 2)
    abToolList.SortOrder = Enum.SortOrder.LayoutOrder
    abToolList.Parent = abToolDropdown

    local abToolPadding = Instance.new("UIPadding")
    abToolPadding.PaddingTop = UDim.new(0, 3)
    abToolPadding.PaddingBottom = UDim.new(0, 3)
    abToolPadding.PaddingLeft = UDim.new(0, 3)
    abToolPadding.PaddingRight = UDim.new(0, 3)
    abToolPadding.Parent = abToolDropdown

    local dropdownOpen = false
    local toolOptionButtons = {}
    local dropdownAnim = Instance.new("NumberValue")
    dropdownAnim.Value = 0
    local dropdownAnimTween
    local OTHER_ROWS_HEIGHT = 42 + 40 + 48 + 64 + (abLayout.Padding.Offset * 4)
    local TOOL_ROW_BASE_HEIGHT = 54
    local TOOL_DROPDOWN_OPEN_HEIGHT = #TELEPORT_TOOLS * 24 + 6
    local TOOL_ROW_EXTRA_GAP = 2

    local function applyDropdownProgress(progress)
        local dropdownHeight = TOOL_DROPDOWN_OPEN_HEIGHT * progress
        local rowHeight = TOOL_ROW_BASE_HEIGHT + dropdownHeight + (TOOL_ROW_EXTRA_GAP * progress)
        local contentHeight = OTHER_ROWS_HEIGHT + rowHeight
        abToolDropdown.Size = UDim2.new(1, -20, 0, dropdownHeight)
        abToolRow.Size = UDim2.new(1, 0, 0, rowHeight)
        abPanel.Size = UDim2.new(0, PANEL_WIDTH, 0, HEADER_HEIGHT + 8 + contentHeight + PANEL_PADDING)
    end

    dropdownAnim:GetPropertyChangedSignal("Value"):Connect(function()
        applyDropdownProgress(dropdownAnim.Value)
    end)

    local function updateToolButton()
        local toolName = TELEPORT_TOOLS[selectedToolIndex] or TELEPORT_TOOLS[1]
        Config.TpSettings = Config.TpSettings or {}
        Config.TpSettings.Tool = toolName
        abToolValue.Text = toolName
        SaveConfig()

        for index, button in ipairs(toolOptionButtons) do
            local isSelected = index == selectedToolIndex
            button.BackgroundColor3 = isSelected and Theme.Accent1 or Theme.Surface
            button.TextColor3 = isSelected and Color3.new(0, 0, 0) or Theme.TextPrimary
        end
    end

    local function setDropdownOpen(isOpen)
        dropdownOpen = isOpen
        abToolArrow.Text = isOpen and "^" or "v"

        if isOpen then
            abToolDropdown.Visible = true
        end

        suppressPanelAutoSize = true
        if dropdownAnimTween then
            dropdownAnimTween:Cancel()
        end

        dropdownAnimTween = TweenService:Create(
            dropdownAnim,
            PANEL_TWEEN_INFO,
            {Value = isOpen and 1 or 0}
        )
        dropdownAnimTween:Play()
        dropdownAnimTween.Completed:Once(function()
            suppressPanelAutoSize = false
            if not dropdownOpen then
                abToolDropdown.Visible = false
            end
            refreshPanelHeight(false)
        end)

    end

    for index, toolName in ipairs(TELEPORT_TOOLS) do
        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, 0, 0, 22)
        optionBtn.BackgroundColor3 = Theme.Surface
        optionBtn.Text = toolName
        optionBtn.Font = Enum.Font.GothamBold
        optionBtn.TextSize = 11
        optionBtn.TextColor3 = Theme.TextPrimary
        optionBtn.BorderSizePixel = 0
        optionBtn.AutoButtonColor = false
        optionBtn.LayoutOrder = index
        optionBtn.ZIndex = 6
        optionBtn.Parent = abToolDropdown
        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 4)
        optionCorner.Parent = optionBtn

        local optionStroke = Instance.new("UIStroke")
        optionStroke.Color = Theme.SurfaceHighlight
        optionStroke.Thickness = 1
        optionStroke.Transparency = 0.35
        optionStroke.Parent = optionBtn

        optionBtn.MouseButton1Click:Connect(function()
            selectedToolIndex = index
            updateToolButton()
            setDropdownOpen(false)
            ShowNotification("AUTO BUY", "Tool: " .. Config.TpSettings.Tool)
        end)

        toolOptionButtons[index] = optionBtn
    end

    abToolBtn.MouseButton1Click:Connect(function()
        setDropdownOpen(not dropdownOpen)
    end)

    updateToolButton()
    setDropdownOpen(false)
    task.defer(function()
        applyDropdownProgress(dropdownAnim.Value)
    end)

    local abThemeRow = makeAbRow(58, 6)
    local abThemeLbl = Instance.new("TextLabel")
    abThemeLbl.Size = UDim2.new(1, -20, 0, 16)
    abThemeLbl.Position = UDim2.new(0, 10, 0, 6)
    abThemeLbl.BackgroundTransparency = 1
    abThemeLbl.Text = "Themes"
    abThemeLbl.Font = Enum.Font.GothamBold
    abThemeLbl.TextSize = 11
    abThemeLbl.TextColor3 = Theme.TextPrimary
    abThemeLbl.TextXAlignment = Enum.TextXAlignment.Left
    abThemeLbl.Parent = abThemeRow

    local abThemeFrame = Instance.new("Frame")
    abThemeFrame.Size = UDim2.new(1, -20, 0, 28)
    abThemeFrame.Position = UDim2.new(0, 10, 0, 24)
    abThemeFrame.BackgroundTransparency = 1
    abThemeFrame.Parent = abThemeRow

    local abThemeLayout = Instance.new("UIListLayout")
    abThemeLayout.FillDirection = Enum.FillDirection.Horizontal
    abThemeLayout.Padding = UDim.new(0, 6)
    abThemeLayout.SortOrder = Enum.SortOrder.LayoutOrder
    abThemeLayout.Parent = abThemeFrame

    -- The Auto Buy panel uses the single monochrome main-hub theme.
    abThemeRow.Visible = false

    local themeButtons = {}

    local abRangeRow = makeAbRow(48, 4)
    local abRangeLbl = Instance.new("TextLabel")
    abRangeLbl.Size = UDim2.new(1, -10, 0, 16)
    abRangeLbl.Position = UDim2.new(0, 10, 0, 4)
    abRangeLbl.BackgroundTransparency = 1
    abRangeLbl.Text = "Range: " .. (Config.AutoBuyRange or 17) .. " studs"
    abRangeLbl.Font = Enum.Font.GothamBold
    abRangeLbl.TextSize = 11
    abRangeLbl.TextColor3 = Theme.TextPrimary
    abRangeLbl.TextXAlignment = Enum.TextXAlignment.Left
    abRangeLbl.Parent = abRangeRow

    local abSlBg = Instance.new("Frame")
    abSlBg.Size = UDim2.new(1, -20, 0, 6)
    abSlBg.Position = UDim2.new(0, 10, 0, 32)
    abSlBg.BackgroundColor3 = Theme.SurfaceHighlight
    abSlBg.BorderSizePixel = 0
    abSlBg.Parent = abRangeRow
    Instance.new("UICorner", abSlBg).CornerRadius = UDim.new(1, 0)

    local abSlFill = Instance.new("Frame")
    abSlFill.BackgroundColor3 = Theme.Accent1
    abSlFill.BorderSizePixel = 0
    abSlFill.Parent = abSlBg
    Instance.new("UICorner", abSlFill).CornerRadius = UDim.new(1, 0)

    local abSlKnob = Instance.new("Frame")
    abSlKnob.Size = UDim2.new(0, 13, 0, 13)
    abSlKnob.AnchorPoint = Vector2.new(0.5, 0.5)
    abSlKnob.BackgroundColor3 = Color3.new(1, 1, 1)
    abSlKnob.BorderSizePixel = 0
    abSlKnob.Parent = abSlBg
    Instance.new("UICorner", abSlKnob).CornerRadius = UDim.new(1, 0)

    local abSlKS = Instance.new("UIStroke")
    abSlKS.Color = Theme.Accent1
    abSlKS.Thickness = 1.5
    abSlKS.Parent = abSlKnob

    local AB_MIN, AB_MAX = 5, 40
    local function updateAbSlider(value)
        value = math.clamp(math.floor(value), AB_MIN, AB_MAX)
        Config.AutoBuyRange = value
        SaveConfig()
        abRangeLbl.Text = "Range: " .. value .. " studs"
        local pct = (value - AB_MIN) / (AB_MAX - AB_MIN)
        abSlFill.Size = UDim2.new(pct, 0, 1, 0)
        abSlKnob.Position = UDim2.new(pct, 0, 0.5, 0)
        local ring = Workspace:FindFirstChild("LefaAutoBuyRing")
        if ring then
            ring.Size = Vector3.new(0.5, value * 2, value * 2)
        end
    end

    local abDrag = false
    updateAbSlider(Config.AutoBuyRange or 17)

    abSlBg.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        abDrag = true
        updateAbSlider(AB_MIN + ((input.Position.X - abSlBg.AbsolutePosition.X) / abSlBg.AbsoluteSize.X) * (AB_MAX - AB_MIN))
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            abDrag = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not abDrag then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        updateAbSlider(AB_MIN + ((input.Position.X - abSlBg.AbsolutePosition.X) / abSlBg.AbsoluteSize.X) * (AB_MAX - AB_MIN))
    end)

    local abCircleRow = makeAbRow(64, 5)
    local abCircleLbl = Instance.new("TextLabel")
    abCircleLbl.Size = UDim2.new(1, 0, 0, 18)
    abCircleLbl.Position = UDim2.new(0, 10, 0, 4)
    abCircleLbl.BackgroundTransparency = 1
    abCircleLbl.Text = "Circle Color"
    abCircleLbl.Font = Enum.Font.GothamBold
    abCircleLbl.TextSize = 11
    abCircleLbl.TextColor3 = Theme.TextPrimary
    abCircleLbl.TextXAlignment = Enum.TextXAlignment.Left
    abCircleLbl.Parent = abCircleRow

    local THEME_SWATCHES = {
        Color3.fromRGB(232, 116, 170),
        Color3.fromRGB(0, 220, 255),
        Color3.fromRGB(255, 215, 0),
        Color3.fromRGB(180, 80, 255),
        Color3.fromRGB(0, 220, 80),
        Color3.fromRGB(255, 140, 0),
        Color3.fromRGB(255, 50, 50),
        Color3.fromRGB(160, 160, 180),
    }

    local abSwatchFrame = Instance.new("Frame")
    abSwatchFrame.Size = UDim2.new(1, -16, 0, 36)
    abSwatchFrame.Position = UDim2.new(0, 8, 0, 22)
    abSwatchFrame.BackgroundTransparency = 1
    abSwatchFrame.Parent = abCircleRow

    local swatchGrid = Instance.new("UIGridLayout")
    swatchGrid.CellSize = UDim2.new(0, 24, 0, 16)
    swatchGrid.CellPadding = UDim2.new(0, 4, 0, 4)
    swatchGrid.SortOrder = Enum.SortOrder.LayoutOrder
    swatchGrid.FillDirection = Enum.FillDirection.Horizontal
    swatchGrid.Parent = abSwatchFrame

    local function buildCirclePresets()
        for _, child in ipairs(abSwatchFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        for index, color in ipairs(THEME_SWATCHES) do
            local cb = Instance.new("TextButton")
            cb.LayoutOrder = index
            cb.Size = UDim2.new(0, 24, 0, 16)
            cb.BackgroundColor3 = color
            cb.Text = ""
            cb.BorderSizePixel = 0
            cb.AutoButtonColor = false
            cb.Parent = abSwatchFrame
            Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 4)

            local selStroke = Instance.new("UIStroke")
            selStroke.Thickness = 1.5
            selStroke.Color = Color3.new(1, 1, 1)
            selStroke.Parent = cb

            local cur = Config.AutoBuyColor
            local matches = cur
                and math.abs(cur.R - math.floor(color.R * 255)) < 2
                and math.abs(cur.G - math.floor(color.G * 255)) < 2
                and math.abs(cur.B - math.floor(color.B * 255)) < 2
            selStroke.Transparency = matches and 0 or 1

            cb.MouseButton1Click:Connect(function()
                Config.AutoBuyColor = {
                    R = math.floor(color.R * 255),
                    G = math.floor(color.G * 255),
                    B = math.floor(color.B * 255),
                }
                SaveConfig()
                local ring = Workspace:FindFirstChild("LefaAutoBuyRing")
                if ring then
                    ring.Color = color
                end
                buildCirclePresets()
            end)
        end
    end

    local function updateThemeButtonStates()
        local currentTheme = Config.GradientTheme or "Crimson"
        for themeName, button in pairs(themeButtons) do
            local stroke = button:FindFirstChild("ThemeStroke")
            if stroke then
                stroke.Transparency = themeName == currentTheme and 0 or 0.55
                stroke.Thickness = themeName == currentTheme and 1.6 or 1
            end
        end
    end

    local function applyGradientTheme(themeName)
        -- Auto Buy always follows the monochrome main-hub theme.
        local selected = {
            Accent1 = Color3.fromRGB(255, 255, 255),
            Accent2 = Color3.fromRGB(200, 200, 200),
            PanelTop = Color3.fromRGB(16, 16, 16),
            PanelBottom = Color3.fromRGB(0, 0, 0),
            HeaderTop = Color3.fromRGB(36, 36, 36),
            HeaderBottom = Color3.fromRGB(16, 16, 16),
        }
        Theme.Accent1 = selected.Accent1
        Theme.Accent2 = selected.Accent2

        Config.GradientTheme = themeName
        SaveConfig()

        abPanelGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, selected.PanelTop),
            ColorSequenceKeypoint.new(1, selected.PanelBottom),
        })
        abHeaderGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, selected.HeaderTop),
            ColorSequenceKeypoint.new(1, selected.HeaderBottom),
        })
        abBadgeGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, selected.Accent2),
            ColorSequenceKeypoint.new(1, selected.Accent1),
        })

        abStroke.Color = selected.Accent1
        abBadgeStroke.Color = selected.Accent1
        abHeaderGlow.BackgroundColor3 = selected.Accent1
        abToggleStroke.Color = selected.Accent1
        abKeyBtn.TextColor3 = selected.Accent1
        abToolBtn.TextColor3 = selected.Accent1
        abToolStroke.Color = selected.Accent1
        abToolValue.TextColor3 = selected.Accent1
        abToolDropStroke.Color = selected.Accent1
        abSlFill.BackgroundColor3 = selected.Accent1
        abSlKS.Color = selected.Accent1

        if autoBuyActive then
            abToggleBtn.BackgroundColor3 = selected.Accent1
            abStateChip.BackgroundColor3 = selected.Accent1
        else
            abToggleBtn.BackgroundColor3 = AUTO_BUY_OFF_BG
            abStateChip.BackgroundColor3 = Theme.SurfaceHighlight
        end

        updateToolButton()
        updateThemeButtonStates()
    end

    for index, themeName in ipairs(GRADIENT_THEME_ORDER) do
        local data = GRADIENT_THEMES[themeName]
        local themeBtn = Instance.new("TextButton")
        themeBtn.Size = UDim2.new(0, 47, 0, 28)
        themeBtn.BackgroundColor3 = data.PanelBottom
        themeBtn.Text = ""
        themeBtn.BorderSizePixel = 0
        themeBtn.AutoButtonColor = false
        themeBtn.LayoutOrder = index
        themeBtn.Parent = abThemeFrame
        Instance.new("UICorner", themeBtn).CornerRadius = UDim.new(0, 7)

        local themeGradient = Instance.new("UIGradient")
        themeGradient.Rotation = 22
        themeGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, data.Accent2),
            ColorSequenceKeypoint.new(0.35, data.Accent1),
            ColorSequenceKeypoint.new(0.7, data.HeaderTop),
            ColorSequenceKeypoint.new(1, data.PanelBottom),
        })
        themeGradient.Parent = themeBtn

        local themeStroke = Instance.new("UIStroke")
        themeStroke.Name = "ThemeStroke"
        themeStroke.Color = Color3.new(1, 1, 1)
        themeStroke.Transparency = 0.55
        themeStroke.Thickness = 1
        themeStroke.Parent = themeBtn

        local themeText = Instance.new("TextLabel")
        themeText.Size = UDim2.new(1, 0, 1, 0)
        themeText.BackgroundTransparency = 1
        themeText.Text = string.sub(themeName, 1, 1)
        themeText.Font = Enum.Font.GothamBlack
        themeText.TextSize = 10
        themeText.TextColor3 = Theme.TextPrimary
        themeText.Parent = themeBtn

        themeBtn.MouseButton1Click:Connect(function()
            applyGradientTheme(themeName)
        end)

        themeButtons[themeName] = themeBtn
    end

    buildCirclePresets()
    applyGradientTheme(Config.GradientTheme or "Crimson")

    local abRing

    local function getCircleColor()
        local color = Config.AutoBuyColor
        if color then
            return Color3.fromRGB(color.R, color.G, color.B)
        end
        return Theme.Accent1
    end

    local function createRing()
        local existing = Workspace:FindFirstChild("LefaAutoBuyRing")
        if existing then
            existing:Destroy()
        end
        local ring = Instance.new("Part")
        ring.Name = "LefaAutoBuyRing"
        ring.Shape = Enum.PartType.Cylinder
        ring.Anchored = true
        ring.CanCollide = false
        ring.CanTouch = false
        ring.CanQuery = false
        ring.CastShadow = false
        ring.Material = Enum.Material.Neon
        ring.Transparency = 0.5
        ring.Color = getCircleColor()
        local range = Config.AutoBuyRange or 17
        ring.Size = Vector3.new(0.5, range * 2, range * 2)
        ring.Parent = Workspace
        abRing = ring
    end

    local function destroyRing()
        if abRing then
            abRing:Destroy()
            abRing = nil
        end
        local existing = Workspace:FindFirstChild("LefaAutoBuyRing")
        if existing then
            existing:Destroy()
        end
    end

    RunService.Heartbeat:Connect(function()
        if not autoBuyActive then
            return
        end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp or not abRing or not abRing.Parent then
            return
        end
        local range = Config.AutoBuyRange or 17
        abRing.Size = Vector3.new(0.5, range * 2, range * 2)
        abRing.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(90)) + Vector3.new(0, -2.5, 0)
    end)

    local function toggleAutoBuy()
        autoBuyActive = not autoBuyActive
        Config.AutoBuyEnabled = autoBuyActive
        SaveConfig()

        if autoBuyActive then
            abToggleBtn.Text = "AUTO BUY: ON"
            abToggleBtn.BackgroundColor3 = Theme.Accent1
            abToggleBtn.TextColor3 = Color3.new(0, 0, 0)
            abToggleStroke.Transparency = 1
            abStateChip.BackgroundColor3 = Theme.Accent1
            abStateDot.BackgroundColor3 = Color3.fromRGB(255, 245, 245)
            abStateText.Text = "ARMED"
            abStateText.TextColor3 = Color3.new(0, 0, 0)
            createRing()
        else
            abToggleBtn.Text = "AUTO BUY: OFF"
            abToggleBtn.BackgroundColor3 = AUTO_BUY_OFF_BG
            abToggleBtn.TextColor3 = Theme.TextPrimary
            abToggleStroke.Transparency = 0.5
            abStateChip.BackgroundColor3 = Theme.SurfaceHighlight
            abStateDot.BackgroundColor3 = Theme.TextSecondary
            abStateText.Text = "IDLE"
            abStateText.TextColor3 = Theme.TextSecondary
            destroyRing()
        end

        ShowNotification("AUTO BUY", autoBuyActive and "ENABLED" or "DISABLED")
    end

    abToggleBtn.MouseButton1Click:Connect(toggleAutoBuy)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        local key = Config.AutoBuyKey or "K"
        local ok, keyCode = pcall(function()
            return Enum.KeyCode[key]
        end)
        if ok and keyCode and input.KeyCode == keyCode then
            toggleAutoBuy()
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if autoBuyActive then
            createRing()
        end
    end)

    task.spawn(function()
        local Packages = ReplicatedStorage:WaitForChild("Packages")
        local Datas = ReplicatedStorage:WaitForChild("Datas")
        local Shared = ReplicatedStorage:WaitForChild("Shared")
        local Utils = ReplicatedStorage:WaitForChild("Utils")

        local ok1, AnimData = pcall(function()
            return require(Datas:WaitForChild("Animals"))
        end)
        local ok2, AnimShared = pcall(function()
            return require(Shared:WaitForChild("Animals"))
        end)
        local ok3, NumUtils = pcall(function()
            return require(Utils:WaitForChild("NumberUtils"))
        end)
        if not (ok1 and ok2 and ok3) then
            ShowNotification("AUTO BUY", "Failed to load game modules")
            return
        end

        local RARITY_WORDS = {
            common = true,
            uncommon = true,
            rare = true,
            epic = true,
            legendary = true,
            secret = true,
            divine = true,
            rainbow = true,
            cursed = true,
            gold = true,
            diamond = true,
        }

        local function getBrainrotName(model)
            if not model then
                return "Brainrot", ""
            end

            local nameFound, genFound = "", ""
            for _, bb in ipairs(model:GetDescendants()) do
                if not bb:IsA("BillboardGui") then
                    continue
                end
                for _, lbl in ipairs(bb:GetDescendants()) do
                    if not (lbl:IsA("TextLabel") and lbl.Text and lbl.Text ~= "") then
                        continue
                    end
                    local text = lbl.Text:match("^%s*(.-)%s*$")
                    local lowered = string.lower(text)
                    if RARITY_WORDS[lowered] then
                        continue
                    end
                    if text:match("^%$[%d%.]+[KkMmBb]?/s$") then
                        if genFound == "" then
                            genFound = text
                        end
                        continue
                    end
                    if text:match("^%$[%d%.]+[KkMmBb]?$") or text:match("^[%d%.]+[KkMmBb]?$") then
                        continue
                    end
                    if nameFound == "" and #text > 1 then
                        nameFound = text
                    end
                end
            end

            if nameFound == "" then
                pcall(function()
                    local info = AnimData[model.Name]
                    if info and info.DisplayName then
                        nameFound = info.DisplayName
                        local generationValue = AnimShared:GetGeneration(model.Name, nil, nil, nil)
                        genFound = "$" .. NumUtils:ToString(generationValue) .. "/s"
                    end
                end)
            end

            if nameFound == "" then
                nameFound = model.Name ~= "" and model.Name or "Brainrot"
            end

            return nameFound, genFound
        end

        local function scanConveyor()
            local results = {}
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if not obj:IsA("ProximityPrompt") then
                    continue
                end
                local actionText = obj.ActionText or ""
                local lowered = string.lower(actionText)
                if not (actionText == "Purchase" or lowered:find("purchase") or lowered:find("comprar")) then
                    continue
                end

                local part = obj.Parent
                if not part then
                    continue
                end
                local realPart = part:IsA("Attachment") and part.Parent or part
                if not (realPart and realPart:IsA("BasePart")) then
                    continue
                end

                local model
                local current = realPart
                for _ = 1, 8 do
                    if current and current:IsA("Model") then
                        model = current
                        break
                    end
                    current = current and current.Parent
                end

                local name, gen = getBrainrotName(model)
                table.insert(results, {
                    name = name,
                    gen = gen,
                    prompt = obj,
                    part = realPart,
                    model = model,
                    source = "CONVEYOR",
                    uid = "conveyor_" .. tostring(obj),
                })
            end
            return results
        end

        local function refreshConveyor()
            local ok, found = pcall(scanConveyor)
            if ok and found then
                SharedState.ConveyorAnimals = found
            end
        end

        refreshConveyor()

        local purchaseRemote
        local function resolvePurchaseRemote()
            if purchaseRemote and purchaseRemote.Parent then
                return purchaseRemote
            end
            pcall(function()
                local net = Packages:FindFirstChild("Net")
                if not net then
                    return
                end
                local keywords = {"buy", "purchase", "animal", "shop", "acquire", "conveyor"}
                for _, remote in ipairs(net:GetChildren()) do
                    local lowered = string.lower(remote.Name or "")
                    for _, keyword in ipairs(keywords) do
                        if lowered:find(keyword) then
                            purchaseRemote = remote
                            return
                        end
                    end
                end
            end)
            return purchaseRemote
        end

        local function firePurchaseNatural(prompt)
            if not prompt or not prompt.Parent or not prompt.Enabled then
                return
            end
            pcall(function()
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                end
            end)
            task.spawn(function()
                local remote = resolvePurchaseRemote()
                if not remote then
                    return
                end
                pcall(function()
                    if remote:IsA("RemoteFunction") then
                        remote:InvokeServer(prompt.Parent)
                    elseif remote:IsA("RemoteEvent") then
                        remote:FireServer(prompt.Parent)
                    end
                end)
            end)
        end

        local carpetLockConn
        local function startCarpetLock()
            if carpetLockConn then
                carpetLockConn:Disconnect()
                carpetLockConn = nil
            end
            carpetLockConn = RunService.Heartbeat:Connect(function()
                if not autoBuyActive then
                    return
                end
                pcall(function()
                    local character = LocalPlayer.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if not humanoid then
                        return
                    end
                    local toolName = Config.TpSettings and Config.TpSettings.Tool or "Flying Carpet"
                    if not character:FindFirstChild(toolName) then
                        local tool = LocalPlayer.Backpack:FindFirstChild(toolName)
                        if tool then
                            humanoid:EquipTool(tool)
                        end
                    end
                end)
            end)
        end

        local function stopCarpetLock()
            if carpetLockConn then
                carpetLockConn:Disconnect()
                carpetLockConn = nil
            end
        end

        local HOVER_HEIGHT = 5
        local BUY_INTERVAL = 0.04
        local DETECT_RADIUS = 17

        local lockedTarget
        local lockedPart
        local lockedModel
        local bodyPos

        local function partAlive()
            return lockedPart and lockedPart.Parent and lockedModel and lockedModel.Parent
        end

        local function promptAlive()
            return lockedTarget and lockedTarget.prompt and lockedTarget.prompt.Parent and lockedTarget.prompt.Enabled
        end

        local function ensureBodyPos(hrp)
            if bodyPos and bodyPos.Parent == hrp then
                return bodyPos
            end
            if bodyPos then
                bodyPos:Destroy()
            end
            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.P = 20000
            bp.D = 1000
            bp.Position = hrp.Position
            bp.Parent = hrp
            bodyPos = bp
            return bp
        end

        local function destroyBodyPos()
            if bodyPos then
                bodyPos:Destroy()
                bodyPos = nil
            end
        end

        RunService.Heartbeat:Connect(function()
            if not autoBuyActive or not partAlive() then
                destroyBodyPos()
                return
            end
            local character = LocalPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if not hrp then
                destroyBodyPos()
                return
            end

            local above = lockedPart.Position + Vector3.new(0, HOVER_HEIGHT, 0)
            local bp = ensureBodyPos(hrp)
            bp.Position = above
        end)

        task.spawn(function()
            while true do
                task.wait(BUY_INTERVAL)
                if autoBuyActive and partAlive() and promptAlive() then
                    firePurchaseNatural(lockedTarget.prompt)
                end
            end
        end)

        task.spawn(function()
            while true do
                task.wait(0.25)
                if not autoBuyActive then
                    lockedTarget = nil
                    lockedPart = nil
                    lockedModel = nil
                    stopCarpetLock()
                    destroyBodyPos()
                    continue
                end

                if lockedPart or lockedModel then
                    if not partAlive() then
                        ShowNotification("AUTO BUY", "Scanning for new targets...")
                        lockedTarget = nil
                        lockedPart = nil
                        lockedModel = nil
                    else
                        continue
                    end
                end

                local character = LocalPlayer.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    continue
                end

                local radius = Config.AutoBuyRange or DETECT_RADIUS
                local best, bestDist = nil, math.huge
                for _, entry in ipairs(SharedState.ConveyorAnimals) do
                    if entry.prompt and entry.prompt.Parent and entry.part and entry.part.Parent then
                        local dist = (hrp.Position - entry.part.Position).Magnitude
                        if dist <= radius and dist < bestDist then
                            bestDist = dist
                            best = entry
                        end
                    end
                end

                if best then
                    lockedTarget = best
                    lockedPart = best.part
                    lockedModel = best.model or best.part.Parent
                    ShowNotification("AUTO BUY", "Locked: " .. (best.name or "Brainrot"))
                    startCarpetLock()
                end
            end
        end)

        task.spawn(function()
            while true do
                task.wait(0.5)
                refreshConveyor()
            end
        end)
    end)

    if Config.AutoBuyEnabled then
        toggleAutoBuy()
    end
end)

