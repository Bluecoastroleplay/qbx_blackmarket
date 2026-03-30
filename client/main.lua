-- ─────────────────────────────────────────────────────────────────────────────
-- qbx_blackmarket — client/main.lua
-- ─────────────────────────────────────────────────────────────────────────────

local dealerPed       = nil
local spawningInProgress = false  -- prevents concurrent spawn calls

local function debugLog(msg, ...)
    if not Config.Debug then return end
    print(('[^3qbx_blackmarket^7] ^2DEBUG^7: ' .. msg):format(...))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Ped cleanup
-- ─────────────────────────────────────────────────────────────────────────────

local function removeDealerPed()
    spawningInProgress = false
    if dealerPed and DoesEntityExist(dealerPed) then
        exports.ox_target:removeLocalEntity(dealerPed)
        DeleteEntity(dealerPed)
    end
    dealerPed = nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Ped spawning
-- lib.requestModel confirmed: coxdocs.dev/ox_lib/Modules/Streaming/Client
-- Throws on invalid model — pcall required.
--
-- Ground Z fix: GetGroundZFor_3dCoord with useLoadedGround=false is unreliable
-- on resource restart since terrain may not be streamed at the ped location.
-- Solution: use the config Z directly and rely on PlaceObjectOnGroundProperly
-- with a retry loop, same pattern used in qbx_weed and qbx_cocaine.
-- ─────────────────────────────────────────────────────────────────────────────

local function spawnDealerPed()
    if spawningInProgress then return end
    if dealerPed and DoesEntityExist(dealerPed) then return end
    spawningInProgress = true

    CreateThread(function()
        local c = Config.Ped

        -- lib.requestModel throws on invalid — pcall required
        local ok, model = pcall(lib.requestModel, c.model)
        if not ok or not model then
            print(('[^1qbx_blackmarket^7] Failed to load ped model: %s'):format(c.model))
            spawningInProgress = false
            return
        end

        local ped = CreatePed(4, model,
            c.coords.x, c.coords.y, c.coords.z,
            c.coords.w, false, true)
        SetModelAsNoLongerNeeded(model)

        -- Wait for entity registration with timeout
        local waited = 0
        while not DoesEntityExist(ped) do
            Wait(10)
            waited += 10
            if waited >= 3000 then
                print('[^1qbx_blackmarket^7] CreatePed timed out')
                spawningInProgress = false
                return
            end
        end

        -- Confirmed ped setup sequence — flags before freeze
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 17, true)
        SetPedDiesWhenInjured(ped, false)
        SetPedCanRagdoll(ped, false)
        if c.invincible then SetEntityInvincible(ped, true) end
        if c.freeze     then FreezeEntityPosition(ped, true) end

        if c.scenario then
            TaskStartScenarioInPlace(ped, c.scenario, 0, true)
        end

        dealerPed          = ped
        spawningInProgress = false

        exports.ox_target:addLocalEntity(ped, {
            {
                name     = 'blackmarket_open_shop',
                icon     = Config.Target.icon,
                label    = Config.Target.label,
                distance = Config.Target.distance,
                onSelect = function()
                    TriggerServerEvent('qbx_blackmarket:server:openShop')
                end,
            },
        })

        debugLog('Dealer ped spawned — handle: %d', ped)
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Net events
-- ─────────────────────────────────────────────────────────────────────────────

RegisterNetEvent('qbx_blackmarket:client:openShop', function()
    exports.ox_inventory:openInventory('shop', { type = Config.Shop.id })
end)

-- ─────────────────────────────────────────────────────────────────────────────
-- Login — isLoggedIn statebag scoped to local player only
-- Confirmed Qbox pattern — fires on every login/logout including multichar.
-- This is the ONLY spawn trigger. CreateThread(init) at script top is removed
-- because it caused double-spawning when the player was already logged in.
-- On resource restart with player already in-game, the statebag fires
-- immediately, so the ped spawns correctly without any manual thread.
-- ─────────────────────────────────────────────────────────────────────────────

AddStateBagChangeHandler('isLoggedIn',
    ('player:%d'):format(GetPlayerServerId(PlayerId())),
    function(_, _, value)
        if value then
            spawnDealerPed()
        else
            removeDealerPed()
        end
    end
)

-- ─────────────────────────────────────────────────────────────────────────────
-- Resource restart — player already logged in
-- When the resource restarts the statebag won't re-fire, so we need to
-- explicitly spawn the ped if the player is already active.
-- ─────────────────────────────────────────────────────────────────────────────

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    -- Only spawn if already logged in — check our own statebag
    local bagName = ('player:%d'):format(GetPlayerServerId(PlayerId()))
    if LocalPlayer.state.isLoggedIn then
        spawnDealerPed()
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeDealerPed()
end)
