# Spellmate – notes for AI assistants and developers

Turn-based fantasy war game for the browser, born from chess (Godot 4.7, GDScript,
GL Compatibility renderer). Sun Kingdom vs Void Kingdom on a 12x12 battlefield with
terrain. Units move in chess patterns with a max range; attacking starts a battle with a
win chance; miners produce energy for super powers; killing the enemy king wins.
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
  `PieceView` (leaning character), `TerrainView` (terrain tiles), `PieceModelFactory`
  (models from `data/characters.json`), `Style`
  (all colours/materials – use it for every new visual), `CameraRig` (angled perspective
  view like Clash Royale; focus() for power cinematics, orbit_menu() behind the main menu).
- `combat/` – `CombatDirector` runs a battle: FULL = `BattleArena`, a 6-8 s skippable cinematic in
  an arena built from the battle square's terrain, with `BattleHealthBar`s over the fighters
  (power = win chance; blows are scripted so the dice result wins). QUICK = short on-board fight.
- `ai/ai_player.gd` – alpha-beta over legal actions (moves + powers).
- `ui/` – `Hud` (built in code), `UiKit` (cartoon widgets), `Texts` (all Hebrew strings).

## Art assets
- Owner's direction: dark medieval look; cute, funny characters with personality; BOTH kingdoms
  use the same characters in different colours. New character models are pending (owner will
  decide how to make them); until then KayKit Adventurers (CC0) in `assets/characters/kaykit/`.
  Per team and piece: model, visible props, scale, animation names in `data/characters.json`.
  Team colours = recoloured textures made by `tools/recolor_textures.py` (`*_light.png`, `*_shadow.png`).
- Scenery: KayKit Medieval Hexagon (CC0) in `assets/environment/kaykit/`, placed by `presentation/scenery.gd`.
- Only GitHub and package registries are reachable from cloud sessions (itch.io etc. are blocked).
- Still missing: a dragon for the knight piece (currently a crossbow ranger).
- The board never rotates; whose turn it is shows through lighting (`Style.MOOD`), the frame strip and the HUD.
- UI style: forged iron + glowing runes (`ui/rune_button.gd`, `ui/metal_decor.gd`); main menu is
  a live scene (camera orbits the field) with logo on top and options at the bottom.
- Power cards: `ui/power_card.gd` (vector-drawn art per power, themes in `Style.POWER_THEME`).
- Click picking uses the characters' screen shape (`BoardView.square_at_screen`), since they lean up the screen.

## Rules decisions
- Board size, terrain map and starting army: `data/map.json`. Unit types (move pattern, range,
  battle bonuses, trait, AI value): `data/units.json`. Balance (energy, battle numbers): `data/balance.json`.
- A turn = one action: move (moving onto an enemy = battle) or use a power. No check rules.
- Terrain: water blocks (bridges ok), forest stops sliding units and gives +defense,
  hill gives +attack, castle gives its owner +defense, mines double a miner's income.
- Battle (`core/combat.gd`): attacker chance = base 60 + atk - def + terrain + effects, clamped
  10..95. Loser dies; a bishop (phase trait) that loses its attack survives and stays home.
  Dice live in `GameState.rng_state` (deterministic); `Rules.Outcome` forces results for the AI.
- Energy: each miner +1 per own turn start, +1 more on a mine. Max 15. Powers cost energy.
- Powers hit areas: decree shields all king's neighbours, frost storm freezes target + adjacent
  enemies, fire burns a plus shape, giant shove pushes 2 and stuns, shield wall braces adjacent
  soldiers, swap shields the ally, double shift gives 3 energy. Each cast is a short camera cinematic.
- Win: kill the enemy king. Draw at `turn_limit` plies.
- AI (`ai/ai_player.gd`): expectimax over battle outcomes.

## Commands
```bash
godot --headless --import                            # first time / after adding files
godot --headless --script res://tests/run_tests.gd   # all tests (rules + powers)
godot --headless --script res://tools/simulate.gd    # computer vs computer battles
godot --headless --script res://tools/autoplay.gd -- aiai   # AI vs AI through the real UI
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/screenshot.gd -- out.png "e2e4,e7e5" nomenu
```
CI (`.github/workflows/web.yml`) runs the tests and publishes the web build to GitHub Pages.

## Conventions
- Typed GDScript, tabs, `class_name` for shared classes.
- Add a test in `tests/test_*.gd` (extends `TestCase`) for every new rule or power.
- Never let presentation code mutate `GameState`.
