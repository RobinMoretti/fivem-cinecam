--[[
    camera_player_mod - client/camera.lua

    Caméra libre détachée du personnage (machinima).
    - Activation/désactivation via la commande console/chat `/freecam` ou la touche F7.
    - Stick gauche (ou ZQSD/WASD) : déplacement dans l'espace.
    - Stick droit (ou souris) : orientation, comme un FPS.
]]

local isFreeCamActive = false
local freeCam = nil
local camRot = vector3(0.0, 0.0, 0.0) -- x = pitch, y = roll (inutilisé), z = yaw

local MOVE_SPEED = 3.0        -- unités GTA par seconde (ajustable au clavier, sans limite haute)
local MOVE_SPEED_MIN = 0.5
local MOVE_SPEED_STEP = 1.0   -- incrément par pression de PAGEUP/PAGEDOWN

local LOOK_SENSITIVITY = 200.0 -- degrés par seconde à pleine intensité (ajustable au clavier)
local LOOK_SENSITIVITY_MIN = 20.0
local LOOK_SENSITIVITY_STEP = 20.0 -- incrément par pression de INSERT/DELETE
local LOOK_SMOOTHING = 8.0    -- + petit = plus d'inertie/glisse, + grand = plus réactif

local FOV_DEFAULT = 50.0
local FOV_MIN = 10.0   -- zoom max (téléobjectif)
local FOV_MAX = 90.0   -- zoom min (grand angle)
local ZOOM_SPEED = 30.0 -- degrés de FOV/s à pleine pression de L2/R2 (progressif selon la gâchette), ajustable au clavier
local ZOOM_SPEED_MIN = 5.0
local ZOOM_SPEED_STEP = 10.0 -- incrément par pression de NUMPAD+ / NUMPAD-

local SHAKE_TYPE = 'HAND_SHAKE' -- effet natif GTA simulant une caméra tenue à la main
local SHAKE_AMPLITUDE = 0.2     -- 0.0 (aucun) a 1.0 (fort), ajustable au clavier
local SHAKE_AMPLITUDE_MIN = 0.0
local SHAKE_AMPLITUDE_STEP = 0.1 -- incrément par pression de NUMPAD* / NUMPAD/

local TRACKING_MAX_DISTANCE = 100.0 -- portée du viseur pour choisir une cible (mètres)
local TRACKING_SMOOTHING = 4.0      -- vitesse de suivi vers la cible (+ petit = plus lent/cinématique)
local AIM_CHECK_INTERVAL_MS = 100   -- fréquence du raycast de visée (pas besoin de le faire chaque frame)
local TRACK_TOGGLE_DEBOUNCE_MS = 250 -- évite les doubles changements de mode au même appui

local STREAM_ANCHOR_TO_CAMERA = true -- garde le ped caché au niveau de la caméra pour conserver scope/streaming
local STREAM_ANCHOR_Z_OFFSET = 10.0 -- offset vertical de l'ancre (mètres) au-dessus de la caméra

local smoothLookLR = 0.0
local smoothLookUD = 0.0
local currentFov = FOV_DEFAULT
local shakeEnabled = false
local isTimePaused = false
local lastFrameMs = 0
local trackedEntity = nil   -- entité actuellement suivie par la caméra (ou nil)
local trackingMode = 0      -- 0 = aucun, 1 = orientation seule, 2 = orientation + position
local trackedEntityLastCoord = nil -- position de la cible à la frame précédente (mode 2)
local lastTrackToggleMs = 0
local streamAnchorStartCoord = nil
local streamAnchorStartHeading = 0.0
local aimedEntity = nil    -- entité actuellement visée par le centre de l'écran (ou nil)
local aimedEntityDist = 0.0
local nextAimCheckMs = 0

local hudVisible = true
local debugVisible = false

local LOG_PREFIX = '[camera_player_mod]'

local function Log(msg)
    print(('%s %s'):format(LOG_PREFIX, msg))
end

-- Affiche un petit message à l'écran (sous-titre) pour donner un retour visuel.
local function ShowSubtitle(msg)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandPrint(1500, true)
end

