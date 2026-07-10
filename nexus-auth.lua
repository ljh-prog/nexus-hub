local AUTH_SERVER = "https://unused-nastily-blurt.ngrok-free.dev"
local script_key = script_key or "YOUR_KEY_HERE" 

local function getHWID()
    local hwidParts = {}
    

    pcall(function()
        if hwid and type(hwid) == "function" then
            local h = hwid()
            if h and #h > 0 then table.insert(hwidParts, h) end
        end
    end)
    
    pcall(function()
        if gethwid and type(gethwid) == "function" then
            local h = gethwid()
            if h and #h > 0 then table.insert(hwidParts, h) end
        end
    end)
    

    pcall(function()
        if gethwid and type(gethwid) == "string" then
            table.insert(hwidParts, gethwid)
        end
    end)
    

    pcall(function()
        if identifyexecutor then
            local name, version = identifyexecutor()
            table.insert(hwidParts, tostring(name))
        end
    end)
    

    pcall(function()
        local players = game:GetService("Players")
        local lp = players.LocalPlayer
        if lp then
            table.insert(hwidParts, tostring(lp.UserId))
        end
    end)
    
    pcall(function()
        table.insert(hwidParts, tostring(game.GameId))
    end)
    
    pcall(function()
        table.insert(hwidParts, tostring(game.PlaceId))
    end)
    

    local rawHWID = table.concat(hwidParts, "-")
    
    if #rawHWID == 0 then
        rawHWID = "fallback-" .. tostring(math.random(100000, 999999))
    end

    local hash = ""
    pcall(function()
        if crypt and crypt.hash then
            hash = crypt.hash(rawHWID, "sha256")
        end
    end)
    
    if hash == "" or not hash then
        pcall(function()
            if syn and syn.crypt and syn.crypt.hash then
                hash = syn.crypt.hash(rawHWID, "sha256")
            end
        end)
    end
    
    if hash == "" or not hash then
        local h = 5381
        for i = 1, #rawHWID do
            h = (h * 33 + string.byte(rawHWID, i)) % 2147483647
        end
        hash = string.format("%x", h)
    end
    
    print("[Nexus] HWID parts: " .. #hwidParts .. " detected")
    print("[Nexus] Raw HWID length: " .. #rawHWID)
    print("[Nexus] Final HWID: " .. tostring(hash):sub(1, 16) .. "...")
    
    return tostring(hash)
end


local function httpRequest(url, method, body)
    method = method or "GET"
    
    print("[Nexus] HTTP " .. method .. " " .. url)
    
    local success, result = pcall(function()

        if request then
            return request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["ngrok-skip-browser-warning"] = "true"
                },
                Body = body
            })
        end
        

        if http_request then
            return http_request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["ngrok-skip-browser-warning"] = "true"
                },
                Body = body
            })
        end
        
        -- 3. syn.request (Synapse X)
        if syn and syn.request then
            return syn.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["ngrok-skip-browser-warning"] = "true"
                },
                Body = body
            })
        end
        
        -- 4. fluxus.request (Fluxus)
        if fluxus and fluxus.request then
            return fluxus.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["ngrok-skip-browser-warning"] = "true"
                },
                Body = body
            })
        end
        
        -- 5. HttpService (마지막 수단 - GET만)
        local hs = game:GetService("HttpService")
        if method == "GET" then
            -- HttpService는 POST를 지원하지 않으므로 GET만 처리
            return { Body = hs:GetAsync(url, true), StatusCode = 200 }
        end
        
        -- 6. POST를 위한 HttpService:JSONEncode + RequestAsync (일부 executor)
        if game:GetService("HttpService").RequestAsync then
            local resp = game:GetService("HttpService"):RequestAsync({
                Url = url,
                Method = method,
                Headers = { ["Content-Type"] = "application/json", ["ngrok-skip-browser-warning"] = "true" },
                Body = body
            })
            return { Body = resp.Body, StatusCode = resp.StatusCode }
        end
        
        error("No HTTP method available in this executor")
    end)
    
    if success and result then
        print("[Nexus] HTTP Response: " .. tostring(result.StatusCode))
        return result.Body, result.StatusCode
    end
    
    print("[Nexus] HTTP Error: " .. tostring(result))
    return nil, 0
