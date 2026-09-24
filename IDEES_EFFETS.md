# Idées d'effets de caméra

Pistes d'évolution pour `playable_camera_mod`. Ne sont listés ici que les effets
**pas encore implémentés** (déjà faits : caméra libre, zoom, tremblement, pause du
temps, suivi de cible orientation/position, HUD masquable, ancrage du streaming).

Difficulté estimée : 🟢 simple · 🟡 moyen · 🔴 complexe

---

## 1. Mouvements de caméra

| Effet | Description | Difficulté | Pistes techniques |
|---|---|---|---|
| **Roulis (Dutch angle)** | Incliner la caméra sur son axe pour créer un malaise ou du dynamisme | 🟢 | Composante Y de `SetCamRot` ; touches dédiées + retour à 0 |
| **Mouvements lissés (inertie)** | Accélération/décélération douces sur les déplacements, pas seulement sur le regard | 🟢 | Interpolation de la vitesse comme pour `LOOK_SMOOTHING` |
| **Mode drone** | Déplacement relatif à l'horizon (pas au regard), altitude verrouillée | 🟢 | Ignorer le pitch dans le vecteur de déplacement |
| **Travelling sur rail** | Enregistrer 2 points A → B et parcourir le trajet à vitesse constante | 🟡 | `SetCamActiveWithInterp` ou interpolation manuelle position/rotation |
| **Trajectoire spline (keyframes)** | Poser N points clés (position, rotation, FOV) et les rejouer en courbe fluide | 🔴 | Caméra `DEFAULT_SPLINE_CAMERA` + `AddCamSplineNode`, ou Catmull-Rom maison |
| **Orbite automatique** | Tourner autour de la cible suivie à vitesse et rayon réglables | 🟡 | Coordonnées polaires autour de `GetEntityCoords(trackedEntity)` |
| **Caméra embarquée** | Fixer la caméra sur un véhicule ou un personnage (capot, roue, épaule) | 🟡 | `AttachCamToEntity` / `AttachCamToPedBone` avec offset réglable |
| **Crane / grue** | Montée ou descente verticale lente et régulière, idéale en fin de scène | 🟢 | Variante du travelling sur l'axe Z |

## 2. Optique et objectif

| Effet | Description | Difficulté | Pistes techniques |
|---|---|---|---|
| **Profondeur de champ (DOF)** | Flouter l'arrière-plan / le premier plan, mise au point réglable | 🟡 | `SetCamUseShallowDofMode`, `SetCamNearDof`, `SetCamFarDof`, `SetCamDofStrength` + `SetUseHiDof()` chaque frame |
| **Autofocus sur la cible** | La mise au point suit l'entité visée ou suivie | 🟡 | Distance caméra → cible injectée dans les réglages DOF |
| **Rack focus** | Bascule de la mise au point d'un plan à un autre en douceur | 🟡 | Interpolation de la distance de netteté entre deux valeurs |
| **Dolly zoom (effet Vertigo)** | Avancer tout en dézoomant pour garder la cible à taille constante | 🟡 | Garder `distance × tan(FOV / 2)` constant pendant le déplacement |
| **Zoom « crash »** | Zoom très rapide et brutal sur un détail | 🟢 | Interpolation rapide du FOV avec courbe d'accélération |
| **Focales prédéfinies** | Presets 24 / 35 / 50 / 85 / 135 mm | 🟢 | Conversion focale → FOV vertical, cycle sur une touche |
| **Flou de mouvement** | Renforcer le flou lors des mouvements rapides | 🟢 | `SetCamMotionBlurStrength` |

## 3. Temps

| Effet | Description | Difficulté | Pistes techniques |
|---|---|---|---|
| **Ralenti** | Ralentir le jeu (0.1× à 1×) sans ralentir la caméra | 🟢 | `SetTimeScale` (le delta caméra est déjà calculé en temps réel via `GetGameTimer`) |
| **Rampe de vitesse (speed ramp)** | Passer progressivement de la vitesse normale au ralenti | 🟢 | Interpolation du `SetTimeScale` |
| **Heure du jour** | Choisir / faire défiler l'heure pour une lumière de golden hour, de nuit… | 🟢 | `NetworkOverrideClockTime` (local) |
| **Time-lapse** | Accélérer l'horloge pour voir le ciel défiler | 🟡 | Avancer l'heure à chaque frame, nuages via `SetCloudHatOpacity` |
| **Météo** | Choisir pluie, brouillard, neige, orage… | 🟢 | `SetWeatherTypeNowPersist`, `SetRainLevel`, `SetWindSpeed` |

## 4. Image et post-traitement

