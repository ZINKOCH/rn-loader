local function linkId()
 return 4800430
end
local function ownerId()
 return 579838
end
local function placeId()
 local hi = (9000 + 397) * 10000 + 8595
 local lo = (700 + 33) * 1000 + 734
 return hi * 1000000 + lo
end
local function sessMagic()
 return (1511506142)
end

local CONFIG = {
 NAME = "ZINKA",
 SCRIPT_URL = "https://raw.githubusercontent.com/ZINKOCH/rn-loader/main/zinka_MAIN_protected.lua",
 BUST_CACHE = true,
 KEY_LINK = "https://work.ink/2qQe/zinka-key",
 OWNER_USER_ID = ownerId(),
 LINK_ID = linkId(),
 ALLOWED_PLACES = {
 [placeId()] = "[Treatment] Violence District",
 },
 KICK_ON_WRONG_PLACE = true,
 KICK_ON_NO_KEY = true,
 KEY_FILE = "rayon_key.txt",
 BIND_FILE = "rayon_bind.txt",
 WORKER_ORIGIN = "https://raw.githubusercontent.com/ZINKOCH/rn-loader/main",
 DISCORD_INVITE = "https://discord.gg/rSGThCEhxw",
 DISCORD_ENABLED = true,
 AUDIENCE_MODE = false,
 COMMUNITY_KEY = "ZINKA-WAVE1",
}

local genv = (getgenv and getgenv()) or _G
genv.__RN_DISCORD = CONFIG.DISCORD_INVITE
genv.__ZINKA_DISCORD = CONFIG.DISCORD_INVITE
_G.__RN_DISCORD = CONFIG.DISCORD_INVITE
_G.__ZINKA_DISCORD = CONFIG.DISCORD_INVITE
do
 local lockAt = tonumber(genv.__RN_LOADER_LOCK_AT) or 0
 if genv.__RN_LOADER_RUNNING and (os.time() - lockAt) < 90 then
 local guiParent = (gethui and gethui()) or game:FindFirstChildOfClass("CoreGui")
 local keyUi = guiParent and guiParent:FindFirstChild("ZINKA_KEY_UI")
 if keyUi then
 pcall(function() keyUi:Destroy() end)
 genv.__RN_LOADER_RUNNING = nil
 else
 return warn("[" .. CONFIG.NAME .. "] Already running.")
 end
 end
end
genv.__RN_LOADER_RUNNING = true
genv.__RN_LOADER_LOCK_AT = os.time()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local lp = Players.LocalPlayer or Players.PlayerAdded:Wait()
local ACCEPTED_KEY = nil
local DEVICE_HWID = nil
local API_PREFIX = "https://work.ink/_api/v2/token/isValid/"
local AUTH_SALT = "zinka.rn.auth.v3"
local SESS_SALT = "zinka.rn.sess.v1"
local SESS_MAGIC = sessMagic()

local function rawDeviceId()
 local probes = {
 function() return gethwid and gethwid() end,
 function() return get_hwid and get_hwid() end,
 function() return getHWID and getHWID() end,
 function() return syn and syn.get_hwid and syn.get_hwid() end,
 function() return syn and syn.gethwid and syn.gethwid() end,
 function() return fluxus and fluxus.get_hwid and fluxus.get_hwid() end,
 function()
 local ok, svc = pcall(function() return game:GetService("RbxAnalyticsService") end)
 if ok and svc and svc.GetClientId then return svc:GetClientId() end
 end,
 function()
 if lp and lp.UserId and lp.UserId > 0 then
 return "uid:" .. tostring(lp.UserId)
 end
 end,
 }
 for _, fn in ipairs(probes) do
 local ok, v = pcall(fn)
 if ok and v ~= nil then
 local s = tostring(v):gsub("%s+", "")
 if #s >= 4 and s ~= "nil" and s ~= "0" then return s end
 end
 end
 return "fallback:" .. tostring(game.PlaceId) .. ":" .. tostring(os.time() % 100000)
end

local function mix32(n)
 n = (n * 1664525 + 1013904223) % 4294967296
 return n