end

-- ==================== ERROR UI ====================
local function showErrorUI(errorMsg, isHWIDError)
    pcall(function()
        local players = game:GetService("Players")
        local lp = players.LocalPlayer
        local gui = Instance.new("ScreenGui")
        gui.Name = "NexusAuthError"
        gui.Parent = game:GetService("CoreGui")
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 420, 0, isHWIDError and 200 or 150)
        frame.Position = UDim2.new(0.5, -210, 0.5, isHWIDError and -100 or -75)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 30)
        title.Position = UDim2.new(0, 10, 0, 10)
        title.BackgroundTransparency = 1
        title.Text = "❌ Nexus Private - Authentication Failed"
        title.TextColor3 = Color3.fromRGB(255, 60, 60)
        title.Font = Enum.Font.GothamBold
        title.TextSize = 16
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.Parent = frame
        
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, -20, 0, isHWIDError and 100 or 60)
        msg.Position = UDim2.new(0, 10, 0, 50)
        msg.BackgroundTransparency = 1
        msg.Text = errorMsg
        msg.TextColor3 = Color3.fromRGB(255, 255, 255)
        msg.Font = Enum.Font.GothamMedium
        msg.TextSize = 13
        msg.TextWrapped = true
        msg.TextXAlignment = Enum.TextXAlignment.Center
        msg.Parent = frame
        
        if isHWIDError then
            local hint = Instance.new("TextLabel")
            hint.Size = UDim2.new(1, -20, 0, 20)
            hint.Position = UDim2.new(0, 10, 0, 155)
            hint.BackgroundTransparency = 1
            hint.Text = "Go to Discord → Click HWID Reset → Try again"
            hint.TextColor3 = Color3.fromRGB(255, 200, 50)
            hint.Font = Enum.Font.GothamMedium
            hint.TextSize = 12
            hint.TextXAlignment = Enum.TextXAlignment.Center
            hint.Parent = frame
        end
        
        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 100, 0, 30)
        close.Position = UDim2.new(0.5, -50, 1, -40)
        close.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
        close.Text = "Close"
        close.TextColor3 = Color3.fromRGB(255, 255, 255)
        close.Font = Enum.Font.GothamBold
        close.TextSize = 14
        close.Parent = frame
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 6)
        closeCorner.Parent = close
        
        close.MouseButton1Click:Connect(function()
            gui:Destroy()
        end)
        
        task.delay(20, function()
            if gui.Parent then gui:Destroy() end
        end)
    end)
end

-- ==================== AUTHENTICATION ====================
local function getRobloxUserInfo()
    local ok, player = pcall(function()
        return game:GetService("Players").LocalPlayer
    end)
    if ok and player then
        return {
            id = player.UserId or 0,
            name = player.Name or "Unknown"
        }
    end
    return { id = 0, name = "Unknown" }
end

local function forceKick(message)
    print("[Nexus] 🚫 Kicking: " .. tostring(message))
    pcall(function()
        game.Players.LocalPlayer:Kick(message)
    end)
    task.wait(0.3)
    pcall(function()
        game:Shutdown()
    end)
end

local function authenticate()
    local hwid = getHWID()
    local robloxInfo = getRobloxUserInfo()
    
    print("[Nexus] Authenticating...")
    print("[Nexus] Key: " .. script_key)
    
    local body = game:GetService("HttpService"):JSONEncode({
        key = script_key,
        hwid = hwid,
        roblox_id = robloxInfo.id,
        roblox_name = robloxInfo.name
    })
    
    local responseBody, statusCode = httpRequest(AUTH_SERVER .. "/api/auth", "POST", body)
    
    if not responseBody or statusCode ~= 200 then
        -- 에러 메시지 파싱
        local errorMsg = "Connection failed (status: " .. tostring(statusCode) .. ")"
        local errorCode = nil
        if responseBody then
            pcall(function()
                local parsed = game:GetService("HttpService"):JSONDecode(responseBody)
                if parsed.error then errorMsg = parsed.error end
                if parsed.code then errorCode = parsed.code end
            end)
        end
        
        print("[Nexus] ❌ Authentication failed: " .. errorMsg)
        return false, errorMsg, errorCode
    end
    
    -- 응답 파싱
    local success, parsed = pcall(function()
        return game:GetService("HttpService"):JSONDecode(responseBody)
    end)
    
    if not success or not parsed.success then
        local errorMsg = (parsed and parsed.error) or "Unknown error"
        local errorCode = (parsed and parsed.code) or nil
        print("[Nexus] ❌ Authentication failed: " .. errorMsg)
        return false, errorMsg, errorCode
    end
    
    print("[Nexus] ✅ Authentication successful!")
    print("[Nexus] Session: " .. (parsed.session_token or "N/A"))
    
    return true, parsed
