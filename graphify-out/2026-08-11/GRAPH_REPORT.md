# Graph Report - igi-dev-code-circus  (2026-08-11)

## Corpus Check
- 7 files · ~23,071 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 64 nodes · 50 edges · 14 communities (6 shown, 8 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3820feff`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Textures Visual Assets Theme
- Desert Visual Assets Theme
- Grass Visual Assets Theme
- Ice Visual Assets Theme
- menus Visual Assets Theme
- Graphify Rule Definition
- icon Image Asset
- Graphify Workflow Command
- Asset License Terms
- Biomes & Environments Documentation
- IGI Code Circus Project Overview
- rules/graphify.md
- workflows/graphify.md

## God Nodes (most connected - your core abstractions)
1. `Textures Visual Assets Theme` - 15 edges
2. `Desert Visual Assets Theme` - 11 edges
3. `Grass Visual Assets Theme` - 9 edges
4. `Ice Visual Assets Theme` - 9 edges
5. `menus Visual Assets Theme` - 2 edges
6. `graphify` - 1 edges
7. `Workflow: graphify` - 1 edges
8. `Graphify Rule Definition` - 1 edges
9. `Knowledge Graph Query & Navigation` - 1 edges
10. `Desert 7 Image Asset` - 1 edges

## Surprising Connections (you probably didn't know these)
- `colormap Image Asset` --conceptually_related_to--> `Textures Visual Assets Theme`  [EXTRACTED]
  assets/Models/GLB format/desert/Textures/colormap.png → addons/Textures/Leaves001-03.png
- `colormap Image Asset` --conceptually_related_to--> `Textures Visual Assets Theme`  [EXTRACTED]
  assets/Models/GLB format/grass/Textures/colormap.png → addons/Textures/Leaves001-03.png
- `colormap Image Asset` --conceptually_related_to--> `Textures Visual Assets Theme`  [EXTRACTED]
  assets/Models/GLB format/snow/Textures/colormap.png → addons/Textures/Leaves001-03.png
- `colormap Image Asset` --conceptually_related_to--> `Textures Visual Assets Theme`  [EXTRACTED]
  assets/Models/GLB format/Textures/colormap.png → addons/Textures/Leaves001-03.png
- `colormap Image Asset` --conceptually_related_to--> `Textures Visual Assets Theme`  [EXTRACTED]
  assets/Models/OBJ format/Textures/colormap.png → addons/Textures/Leaves001-03.png

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Game UI & Environment Themes** — ui_theme_desert, ui_theme_grass, ui_theme_ice, ui_theme_textures, ui_theme_menus [INFERRED 0.85]

## Communities (14 total, 8 thin omitted)

### Community 0 - "Textures Visual Assets Theme"
Cohesion: 0.12
Nodes (16): flower Image Asset, grass_round Image Asset, grass_thin Image Asset, leaf_alpha Image Asset, leaf_particle Image Asset, Leaves001-03 Image Asset, Leaves001-04 Image Asset, rock_color Image Asset (+8 more)

### Community 1 - "Desert Visual Assets Theme"
Cohesion: 0.17
Nodes (12): Desert 7 Image Asset, Desert Border BG Trial 1 Image Asset, Desert Border Trial 1 Image Asset, Desert Togle 3 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset (+4 more)

### Community 2 - "Grass Visual Assets Theme"
Cohesion: 0.20
Nodes (10): Grass 1 Image Asset, Grass Toggle 3 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset, Sprite-0006 Image Asset, Sprite-0007 Image Asset (+2 more)

### Community 3 - "Ice Visual Assets Theme"
Cohesion: 0.20
Nodes (10): Snow Hotbar 2 Image Asset, Snow Toggle 2 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset, Sprite-0006 Image Asset, Sprite-0007 Image Asset (+2 more)

### Community 4 - "menus Visual Assets Theme"
Cohesion: 0.67
Nodes (3): grid Image Asset, IMG-20230621-WA0013 Image Asset, menus Visual Assets Theme

## Knowledge Gaps
- **55 isolated node(s):** `graphify`, `Workflow: graphify`, `Graphify Rule Definition`, `Graphify Workflow Command`, `IGI Code Circus Project Overview` (+50 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `graphify`, `Workflow: graphify`, `Graphify Rule Definition` to the rest of the system?**
  _55 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Textures Visual Assets Theme` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._