end
local function hashHwid(raw)
 local h = 2166136261
 local s = tostring(raw) .. "|" .. AUTH_SALT .. "|hwid"
 for i = 1, #s do
 h = mix32(_bx(h % 256, string.byte(s, i)) + math.floor(h / 256) + i * 131)
 end
 return string.format("%08x%08x", h % 4294967296, mix32(h + #s) % 4294967296)
end
local function getDeviceHwid()
 if DEVICE_HWID then return DEVICE_HWID end
 DEVICE_HWID = hashHwid(rawDeviceId())
 return DEVICE_HWID
end
local function tokenOf(key, ts, hid)
 local h = 2166136261
 local s = tostring(key) .. "|" .. AUTH_SALT .. "|" .. tostring(ts) .. "|"
 .. tostring(game.PlaceId) .. "|" .. tostring(hid or "")
 for i = 1, #s do
 h = mix32(_bx(h % 256, string.byte(s, i)) + math.floor(h / 256) + i * 131)
 end
 return string.format("%08x%08x", h % 4294967296, mix32(h + #s) % 4294967296)
end
local function sessionSig(key, ts, hid, nonce)
 local h = 2166136261
 local s = tostring(key) .. "|" .. SESS_SALT .. "|" .. tostring(ts) .. "|"
 .. tostring(hid or "") .. "|" .. tostring(nonce) .. "|" .. tostring(SESS_MAGIC)
 .. "|" .. tostring(game.PlaceId)
 for i = 1, #s do
 h = mix32(_bx(h % 256, string.byte(s, i)) + math.floor(h / 256) + i * 173)
 end
 return string.format("%08x%08x", h % 4294967296, mix32(h + #s + SESS_MAGIC) % 4294967296)
end
local function mintNonce(ts, key)
 local a = mix32(ts * 2654435761 + #tostring(key))
 local b = mix32(math.floor((os.clock() % 1) * 1e9) + a)
 return string.format("%08x%08x", a % 4294967296, b % 4294967296)
end

local function publishAuth(key)
 local ts = os.time()
 local hid = getDeviceHwid()
 local tok = tokenOf(key, ts, hid)
 local nonce = mintNonce(ts, key)
 local sess = sessionSig(key, ts, hid, nonce)
 local blob = {
 k = key,
 ts = ts,
 t = tok,
 h = hid,
 lid = CONFIG.LINK_ID,
 n = nonce,
 s = sess,
 _ = mix32(ts + #key),
 }
 genv.__RN_AUTH = blob
 _G.__RN_AUTH = blob
 genv.__RN_AUTH_OK = true
 _G.__RN_AUTH_OK = true
 genv.__RN_HWID = hid
 _G.__RN_HWID = hid
 genv.__RN_LOADER = true
 _G.__RN_LOADER = true
 genv.__RN_OK = true
 genv.__RN_AUTH_SOFT = { ok = true, t = tok }
 genv.__ZINKA_PREAUTH = "ok"
 genv.__RN_AUTH_TOKEN = string.format("%08x", mix32(ts))
 _G.__RN_OK = true
 _G.__RN_AUTH_SOFT = genv.__RN_AUTH_SOFT
 _G.__ZINKA_PREAUTH = "ok"
 _G.__RN_AUTH_TOKEN = genv.__RN_AUTH_TOKEN
end

local hasFS = type(readfile) == "function"
 and type(writefile) == "function"
 and type(isfile) == "function"
local KEY_GENV = "__RN_SAVED_KEY"

local function httpGet(url, timeoutSec)
 timeoutSec = timeoutSec or 25
 local tries = {
 function()
 local req = (syn and syn.request) or http_request or request
 if not req then return nil end
 local r = req({
 Url = url,
 Method = "GET",
 Headers = { ["Accept-Encoding"] = "identity" },
 })
 if not r then return nil end
 local body = r.Body or r.body
 if type(body) == "string" and #body > 0 then return body end
 return nil
 end,
 function() return game:HttpGet(url, true) end,
 function() return game:HttpGetAsync(url, true) end,
 }
 for _, fn in ipairs(tries) do
 local done, body
 task.spawn(function()
 local ok, res = pcall(fn)
 if ok and type(res) == "string" and #res > 0 then body = res end
 done = true
 end)
 local t0 = os.clock()
 while not done and (os.clock() - t0) < timeoutSec do
 task.wait(0.05)
 end
 if type(body) == "string" and #body > 0 then return body end
 end
 return nil
end

local function notify(text, dur)
 pcall(function()
 StarterGui:SetCore("SendNotification", {
 Title = CONFIG.NAME, Text = text, Duration = dur or 5,
 })
 end)
end

local function stop(reason, kick)
 genv.__RN_LOADER_RUNNING = nil
 warn(("[%s] %s"):format(CONFIG.NAME, reason))
 if kick then
 task.delay(0.4, function()
 pcall(function() lp:Kick(("[%s]\n\n%s"):format(CONFIG.NAME, reason)) end)
 end)
 else
 notify(reason, 8)
 end
 error(reason, 0)
end

local function normalizeKey(key)
 return tostring(key or ""):gsub("%s+", "")
end
local function loadSavedKey()
 if hasFS then
 local ok, data = pcall(function()
 if isfile(CONFIG.KEY_FILE) then return readfile(CONFIG.KEY_FILE) end
 end)
 if ok and type(data) == "string" then
 local k = normalizeKey(data)
 if #k >= 10 then return k end
 end
 end
 local g = genv[KEY_GENV] or _G[KEY_GENV]
 if type(g) == "string" then
 local k = normalizeKey(g)
 if #k >= 10 then return k end
 end
 return nil
end
local function saveKey(key)
 key = normalizeKey(key)
 genv[KEY_GENV] = key
 _G[KEY_GENV] = key
 if hasFS then pcall(writefile, CONFIG.KEY_FILE, key) end
end
local function clearKey()
 genv[KEY_GENV] = nil
 _G[KEY_GENV] = nil
 if hasFS then
 pcall(function()
 if isfile(CONFIG.KEY_FILE) then delfile(CONFIG.KEY_FILE) end
 end)
 end
end

local function workerOrigin()
 local explicit = tostring(CONFIG.WORKER_ORIGIN or ""):gsub("%s+", ""):gsub("/+$", "")
 if #explicit > 12 then return explicit end
 local su = tostring(CONFIG.SCRIPT_URL or "")
 local host = su:match("^(https://[%w%-%.]+%.workers%.dev)")
 return host
end

local function localBindCheck(key, hid)
 if not hasFS then return true end
 local path = CONFIG.BIND_FILE
 local map = {}
 pcall(function()
 if isfile(path) then
 for line in string.gmatch(readfile(path), "[^\r\n]+") do
 local k, h = line:match("^([^%s|]+)|([0-9a-fA-F]+)$")
 if k and h then map[k:lower()] = h:lower() end
 end
 end
 end)
 local prev = map[key:lower()]
 if prev and prev ~= hid:lower() then
 return false, "Key already bound to another device"
 end
 map[key:lower()] = hid:lower()
 local lines = {}
 for k, h in pairs(map) do
 lines[#lines + 1] = k .. "|" .. h
 end
 pcall(writefile, path, table.concat(lines, "\n"))
 return true
end
local function bindDevice(key)
 local hid = getDeviceHwid()
 local origin = workerOrigin()
 if origin then
 local uid = (lp and lp.UserId) and tostring(lp.UserId) or "0"
 local url = origin .. "/bind?k=" .. HttpService:UrlEncode(key)
 .. "&h=" .. HttpService:UrlEncode(hid)
 .. "&u=" .. HttpService:UrlEncode(uid)
 local body = httpGet(url)
 if type(body) == "string" then
 body = body:gsub("^%s+", ""):gsub("%s+$", "")
 if body == "OK" then return true end
 local reason = body:match("^DENIED:(%w+)")
 if reason == "bound" then
 return false, "Key already bound to another device"
 end
 if reason == "noconfig" then
 return localBindCheck(key, hid)
 end
 if reason == "invalid" or reason == "expired" or reason == "foreign" or reason == "badkey" then
 return false, "Key is invalid or expired"
 end
 if reason == "badhwid" then
 return false, "Device id unavailable — try another executor"
 end
 if reason then
 return false, "Bind rejected: " .. reason
 end
 end
 return localBindCheck(key, hid)
 end
 return localBindCheck(key, hid)
end

if not game:IsLoaded() then game.Loaded:Wait() end
local placeName = CONFIG.ALLOWED_PLACES[game.PlaceId]
if not placeName then
 local list = {}
 for id, name in pairs(CONFIG.ALLOWED_PLACES) do
 table.insert(list, ("  - %s (%d)"):format(name, id))
 end
 stop(("This script is not made for this game.\n\nCurrent PlaceId: %d\n\nSupported:\n%s")
 :format(game.PlaceId, table.concat(list, "\n")), CONFIG.KICK_ON_WRONG_PLACE)
end

local function validateKey(key)
 key = tostring(key or ""):gsub("%s+", "")
 if #key < 10 then return false, "Key is too short" end
 if key:find("[^%w%-]") then return false, "Key contains invalid characters" end
 local body = httpGet(API_PREFIX .. key)
 if not body then return false, "Cannot reach key server" end
 local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
 if not ok or type(data) ~= "table" then return false, "Bad server response" end
 if not data.valid then return false, "Key is invalid or expired" end
 local info = data.info or {}
 local byLink = CONFIG.LINK_ID and info.linkId == CONFIG.LINK_ID
 local byOwner = CONFIG.OWNER_USER_ID and info.userId == CONFIG.OWNER_USER_ID
 if not (byLink or byOwner) then
 return false, "Key was not issued for this script"
 end
 if info.expiresAfter and info.expiresAfter > 0 then
 local leftMs = info.expiresAfter - (os.time() * 1000)
 if leftMs <= 0 then return false, "Key has expired" end
 return true, ("Key accepted. Left: %dh %dm")
 :format(math.floor(leftMs / 3600000), math.floor(leftMs % 3600000 / 60000)), info
 end
 return true, "Key accepted", info
end

local function activateKey(key)
 key = tostring(key or ""):gsub("%s+", "")
 if CONFIG.AUDIENCE_MODE then
 local want = tostring(CONFIG.COMMUNITY_KEY or ""):gsub("%s+", "")
 if #want >= 6 and key:upper() == want:upper() then
 return true, "Early access · welcome to ZINKA"
 end
 return false, "Wrong key — join Discord (Get Discord), find the key there, then paste it."
 end
 local ok, msg, info = validateKey(key)
 if not ok then return false, msg end
 local bok, bmsg = bindDevice(key)
 if not bok then
 return false, bmsg or "Key already bound to another device"
 end
 return true, msg, info
end

local ACCENT = Color3.fromRGB(150, 120, 255)
local DISCORD_PNG_B64 = [=[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]=]
local DISCORD_ASSET = nil

local function b64decodeLite(data)
 if type(data) ~= "string" or #data == 0 then return nil end
 local function asString(res)
 if type(res) == "string" then return res end
 if type(res) == "buffer" then
 local ok, s = pcall(function()
 return buffer.tostring(res)
 end)
 if ok and type(s) == "string" then return s end
 end
 return nil
 end
 if crypt and crypt.base64decode then
 local ok, res = pcall(crypt.base64decode, data)
 if ok then
 local s = asString(res)
 if s then return s end
 if type(res) == "buffer" then return res end
 end
 end
 if base64_decode then
 local ok, res = pcall(base64_decode, data)
 if ok then
 local s = asString(res)
 if s then return s end
 if type(res) == "buffer" then return res end
 end
 end
 local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
 local map = {}
 for i = 1, #alphabet do map[alphabet:sub(i, i)] = i - 1 end
 data = data:gsub("%s+", ""):gsub("=", "")
 local out, buf, bits = {}, 0, 0
 for i = 1, #data do
 local v = map[data:sub(i, i)]
 if not v then return nil end
 buf = buf * 64 + v
 bits = bits + 6
 if bits >= 8 then
 bits = bits - 8
 out[#out + 1] = string.char(math.floor(buf / (2 ^ bits)) % 256)
 buf = buf % (2 ^ bits)
 end
 end
 return table.concat(out)
end

local function resolveDiscordAsset()
 if DISCORD_ASSET then return DISCORD_ASSET end
 if type(DISCORD_PNG_B64) ~= "string" or #DISCORD_PNG_B64 < 32 then return nil end
 if DISCORD_PNG_B64:sub(1, 10) ~= "iVBORw0KGg" then return nil end
 local bin = b64decodeLite(DISCORD_PNG_B64)
 local binLen = 0
 if type(bin) == "string" then
 binLen = #bin
 elseif type(bin) == "buffer" then
 binLen = buffer.len(bin)
 else
 return nil
 end
 if binLen < 64 then return nil end
 local fileName = "zinka_discord.png"
 if not writefile then return nil end
 local okWrite = pcall(writefile, fileName, bin)
 if not okWrite then return nil end
 local getters = {
 function() return getcustomasset(fileName) end,
 function() return getcustomasset(fileName, true) end,
 function() return getsynasset and getsynasset(fileName) end,
 function() return getcustomasset("./" .. fileName) end,
 }
 for _, fn in ipairs(getters) do
 local ok, res = pcall(fn)
 if ok and type(res) == "string" and #res > 0 then
 DISCORD_ASSET = res
 return DISCORD_ASSET
 end
 end
 return nil
end

local function corner(o, r)
 local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = o; return c
end
local function stroke(o, col, th, tr)
 local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = th or 1
 s.Transparency = tr or 0; s.Parent = o; return s
end
local function grad(o, seq, rot)
 local g = Instance.new("UIGradient"); g.Color = seq; g.Rotation = rot or 0; g.Parent = o; return g
end
local function tw(o, props, t, style)
 return TweenService:Create(o,
 TweenInfo.new(t, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
end

local function makeDiscordIcon(parent, px)
 px = math.max(tonumber(px) or 22, 16)
 local root = Instance.new("Frame")
 root.Name = "DiscordIcon"
 root.BackgroundTransparency = 1
 root.BorderSizePixel = 0
 root.Size = UDim2.fromOffset(px, px)
 root.ZIndex = (parent.ZIndex or 1) + 2
 root.Parent = parent
 local z = root.ZIndex
 local white = Color3.fromRGB(255, 255, 255)
 local hole = parent:IsA("GuiObject") and parent.BackgroundColor3 or Color3.fromRGB(88, 101, 242)
 local body = Instance.new("Frame")
 body.Name = "Body"
 body.BackgroundColor3 = white
 body.BorderSizePixel = 0
 body.Size = UDim2.fromScale(0.92, 0.72)
 body.Position = UDim2.fromScale(0.04, 0.22)
 body.ZIndex = z
 body.Parent = root
 corner(body, math.floor(px * 0.32))
 local function ear(xScale)
 local e = Instance.new("Frame")
 e.BackgroundColor3 = white
 e.BorderSizePixel = 0
 e.AnchorPoint = Vector2.new(0.5, 1)
 e.Size = UDim2.fromScale(0.28, 0.28)
 e.Position = UDim2.fromScale(xScale, 0.30)
 e.Rotation = (xScale < 0.5) and -18 or 18
 e.ZIndex = z
 e.Parent = root
 corner(e, math.floor(px * 0.08))
 end
 ear(0.30)
 ear(0.70)
 local function eye(xScale)
 local e = Instance.new("Frame")
 e.BackgroundColor3 = hole
 e.BorderSizePixel = 0
 e.AnchorPoint = Vector2.new(0.5, 0.5)
 e.Size = UDim2.fromScale(0.18, 0.22)
 e.Position = UDim2.fromScale(xScale, 0.55)
 e.ZIndex = z + 1
 e.Parent = root
 corner(e, math.floor(px * 0.5))
 end
 eye(0.35)
 eye(0.65)
 task.defer(function()
 local asset = resolveDiscordAsset()
 if not asset or not root.Parent then return end
 for _, c in ipairs(root:GetChildren()) do
 if c:IsA("GuiObject") and c.Name ~= "Glyph" then
 c.Visible = false
 end
 end
 local img = Instance.new("ImageLabel")
 img.Name = "Glyph"
 img.BackgroundTransparency = 1
 img.Size = UDim2.fromScale(1, 1)
 img.Image = asset
 img.ImageColor3 = Color3.fromRGB(255, 255, 255)
 img.ScaleType = Enum.ScaleType.Fit
 img.ZIndex = z + 2
 img.Parent = root
 end)
 return root
end

local function askKey()
 local result = nil
 local conns = {}
 local parent = (gethui and gethui()) or game:GetService("CoreGui")
 local prev = parent:FindFirstChild("ZINKA_KEY_UI")
 if prev then prev:Destroy() end
 local gui = Instance.new("ScreenGui")
 gui.Name = "ZINKA_KEY_UI"
 gui.ResetOnSpawn = false
 gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
 gui.DisplayOrder = 1000
 pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
 gui.Parent = parent
 local W, H = 460, 330
 local shadow = Instance.new("ImageLabel")
 shadow.Name = "ZKeyShadow"; shadow.BackgroundTransparency = 1; shadow.ZIndex = 0
 shadow.Image = "rbxassetid://6015897843"
 shadow.ImageColor3 = Color3.fromRGB(0, 0, 0); shadow.ImageTransparency = 0.38
 shadow.ScaleType = Enum.ScaleType.Slice; shadow.SliceCenter = Rect.new(49, 49, 450, 450)
 shadow.AnchorPoint = Vector2.new(0.5, 0.5); shadow.Position = UDim2.fromScale(0.5, 0.5)
 shadow.Size = UDim2.fromOffset(W + 46, H + 46)
 shadow.Parent = gui
 local main = Instance.new("Frame")
 main.AnchorPoint = Vector2.new(0.5, 0.5)
 main.Position = UDim2.fromScale(0.5, 0.5)
 main.Size = UDim2.fromOffset(W - 40, H - 40)
 main.BackgroundColor3 = Color3.fromRGB(15, 15, 21)
 main.BorderSizePixel = 0
 main.ClipsDescendants = true
 main.Active = true
 main.Parent = gui
 corner(main, 16)
 grad(main, ColorSequence.new{
 ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 20, 32)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 18)),
 }, 60)
 local ms = stroke(main, ACCENT, 1.6, 0.4)
 ms.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
 TweenService:Create(ms, TweenInfo.new(2.0, Enum.EasingStyle.Sine,
 Enum.EasingDirection.InOut, -1, true), {Transparency = 0.12, Thickness = 2.2}):Play()
 local msGrad = grad(ms, ColorSequence.new{
 ColorSequenceKeypoint.new(0.0, Color3.fromRGB(150, 120, 255)),
 ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 220, 255)),
 ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 120, 220)),
 }, 0)
 do
 local acc = 0
 table.insert(conns, RunService.Heartbeat:Connect(function(dt)
 acc = acc + dt
 if acc < 0.05 then return end
 local step = acc; acc = 0
 msGrad.Offset = Vector2.new((msGrad.Offset.X + step * 0.06) % 1, 0)
 end))
 end
 tw(main, {Size = UDim2.fromOffset(W, H)}, 0.28):Play()
 local function syncShadow()
 shadow.Position = main.Position
 shadow.Size = UDim2.fromOffset(main.Size.X.Offset + 46, main.Size.Y.Offset + 46)
 end
 table.insert(conns, main:GetPropertyChangedSignal("Position"):Connect(syncShadow))
 table.insert(conns, main:GetPropertyChangedSignal("Size"):Connect(syncShadow))
 local top = Instance.new("Frame")
 top.Size = UDim2.new(1, 0, 0, 62); top.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
 top.BorderSizePixel = 0; top.Parent = main
 corner(top, 16)
 local topFix = Instance.new("Frame")
 topFix.Size = UDim2.new(1, 0, 0, 16); topFix.Position = UDim2.new(0, 0, 1, -16)
 topFix.BackgroundColor3 = top.BackgroundColor3; topFix.BorderSizePixel = 0; topFix.Parent = top
 local title = Instance.new("TextLabel")
 title.BackgroundTransparency = 1
 title.Position = UDim2.fromOffset(22, 9); title.Size = UDim2.fromOffset(280, 26)
 title.Font = Enum.Font.Michroma; title.Text = "ZINKA"; title.TextSize = 23
 title.TextXAlignment = Enum.TextXAlignment.Left; title.TextYAlignment = Enum.TextYAlignment.Top
 title.TextColor3 = Color3.fromRGB(255, 255, 255); title.ZIndex = 3; title.Parent = top
 local tGrad = grad(title, ColorSequence.new{
 ColorSequenceKeypoint.new(0.00, Color3.fromRGB(150, 120, 255)),
 ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 120, 220)),
 ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 220, 255)),
 ColorSequenceKeypoint.new(0.75, Color3.fromRGB(180, 255, 180)),
 ColorSequenceKeypoint.new(1.00, Color3.fromRGB(150, 120, 255)),
 }, 0)
 do
 local acc = 0
 table.insert(conns, RunService.Heartbeat:Connect(function(dt)
 acc = acc + dt
 if acc < 0.05 then return end
 local step = acc; acc = 0
 tGrad.Offset = Vector2.new((tGrad.Offset.X + step * 0.35) % 1, 0)
 end))
 end
 local sub = Instance.new("TextLabel")
 sub.BackgroundTransparency = 1
 sub.Position = UDim2.fromOffset(24, 38); sub.Size = UDim2.fromOffset(300, 14)
 sub.Font = Enum.Font.Gotham; sub.Text = "key access  •  secure loader"; sub.TextSize = 11
 sub.TextColor3 = Color3.fromRGB(175, 175, 205)
 sub.TextStrokeColor3 = Color3.fromRGB(8, 8, 12); sub.TextStrokeTransparency = 0.4
 sub.TextXAlignment = Enum.TextXAlignment.Left; sub.ZIndex = 3; sub.Parent = top
 local headRule = Instance.new("Frame")
 headRule.Position = UDim2.fromOffset(0, 61); headRule.Size = UDim2.new(1, 0, 0, 1)
 headRule.BackgroundColor3 = ACCENT; headRule.BackgroundTransparency = 0.55
 headRule.BorderSizePixel = 0; headRule.ZIndex = 4; headRule.Parent = main
 local discBtn = Instance.new("TextButton")
 discBtn.Size = UDim2.fromOffset(34, 34); discBtn.Position = UDim2.new(1, -86, 0, 14)
 discBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
 discBtn.Text = ""; discBtn.AutoButtonColor = false; discBtn.ZIndex = 3; discBtn.Parent = top
 discBtn.Active = true
 corner(discBtn, 8)
 local discDim = Instance.new("Frame")
 discDim.Size = UDim2.fromScale(1, 1); discDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
 discDim.BackgroundTransparency = 0.45; discDim.BorderSizePixel = 0
 discDim.ZIndex = 4; discDim.Parent = discBtn
 corner(discDim, 8)
 local discMark = makeDiscordIcon(discBtn, 20)
 discMark.AnchorPoint = Vector2.new(0.5, 0.5)
 discMark.Position = UDim2.fromScale(0.5, 0.5)
 discMark.ZIndex = 6
 for _, d in ipairs(discMark:GetDescendants()) do
 if d:IsA("GuiObject") then d.ZIndex = 6 end
 end
 local closeB = Instance.new("TextButton")
 closeB.Name = "Close"
 closeB.Size = UDim2.fromOffset(30, 30); closeB.Position = UDim2.new(1, -42, 0, 16)
 closeB.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
 closeB.Text = "×"; closeB.Font = Enum.Font.GothamBold; closeB.TextSize = 18
 closeB.TextColor3 = Color3.fromRGB(220, 210, 230)
 closeB.AutoButtonColor = true; closeB.Active = true; closeB.Selectable = true
 closeB.ZIndex = 20; closeB.Parent = top
 corner(closeB, 8)
 do
 local dragging, ds, sp
 top.InputBegan:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 then
 dragging = true; ds = i.Position; sp = main.Position
 end
 end)
 top.InputEnded:Connect(function(i)
 if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
 end)
 table.insert(conns, UIS.InputChanged:Connect(function(i)
 if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
 local d = i.Position - ds
 main.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
 end
 end))
 end
 local status = Instance.new("TextLabel")
 status.BackgroundTransparency = 1
 status.Position = UDim2.fromOffset(22, 74); status.Size = UDim2.fromOffset(W - 44, 36)
 status.Font = Enum.Font.Gotham; status.TextSize = 13; status.TextWrapped = true
 status.TextXAlignment = Enum.TextXAlignment.Left; status.TextYAlignment = Enum.TextYAlignment.Top
 status.TextColor3 = Color3.fromRGB(175, 175, 205)
 status.Text = CONFIG.AUDIENCE_MODE
 and "Press Get Discord, join the server, find the key there, then paste it here."
 or "Press Get Key, complete the link steps, then paste your key here."
 status.Parent = main
 local boxBg = Instance.new("Frame")
 boxBg.Position = UDim2.fromOffset(22, 118); boxBg.Size = UDim2.fromOffset(W - 44, 44)
 boxBg.BackgroundColor3 = Color3.fromRGB(24, 22, 34); boxBg.BorderSizePixel = 0
 boxBg.Parent = main
 corner(boxBg, 10)
 local boxStroke = stroke(boxBg, ACCENT, 1, 0.7)
 local box = Instance.new("TextBox")
 box.BackgroundTransparency = 1
 box.Position = UDim2.fromOffset(14, 0); box.Size = UDim2.new(1, -28, 1, 0)
 box.Font = Enum.Font.Code; box.TextSize = 15
 box.TextColor3 = Color3.fromRGB(235, 235, 245)
 box.PlaceholderColor3 = Color3.fromRGB(110, 108, 130)
 box.PlaceholderText = "paste key here"
 box.ClearTextOnFocus = false; box.Text = ""
 box.TextXAlignment = Enum.TextXAlignment.Left
 box.Parent = boxBg
 box.Focused:Connect(function() tw(boxStroke, {Transparency = 0.15}, 0.18):Play() end)
 box.FocusLost:Connect(function() tw(boxStroke, {Transparency = 0.7}, 0.18):Play() end)
 local BW = (W - 44 - 16) / 2
 local getBtn = Instance.new("TextButton")
 getBtn.Position = UDim2.fromOffset(22, 176); getBtn.Size = UDim2.fromOffset(BW, 42)
 getBtn.BackgroundColor3 = Color3.fromRGB(30, 28, 40); getBtn.BorderSizePixel = 0
 getBtn.Font = Enum.Font.GothamMedium; getBtn.TextSize = 14
 getBtn.TextColor3 = Color3.fromRGB(225, 220, 240)
 getBtn.Text = CONFIG.AUDIENCE_MODE and "Get Discord" or "Get Key"; getBtn.AutoButtonColor = false; getBtn.Parent = main
 corner(getBtn, 10)
 stroke(getBtn, ACCENT, 1, 0.6)
 local okBtn = Instance.new("TextButton")
 okBtn.Position = UDim2.fromOffset(22 + BW + 16, 176); okBtn.Size = UDim2.fromOffset(BW, 42)
 okBtn.BackgroundColor3 = Color3.fromRGB(150, 120, 255); okBtn.BorderSizePixel = 0
 okBtn.Font = Enum.Font.GothamBold; okBtn.TextSize = 14
 okBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
 okBtn.Text = "Submit Key"; okBtn.AutoButtonColor = false; okBtn.Parent = main
 corner(okBtn, 10)
 grad(okBtn, ColorSequence.new{
 ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 130, 255)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
 }, 15)
 local discRow = Instance.new("TextButton")
 discRow.Position = UDim2.fromOffset(22, 228); discRow.Size = UDim2.fromOffset(W - 44, 36)
 discRow.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
 discRow.Text = ""; discRow.AutoButtonColor = false; discRow.Parent = main
 corner(discRow, 10)
 local discRowDim = Instance.new("Frame")
 discRowDim.Size = UDim2.fromScale(1, 1); discRowDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
 discRowDim.BackgroundTransparency = 0.35; discRowDim.BorderSizePixel = 0
 discRowDim.ZIndex = 2; discRowDim.Parent = discRow
 corner(discRowDim, 10)
 local discRowMark = makeDiscordIcon(discRow, 20)
 discRowMark.Position = UDim2.fromOffset(12, 8)
 discRowMark.ZIndex = 4
 for _, d in ipairs(discRowMark:GetDescendants()) do
 if d:IsA("GuiObject") then d.ZIndex = 4 end
 end
 local discRowText = Instance.new("TextLabel")
 discRowText.BackgroundTransparency = 1
 discRowText.Position = UDim2.fromOffset(40, 0); discRowText.Size = UDim2.new(1, -50, 1, 0)
 discRowText.Font = Enum.Font.GothamMedium; discRowText.TextSize = 13
 discRowText.TextXAlignment = Enum.TextXAlignment.Left
 discRowText.TextColor3 = Color3.fromRGB(255, 255, 255)
 discRowText.Text = CONFIG.DISCORD_ENABLED and "Discord  ·  Join / copy invite" or "Discord  ·  Coming soon"
 discRowText.ZIndex = 4; discRowText.Parent = discRow
 local hint = Instance.new("TextLabel")
 hint.BackgroundTransparency = 1
 hint.Position = UDim2.fromOffset(22, 272); hint.Size = UDim2.fromOffset(W - 44, 34)
 hint.Font = Enum.Font.Gotham; hint.TextSize = 11; hint.TextWrapped = true
 hint.TextXAlignment = Enum.TextXAlignment.Left; hint.TextYAlignment = Enum.TextYAlignment.Top
 hint.TextColor3 = Color3.fromRGB(115, 113, 135)
 hint.Text = CONFIG.AUDIENCE_MODE
 and "Key is only posted in Discord — Get Discord copies the invite. Enter also submits."
 or "Key is saved locally — you won't need to paste it every time. Enter also submits."
 hint.Parent = main
 local function hover(btn, over, base)
 btn.MouseEnter:Connect(function() tw(btn, {BackgroundColor3 = over}, 0.15):Play() end)
 btn.MouseLeave:Connect(function() tw(btn, {BackgroundColor3 = base}, 0.15):Play() end)
 end
 hover(getBtn, Color3.fromRGB(44, 40, 58), Color3.fromRGB(30, 28, 40))
 hover(okBtn, Color3.fromRGB(175, 148, 255), Color3.fromRGB(150, 120, 255))
 local CURSOR_BIND = "ZINKA_KeyCursor"
 pcall(function() RunService:UnbindFromRenderStep(CURSOR_BIND) end)
 local zCursor = Instance.new("ImageLabel")
 zCursor.Name = "ZCursor"; zCursor.BackgroundTransparency = 1
 zCursor.Size = UDim2.fromOffset(34, 34)
 zCursor.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png"
 zCursor.ZIndex = 999; zCursor.Visible = false; zCursor.Parent = gui
 local zcGlow = Instance.new("ImageLabel")
 zcGlow.Name = "glow"; zcGlow.BackgroundTransparency = 1
 zcGlow.AnchorPoint = Vector2.new(0.5, 0.5); zcGlow.Position = UDim2.fromScale(0.35, 0.35)
 zcGlow.Size = UDim2.fromOffset(46, 46)
 zcGlow.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowCursor.png"
 zcGlow.ImageColor3 = ACCENT; zcGlow.ImageTransparency = 0.4
 zcGlow.ZIndex = 998; zcGlow.Parent = zCursor
 local guiInset = GuiService:GetGuiInset()
 local cursorBound = false
 pcall(function()
 RunService:BindToRenderStep(CURSOR_BIND, Enum.RenderPriority.Last.Value + 1, function()
 if not main.Parent then return end
 if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
 UIS.MouseBehavior = Enum.MouseBehavior.Default
 end
 if UIS.MouseIconEnabled then
 UIS.MouseIconEnabled = false
 end
 local m = UIS:GetMouseLocation()
 zCursor.Position = UDim2.fromOffset(m.X, m.Y - guiInset.Y)
 zCursor.Visible = true
 end)
 cursorBound = true
 end)
 local function releaseCursor()
 if cursorBound then
 pcall(function() RunService:UnbindFromRenderStep(CURSOR_BIND) end)
 cursorBound = false
 end
 pcall(function() UIS.MouseIconEnabled = true end)
 end
 local function setStatus(text, color)
 status.Text = text
 status.TextColor3 = color or Color3.fromRGB(175, 175, 205)
 end
 local function shutdown(res)
 releaseCursor()
 for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
 tw(main, {Size = UDim2.fromOffset(W - 40, H - 40)}, 0.2):Play()
 tw(shadow, {ImageTransparency = 1}, 0.2):Play()
 task.delay(0.22, function() gui:Destroy() end)
 result = res
 end
 if CONFIG.DISCORD_ENABLED then
 discDim.BackgroundTransparency = 1
 discRowDim.BackgroundTransparency = 1
 end
 local function discordSoon()
 if not CONFIG.DISCORD_ENABLED then
 setStatus("Discord soon — invite is not open yet.", Color3.fromRGB(185, 175, 255))
 return
 end
 local invite = CONFIG.DISCORD_INVITE
 local copied = pcall(setclipboard, invite)
 if copied then
 setStatus("Discord invite copied — paste in your browser.", Color3.fromRGB(120, 200, 255))
 else
 setStatus("Clipboard unavailable. Invite: discord.gg/… (ask owner)", Color3.fromRGB(235, 185, 95))
 end
 end
 discBtn.MouseButton1Click:Connect(discordSoon)
 discRow.MouseButton1Click:Connect(discordSoon)
 getBtn.MouseButton1Click:Connect(function()
 if CONFIG.AUDIENCE_MODE then
 local invite = CONFIG.DISCORD_INVITE
 local copied = pcall(setclipboard, invite)
 if copied then
 setStatus("Discord invite copied — join and find the key in the server.",
 Color3.fromRGB(120, 200, 255))
 getBtn.Text = "Copied ✓"
 task.delay(2, function() if getBtn.Parent then getBtn.Text = "Get Discord" end end)
 else
 setStatus("Clipboard unavailable. Ask in Discord for the invite.", Color3.fromRGB(235, 185, 95))
 end
 return
 end
 local link = CONFIG.KEY_LINK
 local copied = pcall(setclipboard, link)
 if copied then
 setStatus("Link copied. Open it in your browser, finish the steps, then paste the key.",
 Color3.fromRGB(120, 200, 255))
 getBtn.Text = "Copied ✓"
 task.delay(2, function() if getBtn.Parent then getBtn.Text = "Get Key" end end)
 else
 setStatus("Clipboard unavailable. Ask the owner for the key link.", Color3.fromRGB(235, 185, 95))
 end
 end)
 closeB.MouseButton1Click:Connect(function()
 shutdown(false)
 end)
 closeB.Activated:Connect(function()
 shutdown(false)
 end)
 table.insert(conns, UIS.InputBegan:Connect(function(input, gpe)
 if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
 local p = input.Position
 local ap, asz = closeB.AbsolutePosition, closeB.AbsoluteSize
 if p.X >= ap.X and p.X <= ap.X + asz.X and p.Y >= ap.Y and p.Y <= ap.Y + asz.Y then
 shutdown(false)
 end
 end))
 local busy = false
 local function submit()
 if busy then return end
 local key = (box.Text:gsub("%s+", ""))
 if key == "" then
 setStatus("Empty field — paste your key.", Color3.fromRGB(235, 185, 95))
 return
 end
 busy = true
 okBtn.Text = "Checking…"
 setStatus("Validating key…", Color3.fromRGB(175, 175, 205))
 local ok, msg = activateKey(key)
 if ok then
 setStatus(msg, Color3.fromRGB(125, 230, 150))
 okBtn.Text = "Accepted ✓"
 ACCEPTED_KEY = key
 saveKey(key)
 publishAuth(key)
 task.wait(0.7)
 shutdown(true)
 else
 setStatus("Error: " .. msg, Color3.fromRGB(255, 115, 115))
 okBtn.Text = "Submit Key"
 busy = false
 local base = boxBg.Position
 for _, dx in ipairs({8, -8, 5, -5, 0}) do
 boxBg.Position = base + UDim2.fromOffset(dx, 0)
 task.wait(0.03)
 end
 boxBg.Position = base
 end
 end
 okBtn.MouseButton1Click:Connect(submit)
 box.FocusLost:Connect(function(enter) if enter then submit() end end)
 repeat task.wait(0.1) until result ~= nil
 return result == true
