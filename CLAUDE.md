# Spellmate – notes for AI assistants and developers

Fantasy chess for the browser (Godot 4.7, GDScript, GL Compatibility renderer).
Every piece moves like normal chess and has one super power paid for with energy.
Design doc (Hebrew GDD): https://claude.ai/artifact/HXu7MHfE4DuFUTcmkgh3To
The owner is not a developer: explain changes in plain Hebrew, keep UI text Hebrew.

## Architecture (keep these boundaries)
- `core/` – pure rules engine, no Nodes, no graphics. `GameState` (data), `MoveGen`,
  `Rules` (legal actions, apply_action, game_result), `GameAction` (move or ability).
  Every state change goes through `Rules.apply_action()`, which returns event dicts.
- `core/abilities/` – one script per power, extends `Ability`, registered in
  `AbilityRegistry`. Numbers live in `data/balance.json` (cost, cooldown in own turns,
  duration in plies). Rules handles energy, cooldown, frozen pieces and king safety.
- `game/game_controller.gd` – owns the match, undo stack, AI turns; emits signals.
- `game/main.gd` – builds the scene and turns clicks into actions.
- `presentation/` – `BoardView` (only reads state; `play_events()` animates then `sync()`),
  `PieceView` (leaning character), `PieceModelFactory` (placeholder models; a real
  `assets/characters/<kind>.glb` replaces a placeholder automatically), `Style`
  (all colours/materials – use it for every new visual), `CameraRig` (orthographic,
  straight down, never angled).
- `combat/combat_director.gd` – capture battle; currently a quick on-board effect.
  Phase 4 replaces `play_capture()` with a cinematic arena scene.
- `ai/ai_player.gd` – alpha-beta over legal actions (moves + powers).
- `ui/` – `Hud` (built in code), `UiKit` (cartoon widgets), `Texts` (all Hebrew strings).

## Art assets
- Characters: Light team = KayKit Adventurers (`assets/characters/kaykit/`), Shadow team = KayKit
  Skeletons (`assets/characters/skeletons/`), both CC0. Per team and piece: model, visible props,
  attached weapons, scale and animation names in `data/characters.json`.
  Team colours = recoloured textures made by `tools/recolor_textures.py` (`*_light.png`, `*_shadow.png`).
- Scenery: KayKit Medieval Hexagon (CC0) in `assets/environment/kaykit/`, placed by `presentation/scenery.gd`.
- Only GitHub and package registries are reachable from cloud sessions (itch.io etc. are blocked).
- Still missing: a dragon for the knight piece (currently a crossbow ranger).
- The board never rotates; whose turn it is shows through lighting (`Style.MOOD`), the frame strip and the HUD.
- Power cards: `ui/power_card.gd` (vector-drawn art per power, themes in `Style.POWER_THEME`).
- Click picking uses the characters' screen shape (`BoardView.square_at_screen`), since they lean up the screen.

## Rules decisions
- Using a power replaces the move. Energy: +1 at the start of each own turn, +1 per capture, max 10.
- A power may never leave the own king in check and never affects a king.
- No powers while in check: check must be answered with a normal chess move, so mate works as in chess.
- Lava blocks landing and sliding (also blocks check lines); knights jump over it.
- Frozen pieces cannot move/use powers but still give check.
- Effects store an absolute expiry ply (`state.ply + duration`).

## Commands
```bash
godot --headless --import                            # first time / after adding files
godot --headless --script res://tests/run_tests.gd   # all tests (perft + powers)
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/screenshot.gd -- out.png "e2e4,e7e5" nomenu
```
CI (`.github/workflows/web.yml`) runs the tests and publishes the web build to GitHub Pages.

## Conventions
- Typed GDScript, tabs, `class_name` for shared classes.
- Add a test in `tests/test_*.gd` (extends `TestCase`) for every new rule or power.
- Never let presentation code mutate `GameState`.
