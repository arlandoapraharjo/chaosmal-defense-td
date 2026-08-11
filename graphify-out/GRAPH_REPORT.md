# Graph Report - IGI-Code-Circus  (2026-08-12)

## Corpus Check
- 10 files · ~27,363 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 109 nodes · 112 edges · 34 communities (8 shown, 26 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.5)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1cf6b5f8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- pywin32_postinstall.py
- Biome Setup Guide
- Project Documentation & Recent Updates
- pywin32_testall.py
- Tee
- rules/graphify.md
- workflows/graphify.md
- refresh_graph.md
- update_viz.md
- MainMenu
- animation_player
- EnemyDetector
- TurretUpgradeManager
- HotbarTheme
- Bush2Glb3 Scene
- Snow Bush Scene
- Desert Tile Scene
- Desert Tile Corner Scene
- Desert Tile Spawn Scene
- Desert Tile Spawnend Scene
- Desert Tile Straight Scene
- Better Tile Grass Scene
- Bush Scene
- Foliage Snow Tree Scene
- Foliage Tree Scene
- Grass Scene
- Grass Single Scene
- Grass Single Snow Scene
- Snow Bush Scene
- Pilarshockwave Scene
- Enemy
- Map Scene

## God Nodes (most connected - your core abstractions)
1. `install()` - 12 edges
2. `Map Scene` - 10 edges
3. `uninstall()` - 8 edges
4. `Map Scene` - 7 edges
5. `get_root_hkey()` - 6 edges
6. `Project Documentation & Recent Updates` - 6 edges
7. `RegisterHelpFile()` - 5 edges
8. `RegisterPythonwin()` - 5 edges
9. `get_shortcuts_folder()` - 5 edges
10. `MapGenerator` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Map Scene` --references--> `BiomeData`  [EXTRACTED]
  map.tscn → biomes/BiomeData.gd
- `Map Scene` --references--> `BiomeData`  [EXTRACTED]
  scenes/map.tscn → biomes/BiomeData.gd
- `Map Scene` --references--> `CurrencyManager`  [EXTRACTED]
  scenes/map.tscn → scripts/CurrencyManager.gd
- `World Scene` --references--> `MapGenerator`  [EXTRACTED]
  assets/Models/GLB format/world.tscn → scripts/MapGenerator.gd
- `Map Scene` --references--> `Currencyui Scene`  [EXTRACTED]
  scenes/map.tscn → UI/CurrencyUI.tscn

## Import Cycles
- None detected.

## Communities (34 total, 26 thin omitted)

### Community 0 - "pywin32_postinstall.py"
Cohesion: 0.24
Nodes (19): CopyTo(), create_shortcut(), fixup_dbi(), get_root_hkey(), get_shortcuts_folder(), get_special_folder_path(), get_system_dir(), install() (+11 more)

### Community 1 - "Biome Setup Guide"
Cohesion: 0.20
Nodes (9): Biome Setup Guide, Decorations group, Desert / Grass, Environment Audit Checklist (Item 2), How to create a new BiomeData resource, Known biome asset paths, Look & Feel group, Snow (confirmed working) (+1 more)

### Community 2 - "Project Documentation & Recent Updates"
Cohesion: 0.29
Nodes (6): Asset Imports & Fixing Missing Textures, Biome System & Map Generation, Biome Tree Rotation, Enemy Movement, Enemy Pathing & Coordinate Alignment, Project Documentation & Recent Updates

### Community 4 - "pywin32_testall.py"
Cohesion: 0.60
Nodes (4): find_and_run(), main(), A test runner for pywin32, run_test()

### Community 98 - "Enemy"
Cohesion: 0.67
Nodes (3): Enemy, WaveManager, Explosion Scene

### Community 99 - "Map Scene"
Cohesion: 0.11
Nodes (24): BiomeData, BuilderController, CameraController, CurrencyManager, IncursionPillar, MapGenerator, PauseOverlay, PillarShockwave (+16 more)

## Knowledge Gaps
- **46 isolated node(s):** `graphify`, `Workflow: graphify`, `Workflow: refresh-graph`, `Workflow: update-viz`, `Biome System & Map Generation` (+41 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **26 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MapGenerator` connect `Map Scene` to `Enemy`?**
  _High betweenness centrality (0.024) - this node is a cross-community bridge._
- **What connects `graphify`, `Workflow: graphify`, `Workflow: refresh-graph` to the rest of the system?**
  _46 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Map Scene` be split into smaller, more focused modules?**
  _Cohesion score 0.10869565217391304 - nodes in this community are weakly interconnected._