end

local granted = false
local saved = loadSavedKey()
if saved then
 local ok, msg = activateKey(saved)
 if ok then
 granted = true
 ACCEPTED_KEY = saved
 publishAuth(saved)
 notify(msg, 5)
 else
 clearKey()
 notify("Saved key rejected: " .. msg, 6)
 end
end
if not granted then
 granted = askKey()
end
if not granted then
 stop("Access denied — no valid key.\n\nUse Get Key in the loader UI.",
 CONFIG.KICK_ON_NO_KEY)
end

local function addParam(url, kv)
 return url .. (url:find("?") and "&" or "?") .. kv
end
local scriptUrl = CONFIG.SCRIPT_URL
if ACCEPTED_KEY then
 scriptUrl = addParam(scriptUrl, "k=" .. HttpService:UrlEncode(ACCEPTED_KEY))
end
do
 local hid = getDeviceHwid()
 if hid then scriptUrl = addParam(scriptUrl, "h=" .. HttpService:UrlEncode(hid)) end
end
if CONFIG.BUST_CACHE then scriptUrl = addParam(scriptUrl, "v=" .. tostring(os.time())) end

local function b64decode(s)
 if type(s) ~= "string" or #s == 0 then return nil end
 if crypt and crypt.base64decode then
 local ok, res = pcall(crypt.base64decode, s)
 if ok and type(res) == "string" then return res end
 end
 if base64_decode then
 local ok, res = pcall(base64_decode, s)
 if ok and type(res) == "string" then return res end
 end
 local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
 local map = {}
 for i = 1, #alphabet do map[alphabet:sub(i, i)] = i - 1 end
 s = s:gsub("%s+", ""):gsub("=", "")
 local out, buf, bits = {}, 0, 0
 for i = 1, #s do
 local v = map[s:sub(i, i)]
 if not v then return nil end
 buf = buf * 64 + v
 bits = bits + 6
 if bits >= 8 then
 bits = bits - 8
 out[#out + 1] = string.char(math.floor(buf / (2 ^ bits)) % 256)
 buf = buf % (2 ^ bits)
 end
 end
 return table.concat(out)
end

local function openLoadUi(gameLabel)
 local parent = (gethui and gethui()) or game:GetService("CoreGui")
 local prev = parent:FindFirstChild("ZINKA_LOAD_UI")
 if prev then prev:Destroy() end
 local gui = Instance.new("ScreenGui")
 gui.Name = "ZINKA_LOAD_UI"
 gui.ResetOnSpawn = false
 gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
 gui.DisplayOrder = 1001
 pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
 gui.Parent = parent
 local W, H = 420, 210
 local shadow = Instance.new("ImageLabel")
 shadow.BackgroundTransparency = 1; shadow.ZIndex = 0
 shadow.Image = "rbxassetid://6015897843"
 shadow.ImageColor3 = Color3.fromRGB(0, 0, 0); shadow.ImageTransparency = 0.35
 shadow.ScaleType = Enum.ScaleType.Slice; shadow.SliceCenter = Rect.new(49, 49, 450, 450)
 shadow.AnchorPoint = Vector2.new(0.5, 0.5); shadow.Position = UDim2.fromScale(0.5, 0.5)
 shadow.Size = UDim2.fromOffset(W + 40, H + 40); shadow.Parent = gui
 local main = Instance.new("Frame")
 main.AnchorPoint = Vector2.new(0.5, 0.5)
 main.Position = UDim2.fromScale(0.5, 0.5)
 main.Size = UDim2.fromOffset(W - 30, H - 30)
 main.BackgroundColor3 = Color3.fromRGB(15, 15, 21)
 main.BorderSizePixel = 0; main.ClipsDescendants = true; main.Parent = gui
 corner(main, 16)
 grad(main, ColorSequence.new{
 ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 20, 32)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 12, 18)),
 }, 55)
 local ms = stroke(main, ACCENT, 1.5, 0.35)
 local msGrad = grad(ms, ColorSequence.new{
 ColorSequenceKeypoint.new(0.0, Color3.fromRGB(150, 120, 255)),
 ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 220, 255)),
 ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 120, 220)),
 }, 0)
 local pulse = TweenService:Create(ms, TweenInfo.new(1.6, Enum.EasingStyle.Sine,
 Enum.EasingDirection.InOut, -1, true), {Transparency = 0.1, Thickness = 2.1})
 pulse:Play()
 local animConn = RunService.Heartbeat:Connect(function(dt)
 msGrad.Offset = Vector2.new((msGrad.Offset.X + dt * 0.08) % 1, 0)
 end)
 tw(main, {Size = UDim2.fromOffset(W, H)}, 0.28, Enum.EasingStyle.Back):Play()
 local brand = Instance.new("TextLabel")
 brand.BackgroundTransparency = 1
 brand.Position = UDim2.fromOffset(22, 18); brand.Size = UDim2.new(1, -44, 0, 28)
 brand.Font = Enum.Font.Michroma; brand.Text = "ZINKA"; brand.TextSize = 22
 brand.TextXAlignment = Enum.TextXAlignment.Left
 brand.TextColor3 = Color3.fromRGB(255, 255, 255); brand.Parent = main
 local bGrad = grad(brand, ColorSequence.new{
 ColorSequenceKeypoint.new(0.00, Color3.fromRGB(150, 120, 255)),
 ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 120, 220)),
 ColorSequenceKeypoint.new(0.70, Color3.fromRGB(120, 220, 255)),
 ColorSequenceKeypoint.new(1.00, Color3.fromRGB(150, 120, 255)),
 }, 0)
 TweenService:Create(bGrad, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
 {Offset = Vector2.new(1, 0)}):Play()
 local sub = Instance.new("TextLabel")
 sub.BackgroundTransparency = 1
 sub.Position = UDim2.fromOffset(22, 48); sub.Size = UDim2.new(1, -44, 0, 18)
 sub.Font = Enum.Font.Gotham; sub.TextSize = 12
 sub.TextXAlignment = Enum.TextXAlignment.Left
 sub.TextColor3 = Color3.fromRGB(170, 170, 200)
 sub.Text = tostring(gameLabel or "Loading"); sub.Parent = main
 local status = Instance.new("TextLabel")
 status.BackgroundTransparency = 1
 status.Position = UDim2.fromOffset(22, 78); status.Size = UDim2.new(1, -44, 0, 20)
 status.Font = Enum.Font.GothamMedium; status.TextSize = 13
 status.TextXAlignment = Enum.TextXAlignment.Left
 status.TextColor3 = Color3.fromRGB(210, 210, 230)
 status.Text = "Preparing download…"; status.Parent = main
 local track = Instance.new("Frame")
 track.Position = UDim2.fromOffset(22, 118); track.Size = UDim2.new(1, -44, 0, 10)
 track.BackgroundColor3 = Color3.fromRGB(28, 26, 40); track.BorderSizePixel = 0
 track.Parent = main; corner(track, 6)
 local fill = Instance.new("Frame")
 fill.Size = UDim2.new(0, 0, 1, 0); fill.BackgroundColor3 = ACCENT
 fill.BorderSizePixel = 0; fill.Parent = track; corner(fill, 6)
 grad(fill, ColorSequence.new{
 ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 120, 255)),
 ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 210, 255)),
 ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 220)),
 }, 0)
 local glow = Instance.new("Frame")
 glow.AnchorPoint = Vector2.new(1, 0.5)
 glow.Position = UDim2.new(1, 0, 0.5, 0); glow.Size = UDim2.fromOffset(18, 18)
 glow.BackgroundColor3 = Color3.fromRGB(200, 180, 255)
 glow.BackgroundTransparency = 0.35; glow.BorderSizePixel = 0
 glow.Visible = false; glow.Parent = fill; corner(glow, 9)
 local pctLbl = Instance.new("TextLabel")
 pctLbl.BackgroundTransparency = 1
 pctLbl.Position = UDim2.fromOffset(22, 140); pctLbl.Size = UDim2.new(0.5, -22, 0, 18)
 pctLbl.Font = Enum.Font.GothamBold; pctLbl.TextSize = 13
 pctLbl.TextXAlignment = Enum.TextXAlignment.Left
 pctLbl.TextColor3 = Color3.fromRGB(230, 225, 255)
 pctLbl.Text = "0%"; pctLbl.Parent = main
 local partLbl = Instance.new("TextLabel")
 partLbl.BackgroundTransparency = 1
 partLbl.Position = UDim2.new(0.5, 0, 0, 140); partLbl.Size = UDim2.new(0.5, -22, 0, 18)
 partLbl.Font = Enum.Font.Code; partLbl.TextSize = 12
 partLbl.TextXAlignment = Enum.TextXAlignment.Right
 partLbl.TextColor3 = Color3.fromRGB(140, 138, 165)
 partLbl.Text = ""; partLbl.Parent = main
 local hint = Instance.new("TextLabel")
 hint.BackgroundTransparency = 1
 hint.Position = UDim2.fromOffset(22, 168); hint.Size = UDim2.new(1, -44, 0, 18)
 hint.Font = Enum.Font.Gotham; hint.TextSize = 11
 hint.TextXAlignment = Enum.TextXAlignment.Left
 hint.TextColor3 = Color3.fromRGB(110, 108, 130)
 hint.Text = "secure chunked transfer"; hint.Parent = main
 local closed = false
 local function close()
 if closed then return end
 closed = true
 pcall(function() animConn:Disconnect() end)
 pcall(function() pulse:Cancel() end)
 local t = tw(main, {Size = UDim2.fromOffset(W - 20, 0)}, 0.2)
 t:Play(); t.Completed:Wait()
 pcall(function() gui:Destroy() end)
 end
 local function set(done, total, label)
 if closed or not gui.Parent then return end
 total = math.max(tonumber(total) or 1, 1)
 done = tonumber(done) or 0
 if done < 0 then done = 0 elseif done > total then done = total end
 local p = done / total
 status.Text = label or status.Text
 pctLbl.Text = ("%d%%"):format(math.floor(p * 100 + 0.5))
 partLbl.Text = ("%d / %d"):format(done, total)
 glow.Visible = p > 0.02
 tw(fill, {Size = UDim2.new(p, 0, 1, 0)}, 0.18, Enum.EasingStyle.Quad):Play()
 end
 local function fail(msg)
 if closed or not gui.Parent then return end
 status.Text = tostring(msg or "Failed")
 status.TextColor3 = Color3.fromRGB(255, 120, 120)
 hint.Text = "check connection / redeploy worker"
 pctLbl.TextColor3 = Color3.fromRGB(255, 140, 140)
 task.wait(1.4)
 close()
 end
 local function succeed()
 if closed or not gui.Parent then return end
 status.Text = "Loaded — starting…"
 status.TextColor3 = Color3.fromRGB(130, 235, 160)
 set(1, 1, status.Text)
 hint.Text = "welcome"
 task.wait(0.35)
 close()
 end
 return { set = set, fail = fail, succeed = succeed, close = close }
