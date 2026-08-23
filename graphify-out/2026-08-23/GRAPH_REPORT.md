# Graph Report - C:\Users\user\repos\IGI-Code-Circus  (2026-08-23)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 93 nodes · 64 edges · 35 communities (8 shown, 27 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6fc1e254`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Project Documentation & Recent Updates
- Biome Setup Guide
- Game Scaling Stats — Hard Mode Redesign (v2)
- rules/graphify.md
- workflows/graphify.md
- refresh_graph.md
- update_viz.md
- MapGenerator
- TurretHotbar
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
- Thin Tree Scene
- Thin Tree Snow Scene
- Pilarshockwave Scene
- HitParticle
- Map Scene

## God Nodes (most connected - your core abstractions)
1. `Map Scene` - 10 edges
2. `Game Scaling Stats — Hard Mode Redesign (v2)` - 8 edges
3. `Project Documentation & Recent Updates` - 6 edges
4. `HitParticle` - 5 edges
5. `Turret` - 5 edges
6. `Biome Setup Guide` - 4 edges
7. `How to create a new BiomeData resource` - 4 edges
8. `MapGenerator` - 4 edges
9. `Known biome asset paths` - 3 edges
10. `TurretHotbar` - 2 edges

## Surprising Connections (you probably didn't know these)
- `Map Scene` --references--> `BuilderController`  [EXTRACTED]
  scenes/map.tscn → scripts/BuilderController.gd
- `Map Scene` --references--> `CameraController`  [EXTRACTED]
  scenes/map.tscn → scripts/CameraController.gd
- `Map Scene` --references--> `Turrethotbar Scene`  [EXTRACTED]
  scenes/map.tscn → UI/Hotbar/TurretHotbar.tscn
- `Map Scene` --references--> `BiomeData`  [EXTRACTED]
  scenes/map.tscn → biomes/BiomeData.gd
- `Map Scene` --references--> `CurrencyManager`  [EXTRACTED]
  scenes/map.tscn → scripts/CurrencyManager.gd

## Import Cycles
- None detected.

## Communities (35 total, 27 thin omitted)

### Community 1 - "Project Documentation & Recent Updates"
Cohesion: 0.29
Nodes (6): Asset Imports & Fixing Missing Textures, Biome System & Map Generation, Biome Tree Rotation, Enemy Movement, Enemy Pathing & Coordinate Alignment, Project Documentation & Recent Updates

### Community 2 - "Biome Setup Guide"
Cohesion: 0.20
Nodes (9): Biome Setup Guide, Decorations group, Desert / Grass, Environment Audit Checklist (Item 2), How to create a new BiomeData resource, Known biome asset paths, Look & Feel group, Snow (confirmed working) (+1 more)

### Community 3 - "Game Scaling Stats — Hard Mode Redesign (v2)"
Cohesion: 0.22
Nodes (8): 1. Enemy Spawn Count Per Wave (NEW — this didn't exist in v1), 2. Enemy Health & Coins — Steeper Curve + Boss Waves, 3. Turret Damage & Cost — Steeper Growth + Real Cost Curve, 4. New Enemy Variants (adds decision-making, not just bigger numbers), 5. Spawn Timing / Density Curve, 6. Other Systems Worth Adding, 7. Suggested Playtesting Checklist, Game Scaling Stats — Hard Mode Redesign (v2)

### Community 8 - "MapGenerator"
Cohesion: 0.22
Nodes (9): CameraController, Enemy, IncursionPillar, MapGenerator, PillarShockwave, WaveManager, World Scene, Explosion Scene (+1 more)

### Community 9 - "TurretHotbar"
Cohesion: 0.50
Nodes (4): HotbarSlot, TurretHotbar, Hotbarslot Scene, Turrethotbar Scene

### Community 98 - "HitParticle"
Cohesion: 0.24
Nodes (10): BoulderImpact, BuilderController, HitParticle, Turret, Ballista Hit Particle Scene, Boulder Impact Scene, Cannon Hit Particle Scene, Hit Particle Scene (+2 more)

### Community 99 - "Map Scene"
Cohesion: 0.18
Nodes (11): BiomeData, CurrencyManager, PauseOverlay, CurrencyUI, SpeedToggle, WaveUI, Map Scene, Pauseoverlay Scene (+3 more)

## Knowledge Gaps
- **58 isolated node(s):** `graphify`, `Workflow: graphify`, `Workflow: refresh-graph`, `Workflow: update-viz`, `Biome System & Map Generation` (+53 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **27 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Map Scene` connect `Map Scene` to `MapGenerator`, `TurretHotbar`, `HitParticle`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Why does `BuilderController` connect `HitParticle` to `Map Scene`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **What connects `graphify`, `Workflow: graphify`, `Workflow: refresh-graph` to the rest of the system?**
  _58 weakly-connected nodes found - possible documentation gaps or missing edges._