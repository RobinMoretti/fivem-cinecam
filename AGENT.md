# AGENT.md — camera_player_mod

Ce fichier sert de mémoire de contexte pour la suite du développement de ce
mod, entre deux sessions de travail (humain ou IA). À mettre à jour à chaque
étape franchie.

## Objectif général

Créer un mod FiveM/GTA V qui permet d'avoir une **caméra libre, détachée du
personnage joueur**, pour faire du machinima (films/cinématiques en jeu).
Le mod est destiné à être **partagé publiquement** : garder le code simple,
lisible, et sans dépendance externe.

Inspiration : mode "Director"/caméra libre du Rockstar Editor, mais
utilisable directement en jeu (solo ou sur un serveur FiveM).

## Contraintes / partis pris

- Resource **client-only** (aucune logique serveur nécessaire pour l'instant :
  la caméra est purement locale à celui qui l'utilise).
- Code simple, commenté uniquement quand nécessaire (le mod sera partagé).
- Référence pour les natives GTA/FiveM : https://docs.fivem.net/natives/
- Convention du projet : chaque resource a son `fxmanifest.lua`, un
  `README.md` d'utilisation, et ici en plus un `AGENT.md` de suivi.
- **Important** : tout nouveau raccourci (clavier ou manette) ajouté dans
  `client/camera.lua` doit aussi être ajouté au tableau de raccourcis du
  [README.md](./README.md) (section "Raccourcis"). Garder les deux fichiers
  synchronisés à chaque modification.

## Structure actuelle

```
camera_player_mod/
├── fxmanifest.lua      # manifeste (client_script uniquement)
├── README.md           # doc d'installation / utilisation
├── AGENT.md            # ce fichier
└── client/
    └── camera.lua      # logique de la caméra libre
```

## Avancement

- [x] Mise en place de la resource (fxmanifest, arborescence)
- [x] Toggle basique : commande `/freecam` + touche `F7`
      (`RegisterKeyMapping`, rebindable dans les paramètres FiveM)
- [x] Activation d'une caméra scriptée (`CreateCamWithParams` +
      `RenderScriptCams`) qui fige et cache le ped joueur
- [x] Déplacement libre de la caméra dans l'espace (stick gauche / ZQSD-WASD)
- [x] Orientation façon FPS (stick droit / souris), avec clamp du pitch
      à ±89° pour éviter le gimbal lock
- [x] Monter/descendre à la verticale : Espace/Ctrl (clavier) et L1/R1
      (manette), indépendant du regard
- [x] Nettoyage automatique si la resource est stoppée pendant que la
      caméra est active (`onResourceStop`)
- [x] Vitesse de déplacement ajustable au clavier (PAGEUP/PAGEDOWN), sans
      limite haute
- [x] Vitesse de rotation ajustable au clavier uniquement (INSERT/DELETE)
- [x] Vitesse de zoom ajustable au clavier uniquement (NUMPAD+/NUMPAD-)
- [x] Réglage du FOV / zoom (L2 dézoomer / R2 zoomer, maintenu, en continu)
- [x] Raccourcis clavier dédiés pour zoom (HOME/END), indépendants de la
      manette et rebindables
- [x] Affichage/masquage du HUD (map, vie, munitions...) : touche `F6`
- [x] Mode debug à l'écran (vitesses, FOV, position, rotation) : touche `F9`
- [x] Vitesse de rotation réduite proportionnellement au zoom (évite une
      rotation incontrôlable en fort zoom)
- [x] Tremblement caméra "à la main" (`ShakeCam` natif, type `HAND_SHAKE`) :
      touche `F10` pour activer/désactiver, intensité ajustable au clavier
      (NUMPAD* / `F11`)
- [x] Pause/relance du temps (monde figé pour caler la caméra) : touche `N`,
      la caméra reste pilotable pendant la pause
- [x] Suivi automatique d'une cible visée (ped/véhicule/objet, façon FPS) :
      bouton `Croix` manette cycle entre 2 modes (orientation seule /
      orientation + position, façon caméra de poursuite) et le désactive,
      infos affichées en mode debug
- [x] Correction du conflit R1 / roue d'armes (`INPUT_SELECT_WEAPON`)
- [x] Streaming/LOD du monde recentré sur la caméra (`SetFocusPosAndVel`) +
      ancre de streaming (ped caché déplacé avec la caméra, offset +10m) :
      évite la disparition des peds/véhicules en s'éloignant du point initial