end

local function decodeDeniedOrStop(body, loadUi)
 local function die(msg, kick)
 if loadUi then pcall(loadUi.fail, msg) end
 stop(msg, kick)
 end
 if type(body) ~= "string" or #body == 0 then
 die("Failed to download script. Check your connection.", false)
 end
 if body:match("^%s*<") then
 die("Server returned a page instead of code. Check the URL.", false)
 end
 local denied = body:match("^%-%-%[%[DENIED:([%w]+)%]%]")
 if denied then
 local infra = denied:match("^source") or denied == "validator" or denied == "noconfig"
 local reasons = {
 badkey    = "Key does not look valid.",
 invalid   = "Key is invalid or expired.",
 foreign   = "Key was not issued for this script.",
 expired   = "Key has expired.",
 bound     = "Key already bound to another device",
 badhwid   = "Device id unavailable — try another executor",
 validator = "Key server is down — try later.",
 noconfig  = "Distributor is misconfigured — contact the owner.",
 badpart   = "Script part missing — redeploy worker / try again.",
 }
 local text = reasons[denied] or (infra and "Source unavailable — contact the owner."
 or ("Denied: " .. denied))
 if denied == "bound" then
 clearKey()
 die(text, CONFIG.KICK_ON_NO_KEY)
 elseif infra or denied == "badpart" then
 die(text, false)
 else
 clearKey()
 die(text .. "\n\nGet a new key via the loader UI.", CONFIG.KICK_ON_NO_KEY)
 end
 end
 return body
