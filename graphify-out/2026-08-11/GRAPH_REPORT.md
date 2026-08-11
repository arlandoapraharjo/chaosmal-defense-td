# Graph Report - .  (2026-08-11)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 109 nodes · 89 edges · 31 communities (8 shown, 23 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `151dcec8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Textures Visual Assets Theme
- Desert Visual Assets Theme
- Grass Visual Assets Theme
- Ice Visual Assets Theme
- Mainmenu Scene
- Graphify Rule Definition
- icon Image Asset
- Graphify Workflow Command
- Asset License Terms
- Biomes & Environments Documentation
- IGI Code Circus Project Overview
- animation_player
- EnemyDetector
- TurretUpgradeManager
- HotbarTheme
- Bush2Glb3 Scene
- Desert Tile Scene
- Desert Tile Corner Scene
- Desert Tile Spawn Scene
- Desert Tile Spawnend Scene
- Desert Tile Straight Scene
- Better Tile Grass Scene
- Bush Scene
- Grass Scene
- Grass Single Scene
- Grass Single Snow Scene
- Snow Bush Scene
- Pilarshockwave Scene
- MapGenerator
- Map Scene

## God Nodes (most connected - your core abstractions)
1. `Textures Visual Assets Theme` - 15 edges
2. `Desert Visual Assets Theme` - 11 edges
3. `Map Scene` - 10 edges
4. `Grass Visual Assets Theme` - 9 edges
5. `Ice Visual Assets Theme` - 9 edges
6. `Map Scene` - 7 edges
7. `MapGenerator` - 5 edges
8. `leaf_alpha Image Asset` - 3 edges
9. `tree_bark Image Asset` - 3 edges
10. `BuilderController` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Foliage Snow Tree Scene` --references--> `leaf_alpha Image Asset`  [EXTRACTED]
  scenes/foliage_snow_tree.tscn → addons/Textures/leaf_alpha.png
- `Foliage Tree Scene` --references--> `leaf_alpha Image Asset`  [EXTRACTED]
  scenes/foliage_tree.tscn → addons/Textures/leaf_alpha.png
- `Foliage Snow Tree Scene` --references--> `tree_bark Image Asset`  [EXTRACTED]
  scenes/foliage_snow_tree.tscn → addons/Textures/tree_bark.png
- `Foliage Tree Scene` --references--> `tree_bark Image Asset`  [EXTRACTED]
  scenes/foliage_tree.tscn → addons/Textures/tree_bark.png
- `Mainmenu Scene` --references--> `IMG-20230621-WA0013 Image Asset`  [EXTRACTED]
  UI/Menus/MainMenu.tscn → assets/menus/IMG-20230621-WA0013.jpg

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Game UI & Environment Themes** — ui_theme_desert, ui_theme_grass, ui_theme_ice, ui_theme_textures, ui_theme_menus [INFERRED 0.85]

## Communities (31 total, 23 thin omitted)

### Community 0 - "Textures Visual Assets Theme"
Cohesion: 0.12
Nodes (19): flower Image Asset, grass_round Image Asset, grass_thin Image Asset, leaf_alpha Image Asset, leaf_particle Image Asset, Leaves001-03 Image Asset, Leaves001-04 Image Asset, rock_color Image Asset (+11 more)

### Community 1 - "Desert Visual Assets Theme"
Cohesion: 0.17
Nodes (12): Desert 7 Image Asset, Desert Border BG Trial 1 Image Asset, Desert Border Trial 1 Image Asset, Desert Togle 3 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset (+4 more)

### Community 2 - "Grass Visual Assets Theme"
Cohesion: 0.20
Nodes (10): Grass 1 Image Asset, Grass Toggle 3 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset, Sprite-0006 Image Asset, Sprite-0007 Image Asset (+2 more)

### Community 3 - "Ice Visual Assets Theme"
Cohesion: 0.20
Nodes (10): Snow Hotbar 2 Image Asset, Snow Toggle 2 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset, Sprite-0006 Image Asset, Sprite-0007 Image Asset (+2 more)

### Community 4 - "Mainmenu Scene"
Cohesion: 0.50
Nodes (5): grid Image Asset, IMG-20230621-WA0013 Image Asset, MainMenu, Mainmenu Scene, menus Visual Assets Theme

### Community 98 - "MapGenerator"
Cohesion: 0.29
Nodes (7): Enemy, IncursionPillar, MapGenerator, PillarShockwave, WaveManager, Explosion Scene, Pillarshockwave Scene

### Community 99 - "Map Scene"
Cohesion: 0.13
Nodes (20): BiomeData, BuilderController, CameraController, CurrencyManager, PauseOverlay, Turret, CurrencyUI, HotbarSlot (+12 more)

## Knowledge Gaps
- **76 isolated node(s):** `Graphify Rule Definition`, `Graphify Workflow Command`, `IGI Code Circus Project Overview`, `Asset License Terms`, `Biomes & Environments Documentation` (+71 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **23 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Map Scene` connect `Map Scene` to `MapGenerator`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Why does `MapGenerator` connect `MapGenerator` to `Map Scene`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **What connects `Graphify Rule Definition`, `Graphify Workflow Command`, `IGI Code Circus Project Overview` to the rest of the system?**
  _76 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Textures Visual Assets Theme` be split into smaller, more focused modules?**
  _Cohesion score 0.11695906432748537 - nodes in this community are weakly interconnected._
- **Should `Map Scene` be split into smaller, more focused modules?**
  _Cohesion score 0.12631578947368421 - nodes in this community are weakly interconnected._