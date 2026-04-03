# Colmado Dash — Art Assets Needed

This folder is for game assets. The game is built with procedural ColorRect nodes,
so it runs without any art files. When you're ready to upgrade:

## Sprites Needed

### Player Vehicles
- `player_bicycle.png` — Top-down bicycle sprite (32x48px)
- `player_moped.png`   — Top-down moped sprite (40x56px)
- `player_car.png`     — Top-down car sprite (48x64px)

### Enemies
- `enemy_saboteur.png` — Red-shirted saboteur character (24x32px)
- `enemy_car.png`      — Road car (40x60px)
- `enemy_police.png`   — Police car with lights (40x60px)

### Weapons / Projectiles
- `weapon_platano.png` — Yellow banana, tileable (16x8px)
- `weapon_huevo.png`   — Egg sprite (12x12px)
- `weapon_salami.png`  — Salami log (16x16px)
- `weapon_fart.png`    — Green cloud (64x64px, semi-transparent)

### Environment
- `building_colmado.png`     — Colmado storefront (80x120px)
- `building_variedades.png`  — Variedades store (80x120px)
- `road_tile.png`            — Road segment tile (128x128px)
- `sidewalk_tile.png`        — Sidewalk tile (64x128px)

### HUD / UI
- `heart_full.png`   — Heart icon (24x24px)
- `heart_empty.png`  — Empty heart icon (24x24px)
- `arrow_ui.png`     — Direction arrow (32x32px)

### Fonts
- `PressStart2P.ttf` — Pixel font (free on Google Fonts)
  Download: https://fonts.google.com/specimen/Press+Start+2P

## PS1 Visual Style Guidelines

When creating sprites:
1. **Max 32 colors per sprite** — Use indexed/palette mode
2. **Pixel art** — No anti-aliasing, sharp edges only
3. **Warm tones** — DR aesthetic: warm oranges, yellows, greens
4. **Chunky shapes** — Bold silhouettes, no thin details
5. **Dither shading** — Use 2x2 or 4x4 dithering for gradients

## Sound Effects Needed (future)
- `sfx_pickup.wav`   — Package pickup sound
- `sfx_deliver.wav`  — Delivery success jingle
- `sfx_hit.wav`      — Player gets hit
- `sfx_throw.wav`    — Weapon throw
- `sfx_die.wav`      — Enemy death
- `music_game.ogg`   — Merengue/dembow loop (120-130 BPM)
- `music_menu.ogg`   — Menu theme, chill DR vibe

## Music Style
Think: fast-paced merengue/dembow with 8-bit/PS1 chip elements.
Artists for reference: Los Hermanos Rosario, Kinito Mendez (for the vibe)
but in chiptuney PS1 style.
