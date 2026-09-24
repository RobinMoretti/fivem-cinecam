# 🎥 playable_camera_mod

**Caméra libre pour faire du machinima dans GTA V / FiveM.**

Détachez la caméra de votre personnage, déplacez-vous librement dans le monde,
zoomez, figez le temps et suivez une cible, le tout directement en jeu, à la
manière du Rockstar Editor.

Il s'agit d'un **mod FiveM** (une *resource*) : il ne s'installe pas dans GTA V
solo, mais sur un serveur FiveM, et fonctionne pour les joueurs connectés à ce
serveur (voir [Installation](#installation)).

![FiveM](https://img.shields.io/badge/FiveM-cerulean-orange)
![Lua](https://img.shields.io/badge/Lua-5.4-blue)
![Client only](https://img.shields.io/badge/resource-client--only-lightgrey)
![Version](https://img.shields.io/badge/version-0.1.0-green)
![License: MIT](https://img.shields.io/badge/license-MIT-yellow)

<!-- Ajoutez ici une capture d'écran ou un GIF de démo :
![Démo](docs/demo.gif)
-->

> [!NOTE]
> Projet en cours de développement. Le suivi détaillé et les notes techniques
> se trouvent dans [AGENT.md](./AGENT.md).

---

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Contrôles](#contrôles)
- [Suivi de cible](#suivi-de-cible)
- [Configuration](#configuration)
- [Commandes](#commandes)
- [Limitations connues](#limitations-connues)
- [Roadmap](#roadmap)
- [Contribuer](#contribuer)
- [Licence](#licence)

---

## Fonctionnalités

- **Caméra libre** détachée du personnage (vol libre, montée/descente verticale)
- **Clavier/souris et manette** pris en charge nativement
- **Zoom progressif** (FOV) : la vitesse du zoom suit la pression sur les gâchettes
- **Rotation adaptée au zoom** : la caméra ralentit en gros plan, comme un vrai objectif
- **Vitesses réglables** (déplacement, rotation, zoom), sans plafond pour le déplacement
- **Tremblement « caméra à l'épaule »** (effet natif `HAND_SHAKE`), intensité réglable
- **Pause du temps** : le monde se fige, la caméra reste pilotable
- **Suivi de cible** : orientation automatique ou caméra de poursuite sur un ped, un véhicule ou un objet
- **Masquage du HUD** pour des plans propres
- **Mode debug** : vitesse, FOV, position, rotation et cible visée
- **Streaming du monde recentré sur la caméra** : décor, peds et véhicules restent chargés même loin du point de départ
- **Touches clavier rebindables** dans les paramètres FiveM
- **Aucune dépendance**, 100 % côté client

## Installation

Le mod s'installe côté serveur, comme n'importe quelle resource FiveM : les
joueurs n'ont rien à installer, FiveM leur envoie automatiquement le script à
la connexion.

1. Téléchargez ou clonez ce dépôt dans le dossier `resources` de votre serveur FiveM :
   ```bash
   cd resources
   git clone <url-du-depot> playable_camera_mod
   ```
   Si vous téléchargez le ZIP, décompressez-le et renommez le dossier en
   `playable_camera_mod` (il doit contenir directement `fxmanifest.lua`).
2. Ajoutez la ligne suivante dans votre `server.cfg` :
   ```cfg
   ensure playable_camera_mod
   ```
3. Démarrez ou redémarrez le serveur (ou tapez `ensure playable_camera_mod` dans la console serveur / txAdmin).

> [!TIP]
> Le nom utilisé dans `ensure` doit correspondre exactement au nom du dossier de la resource.

## Utilisation

Appuyez sur **`F7`** (ou tapez `/freecam` dans le chat ou la console `F8`) pour
activer ou désactiver la caméra libre.

Pendant que la caméra est active, votre personnage est figé, invisible et
invincible. À la désactivation, il revient à son point de départ et tout est
restauré (HUD, temps, streaming).

## Contrôles

### Déplacement et cadrage

| Action | Clavier / souris | Manette |
|---|---|---|
| Activer / désactiver la caméra | `F7` | — |
| Se déplacer | `ZQSD` / `WASD` | Stick gauche |
| Orienter la caméra | Souris | Stick droit |
| Monter | `Espace` | `R1` / `RB` |
| Descendre | `Ctrl` | `L1` / `LB` |
| Zoomer (FOV −) | `Début` (`HOME`) | `R2` / `RT` (progressif) |
| Dézoomer (FOV +) | `Fin` (`END`) | `L2` / `LT` (progressif) |

### Réglages de vitesse (clavier uniquement)

| Action | Diminuer | Augmenter |
|---|---|---|
| Vitesse de déplacement | `Page ↓` | `Page ↑` |
| Vitesse de rotation | `Suppr` (`DELETE`) | `Inser` (`INSERT`) |
| Vitesse de zoom | `Pavé num. −` | `Pavé num. +` |
| Intensité du tremblement | `F11` | `Pavé num. *` |

La manette conserve sa sensibilité analogique naturelle (sticks et gâchettes) :
ces réglages ne concernent que le clavier.

### Outils

| Action | Clavier | Manette |
|---|---|---|
| Afficher / masquer le HUD | `F6` | — |
| Afficher / masquer le debug | `F9` | — |
| Activer / désactiver le tremblement | `F10` | — |
| Pause / reprise du temps | `N` | — |
| Cycler le suivi de cible | — | `Croix` / `A` |

Toutes les touches clavier sont modifiables dans
**Paramètres › Touches › FiveM**, sans impact sur la manette.

## Suivi de cible

Visez un personnage, un véhicule ou un objet au centre de l'écran, puis
appuyez sur **`Croix`** (manette) pour passer d'un mode à l'autre :

| Mode | Comportement |
|---|---|
| **0 — Aucun** | Contrôle manuel classique (par défaut) |
| **1 — Orientation** | La caméra reste braquée sur la cible, vous restez libre de vous déplacer autour (plan en orbite) |
| **2 — Poursuite** | La caméra suit aussi les déplacements de la cible en gardant la même distance et le même angle, tout en restant ajustable |

Un quatrième appui revient au mode 0. Si la cible disparaît, le suivi se
désactive automatiquement. En mode debug (`F9`), un réticule s'affiche avec le
nom, la distance et le mode de la cible.

## Configuration

Les valeurs par défaut sont regroupées en haut de
[`client/camera.lua`](./client/camera.lua) :

| Variable | Défaut | Description |
|---|---|---|
| `MOVE_SPEED` | `3.0` | Vitesse de déplacement (unités/s) |
| `LOOK_SENSITIVITY` | `200.0` | Vitesse de rotation (°/s) |
| `LOOK_SMOOTHING` | `8.0` | Inertie du regard (plus petit = plus fluide) |
| `FOV_DEFAULT` | `50.0` | Champ de vision au lancement |
| `FOV_MIN` / `FOV_MAX` | `10.0` / `90.0` | Limites du zoom |
| `ZOOM_SPEED` | `30.0` | Vitesse du zoom (°/s) |
| `SHAKE_AMPLITUDE` | `0.2` | Intensité du tremblement (0.0 à 1.0) |
| `TRACKING_MAX_DISTANCE` | `100.0` | Portée de visée pour le suivi (m) |
| `TRACKING_SMOOTHING` | `4.0` | Douceur du suivi (plus petit = plus cinématique) |
| `STREAM_ANCHOR_TO_CAMERA` | `true` | Garde le monde chargé autour de la caméra |
| `STREAM_ANCHOR_Z_OFFSET` | `10.0` | Hauteur de l'ancre de streaming au-dessus de la caméra (m) |

## Commandes

| Commande | Effet |
|---|---|
| `/freecam` | Active / désactive la caméra libre |
| `/freecam_togglepause` | Met en pause / relance le temps |
| `/freecam_cycletrack` | Passe au mode de suivi suivant (alternative clavier à `Croix`) |

Des logs de diagnostic préfixés `[camera_player_mod]` sont affichés dans la
console `F8`.

## Limitations connues

- La caméra est **locale** : les autres joueurs ne voient pas votre point de vue.
- Le suivi de cible n'a pas de touche clavier par défaut (utilisez `/freecam_cycletrack`
  ou créez un bind via `bind keyboard <touche> freecam_cycletrack` dans la console F8).
- Pas d'outil de capture intégré : utilisez `Win + Maj + S` ou la Xbox Game Bar
  (`Win + Alt + Impr. écran`), ou un logiciel d'enregistrement comme OBS.

## Roadmap

- [x] Caméra libre clavier / manette
- [x] Zoom, vitesses réglables, tremblement
- [x] Pause du temps
- [x] Suivi de cible (orientation / poursuite)
- [x] Streaming du monde autour de la caméra
- [ ] Option pour garder le personnage visible mais figé
- [ ] Enregistrement et relecture de trajectoires de caméra

## Contribuer

Les issues et pull requests sont les bienvenues. Avant de proposer une
modification, jetez un œil à [AGENT.md](./AGENT.md), qui documente les choix
techniques et les pièges déjà rencontrés (IDs de contrôles GTA, conflits de
touches, etc.).

Si vous ajoutez un raccourci, pensez à mettre à jour les tableaux de ce README.

## Crédits

- Documentation des natives : [docs.fivem.net/natives](https://docs.fivem.net/natives/)
- Développé par Robin Moretti

## Licence

Distribué sous licence [MIT](./LICENSE).