- [ ] Option pour garder le ped visible mais figé (au choix)
- [ ] Sauvegarde/relecture de trajectoires de caméra (piste d'amélioration,
      pas prioritaire)

## Détails d'implémentation (mouvement/orientation)

- Les contrôles utilisés (`INPUT_LOOK_LR`/`UD` = 1/2, `INPUT_MOVE_LR`/`UD` =
  30/31) sont communs à la manette (stick droit = look, stick gauche =
  move) et au clavier/souris (WASD/ZQSD + souris) : aucun code séparé n'est
  nécessaire par périphérique.
- `RotationToDirection(rotation)` convertit une rotation (pitch/roll/yaw en
  degrés) en vecteur direction normalisé. Utilisé deux fois :
  - avec le pitch réel de la caméra → vecteur "avant" (permet de monter/
    descendre en regardant vers le haut/bas, comme en vol libre) ;
  - avec pitch forcé à 0 et yaw+90° → vecteur "droite" horizontal (le
    strafing reste à plat même si on regarde en l'air).
- Monter/descendre à la verticale : Espace/Ctrl (clavier) ou L1/R1 (manette),
  indépendamment du regard. Le bouton Croix manette (`INPUT_SPRINT`, 21 — `INPUT_JUMP` 22 est Carré sur manette) est
  désormais réservé au cycle de tracking.
- Le vecteur "droite" utilise `yaw - 90°` (et non `+90°`) : avec la
  convention de heading de GTA (0° = nord/+Y, sens antihoraire), c'est ce
  signe qui donne le vrai vecteur "droite" pour le strafe (`+90°` donnait un
  déplacement gauche/droite inversé).
- La rotation (regard) passe par un lissage exponentiel (`LOOK_SMOOTHING`)
  avant d'être appliquée : ça donne une petite inertie/glisse et évite une
  rotation trop raide. Diminuer `LOOK_SMOOTHING` = plus d'inertie, augmenter
  = plus réactif/instantané.
- **Monter/descendre : historique du bug (3 tentatives)**
  1. La version initiale lisait `INPUT_JUMP` (22) / `INPUT_DUCK` (36) pour
     Espace/Ctrl. Sur manette, un bouton inattendu (ex. Carré) semblait
     s'y substituer, symptôme d'une lecture peu fiable.
  2. **Tentative 2 (partiellement erronée)** : on a d'abord accusé Jump/Duck
     d'être "liés aux capacités du ped" et remplacé le clavier par des
     commandes `RegisterKeyMapping` dédiées (`+freecam_moveup` sur `SPACE`,
     etc.), tout en ajoutant L1/R1 sur les IDs `165`/`166` pour la manette.
     Résultat : la hauteur a complètement cessé de fonctionner, au clavier
     ET à la manette.
  3. **Cause n°1 (confirmée)** : `SetPlayerControl(PlayerId(), false, 0)`
     dans `EnableFreeCam` coupait le contrôle joueur de façon globale et
     perturbait la lecture de Jump/Duck selon le contexte. **Fix** : native
     retiré (le ped reste figé + invisible + invincible, donc toujours
     totalement détaché, sans cet effet de bord). Le clavier (Espace/Ctrl)
     est repassé en lecture directe de `INPUT_JUMP`/`INPUT_DUCK` (22/36) au
     lieu de `RegisterKeyMapping` — ces touches ont un contrôle natif par
     défaut, et `RegisterKeyMapping` ne se déclenche pas fiablement dessus
     (contrairement aux touches "libres" comme HOME, INSERT, ADD...). Ça a
     réparé le clavier, mais **pas la manette** (L1/R1 toujours cassés).
  4. **Cause n°2 (la vraie, pour L1/R1)** : les IDs `165`/`166` utilisés
     pour `INPUT_FRONTEND_LB`/`RB` étaient **faux**. Vérifié via une liste
     de contrôles GTA V faisant autorité (repo GitHub
     `Corso-Project/RAGE-MP-Helper`, fichier `keys/controls.ts`) :
     - `165` = `INPUT_SELECT_WEAPON_SPECIAL`
     - `166` = `INPUT_SELECT_CHARACTER_MICHAEL`
     - Les vrais IDs de `INPUT_FRONTEND_LB`/`INPUT_FRONTEND_RB` sont
       **`205`/`206`**.
     **Fix définitif** : remplacé `165`/`166` par `205`/`206` partout
     (`DisableControlAction` + `IsDisabledControlPressed`). Le clavier et la
     manette lisent maintenant `INPUT_JUMP`/`INPUT_DUCK` (22/36) combinés en
     `OR` avec L1/R1 (`205`/`206`), sans passer par `RegisterKeyMapping`
     pour la hauteur.
  - **Leçon retenue** : toujours vérifier un ID de contrôle GTA sur une
    source fiable avant de l'utiliser (la doc officielle FiveM natives ne
    liste pas les ID de contrôles ; utiliser un repo de référence comme
    `RAGE-MP-Helper/keys/controls.ts` ou équivalent).