| Effet | Description | Difficulté | Pistes techniques |
|---|---|---|---|
| **Filtres colorimétriques** | Noir et blanc, sépia, teinte froide/chaude… | 🟢 | `SetTimecycleModifier` + `SetTimecycleModifierStrength` |
| **Effets écran** | Flash, vision trouble, drogue, flou d'impact | 🟢 | `AnimpostfxPlay` / `AnimpostfxStop` |
| **Vision nocturne / thermique** | Plans façon surveillance ou militaire | 🟢 | `SetNightvision`, `SetSeethrough` |
| **Bandes cinéma (letterbox)** | Barres noires 2.39:1, 1.85:1, 4:3… | 🟢 | `DrawRect` en haut et en bas de l'écran chaque frame |
| **Fondu au noir / au blanc** | Transitions d'ouverture et de fermeture de plan | 🟢 | `DoScreenFadeOut` / `DoScreenFadeIn` ou `DrawRect` avec alpha animé |
| **Vignettage** | Assombrir les bords de l'image | 🟡 | Modificateur de timecycle dédié ou sprite plein écran |
| **Grain / style VHS** | Rendu vieille pellicule ou caméscope | 🟡 | Combinaison de modificateurs de timecycle et d'effets `Animpostfx` |

## 5. Suivi et cadrage intelligent

| Effet | Description | Difficulté | Pistes techniques |
|---|---|---|---|
| **Décalage de cadrage** | Garder la cible à gauche/droite de l'image (règle des tiers) plutôt qu'au centre | 🟡 | Ajouter un offset angulaire à l'orientation de suivi |
| **Suivi d'os** | Viser la tête ou une main plutôt que le centre de l'entité | 🟢 | `GetPedBoneCoords` dans `GetTrackingTargetCoord` |
| **Anticipation** | Viser légèrement devant une cible en mouvement | 🟡 | Ajouter `GetEntityVelocity × facteur` à la position visée |
| **Caméra de poursuite distance fixe** | Suivre derrière un véhicule à distance constante (plan de course) | 🟡 | Offset dans le repère de l'entité via `GetOffsetFromEntityInWorldCoords` |
| **Coupe automatique multi-caméras** | Poser plusieurs caméras fixes et basculer entre elles (touche ou minuterie) | 🟡 | Tableau de caméras + `SetCamActive` / `RenderScriptCams` |
| **Suivi de cible par clavier** | Touche clavier par défaut pour le suivi (aujourd'hui manette uniquement) | 🟢 | `RegisterKeyMapping` sur une touche non utilisée |

## 6. Mise en scène et monde

| Effet | Description | Difficulté | Pistes techniques |
|---|---|---|---|
| **Masquer le joueur** | Rendre son propre personnage invisible pendant le tournage | 🟢 | `SetEntityLocallyInvisible` chaque frame |
| **Figer les PNJ / le trafic** | Vider ou geler la ville pour un plan propre | 🟡 | `SetPedDensityMultiplierThisFrame`, `SetVehicleDensityMultiplierThisFrame` |
| **Gel d'une entité** | Figer un personnage ou un véhicule précis en pleine action | 🟢 | `FreezeEntityPosition` sur l'entité visée |
| **Éclairage d'appoint** | Poser une lampe virtuelle (couleur, portée, intensité) | 🟡 | `DrawLightWithRange` / `DrawSpotLight` chaque frame |

## 7. Outils de tournage

| Outil | Description | Difficulté | Pistes techniques |
|---|---|---|---|
| **Grille de composition** | Afficher la grille des tiers / une croix de centre | 🟢 | `DrawRect` fins, masqués à l'enregistrement |
| **Sauvegarde de positions** | Mémoriser et rappeler des plans (position, rotation, FOV) | 🟢 | Table Lua + `SetResourceKvp` pour la persistance |
| **Téléportation du joueur à la caméra** | Ramener le personnage au point de vue actuel | 🟢 | `SetEntityCoords(PlayerPedId(), …)` |
| **Enregistrement / relecture de mouvement** | Enregistrer un mouvement manuel puis le rejouer à l'identique | 🔴 | Échantillonnage position/rotation/FOV par frame + relecture interpolée |
| **Intégration Rockstar Editor** | Lancer / arrêter un enregistrement du jeu depuis la freecam | 🟡 | `StartRecording` / `StopRecordingAndSaveClip` (à vérifier sous FiveM) |

---

## Priorités suggérées

Rapport effet visuel / effort le plus intéressant pour commencer :

1. **Profondeur de champ + autofocus** : c'est ce qui donne le plus vite un rendu « cinéma ».
2. **Roulis** et **bandes cinéma** : très simples, gros impact visuel.
3. **Ralenti** : le delta temps réel est déjà en place.
4. **Filtres colorimétriques** et **heure / météo** : ambiance immédiate.
5. **Travelling A → B**, puis les **splines** : c'est la base des plans de caméra reproductibles.
