# Spellmate – notes for AI assistants and developers

Fantasy strategy for the browser in SIMULTANEOUS TURNS (Godot 4.7, GDScript, GL Compatibility).
Each turn: PLAN (time stands still; the player picks heroes with a drag box / click, sends them
with right click, plans cards and powers), then "בצע!" - the computer plans at the same moment
without seeing the player's plan, and both sides act together for 5 s (fast / skip buttons,
a short slow-motion cinematic on big moments), then a turn summary. Under the hood the battle
engine is real-time; turns are made by BattleScreen stepping it 5 s at a time.
Sun Kingdom (team 0, bottom) vs Void Kingdom (team 1, top). Each side has a walled palace
(gate + 2 towers) with its king inside. Deck of 8 cards (heroes + spells), hero powers.
Energy only from miners at crystal mines. Kill the enemy king to win.
Between battles: a 3D base village (buildings unlock heroes), hero levels, deck, chests, trophies, arenas.
Design doc (Hebrew GDD): https://claude.ai/artifact/HXu7MHfE4DuFUTcmkgh3To
The owner is not a developer: explain changes in plain Hebrew, keep UI text Hebrew.
The owner wants many questions (in Hebrew, with many options) before big changes.

## Architecture (keep these boundaries)
- `core/battle/` – pure real-time rules, no Nodes. `MapGen` (3 sizes, point-symmetric maps),
  `BUnit` (hero, king, gate, tower, magic wall), `Battle` (step(dt) in 0.05 s ticks; orders:
  order_move / order_attack / play_card / cast_ability / upgrade_palace; `events` list for the
  screen; AStarGrid2D per team: enemy gates/walls block), `BattleAI` (plan_turn() once per
  turn; think() for real-time use), `BattleData`.
- `core/profile.gd` – progress between battles (gold, trophies, buildings, hero levels/xp, deck,
  chests), saved to user://profile.json. `core/chess.gd` = Terrain enum + team constants only.
- `game/app.gd` – main scene (`scenes/app.tscn`): world light, camera, switches screens.
  `BattleScreen` (turn phases PLAN/ACTION/SCENE, the plan list of cards/powers with reserved
  energy, input -> orders, sounds, voices), `BaseScreen` (village + panels + hero book),
  `TutorialGuide` (first battle, AI level 0 only defends).
- `presentation/` – `BattleView` (only reads Battle; units, structures, shots, spell fx, fog),
  `UnitView`, `TerrainView` (MultiMesh tiles), `PieceModelFactory` (models from
  `data/characters.json`: model, show, attach props to bones, tint, shape extras), `Portraits`
  (renders hero pictures for cards), `Style` (all colours), `CameraRig`, `Effects`.
- `ui/` – `BattleHud` (turn strip, wax seal "בצע!", hero info page, turn summary, cinema bars,
  help page), `BattleCard`, `ResultsPanel`, `HeroTexts` (all Hebrew hero/spell/power text, funny
  lines, HOW_TO_PLAY, TIPS for the hero book).
- UI STYLE = ANCIENT SPELLBOOK (owner's choice): `UiKit` (parchment panels with burnt edges,
  ink text, gold-leaf titles), `BookButton` (stitched leather / paper / red wax seal),
  `BookDecor` (gold corner flourishes). Fonts: titles Noto Rashi Hebrew, text David Libre.
  Textures from `tools/make_ui_textures.py` (`assets/ui/`). Short labels do not wrap; long
  texts need autowrap + a width. The web build has no system fonts: symbols/emoji come from
  NotoSansSymbols2 + NotoEmoji set as fallbacks in `UiKit.setup_fonts()` - keep it that way.
- `audio/` – `Sfx.play(name)`, `Music.play("base"|"plan"|"battle")` (cross-fades, tracks keep
  running), `Voice.babble(hero)`. Effects/voices: `tools/make_sounds.py`; knightly music
  (drums, brass, strings, lute, harp) + fanfare/lose: `tools/make_music.py`. No downloads.

## Data
- `data/heroes.json` (hp, dmg, rate, range, speed, cost, role, ability), `data/spells.json`,
  `data/battle.json` (energy, structures, palace upgrades, map sizes + time limits),
  `data/meta.json` (buildings, unlocks, rewards, chests, arenas), `data/characters.json` (looks).
- Ability/spell types are generic: area_damage, area_heal, area_buff, dash, wall; effects
  freeze, stun, slow, burn, shield, rage. A new power = data only, plus Hebrew text in HeroTexts.

## Rules decisions
- King is untargetable until his gate or a tower falls. A fallen tower leaves a breach.
- Hero card: once per life; after death it returns after 8 + 2*cost s. Spells have a cooldown.
  The screen shows waits in turns (seconds / 5).
- Heroes without orders fight nearby enemies on their own (owner's choice); move orders persist.
- Heroes: idle ones fight enemies within range+2.5; on a move order they only hit what is in
  reach; healers heal; miners walk to the nearest free mine. If a side has no miner, the palace
  gives 1 energy / 5 s (so nobody gets stuck).
- Time limit per map size; then the side with more palace health wins.
- Levels: +10% hp/dmg per level. Palace building level: +8% palace/king hp; mine level: +1 start energy.
- AI ignores the fog (simplification).

## Art assets
- Dark medieval, cute funny characters, both kingdoms share characters in different colours.
  Every hero type must look different (owner request): KayKit Adventurers + Skeletons
  (`assets/characters/kaykit/`), weapons in `props/`, plus shape accessories in PieceModelFactory.
  Team colours = recoloured textures by `tools/recolor_textures.py`.
- Scenery and village buildings: KayKit Medieval Hexagon (`assets/environment/kaykit/`), chest: KayKit Dungeon.
- Only GitHub and package registries are reachable from cloud sessions (itch.io etc. are blocked).

## Commands
```bash
godot --headless --import                                   # first time / after adding files
godot --headless --script res://tests/run_tests.gd          # all tests
godot --headless --script res://tools/battle_sim.gd -- small 6   # computer vs computer battles
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/flow_check.gd -- /tmp/shots   # plays the whole game
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/app_shot.gd -- out.png 6 --battle small select
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/app_shot.gd -- out.png 5 --base rich panel=book:dragon
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/hero_lineup.gd -- out.png both
python3 tools/make_sounds.py && python3 tools/make_music.py   # regenerate sounds and music
python3 tools/make_ui_textures.py                            # parchment / leather / wax textures
```
A GDScript parse error makes `godot --script` hang: redirect output to a file and use `timeout`.
CI (`.github/workflows/web.yml`) runs the tests and publishes the web build to GitHub Pages.

## Conventions
- Typed GDScript, tabs, `class_name` for shared classes.
- Add a test in `tests/test_*.gd` (extends `TestCase`) for every new rule.
- Never let presentation code change `Battle` except through its order functions.
