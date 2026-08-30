# Graph Report - C:\Users\user\repos\IGI-Code-Circus  (2026-08-30)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 109 nodes · 80 edges · 37 communities (9 shown, 28 thin omitted)
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
- IncursionPillar
- TurretHotbar
- BuilderController
- animation_player
- BiomeManager
- EnemyDetector
- TurretHighlighter
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
- Turret
- Map Scene

## God Nodes (most connected - your core abstractions)
1. `Map Scene` - 13 edges
2. `Game Scaling Stats — Hard Mode Redesign (v2)` - 8 edges
3. `Turret` - 7 edges
4. `Project Documentation & Recent Updates` - 6 edges
5. `HitParticle` - 6 edges
6. `IncursionPillar` - 5 edges
7. `Biome Setup Guide` - 4 edges
8. `How to create a new BiomeData resource` - 4 edges
9. `MapGenerator` - 4 edges
10. `Known biome asset paths` - 3 edges

## Surprising Connections (you probably didn't know these)
- `Pillar Hit Particle Scene` --references--> `HitParticle`  [EXTRACTED]
  scenes/pillar_hit_particle.tscn → scripts/HitParticle.gd
- `Map Scene` --references--> `Turrethotbar Scene`  [EXTRACTED]
  scenes/map.tscn → UI/Hotbar/TurretHotbar.tscn
- `MainMenu` --loads--> `Map Scene`  [EXTRACTED]
  UI/Menus/MainMenu.gd → scenes/map.tscn
- `Map Scene` --references--> `BiomeData`  [EXTRACTED]
  scenes/map.tscn → biomes/BiomeData.gd
- `Map Scene` --references--> `BuilderController`  [EXTRACTED]
  scenes/map.tscn → scripts/BuilderController.gd

## Import Cycles
- None detected.

## Communities (37 total, 28 thin omitted)

### Community 1 - "Project Documentation & Recent Updates"
Cohesion: 0.29
Nodes (6): Asset Imports & Fixing Missing Textures, Biome System & Map Generation, Biome Tree Rotation, Enemy Movement, Enemy Pathing & Coordinate Alignment, Project Documentation & Recent Updates

### Community 2 - "Biome Setup Guide"
Cohesion: 0.20
Nodes (9): Biome Setup Guide, Decorations group, Desert / Grass, Environment Audit Checklist (Item 2), How to create a new BiomeData resource, Known biome asset paths, Look & Feel group, Snow (confirmed working) (+1 more)

### Community 3 - "Game Scaling Stats — Hard Mode Redesign (v2)"
Cohesion: 0.22
Nodes (8): 1. Enemy Spawn Count Per Wave (NEW — this didn't exist in v1), 2. Enemy Health & Coins — Steeper Curve + Boss Waves, 3. Turret Damage & Cost — Steeper Growth + Real Cost Curve, 4. New Enemy Variants (adds decision-making, not just bigger numbers), 5. Spawn Timing / Density Curve, 6. Other Systems Worth Adding, 7. Suggested Playtesting Checklist, Game Scaling Stats — Hard Mode Redesign (v2)

### Community 8 - "IncursionPillar"
Cohesion: 0.25
Nodes (8): IncursionPillar, PillarDestructionParticle, PillarParticleSystem, PillarShockwave, Pillar Ambient Particles Scene, Pillar Destruction Scene, Pillar Hit Particle Scene, Pillarshockwave Scene

### Community 9 - "TurretHotbar"
Cohesion: 0.50
Nodes (4): HotbarSlot, TurretHotbar, Hotbarslot Scene, Turrethotbar Scene

### Community 10 - "BuilderController"
Cohesion: 0.67
Nodes (3): BuilderController, TurretPlacementParticle, Turret Placement Particle Scene

### Community 98 - "Turret"
Cohesion: 0.18
Nodes (13): BoulderImpact, HitParticle, Turret, TurretDismantleParticle, UpgradeCelebrationParticle, Ballista Hit Particle Scene, Boulder Impact Scene, Cannon Hit Particle Scene (+5 more)

### Community 99 - "Map Scene"
Cohesion: 0.10
Nodes (22): BiomeData, CameraController, CurrencyManager, Enemy, GameOverOverlay, MapGenerator, PauseOverlay, WaveManager (+14 more)

## Knowledge Gaps
- **66 isolated node(s):** `Asset Imports & Fixing Missing Textures`, `Biome System & Map Generation`, `Biome Tree Rotation`, `Enemy Movement`, `Enemy Pathing & Coordinate Alignment` (+61 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **28 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Map Scene` connect `Map Scene` to `TurretHotbar`, `BuilderController`?**
  _High betweenness centrality (0.146) - this node is a cross-community bridge._
- **Why does `Turret` connect `Turret` to `BuilderController`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `BuilderController` connect `BuilderController` to `Turret`, `Map Scene`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **What connects `Asset Imports & Fixing Missing Textures`, `Biome System & Map Generation`, `Biome Tree Rotation` to the rest of the system?**
  _66 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Map Scene` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._