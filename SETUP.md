# Colmado Dash — Setup & Export Guide

## Prerequisites

- **Godot 4.3+** (download at https://godotengine.org/download)
- **Xcode 15+** (for iOS export, macOS only)
- **Apple Developer Account** (for device deployment)

---

## Step 1: Open the Project

1. Launch **Godot 4**
2. Click **Import** on the Project Manager
3. Navigate to this folder (`colmado-godot/`)
4. Click **project.godot** → **Open**
5. The project will import and open in the editor

---

## Step 2: Run in Editor (Desktop Test)

1. Press **F5** or click the ▶ Play button
2. The game starts at the Menu scene
3. Keyboard controls:
   - **WASD / Arrow Keys** — Move player
   - **Spacebar** — Fire weapon
4. Touch/tap controls work in the iOS simulator

---

## Step 3: Export to iOS

### 3a. Install Godot iOS Export Templates

1. In Godot: **Editor → Export Template Manager**
2. Click **Download and Install** for version 4.3
3. Wait for download to complete

### 3b. Configure iOS Export

1. Go to **Project → Export**
2. Click **Add** → select **iOS**
3. Fill in:
   - **Bundle Identifier**: `com.pjavier.colmadodash`
   - **App Name**: `Colmado Dash`
   - **Team ID**: Your Apple Developer Team ID
4. Under **Signing**:
   - Select your provisioning profile
   - Select your signing certificate

### 3c. Export the Xcode Project

1. Click **Export Project**
2. Choose format: **Xcode Project** (NOT .ipa for device testing)
3. Save to a location like `~/Desktop/ColmadoDash-iOS/`
4. Uncheck "Debug" if making release build

### 3d. Build & Deploy with Xcode

1. Open the exported `.xcodeproj` in **Xcode**
2. Select your **device** or **simulator** from the scheme dropdown
3. Press **⌘R** to build and run
4. For device: Connect iPhone via USB, trust the computer
5. For simulator: Any iOS 16+ simulator works

---

## Step 4: TestFlight Distribution

1. In Xcode: **Product → Archive**
2. In the Organizer: **Distribute App → TestFlight**
3. Follow the upload wizard
4. In App Store Connect: Add testers via email

---

## Project Structure

```
colmado-godot/
├── project.godot          ← Godot project config
├── export_presets.cfg     ← iOS export settings
├── icon.svg               ← App icon
├── scenes/
│   ├── Main.tscn          ← Entry point (auto-loads menu)
│   ├── MenuScene.tscn     ← Title screen
│   ├── MissionSelect.tscn ← Choose your mission
│   ├── GameScene.tscn     ← Main gameplay
│   ├── Garage.tscn        ← Buy/select vehicles
│   └── Shop.tscn          ← Buy weapons & ammo
├── scripts/
│   ├── GameState.gd       ← Autoload singleton (save/load)
│   ├── Main.gd            ← Entry scene
│   ├── MenuScene.gd       ← Menu logic
│   ├── MissionSelect.gd   ← Mission selection
│   ├── GameScene.gd       ← Core gameplay loop
│   ├── Player.gd          ← Player controller
│   ├── Enemy.gd           ← Enemy AI (3 types)
│   ├── Weapon.gd          ← Weapon projectiles
│   ├── HUD.gd             ← UI + virtual joystick
│   ├── Garage.gd          ← Garage screen logic
│   └── Shop.gd            ← Shop screen logic
└── assets/
    └── README.md          ← Art assets guide
```

---

## Gameplay Guide

### Objective
Deliver packages from colmados (pickup markers 📦) to destinations (🏠).
Complete all deliveries before time runs out!

### Controls (Mobile)
- **Left side of screen** — Virtual joystick (move)
- **Right side of screen (FUEGO button)** — Throw weapon
- **ARMA button** — Cycle through weapons

### Weapons
| Weapon | Effect |
|--------|--------|
| 🍌 Platano | Boomerang — goes and returns |
| 🥚 Huevo | Straight shot, leaves slime |
| 🥩 Salami | Arc throw, big explosion |
| 💨 Fart Cloud | Area slow — lentifica enemies |

### Vehicles
| Vehicle | Speed | Cost |
|---------|-------|------|
| Bicicleta | Slow | Free |
| Motora | Medium | $200 |
| Carro | Fast | $600 |

### Enemies
- 🔴 **Saboteur** — Runs straight at you
- 🟡 **Car** — Drives across the road
- 🔵 **Police** — Chases you if score > 500

### Scoring
- +100 pts per delivery
- Streak bonus: each consecutive delivery adds +10 pts
- Lose streak when hit

---

## Tips for Development

1. **Add pixel font**: Download `PressStart2P.ttf` from Google Fonts and import it into the project for authentic PS1 look

2. **Add scanline shader**: Create a `CanvasLayer` with a shader:
   ```glsl
   void fragment() {
     COLOR = texture(TEXTURE, UV);
     float scanline = sin(UV.y * 200.0) * 0.03;
     COLOR.rgb -= scanline;
   }
   ```

3. **Add art**: See `assets/README.md` for full list of sprites needed

4. **Sound**: Add `.ogg` music files to `assets/` and play via `AudioStreamPlayer`

---

## GitHub Repository
https://github.com/Pjavier23/colmado-godot

---

*Built with Godot 4.3 — ¡Dale que tú puedes!*