-- Affiche une ligne de texte de debug à l'écran (coin haut-gauche).
local function DrawDebugLine(y, text)
    SetTextFont(4)
    SetTextScale(0.32, 0.32)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.015, y)
end

-- Convertit une rotation (degrés) en vecteur direction normalisé.
local function RotationToDirection(rotation)
    local radX = math.rad(rotation.x)
    local radZ = math.rad(rotation.z)
    return vector3(
        -math.sin(radZ) * math.abs(math.cos(radX)),
        math.cos(radZ) * math.abs(math.cos(radX)),
        math.sin(radX)
    )
end

-- Renvoie l'entité (ped/véhicule/objet) visée par le centre de l'écran, ou nil si rien trouvé.
local function GetEntityAtCrosshair(camCoord, forward)
    local dest = camCoord + (forward * TRACKING_MAX_DISTANCE)
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        camCoord.x, camCoord.y, camCoord.z,
        dest.x, dest.y, dest.z,
        -1, PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    if hit == 1 and entityHit ~= 0 and DoesEntityExist(entityHit) then
        return entityHit, #(camCoord - endCoords)
    end
    return nil, 0.0
end

-- Libellé lisible pour le type d'une entité (ped/véhicule/objet).
local function GetEntityTypeLabel(entity)
    if IsEntityAPed(entity) then
        return 'Personnage'
    elseif IsEntityAVehicle(entity) then
        return 'Vehicule'
    elseif IsEntityAnObject(entity) then
        return 'Objet'
    end
    return 'Inconnu'
end

-- Point visé sur une entité suivie (légèrement relevé pour peds/véhicules, pour viser le buste
-- plutôt que les pieds).
local function GetTrackingTargetCoord(entity)
    local coord = GetEntityCoords(entity)
    if IsEntityAPed(entity) then
        return coord + vector3(0.0, 0.0, 0.6)
    elseif IsEntityAVehicle(entity) then
        return coord + vector3(0.0, 0.0, 0.5)
    end
    return coord
end

-- Active la caméra libre : fige/cache le ped et bascule le rendu sur une caméra scriptée.
local function EnableFreeCam()
    if isFreeCamActive then return end
    isFreeCamActive = true

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    streamAnchorStartCoord = coords
    streamAnchorStartHeading = heading

    camRot = vector3(0.0, 0.0, heading)
    smoothLookLR = 0.0
    smoothLookUD = 0.0
    currentFov = FOV_DEFAULT
    hudVisible = true
    debugVisible = false
    shakeEnabled = false
    isTimePaused = false
    lastFrameMs = GetGameTimer()
    trackedEntity = nil
    trackingMode = 0
    trackedEntityLastCoord = nil
    aimedEntity = nil
    aimedEntityDist = 0.0
    nextAimCheckMs = 0

    freeCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        coords.x, coords.y, coords.z + 1.0,
        camRot.x, camRot.y, camRot.z,
        currentFov, false, 0)
    SetCamActive(freeCam, true)
    RenderScriptCams(true, false, 0, true, false)

    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityInvincible(playerPed, true)
    -- Note : on ne coupe plus le contrôle joueur ici (voir AGENT.md, section
    -- "hauteur : bug corrigé"). Le ped est déjà figé + invisible + invincible,
    -- et chaque contrôle utile est individuellement bloqué via
    -- DisableControlAction dans la boucle principale : c'est suffisant pour
    -- être totalement détaché du personnage, sans les effets de bord que
    -- SetPlayerControl(false) provoquait sur la lecture de certains boutons.
end

