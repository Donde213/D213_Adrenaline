local fearActive = false
local adrenalineEndTime = 0
local effectsRunning = false

-- VIGNETTE
local function setVignette(state, opacity)
    SendNUIMessage({
        type = "vignette",
        state = state,
        opacity = opacity or 1.0
    })
end

-- DRUNK EFFECT
local function startDrunk()
    ShakeGameplayCam("DRUNK_SHAKE", 0.8)
    SetPedMotionBlur(PlayerPedId(), true)
end

local function stopDrunk()
    StopGameplayCamShaking(true)
    SetPedMotionBlur(PlayerPedId(), false)
end

-- NOTIFY
local function notify(msg, nType)
    exports.ox_lib:notify({
        title = Config.NotifyTitle,
        description = msg,
        type = nType or "inform"
    })
end

-- 🔥 ADRENALINE (NO RESTART, ONLY EXTEND)
function triggerAdrenaline(duration, reason)
    local now = GetGameTimer()

    adrenalineEndTime = math.max(adrenalineEndTime, now + duration)

    if effectsRunning then return end
    effectsRunning = true

    setVignette(true, 1.0)
    startDrunk()

    notify(reason or "Adrenaline triggered!", "inform")

    CreateThread(function()
        while GetGameTimer() < adrenalineEndTime do
            Wait(250)
        end

        setVignette(false, 0)
        stopDrunk()

        effectsRunning = false
        adrenalineEndTime = 0
    end)
end

local function triggerFear()
    if fearActive then return end
    fearActive = true

    local ped = PlayerPedId()

    notify("Gunfire nearby! Taking cover!", "error")

    setVignette(true, 1.0)
    startDrunk()

    CreateThread(function()

        local dict = "none"
        local anim = "none"

        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(0) end

        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)

        -- start smooth IN
        TaskPlayAnim(
            ped,
            dict,
            anim,
            4.0,      -- ease IN
            4.0,      -- ease OUT
            Config.FearDuration,
            49,       -- stable flag (no ragdoll, no override spam)
            0,
            false,
            false,
            false
        )

        -- HOLD DURATION
        Wait(Config.FearDuration)

        -- STOP CLEANLY
        StopAnimTask(ped, dict, anim, 1.5)

        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)

        StopGameplayCamShaking(true)
        setVignette(false, 0)
        stopDrunk()

        fearActive = false
    end)
end

-- 🔫 PLAYER SHOOT (SYNC SERVER)
CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()

        if IsPedShooting(ped) then
            TriggerServerEvent("adrenaline:shotFired", GetEntityCoords(ped))
            triggerAdrenaline(Config.SelfShootDuration, "You fired your weapon!")
            Wait(500)
        end
    end
end)

-- 📡 NEARBY SHOTS
RegisterNetEvent("adrenaline:shotNearby", function(coords, shooter)
    local myId = GetPlayerServerId(PlayerId())

    if shooter == myId then return end

    local dist = #(GetEntityCoords(PlayerPedId()) - coords)

    if dist <= Config.NearbyRadius then
        triggerAdrenaline(Config.NearbyShootDuration, "Gunfire nearby!")
        triggerFear()
    end
end) 

RegisterCommand("spawnfreeped", function()
    local model = `mp_m_freemode_01`
    local weapon = `WEAPON_SNSPISTOL`

    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end

    local coords = GetEntityCoords(PlayerPedId())

    local ped = CreatePed(4, model, coords + vec3(2.0, 0.0, 0.0), 0.0, true, true)

    SetPedAsEnemy(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)

    -- GIVE WEAPON
    GiveWeaponToPed(ped, weapon, 250, false, true)
    SetCurrentPedWeapon(ped, weapon, true)

  -- IMPORTANT FIXES
    SetPedAsEnemy(ped, true)
    SetPedRelationshipGroupHash(ped, `HATES_PLAYER`)
    SetPedCombatAttributes(ped, 46, true) -- always fight
    SetPedCombatAttributes(ped, 0, true)
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)

    -- DO NOT block AI
    SetBlockingOfNonTemporaryEvents(ped, false)

    GiveWeaponToPed(ped, weapon, 250, false, true)
    SetCurrentPedWeapon(ped, weapon, true)

    -- FORCE ATTACK PLAYER
    TaskCombatPed(ped, PlayerPedId(), 0, 16)

    print("Aggressive ped spawned and attacking player")
end)

RegisterCommand("testfear", function()
    triggerFear()
end)