end


local function loadMainScript(authData)
    if not authData or not authData.script_url then
        print("[Nexus] ❌ No script URL received")
        return false
    end
    
    print("[Nexus] 📜 Loading script from: " .. authData.script_url)
    
    local scriptContent, statusCode = httpRequest(authData.script_url, "GET")
    
    if not scriptContent or statusCode ~= 200 then
        print("[Nexus] ❌ Failed to load script (status: " .. tostring(statusCode) .. ")")
        return false
    end
    
    local success, err = pcall(function()
        local func = loadstring(scriptContent)
        if func then
            func()
        else
            error("Failed to compile script")
        end
    end)
    
    if not success then
        print("[Nexus] ❌ Script execution error: " .. tostring(err))
        return false
    end
    
    print("[Nexus] ✅ Script loaded successfully!")
    return true
end


local function startHeartbeat()
    if not sessionToken then return end
    
    task.spawn(function()
        while true do
            task.wait(300) 
            local body = game:GetService("HttpService"):JSONEncode({
                session_token = sessionToken
            })
            httpRequest(AUTH_SERVER .. "/api/heartbeat", "POST", body)
        end
    end)
end


local function main()
    print("[Nexus] ===================================")
    print("[Nexus] Nexus Private Auth Wrapper v3")
    print("[Nexus] ===================================")
    

    local success, result, errorCode = authenticate()
    
    if not success then

        local isHWIDError = (errorCode == "HWID_MISMATCH")
        
        if isHWIDError then
            showErrorUI(
                "⚠️ HWID Mismatch!\n\nThis key is bound to another device.\nTo use this script on this device, go to the Discord server and click the HWID Reset button.",
                true
            )
        else
            showErrorUI(result or "Unknown error", false)
        end

        -- 인증 실패 시 잠깐 메시지를 보여준 뒤 강제로 게임에서 튕김
        task.delay(3, function()
            forceKick(isHWIDError
                and "[Nexus] HWID mismatch - this key is bound to another device. Reset your HWID on Discord."
                or ("[Nexus] Authentication failed: " .. tostring(result or "Unknown error")))
        end)
        return
    end

    sessionToken = result.session_token

    startHeartbeat()

    -- 실제 스크립트 실행 로그를 웹 서버로 전송 (디바이스/실행 감지)
    print("[Nexus] Sending execution log...")
    local execOk, execErr = pcall(function()
        local executorName = "Unknown"
        local exOk, exResult = pcall(function()
            if identifyexecutor then
                local name = identifyexecutor()
                return tostring(name)
            end
            return "Unknown"
        end)
        if exOk and exResult then
            executorName = exResult
        end

        local robloxInfo = getRobloxUserInfo()
        local runBody = game:GetService("HttpService"):JSONEncode({
            key = script_key,
            hwid = getHWID(),
            executor = executorName,
            roblox_id = robloxInfo.id,
            roblox_name = robloxInfo.name
        })
        local respBody, statusCode = httpRequest(AUTH_SERVER .. "/api/execute", "POST", runBody)
        print("[Nexus] /api/execute -> status: " .. tostring(statusCode))
    end)
    if not execOk then
        print("[Nexus] ❌ Execute-log block errored: " .. tostring(execErr))
    end

    loadMainScript(result)
end


main()