-- Désactive la caméra libre et rend le contrôle du personnage.
local function DisableFreeCam()
    if not isFreeCamActive then return end
    isFreeCamActive = false

    RenderScriptCams(false, false, 0, true, false)
    if freeCam then
        StopCamShaking(freeCam, true)
        DestroyCam(freeCam, false)
        freeCam = nil
    end

    local playerPed = PlayerPedId()

    -- Si le ped a servi d'ancre de streaming autour de la caméra, on le remet
    -- à son point de départ pour que la sortie de freecam ne téléporte pas le joueur.
    if streamAnchorStartCoord then
        SetEntityCoordsNoOffset(playerPed, streamAnchorStartCoord.x, streamAnchorStartCoord.y, streamAnchorStartCoord.z, false, false, false)
        SetEntityHeading(playerPed, streamAnchorStartHeading)
    end

    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityInvincible(playerPed, false)
    SetPlayerControl(PlayerId(), true, 0)

    -- On s'assure que le HUD est bien réaffiché en sortant de la caméra libre.
    DisplayHud(true)
    DisplayRadar(true)

    -- Sécurité : on ne laisse jamais le monde en pause en sortant de la caméra libre.
    if isTimePaused then
        SetTimeScale(1.0)
        isTimePaused = false
    end

    -- On rend le focus de streaming/LOD au joueur (voir SetFocusPosAndVel dans la boucle).
    ClearFocus()

    streamAnchorStartCoord = nil
    streamAnchorStartHeading = 0.0
end

RegisterCommand('freecam', function()
    if isFreeCamActive then
        DisableFreeCam()
    else
        EnableFreeCam()
    end
end, false)

RegisterKeyMapping('freecam', 'Activer/desactiver la camera libre (machinima)', 'keyboard', 'F7')

-- Change la vitesse de déplacement d'un palier et affiche un retour à l'écran.
local function ChangeMoveSpeed(delta)
    if not isFreeCamActive then return end
    MOVE_SPEED = math.max(MOVE_SPEED_MIN, MOVE_SPEED + delta)
    ShowSubtitle(('Vitesse de deplacement : %.1f'):format(MOVE_SPEED))
end

RegisterCommand('freecam_speedup', function() ChangeMoveSpeed(MOVE_SPEED_STEP) end, false)
RegisterKeyMapping('freecam_speedup', 'Camera libre : augmenter la vitesse', 'keyboard', 'PAGEUP')

RegisterCommand('freecam_speeddown', function() ChangeMoveSpeed(-MOVE_SPEED_STEP) end, false)
RegisterKeyMapping('freecam_speeddown', 'Camera libre : diminuer la vitesse', 'keyboard', 'PAGEDOWN')

-- Change la vitesse de rotation d'un palier (clavier uniquement, la manette garde sa propre
-- sensibilité analogique naturelle du stick droit).
local function ChangeLookSensitivity(delta)
    if not isFreeCamActive then return end
    LOOK_SENSITIVITY = math.max(LOOK_SENSITIVITY_MIN, LOOK_SENSITIVITY + delta)
    ShowSubtitle(('Vitesse de rotation : %.0f'):format(LOOK_SENSITIVITY))
end

RegisterCommand('freecam_rotspeedup', function() ChangeLookSensitivity(LOOK_SENSITIVITY_STEP) end, false)
RegisterKeyMapping('freecam_rotspeedup', 'Camera libre : augmenter la vitesse de rotation', 'keyboard', 'INSERT')

RegisterCommand('freecam_rotspeeddown', function() ChangeLookSensitivity(-LOOK_SENSITIVITY_STEP) end, false)
RegisterKeyMapping('freecam_rotspeeddown', 'Camera libre : diminuer la vitesse de rotation', 'keyboard', 'DELETE')

-- Change la vitesse de zoom d'un palier (clavier uniquement).
local function ChangeZoomSpeed(delta)
    if not isFreeCamActive then return end
    ZOOM_SPEED = math.max(ZOOM_SPEED_MIN, ZOOM_SPEED + delta)
    ShowSubtitle(('Vitesse de zoom : %.0f'):format(ZOOM_SPEED))
end

RegisterCommand('freecam_zoomspeedup', function() ChangeZoomSpeed(ZOOM_SPEED_STEP) end, false)
RegisterKeyMapping('freecam_zoomspeedup', 'Camera libre : augmenter la vitesse de zoom', 'keyboard', 'ADD')

RegisterCommand('freecam_zoomspeeddown', function() ChangeZoomSpeed(-ZOOM_SPEED_STEP) end, false)
RegisterKeyMapping('freecam_zoomspeeddown', 'Camera libre : diminuer la vitesse de zoom', 'keyboard', 'SUBTRACT')

