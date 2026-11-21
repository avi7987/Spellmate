# Spellmate – notes for AI assistants and developers

Fantasy strategy for the browser in SIMULTANEOUS TURNS (Godot 4.7, GDScript, GL Compatibility).
Each turn: PLAN (time stands still; CHESS-LIKE: the player left-clicks a hero, the squares it can
reach this turn light up gold (Battle.reach_cells, `moves` in heroes.json), left-clicks a lit
square to walk or a red enemy to attack; right click cancels; plans cards and powers), then "בצע!" - the computer plans at the same moment
without seeing the player's plan, and both sides act together for 5 s (fast / skip buttons,
a short slow-motion cinematic on big moments), then a turn summary. Under the hood the battle
engine is real-time; turns are made by BattleScreen stepping it 5 s at a time.
Sun Kingdom (team 0, bottom) vs Void Kingdom (team 1, top); neutral monsters are team 2.
Each side has a walled palace (a gate, NO towers - owner: "not Clash Royale") with its king
inside. The king can NEVER be hurt; you win by the GAME MODE (Battle.mode, picked in the world
screen): mate (classic "מט קסום": break the gate, threaten the king's square and every square
around him at a turn's end), crown (steal the enemy crown from his throne and carry it home),
throne (a hero on the enemy throne for 3 turns), runes (bring 3 runes from the field to your
king; kill a carrier and the rune drops). Every hero walks at most its `moves` squares per
turn (budget, reset each turn; +1 for the favoured sky / rage, -1 slow / crown). Deck of 8 cards
(heroes + spells); a hero card can be played again and again (1 turn recharge, energy is the
limit, max 15 heroes on the field). Hero powers. Energy from miners at crystal mines (plus the
magic well, treasure chests and monster rewards). Win by the game mode.
WORLDS (biomes, `data/biomes.json`), chosen before a battle: meadow, swamp (mud slows), fire
(lava burns, lava river), ice (slides fast), desert (deep sand), candy (sugar rage), mushrooms
(spores heal), ghost castle (ghost mist = half damage). Every map: special ground, small lakes, shrines (healing spring, power stone,
magic well), treasure chest pairs every 25 s, two monster camps in the middle.
When a hero defeats a hero, an ARENA scene (`combat/battle_arena.gd`, built from the world and
square where it happened) plays once per turn (setting: always / important / never).
Daily quests in the village; the enemy king taunts the player.
SIGNATURE MECHANIC (owner asked for something unique): DAY AND NIGHT. A cycle of 6 turns
(day, day, eclipse, night, night, eclipse - an eclipse before both day and night keeps it fair;
random start per battle, all starts equally likely). Day = the Sun (player) gets +30%
damage and +15% speed, night = the Void does; the ECLIPSE recharges every power at once. The HUD
shows the next 6 turns. Every hero fights differently (`trait` in heroes.json, BUnit.style()):
pack (soldier), kite (archer), taunt (shield), momentum (knight), stealth (assassin), chain
(queen), knockback (giant), setup (ballista), breath (dragon), scorch (fire mage), roots (druid),
song (bard: friends nearby attack 25% faster), raise (necromancer: a fallen enemy nearby rises as
a skeleton soldier for 15 s), stone (golem: half damage from ranged). Every hero has
TWO powers (`abilities`); the player picks one per hero in the heroes screen (settings.powers ->
Battle.loadout). Each arena has a RIVAL KING (meta.json arenas: rival style swarm / magic /
fortress / siege / all -> BattleAI.style, enemy deck, taunts). While planning, arrows show where
every hero is going and a ring shows how far a chosen hero walks in one turn.
Between battles: a 3D base village (buildings unlock heroes), hero levels, deck, chests, trophies, arenas.
Design doc (Hebrew GDD): https://claude.ai/artifact/HXu7MHfE4DuFUTcmkgh3To
The owner is not a developer: explain changes in plain Hebrew, keep UI text Hebrew.
The owner wants many questions (in Hebrew, with many options) before big changes.

## Architecture (keep these boundaries)
- `core/battle/` – pure real-time rules, no Nodes. `MapGen` (3 sizes, point-symmetric maps),
  `BUnit` (hero, king, gate, magic wall), `Battle` (step(dt) in 0.05 s ticks; orders:
  order_move / order_attack / play_card / cast_ability / upgrade_palace; `events` list for the
  screen; AStarGrid2D per team: enemy gates/walls block), `BattleAI` (plan_turn() once per
  turn; think() for real-time use), `BattleData`.
- `core/profile.gd` – progress between battles (gold, trophies, buildings, hero levels/xp, deck,
  chests, daily quests, settings: world, map size, arena scenes), saved to user://profile.json. `core/chess.gd` = Terrain enum + team constants only.
- `game/app.gd` – main scene (`scenes/app.tscn`): world light, camera, switches screens.
  `BattleScreen` (turn phases PLAN/ACTION/SCENE, the plan list of cards/powers with reserved
  energy, input -> orders, sounds, voices), `BaseScreen` (village + panels + hero book),
  `TutorialGuide` (first battle, AI level 0 only defends).
- `combat/` – `BattleArena` (duel scene far below the map, own camera, health bars
  `BattleHealthBar`, set built from the world + terrain of the fight).
- `presentation/` – `BattleView` (only reads Battle; units, structures, shrines, treasure,
  shots, spell fx, fog),
  `UnitView`, `TerrainView` (MultiMesh tiles in the world's colours, world props: trees, dead
  trees, fire rocks, snowy pines, cacti, lollipops, glowing mushrooms), `PieceModelFactory` (models from
  `data/characters.json`: model, show, attach props to bones, tint, shape extras; shape-built
  dragon, ballista and the 7 world monsters), `Portraits`
  (renders hero pictures for cards), `Style` (all colours), `CameraRig`, `Effects`.
- CARDS: `BattleCard` = SHINY RARE CARDS: `rarity` in heroes/spells.json (common / rare / epic /
  legendary), holographic band, sparkles, rainbow on legendary, crystal cost, grows on hover.
- `ui/` – `BattleHud` (turn strip, wax seal "בצע!", hero info page, turn summary, cinema bars,
  help page), `BattleCard`, `ResultsPanel`, `HeroTexts` (all Hebrew hero/spell/power text, funny
  lines, HOW_TO_PLAY, TIPS for the hero book).
- UI STYLE = ROYAL GOLD (owner picked concept 1 of 10 knightly/royal concepts): `UiKit` (titles/
  buttons Noto Serif Hebrew Black in GOLD LEAF - `UiKit.gild()` shader; text Secular One; dark-brown
  outline; red-velvet panels with a gold rim, inner gold line and a little crown - `PanelDecor`;
  gold / crimson / royal-blue buttons), `GameButton`, `WorldTile`.
  ALL TEXT IS RIGHT-TO-LEFT. Short labels do not wrap; long texts need autowrap + a width; long
  pages go in a ScrollContainer (a page taller than the screen hid the close button). Hebrew:
  natural, plural address ("לחצו"). The web build has no system fonts: symbols/emoji come from
  NotoSansSymbols2 + NotoEmoji fallbacks in `UiKit.setup_fonts()` - keep it that way.
- `audio/` – `Sfx.play(name)`, `Music.play("base"|"plan"|"battle")` (cross-fades, tracks keep
  running), `Voice.babble(hero)`. Effects/voices: `tools/make_sounds.py`; knightly music
  (drums, brass, strings, lute, harp) + fanfare/lose: `tools/make_music.py`. No downloads.

## Data
- `data/heroes.json` (hp, dmg, rate, range, speed, cost, role, ability), `data/spells.json`,
  `data/battle.json` (energy, structures, palace upgrades, map sizes + time limits),
  `data/meta.json` (buildings, unlocks, rewards, chests, arenas, quests), `data/characters.json`
  (looks), `data/biomes.json` (worlds, monsters, shrines, treasure).
- Ability/spell types are generic: area_damage, area_heal, area_buff, dash, wall; effects
  freeze, stun, slow, burn, shield, rage. A new power = data only, plus Hebrew text in HeroTexts.

## Rules decisions
- The king can never be targeted. He steps to the safest square of his palace at each turn start.
  Only heroes inside the palace (floor grown by 1) threaten him for mate.
- Hero card: any number of times; after each use it recharges 5 s (one turn). Max 15 heroes.
  Spells have a cooldown. The screen shows waits in turns (seconds / 5).
- Fairness: maps, the starting army, summon spots and monster camps are point-symmetric. Check
  with computer-vs-computer runs whenever rules change (both sides should win about equally;
  battle_sim.gd takes a mode and a seed; give both AIs different seeds or games are near-mirrors).
- Units act in a random order each tick (a fair coin; plain alternation repeated per turn and was
  a real bias). Pushes between heroes are summed and applied together. The Void's A* grid is
  stored turned 180 degrees (`_gm`) so both sides break path ties alike. Keep all of these. Monsters
  guard their camp (aggro 2.6 from home, leash 5.5) and give energy + gold to whoever kills them.
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
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/app_shot.gd -- out.png 4 --battle medium --world fire   # a world
xvfb-run -a godot --rendering-driver opengl3 --script res://tools/app_shot.gd -- out.png 5 --base panel=world      # also: quests, deck, heroes, book:<id>
```
A GDScript parse error makes `godot --script` hang: redirect output to a file and use `timeout`.
CI (`.github/workflows/web.yml`) runs the tests and publishes the web build to GitHub Pages.

## Conventions
- Typed GDScript, tabs, `class_name` for shared classes.
- Add a test in `tests/test_*.gd` (extends `TestCase`) for every new rule.
- Never let presentation code change `Battle` except through its order functions.