end

local function httpGetRetry(url, tries, timeoutSec)
 tries = tries or 3
 local last
 for attempt = 1, tries do
 last = httpGet(url, timeoutSec or 20)
 if type(last) == "string" and #last > 0 then return last end
 task.wait(0.15 * attempt)
 end
 return last
end

local loadUi = openLoadUi(placeName)
loadUi.set(0, 1, "Connecting to distributor…")
local source
do
 local manifestBody = decodeDeniedOrStop(httpGetRetry(scriptUrl, 3, 30), loadUi)
 local trimmed = manifestBody:match("^%s*(.-)%s*$") or manifestBody
 local meta
 if trimmed:sub(1, 1) == "{" then
 local ok, data = pcall(function() return HttpService:JSONDecode(trimmed) end)
 if ok then meta = data end
 end
 local ver = type(meta) == "table" and tonumber(meta.v) or 0
 if type(meta) == "table" and (ver == 2 or ver == 3) and tonumber(meta.n) then
 local n = tonumber(meta.n)
 if n < 1 or n > 800 then
 loadUi.fail("Bad script manifest.")
 stop("Bad script manifest.", false)
 end
 local ticket = type(meta.t) == "string" and meta.t or ""
 local partSize = tonumber(meta.part) or 0
 local expectSize = tonumber(meta.size) or 0
 if expectSize > 0 and partSize > 0 then
 local need = math.ceil(expectSize / partSize)
 if need > n then n = need end
 end
 local useRaw = (ver == 3) or (meta.enc == "raw")
 loadUi.set(0, n, useRaw and "Downloading script…" or "Downloading script (legacy)…")
 local parts = table.create and table.create(n) or {}
 for i = 0, n - 1 do
 local partUrl = addParam(scriptUrl, "part=" .. tostring(i))
 if #ticket >= 8 then
 partUrl = addParam(partUrl, "t=" .. HttpService:UrlEncode(ticket))
 end
 local piece
 for attempt = 1, 4 do
 local body = httpGetRetry(partUrl, 2, 15)
 if type(body) ~= "string" or #body == 0 then
 piece = nil
 elseif body:match("^%-%-%[%[DENIED:") then
 decodeDeniedOrStop(body, loadUi)
 elseif useRaw or body:sub(1, 4) == "ZP3|" then
 local nl = string.find(body, "\n", 1, true)
 if nl and body:sub(1, 4) == "ZP3|" then
 local header = body:sub(1, nl - 1)
 local rest = body:sub(nl + 1)
 local idx, _pn, len = header:match("^ZP3|(%d+)|(%d+)|(%d+)$")
 local nlen = tonumber(len)
 if idx and nlen and #rest == nlen then
 piece = rest
 else
 piece = nil
 end
 else
 piece = nil
 end
 else
 if body:match("%}$") then
 local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
 if ok and type(data) == "table" and type(data.d) == "string" then
 piece = b64decode(data.d)
 end
 end
 end
 if type(piece) == "string" and #piece > 0 then
 if partSize > 0 and i + 1 < n and #piece < partSize then
 piece = nil
 else
 break
 end
 end
 piece = nil
 task.wait(0.12 * attempt)
 end
 if type(piece) ~= "string" or #piece == 0 then
 loadUi.fail("Part " .. tostring(i) .. " failed — try again.")
 stop("Failed to download script part " .. tostring(i) .. ".", false)
 end
 parts[i + 1] = piece
 loadUi.set(i + 1, n, ("Fetching modules  ·  %d/%d"):format(i + 1, n))
 end
 source = table.concat(parts)
 if expectSize > 0 and #source ~= expectSize then
 local msg = ("Script size mismatch (%d != %d). Redeploy worker (proto 5).")
 :format(#source, expectSize)
 loadUi.fail(msg)
 stop(msg, false)
 end
 elseif type(meta) == "table" and type(meta.d) == "string" and #meta.d > 0 then
 loadUi.set(1, 2, "Decoding payload…")
 source = b64decode(meta.d)
 if type(source) ~= "string" or #source < 100 then
 loadUi.fail("Failed to decode script payload.")
 stop("Failed to decode script payload.", false)
 end
 loadUi.set(2, 2, "Payload ready")
 else
 loadUi.set(1, 1, "Loading legacy payload…")
 source = manifestBody
 end
end
local denied = source:match("^%-%-%[%[DENIED:([%w]+)%]%]")
if denied then
 decodeDeniedOrStop(source, loadUi)
end
loadUi.set(1, 1, "Compiling…")
local chunk, compileErr = loadstring(source, "@" .. CONFIG.NAME)
if not chunk then
 local msg = "Compile error:\n" .. tostring(compileErr)
 loadUi.fail(msg)
 stop(msg, false)
end
loadUi.set(1, 1, "Starting…")
local ranOk, runErr = pcall(chunk)
if not ranOk then
 local msg = "Runtime error:\n" .. tostring(runErr)
 loadUi.fail(msg)
 stop(msg, false)
end
loadUi.succeed()
notify("Script loaded successfully", 4)