-- Raccourcis clavier pour le zoom (maintenu), indépendants de la manette (L2/R2).
-- Convention FiveM : "+nom" = touche enfoncée, "-nom" = touche relâchée.
local keyboardZoomIn = false
local keyboardZoomOut = false

RegisterCommand('+freecam_zoomin', function() keyboardZoomIn = true end, false)
RegisterCommand('-freecam_zoomin', function() keyboardZoomIn = false end, false)
RegisterKeyMapping('freecam_zoomin', 'Camera libre : zoomer', 'keyboard', 'HOME')

RegisterCommand('+freecam_zoomout', function() keyboardZoomOut = true end, false)
RegisterCommand('-freecam_zoomout', function() keyboardZoomOut = false end, false)
RegisterKeyMapping('freecam_zoomout', 'Camera libre : dezoomer', 'keyboard', 'END')

-- Affichage/masquage du HUD (map, vie, munitions...) pendant la prise de vue.
RegisterCommand('freecam_togglehud', function()
    if not isFreeCamActive then return end
    hudVisible = not hudVisible
    ShowSubtitle(hudVisible and 'HUD affiche' or 'HUD masque')
end, false)
RegisterKeyMapping('freecam_togglehud', 'Camera libre : afficher/masquer le HUD', 'keyboard', 'F6')

-- Affichage/masquage du mode debug (vitesse, FOV, position, rotation).
RegisterCommand('freecam_toggledebug', function()
    if not isFreeCamActive then return end
    debugVisible = not debugVisible
    ShowSubtitle(debugVisible and 'Debug affiche' or 'Debug masque')
end, false)
RegisterKeyMapping('freecam_toggledebug', 'Camera libre : afficher/masquer le debug', 'keyboard', 'F9')

-- Activation/désactivation du tremblement caméra (effet "caméra à l'épaule").
RegisterCommand('freecam_toggleshake', function()
    if not isFreeCamActive or not freeCam then return end
    shakeEnabled = not shakeEnabled
    if shakeEnabled then
        ShakeCam(freeCam, SHAKE_TYPE, SHAKE_AMPLITUDE)
    else
        StopCamShaking(freeCam, true)
    end
    ShowSubtitle(shakeEnabled and 'Tremblement camera active' or 'Tremblement camera desactive')
end, false)
RegisterKeyMapping('freecam_toggleshake', 'Camera libre : activer/desactiver le tremblement', 'keyboard', 'F10')

