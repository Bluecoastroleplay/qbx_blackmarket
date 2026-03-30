-- ─────────────────────────────────────────────────────────────────────────────
-- qbx_blackmarket — server/main.lua
-- Server authoritative: shop registration, player validation, rate limiting,
-- proximity check. Client sends intent only — server owns all logic.
-- ─────────────────────────────────────────────────────────────────────────────

local function debugLog(msg, ...)
    if not Config.Debug then return end
    print(('[^3qbx_blackmarket^7] ^2DEBUG^7: ' .. msg):format(...))
end

local function securityLog(src, msg, ...)
    local name    = GetPlayerName(src) or 'Unknown'
    local ids     = GetPlayerIdentifiers(src) or {}
    local license = 'none'
    for _, id in ipairs(ids) do
        if id:sub(1, 8) == 'license:' then license = id; break end
    end
    print(('[^1qbx_blackmarket^7] ^1SECURITY^7 | %s (src:%d | %s) | ' .. msg):format(
        name, src, license, ...))
end

local function isValidSource(src)
    return src and src > 0 and GetPlayerName(src) ~= nil
end

-- ─────────────────────────────
-- Rate limiter
-- ─────────────────────────────

local openRequests   = {}
local RATE_LIMIT_MAX = 5
local RATE_LIMIT_WIN = 60

local function rateLimitCheck(src)
    local now = os.time()
    if not openRequests[src] or now > openRequests[src].reset then
        openRequests[src] = { count = 0, reset = now + RATE_LIMIT_WIN }
    end
    openRequests[src].count += 1
    return openRequests[src].count <= RATE_LIMIT_MAX
end

-- ─────────────────────────────
-- Proximity check — server reads coords from Config, never from client
-- ─────────────────────────────

local function isPlayerNearDealer(src)
    local ped       = GetPlayerPed(src)
    local pCoords   = GetEntityCoords(ped)
    local dCoords   = Config.Ped.coords
    local tolerance = Config.Target.distance + 4.0
    return #(pCoords - vector3(dCoords.x, dCoords.y, dCoords.z)) <= tolerance
end

-- ─────────────────────────────
-- Register shop on resource start
-- ─────────────────────────────

local function registerShop()
    local inventory = {}
    for _, item in ipairs(Config.Shop.items) do
        inventory[#inventory + 1] = { name = item.name, price = item.price }
    end
    exports.ox_inventory:RegisterShop(Config.Shop.id, {
        name      = Config.Shop.label,
        inventory = inventory,
    })
    debugLog('Shop "%s" registered with %d items.', Config.Shop.id, #inventory)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    registerShop()
end)

-- ─────────────────────────────
-- Open shop — validate then trigger client UI
-- ─────────────────────────────

RegisterNetEvent('qbx_blackmarket:server:openShop', function()
    local src = source

    if not isValidSource(src) then return end

    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if not rateLimitCheck(src) then
        securityLog(src, 'Rate limit exceeded on openShop.')
        return
    end

    if not isPlayerNearDealer(src) then
        securityLog(src, 'openShop from invalid position: %s',
            tostring(GetEntityCoords(GetPlayerPed(src))))
        return
    end

    debugLog('Opening shop for src:%d cid:%s', src, player.PlayerData.citizenid)
    TriggerClientEvent('qbx_blackmarket:client:openShop', src)
end)

-- ─────────────────────────────
-- Cleanup on disconnect
-- ─────────────────────────────

AddEventHandler('playerDropped', function()
    openRequests[source] = nil
end)