- **Touche `DIVIDE` non fonctionnelle** : quirk connu de FiveM
  `RegisterKeyMapping` avec le slash du pavé numérique (code étendu mal géré
  par certains claviers/pilotes), contrairement à `MULTIPLY` qui fonctionne
  normalement. Remplacée par `F11` pour `freecam_shakedown`.
- **R1 ouvrait aussi la roue d'armes** : sur manette, R1/RB est bindé sur
  *deux* contrôles GTA différents en même temps : `INPUT_FRONTEND_RB` (206,
  ce qu'on utilisait déjà) **et** `INPUT_SELECT_WEAPON` (37, la roue d'armes
  côté gameplay — équivalent clavier `TAB`). On ne désactivait que 206.
  **Fix** : ajout de `DisableControlAction(0, 37, true)` dans la boucle
  principale, aux côtés des autres contrôles bloqués.
- **Touche `T` en conflit avec le chat FiveM (et piège du remap)** : `T` est
  la touche par défaut pour ouvrir le chat (resource `chat`), qui écoute ce
  raccourci indépendamment de nos propres `RegisterKeyMapping`. On a d'abord
  remplacé par `M`, puis `B`, mais changer uniquement le 4ᵉ argument d'un
  mapping ne suffit pas toujours (FiveM persiste les binds côté client).
  **Décision finale** : suppression du bind clavier tracking par défaut et
  bascule sur **Croix manette** (`INPUT_SPRINT`, 21) pour cycler le suivi en
  freecam, en gardant la commande manuelle `/freecam_cycletrack` en fallback.
  Règle à retenir : pour changer un `RegisterKeyMapping` déjà publié,
  renommer la commande (ou demander aux joueurs de reset leurs touches
  FiveM) — modifier juste l'argument ne suffit pas.
- **Zoom (L2/R2)** : réutilise `INPUT_AIM` (25) / `INPUT_ATTACK` (24), déjà
  désactivés pendant la caméra libre. Lit la valeur analogique de la
  gâchette avec `GetDisabledControlNormal` (0.0 à 1.0 selon la pression) et
  multiplie `ZOOM_SPEED` par cette valeur : zoom progressif sur manette
  (légère pression = zoom lent, pleine pression = zoom rapide). Au clavier
  (`HOME`/`END`, digital), la valeur est forcée à `1.0` (vitesse pleine, pas
  de notion de "pression" possible). Borné entre `FOV_MIN` (téléobjectif) et
  `FOV_MAX` (grand angle). Si le sens zoom in/out ne convient pas à
  l'utilisateur, inverser simplement les deux blocs `if`/`elseif`.
- **Vitesses ajustables au clavier uniquement** (`ChangeMoveSpeed`,
  `ChangeLookSensitivity`, `ChangeZoomSpeed`) : PAGEUP/PAGEDOWN (déplacement,
  sans plafond, juste un plancher `MOVE_SPEED_MIN`), INSERT/DELETE (rotation,
  plancher `LOOK_SENSITIVITY_MIN`), NUMPAD+/NUMPAD- (zoom, plancher
  `ZOOM_SPEED_MIN`). Volontairement pas d'équivalent manette : la manette a
  déjà sa propre sensibilité analogique (stick droit, gâchettes) qui n'a pas
  besoin d'un palier réglable de la même façon.