-- Ajuste l'intensité du tremblement d'un palier (clavier uniquement), utilisable même si le
-- tremblement est actuellement désactivé (l'amplitude sera appliquée à la prochaine activation).
local function ChangeShakeAmplitude(delta)
    if not isFreeCamActive then return end
    SHAKE_AMPLITUDE = math.max(SHAKE_AMPLITUDE_MIN, SHAKE_AMPLITUDE + delta)
    if shakeEnabled and freeCam then
        SetCamShakeAmplitude(freeCam, SHAKE_AMPLITUDE)
    end
    ShowSubtitle(('Amplitude du tremblement : %.1f'):format(SHAKE_AMPLITUDE))
end

RegisterCommand('freecam_shakeup', function() ChangeShakeAmplitude(SHAKE_AMPLITUDE_STEP) end, false)
RegisterKeyMapping('freecam_shakeup', 'Camera libre : augmenter le tremblement', 'keyboard', 'MULTIPLY')

RegisterCommand('freecam_shakedown', function() ChangeShakeAmplitude(-SHAKE_AMPLITUDE_STEP) end, false)
RegisterKeyMapping('freecam_shakedown', 'Camera libre : diminuer le tremblement', 'keyboard', 'F11')

-- Pause/relance du temps (monde figé : peds, véhicules, animations...) pour caler la caméra
-- tranquillement. La caméra reste pilotable normalement pendant la pause (voir boucle
-- principale : le delta de temps utilisé pour ses déplacements n'est pas affecté par SetTimeScale).
local function TogglePause()
    if not isFreeCamActive then
        Log('togglePause ignore: freecam inactive')
        return
    end

    isTimePaused = not isTimePaused
    SetTimeScale(isTimePaused and 0.0 or 1.0)
    ShowSubtitle(isTimePaused and 'Temps en pause' or 'Temps relance')
    Log(('togglePause: isTimePaused=%s'):format(tostring(isTimePaused)))
end

-- Commande manuelle : /freecam_togglepause
RegisterCommand('freecam_togglepause', function()
    TogglePause()
end, false)

-- Commandes dédiées au key mapping (format + / - plus fiable dans FiveM).
RegisterCommand('+freecam_togglepause_key', function()
    Log('key event: +freecam_togglepause_key')
    TogglePause()
end, false)
RegisterCommand('-freecam_togglepause_key', function()
    Log('key event: -freecam_togglepause_key')
end, false)
RegisterKeyMapping('+freecam_togglepause_key', 'Camera libre : mettre en pause/relancer le temps', 'keyboard', 'N')

-- Cycle le suivi de la cible visée par le centre de l'écran (façon FPS) sur 3 états :
-- aucun -> orientation seule -> orientation + position (caméra de poursuite) -> aucun.
local function CycleTrack(source)
    local nowMs = GetGameTimer()
    if (nowMs - lastTrackToggleMs) < TRACK_TOGGLE_DEBOUNCE_MS then
        Log(('cycleTrack ignored (debounce): source=%s deltaMs=%d'):format(tostring(source), nowMs - lastTrackToggleMs))
        return
    end
    lastTrackToggleMs = nowMs

    Log(('cycleTrack called: source=%s active=%s mode=%d aimed=%s tracked=%s'):format(
        tostring(source), tostring(isFreeCamActive), trackingMode, tostring(aimedEntity), tostring(trackedEntity)))

    if not isFreeCamActive then
        ShowSubtitle('Tracking ignore: freecam inactive')
        return
    end

    if trackingMode == 0 then
        if not aimedEntity then
            ShowSubtitle('Aucune cible visee (regardez un personnage/vehicule/objet)')
            Log('cycleTrack: no aimed entity')
            return
        end
        trackedEntity = aimedEntity
        trackingMode = 1
        trackedEntityLastCoord = nil
        ShowSubtitle(('Suivi (orientation) : %s'):format(GetEntityTypeLabel(trackedEntity)))
        Log(('cycleTrack -> mode=1 entity=%s type=%s'):format(tostring(trackedEntity), GetEntityTypeLabel(trackedEntity)))
    elseif trackingMode == 1 then
        trackingMode = 2
        trackedEntityLastCoord = GetEntityCoords(trackedEntity)
        ShowSubtitle(('Suivi (orientation + position) : %s'):format(GetEntityTypeLabel(trackedEntity)))
        Log(('cycleTrack -> mode=2 entity=%s type=%s'):format(tostring(trackedEntity), GetEntityTypeLabel(trackedEntity)))
    else
        trackingMode = 0
        trackedEntity = nil
        trackedEntityLastCoord = nil
        ShowSubtitle('Suivi de cible desactive')
        Log('cycleTrack -> mode=0 (disabled)')
    end
end

-- Commande manuelle (chat/console) utile pour debug : /freecam_cycletrack
RegisterCommand('freecam_cycletrack', function()
    CycleTrack('command:/freecam_cycletrack')
end, false)

-- Le tracking se bascule via bouton Croix manette (INPUT_SPRINT, id 21) pendant
-- la freecam. Attention : sur manette, INPUT_JUMP (22) correspond à Carré, pas à Croix.
-- La commande /freecam_cycletrack reste disponible en fallback.

-- Boucle de mise à jour : orientation (stick droit / souris) + déplacement (stick gauche / ZQSD).
CreateThread(function()
    while true do
        if isFreeCamActive and freeCam then
            -- Delta de temps calculé manuellement via GetGameTimer (temps réel, non affecté par
            -- SetTimeScale) plutôt que GetFrameTime (qui serait figé à 0 si le temps est en pause,
            -- rendant la caméra elle-même incontrôlable).
            local nowMs = GetGameTimer()
            local frameTime = (nowMs - lastFrameMs) / 1000.0
            lastFrameMs = nowMs

            -- On bloque les actions par défaut pour ne garder que la lecture des axes.
            DisableControlAction(0, 1, true)  -- INPUT_LOOK_LR
            DisableControlAction(0, 2, true)  -- INPUT_LOOK_UD
            DisableControlAction(0, 30, true) -- INPUT_MOVE_LR
            DisableControlAction(0, 31, true) -- INPUT_MOVE_UD
            DisableControlAction(0, 21, true) -- INPUT_SPRINT (Croix manette = tracking)
            DisableControlAction(0, 22, true) -- INPUT_JUMP (Espace clavier : monter / Carré manette)
            DisableControlAction(0, 36, true) -- INPUT_DUCK (descendre)
            DisableControlAction(0, 205, true) -- INPUT_FRONTEND_LB (L1 : descendre)
            DisableControlAction(0, 206, true) -- INPUT_FRONTEND_RB (R1 : monter)
            DisableControlAction(0, 37, true)  -- INPUT_SELECT_WEAPON (roue d'armes, aussi sur R1/RB)
            DisableControlAction(0, 25, true)  -- INPUT_AIM (L2 : dézoomer)
            DisableControlAction(0, 24, true)  -- INPUT_ATTACK (R2 : zoomer)

            local isKeyboardInput = IsInputDisabled(2)

            -- INPUT_SPRINT (21) est partagé clavier (Shift) / manette (Croix). On journalise
            -- toujours l'appui, puis on ne déclenche le tracking que si la dernière méthode
            -- d'entrée est manette.
            local crossPressed = IsDisabledControlJustPressed(0, 21) or IsDisabledControlJustPressed(2, 21)
            if crossPressed then
                local lastInputIsKeyboard = GetLastInputMethod(2)
                Log(('input 21 pressed: lastInput=%s isKeyboardInput=%s'):format(
                    lastInputIsKeyboard and 'keyboard' or 'controller', tostring(isKeyboardInput)))

                if not lastInputIsKeyboard then
                    Log('controller event: CROSS (INPUT_SPRINT 21)')
                    CycleTrack('controller-cross:21')
                end
            end

            -- Si une cible suivie a disparu (entité détruite), on arrête le suivi proprement.
            if trackedEntity and not DoesEntityExist(trackedEntity) then
                trackedEntity = nil
                trackingMode = 0
                trackedEntityLastCoord = nil
                ShowSubtitle('Cible perdue, suivi desactive')
            end

            -- Orientation : suivi automatique d'une cible si activé, sinon stick droit sur
            -- manette / souris au clavier, avec un lissage exponentiel (lerp) pour une rotation
            -- plus douce et un peu d'inertie.
            local zoomSensitivityFactor = currentFov / FOV_MAX

            if trackedEntity then
                local camCoordForTrack = GetCamCoord(freeCam)
                local targetCoord = GetTrackingTargetCoord(trackedEntity)
                local dx = targetCoord.x - camCoordForTrack.x
                local dy = targetCoord.y - camCoordForTrack.y
                local dz = targetCoord.z - camCoordForTrack.z
                local horizDist = math.sqrt(dx * dx + dy * dy)
                local targetPitch = math.deg(math.atan(dz, horizDist))
                local targetYaw = math.deg(math.atan(-dx, dy))

                local trackFactor = math.min(1.0, TRACKING_SMOOTHING * frameTime)
                local yawDiff = ((targetYaw - camRot.z + 180.0) % 360.0) - 180.0
                local pitch = camRot.x + (targetPitch - camRot.x) * trackFactor
                pitch = math.max(-89.0, math.min(89.0, pitch))
                local yaw = camRot.z + yawDiff * trackFactor
                camRot = vector3(pitch, 0.0, yaw)
            else
                local rawLookLR = GetDisabledControlNormal(0, 1)
                local rawLookUD = GetDisabledControlNormal(0, 2)
                local smoothFactor = math.min(1.0, LOOK_SMOOTHING * frameTime)
                smoothLookLR = smoothLookLR + (rawLookLR - smoothLookLR) * smoothFactor
                smoothLookUD = smoothLookUD + (rawLookUD - smoothLookUD) * smoothFactor

                -- La vitesse de rotation est réduite proportionnellement au zoom (comme un vrai
                -- objectif optique) : sans ça, un fort zoom rend la rotation incontrôlable.
                local effectiveLookSensitivity = LOOK_SENSITIVITY * zoomSensitivityFactor

                local pitch = camRot.x - (smoothLookUD * effectiveLookSensitivity * frameTime)
                pitch = math.max(-89.0, math.min(89.0, pitch))
                local yaw = camRot.z - (smoothLookLR * effectiveLookSensitivity * frameTime)
                camRot = vector3(pitch, 0.0, yaw)
            end
            SetCamRot(freeCam, camRot.x, camRot.y, camRot.z, 2)

            -- Déplacement : stick gauche sur manette, ZQSD/WASD au clavier.
            local moveLR = GetDisabledControlNormal(0, 30)
            local moveUD = -GetDisabledControlNormal(0, 31)

            local forward = RotationToDirection(camRot)
            local right = RotationToDirection(vector3(0.0, 0.0, camRot.z - 90.0))
            local speed = MOVE_SPEED * frameTime
            local moveOffset = (forward * moveUD) + (right * moveLR)
            moveOffset = moveOffset * speed

            -- Monter/descendre à la verticale, indépendamment de l'orientation.
            -- Espace/Ctrl (clavier, aussi Saut/Accroupi sur manette) ou L1/R1 (manette).
            -- Depuis que SetPlayerControl(false) n'est plus utilisé (voir EnableFreeCam),
            -- ces contrôles se lisent normalement, y compris sur manette.
            local verticalOffset = 0.0
            if (isKeyboardInput and IsDisabledControlPressed(0, 22)) or IsDisabledControlPressed(0, 206) then
                verticalOffset = speed
            elseif (isKeyboardInput and IsDisabledControlPressed(0, 36)) or IsDisabledControlPressed(0, 205) then
                verticalOffset = -speed
            end

            -- Suivi en position (mode 2) : la caméra se déplace du même vecteur que la cible
            -- depuis la frame précédente, en plus du déplacement manuel (caméra de poursuite).
            local followOffset = vector3(0.0, 0.0, 0.0)
            if trackingMode == 2 and trackedEntity then
                local targetNowCoord = GetEntityCoords(trackedEntity)
                if trackedEntityLastCoord then
                    followOffset = targetNowCoord - trackedEntityLastCoord
                end
                trackedEntityLastCoord = targetNowCoord
            end

            local camCoord = GetCamCoord(freeCam)
            local newCoord = camCoord + moveOffset + vector3(0.0, 0.0, verticalOffset) + followOffset
            SetCamCoord(freeCam, newCoord.x, newCoord.y, newCoord.z)

            -- Ancre de streaming: on déplace aussi le ped caché sur la position caméra.
            -- Cela maintient la scope réseau/population (peds/voitures) autour de la
            -- freecam, ce que SetFocusPosAndVel seul ne garantit pas toujours.
            if STREAM_ANCHOR_TO_CAMERA then
                local playerPed = PlayerPedId()
                local anchorCoord = newCoord + vector3(0.0, 0.0, STREAM_ANCHOR_Z_OFFSET)
                SetEntityCoordsNoOffset(playerPed, anchorCoord.x, anchorCoord.y, anchorCoord.z, false, false, false)
                SetEntityHeading(playerPed, camRot.z)
            end

            -- Force le monde (streaming, LOD) à se charger autour de la caméra.
            SetFocusPosAndVel(newCoord.x, newCoord.y, newCoord.z, 0.0, 0.0, 0.0)

            -- Zoom caméra : R2/L2 (manette, progressif selon la pression) ou HOME/END (clavier, plein régime).
            local zoomInAmount = math.max(GetDisabledControlNormal(0, 24), keyboardZoomIn and 1.0 or 0.0)
            local zoomOutAmount = math.max(GetDisabledControlNormal(0, 25), keyboardZoomOut and 1.0 or 0.0)

            if zoomInAmount > 0.0 then
                currentFov = math.max(FOV_MIN, currentFov - (ZOOM_SPEED * zoomInAmount * frameTime))
                SetCamFov(freeCam, currentFov)
            elseif zoomOutAmount > 0.0 then
                currentFov = math.min(FOV_MAX, currentFov + (ZOOM_SPEED * zoomOutAmount * frameTime))
                SetCamFov(freeCam, currentFov)
            end

            -- Cible visée par le centre de l'écran (façon FPS), pour le tracking (Croix manette).
            -- Le raycast est "expensive" (bloquant) : on le limite à 10 fois par seconde plutôt
            -- que chaque frame, largement suffisant pour un réticule/indicateur.
            if nowMs >= nextAimCheckMs then
                aimedEntity, aimedEntityDist = GetEntityAtCrosshair(newCoord, forward)
                nextAimCheckMs = nowMs + AIM_CHECK_INTERVAL_MS
            end

            -- HUD (map, vie, munitions...) : à réappliquer chaque frame pour rester effectif.
            DisplayHud(hudVisible)
            DisplayRadar(hudVisible)

            -- Debug : affiche les variables ajustables (vitesse, FOV, position, rotation).
            if debugVisible then
                DrawDebugLine(0.03, ('Vitesse deplacement : %.1f'):format(MOVE_SPEED))
                DrawDebugLine(0.06, ('Vitesse rotation : %.0f (x%.2f zoom)'):format(LOOK_SENSITIVITY, zoomSensitivityFactor))
                DrawDebugLine(0.09, ('Vitesse zoom : %.0f'):format(ZOOM_SPEED))
                DrawDebugLine(0.12, ('FOV (zoom) : %.1f'):format(currentFov))
                DrawDebugLine(0.15, ('Position : %.1f, %.1f, %.1f'):format(newCoord.x, newCoord.y, newCoord.z))
                DrawDebugLine(0.18, ('Rotation (pitch/yaw) : %.1f, %.1f'):format(camRot.x, camRot.z))
                DrawDebugLine(0.21, ('Tremblement : %s (amplitude %.1f)'):format(shakeEnabled and 'actif' or 'inactif', SHAKE_AMPLITUDE))
                DrawDebugLine(0.24, ('Temps : %s'):format(isTimePaused and 'en pause' or 'normal'))

                if trackedEntity then
                    local modeLabel = (trackingMode == 2) and 'orientation+position' or 'orientation'
                    DrawDebugLine(0.27, ('Suivi (%s) : %s a %.1fm (Croix manette pour changer/arreter)'):format(
                        modeLabel, GetEntityTypeLabel(trackedEntity), #(newCoord - GetEntityCoords(trackedEntity))))
                elseif aimedEntity then
                    DrawDebugLine(0.27, ('Cible visee : %s a %.1fm (Croix manette pour suivre)'):format(
                        GetEntityTypeLabel(aimedEntity), aimedEntityDist))
                else
                    DrawDebugLine(0.27, 'Cible visee : aucune')
                end

                -- Petit réticule au centre de l'écran pour visualiser le point de visée.
                DrawRect(0.5, 0.5, 0.0016, 0.003, 255, 255, 255, 200)
            end

            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Log('resource started')
        Log('default key mappings: freecam=F7, pause=N, track-cycle=controller CROSS')
        Log(('stream anchor to camera: %s (zOffset=%.1fm)'):format(STREAM_ANCHOR_TO_CAMERA and 'enabled' or 'disabled', STREAM_ANCHOR_Z_OFFSET))
        Log('debug commands: /freecam_togglepause and /freecam_cycletrack')
        Log('if N does not trigger, bind +freecam_togglepause_key manually in FiveM key bindings')
    end
end)

-- Sécurité : si la resource est stoppée pendant que la caméra est active,
-- on rend bien le contrôle du personnage pour ne pas le laisser figé/invisible.
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Log('resource stopping')
        if isFreeCamActive then
            DisableFreeCam()
        end
    end
end)
