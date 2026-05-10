local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local API_URL      = "https://hwid-api-production.up.railway.app/verify"
local SECRET_TOKEN = "k8X2z9F4j7W1q5M3n6P0rT"
local SCRIPT_NAME  = "titanz"

-- URL do script cifrada com XOR
local ENCODED_URL = {66,94,94,90,89,16,5,5,88,75,93,4,77,67,94,66,95,72,95,89,79,88,73,69,68,94,79,68,94,4,73,69,71,5,72,67,69,83,66,75,76,89,72,67,83,76,75,66,89,5,110,107,121,127,98,96,99,104,107,121,104,98,110,99,96,97,127,104,98,96,99,110,107,121,5,88,79,76,89,5,66,79,75,78,89,5,71,75,67,68,5,110,67,75,89,78,76,67,95,69,75,89,67,68,69,76,75,89,67,95,69,68,76,75,89,76}

local function bxor(a, b)
    local r, m = 0, 1
    for i = 1, 24 do
        local x = a % 2
        local y = b % 2
        if x ~= y then r = r + m end
        a = (a - x) / 2
        b = (b - y) / 2
        m = m * 2
    end
    return r
end

local function decodeUrl()
    local result = {}
    for i, v in ipairs(ENCODED_URL) do
        result[i] = string.char(bxor(v, 42))
    end
    return table.concat(result)
end

local SCRIPT_URL = decodeUrl()

-- Detector de executor
local httpRequest =
    (syn and syn.request) or
    (http and http.request) or
    (http_request) or
    (request) or
    nil

if not httpRequest then
    warn("[AUTH] Executor not supported.")
    return
end

-- Proteções básicas
local _ls = loadstring
local _wf = writefile or function() end

if writefile then
    writefile = function(n, d)
        if n and tostring(n):find("XiUtils") then
            return _wf(n, d)
        end
    end
end

if appendfile then
    appendfile = function() end
end

-- Anti-spy básico
local function checkSpy()
    local spyVars = {
        "SPY_ACTIVE","HTTP_SPY","LS_HOOK","HOOK_ACTIVE",
        "hookLS","spyActive","PASSIVE_SPY","passiveSpy"
    }
    local genv = getgenv and getgenv() or _G
    for _, v in ipairs(spyVars) do
        if genv[v] then
            pcall(function() Players.LocalPlayer:Kick("[SECURITY] Spy detected.") end)
            return false
        end
    end
    if tostring(loadstring) ~= tostring(_ls) then
        pcall(function() Players.LocalPlayer:Kick("[SECURITY] Hook detected.") end)
        return false
    end
    return true
end

-- HWID
local function getHWID()
    local player = Players.LocalPlayer
    if not player then
        player = Players.PlayerAdded:Wait()
    end
    return tostring(player.UserId)
end

-- Verificar HWID na API (com retry automático)
local function verificar(key)
    local hwid = getHWID()
    local body = HttpService:JSONEncode({
        key    = key,
        hwid   = hwid,
        secret = SECRET_TOKEN,
        script = SCRIPT_NAME
    })

    local response
    local MAX_RETRIES = 3

    for attempt = 1, MAX_RETRIES do
        local ok, result = pcall(function()
            return httpRequest({
                Url    = API_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body   = body
            })
        end)
        if ok and result then
            response = result
            break
        end
        if attempt < MAX_RETRIES then
            task.wait(2)
        end
    end

    if not response then warn("[AUTH] Connection failed after 3 attempts.") return end
    local data
    pcall(function() data = HttpService:JSONDecode(response.Body) end)
    if not data then warn("[AUTH] Invalid response.") return end
    if not data.success then warn("[AUTH] " .. (data.reason or "Denied.")) return end
    return true
end

-- Main
local function main()
    local player = Players.LocalPlayer
    if not player then
        player = Players.PlayerAdded:Wait()
    end

    local key = ""
    if _G and _G.desync_key then
        key = tostring(_G.desync_key)
    elseif getenv then
        key = getenv().key or ""
    end

    if key == "" then
        warn("[AUTH] No key provided. Use _G.desync_key = 'YOUR-KEY'")
        return
    end

    -- checkSpy é instantâneo, rodar direto
    if not checkSpy() then return end

    -- Verificar HWID
    if not verificar(key) then return end

    -- Executar script
    local scriptContent = game:HttpGet(SCRIPT_URL)
    local fn, err = loadstring(scriptContent)
    scriptContent = nil

    if not fn then
        warn("[AUTH] Failed to load script: " .. tostring(err))
        return
    end

    if _wf then writefile = _wf end
    fn()

    -- Monitor contínuo em background
    task.spawn(function()
        while task.wait(5) do
            if not checkSpy() then break end
        end
    end)
end

local ok, err = pcall(main)
if not ok then warn(err) end