- **Raccourcis clavier dédiés (indépendants de la manette)** : ces réglages
  de vitesse ainsi que `HOME`/`END` (zoom) sont enregistrés via
  `RegisterCommand`/`RegisterKeyMapping` — un système d'input FiveM
  totalement séparé du tableau de contrôles GTA lu par `IsDisabledControl*`.
  Attention : ceci ne fonctionne bien que sur des touches **sans** contrôle
  natif par défaut (voir le point "historique du bug" ci-dessus) ; pour la
  hauteur (Espace/Ctrl), qui sont des touches déjà liées nativement, on lit
  directement le contrôle GTA plutôt que `RegisterKeyMapping`. Pour le zoom
  (maintenu), on utilise la convention FiveM `+nom`/`-nom` (key down / key
  up) pour détecter l'appui continu, avec deux booléens partagés
  (`keyboardZoomIn`/`keyboardZoomOut`) lus dans la boucle principale.
- **Vitesse de rotation liée au zoom** : `zoomSensitivityFactor = currentFov
  / FOV_MAX` est multiplié à `LOOK_SENSITIVITY` avant application. À FOV
  large (dézoomé), facteur proche de 1 (vitesse normale) ; à FOV faible
  (très zoomé), facteur proche de `FOV_MIN / FOV_MAX` (rotation fortement
  ralentie), ce qui reproduit le comportement d'un vrai objectif optique et
  évite qu'un fort zoom rende la caméra incontrôlable.
- **Tremblement caméra (F10)** : utilise les natives GTA `ShakeCam(cam, type,
  amplitude)` / `StopCamShaking(cam, immediate)` / `SetCamShakeAmplitude`,
  pas de bruit maison — le type `'HAND_SHAKE'` est prévu par le jeu pour
  simuler une caméra tenue à la main. `SHAKE_AMPLITUDE` (0.0 à ~1.0, pas de
  plafond dur) est ajustable au clavier uniquement (`ChangeShakeAmplitude`,
  MULTIPLY augmente / `F11` diminue), y compris quand le tremblement est
  actuellement désactivé (la valeur sera appliquée au prochain `F10`).
  `StopCamShaking` est aussi appelé dans `DisableFreeCam` avant de détruire
  la caméra, par propreté.
- **Pause du temps (N)** : `SetTimeScale(0.0)` fige la simulation du monde
  (peds, véhicules, animations, physique) pour caler la caméra tranquillement,
  `SetTimeScale(1.0)` la relance. Point important : `GetFrameTime()` est
  affecté par `SetTimeScale` (il tomberait à ~0 pendant la pause, rendant la
  caméra elle-même impossible à bouger). La boucle principale calcule donc
  son propre delta de temps via `GetGameTimer()` (timer réel, non affecté)
  au lieu de `GetFrameTime()` : `frameTime = (nowMs - lastFrameMs) / 1000.0`.
  `lastFrameMs` est réinitialisé dans `EnableFreeCam` pour éviter un saut à
  la première frame. Par sécurité, `DisableFreeCam` force `SetTimeScale(1.0)`
  si la pause était active, pour ne jamais laisser le monde figé après la
  sortie du mode caméra libre.
- **Suivi de cible / tracking (Croix manette)** : `GetEntityAtCrosshair` lance un rayon
  depuis la caméra dans sa direction actuelle (`RotationToDirection(camRot)`,
  déjà utilisé pour le déplacement) via
  `StartExpensiveSynchronousShapeTestLosProbe` + `GetShapeTestResult`, ce qui
  donne l'entité (ped/véhicule/objet) au centre de l'écran, comme un
  réticule FPS. Ce raycast est volontairement limité à 10 fois par seconde
  (`AIM_CHECK_INTERVAL_MS`) plutôt que chaque frame : la native est marquée
  "expensive" (bloquante) par Rockstar, inutile de la spammer à 60 FPS pour
  un simple indicateur.
  - `trackingMode` (0/1/2) pilote le comportement : bouton `Croix` cycle
    0 (aucun) → 1 (orientation seule) → 2 (orientation + position) → 0.
    À l'appui initial (0→1), `trackedEntity` prend la valeur de
    `aimedEntity` (la cible visée à cet instant).
  - **Mode 1 (orientation seule)** : le bloc d'orientation de la boucle
    principale bascule entièrement en automatique : au lieu de lire
    souris/stick droit, on calcule le pitch/yaw nécessaire pour regarder
    `GetTrackingTargetCoord(trackedEntity)` (position de l'entité, avec un
    léger décalage vertical pour peds/véhicules afin de viser le buste
    plutôt que les pieds), puis on interpole doucement vers cette
    orientation (`TRACKING_SMOOTHING`, avec gestion du "wrap" d'angle
    ±180° pour ne jamais faire un tour complet inutile). Le déplacement
    (translation) reste entièrement manuel : on peut tourner autour du
    sujet librement pendant qu'il reste cadré, comme un plan
    d'orbite/poursuite classique en machinima.
  - **Mode 2 (orientation + position, "caméra de poursuite")** : en plus de
    l'orientation automatique du mode 1, la caméra se déplace du même
    vecteur que la cible entre deux frames (`followOffset = targetNowCoord -
    trackedEntityLastCoord`, ajouté à `newCoord` en plus du déplacement
    manuel). Concrètement, la caméra "colle" à la cible en gardant la
    distance/l'angle relatif du moment où le mode 2 a été activé, tout en
    restant ajustable manuellement (on peut se rapprocher/écarter, changer
    d'angle en cours de route) — comme une vraie caméra de poursuite qui
    suit un véhicule ou un personnage en mouvement.
    `trackedEntityLastCoord` est réinitialisé (à la position actuelle de la
    cible) à chaque passage en mode 2 pour éviter un saut de caméra au
    premier appui.
  - Si l'entité suivie est détruite/déchargée (`DoesEntityExist` devient
    faux), le suivi se désactive entièrement (retour à `trackingMode = 0`)
    avec un message.
  - En mode debug (`F9`), un petit réticule carré est dessiné au centre de
    l'écran, et une ligne indique le mode de suivi actif (avec le type et la
    distance de la cible), la cible actuellement visée si aucun suivi n'est
    actif, ou "aucune".
