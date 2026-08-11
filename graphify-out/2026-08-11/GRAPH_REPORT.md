# Graph Report - D:\Godot\Game\IGI-Code-Circus  (2026-08-11)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 49 nodes · 34 edges · 26 communities (5 shown, 21 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b2b52d99`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- MapGenerator
- Turrethotbar Scene
- Enemy
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
- Map Scene
- Map Scene

## God Nodes (most connected - your core abstractions)
1. `Map Scene` - 10 edges
2. `Map Scene` - 7 edges
3. `MapGenerator` - 5 edges
4. `BuilderController` - 3 edges
5. `CameraController` - 3 edges
6. `Turrethotbar Scene` - 3 edges
7. `Speedtoggle Scene` - 3 edges
8. `Pauseoverlay Scene` - 3 edges
9. `TurretHotbar` - 2 edges
10. `BiomeData` - 2 edges

## Surprising Connections (you probably didn't know these)
- `Map Scene` --references--> `BiomeData`  [EXTRACTED]
  scenes/map.tscn → biomes/BiomeData.gd
- `Map Scene` --references--> `BiomeData`  [EXTRACTED]
  map.tscn → biomes/BiomeData.gd
- `Map Scene` --references--> `BuilderController`  [EXTRACTED]
  map.tscn → scripts/BuilderController.gd
- `Map Scene` --references--> `CameraController`  [EXTRACTED]
  map.tscn → scripts/CameraController.gd
- `Map Scene` --references--> `CameraController`  [EXTRACTED]
  scenes/map.tscn → scripts/CameraController.gd

## Import Cycles
- None detected.

## Communities (26 total, 21 thin omitted)

### Community 0 - "MapGenerator"
Cohesion: 0.33
Nodes (6): CameraController, IncursionPillar, MapGenerator, PillarShockwave, World Scene, Pillarshockwave Scene

### Community 1 - "Turrethotbar Scene"
Cohesion: 0.50
Nodes (4): HotbarSlot, TurretHotbar, Hotbarslot Scene, Turrethotbar Scene

### Community 2 - "Enemy"
Cohesion: 0.67
Nodes (3): Enemy, WaveManager, Explosion Scene

### Community 98 - "Map Scene"
Cohesion: 0.33
Nodes (6): BiomeData, PauseOverlay, SpeedToggle, Map Scene, Pauseoverlay Scene, Speedtoggle Scene

### Community 99 - "Map Scene"
Cohesion: 0.25
Nodes (8): BuilderController, CurrencyManager, Turret, CurrencyUI, WaveUI, Map Scene, Currencyui Scene, Waveui Scene

## Knowledge Gaps
- **31 isolated node(s):** `CurrencyUI`, `HotbarSlot`, `HotbarTheme`, `MainMenu`, `SpeedToggle` (+26 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **21 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Map Scene` connect `Map Scene` to `MapGenerator`, `Turrethotbar Scene`, `Map Scene`?**
  _High betweenness centrality (0.167) - this node is a cross-community bridge._
- **Why does `MapGenerator` connect `MapGenerator` to `Enemy`, `Map Scene`, `Map Scene`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **Why does `Map Scene` connect `Map Scene` to `MapGenerator`, `Turrethotbar Scene`, `Map Scene`?**
  _High betweenness centrality (0.066) - this node is a cross-community bridge._
- **What connects `CurrencyUI`, `HotbarSlot`, `HotbarTheme` to the rest of the system?**
  _31 weakly-connected nodes found - possible documentation gaps or missing edges._