- **Streaming/LOD + scope population autour de la caméra** : GTA charge le
  décor (LOD) via le focus de rendu, mais la population/réseau (peds,
  véhicules, entités OneSync) dépend aussi de la position réelle du joueur.
  Donc `SetFocusPosAndVel` seul peut laisser encore des voitures/peds
  disparaître quand la caméra s'éloigne trop du point initial du ped figé.
  **Fix complet** :
  1) `SetFocusPosAndVel(newCoord.x, newCoord.y, newCoord.z, 0, 0, 0)` est
     appelé chaque frame (focus visuel/LOD autour de la caméra) ;
  2) le ped joueur (déjà invisible + figé + invincible) est déplacé chaque
     frame près de la caméra avec un offset vertical (+10m), via
     `SetEntityCoordsNoOffset`, et orienté avec la caméra, pour servir
     d'ancre de streaming/scope population autour de la freecam ;
  3) en sortie de freecam, le ped est restauré à sa position/heading de
     départ, puis `ClearFocus()` rend la priorité de streaming normale au
     joueur.
  Résultat : moins de disparition de voitures/peds en plan éloigné.
- **HUD (F6)** : `DisplayHud`/`DisplayRadar` doivent être rappelés à chaque
  frame pour rester effectifs (sinon le jeu réaffiche le HUD tout seul),
  d'où l'appel dans la boucle principale plutôt qu'au moment du toggle.
  Toujours restaurés à `true` dans `DisableFreeCam` pour ne pas laisser le
  HUD masqué en dehors de la caméra libre.
- **Debug (F9)** : simple affichage à l'écran (`DrawText`) de `MOVE_SPEED`,
  `currentFov`, la position de la caméra et sa rotation (pitch/yaw). Purement
  informatif, aucun état persistant.
- **Screenshot** : fonctionnalité écartée volontairement — Windows dispose
  déjà d'un outil de capture natif (Win+Maj+S, Xbox Game Bar Win+Alt+PrtScn,
  etc.), pas besoin de la réimplémenter dans le mod. Pour rappel si le sujet
  revient : un vrai export d'image nécessiterait la resource externe
  `screenshot-basic` (NUI, pas de native Lua pur pour lire les pixels du
  rendu), ce qui casse l'objectif de garder ce mod simple et sans
  dépendance.

## Prochaines étapes (dans l'ordre)

1. Option pour garder le ped visible mais figé (au choix, ex. commande
   `/freecam nohide`).

## Notes pour reprendre le travail

- Le script part du principe qu'un seul joueur utilise sa propre caméra
  (aucune synchronisation réseau requise). Si un jour on veut un mode
  "réalisateur" partagé (plusieurs personnes voient la même caméra), il
  faudra ajouter une synchronisation via `server` + events, ce qui changera
  l'architecture (actuellement 100% client).
- Toujours tester en jeu avec `/freecam` puis relire ce fichier avant de
  continuer : mettre à jour la case à cocher correspondante dans
  "Avancement" une fois une étape terminée.
