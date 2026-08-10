# Graph Report - .  (2026-08-10)

## Corpus Check
- Corpus is ~22,499 words - fits in a single context window. You may not need a graph.

## Summary
- 59 nodes · 48 edges · 11 communities (5 shown, 6 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- 3D Model Textures & Colormaps
- Desert UI Theme Assets
- Grass UI Theme Assets
- Ice & Snow UI Theme Assets
- Menu & UI Grid Assets
- Graphify Agent Rules
- Project Icon & Root Assets
- Graphify Workflow Automation
- Asset Licensing & Legal
- Biomes Documentation
- Project Readme Documentation

## God Nodes (most connected - your core abstractions)
1. `Textures Visual Assets Theme` - 15 edges
2. `Desert Visual Assets Theme` - 11 edges
3. `Grass Visual Assets Theme` - 9 edges
4. `Ice Visual Assets Theme` - 9 edges
5. `menus Visual Assets Theme` - 2 edges
6. `Graphify Rule Definition` - 1 edges
7. `Knowledge Graph Query & Navigation` - 1 edges
8. `Desert 7 Image Asset` - 1 edges
9. `Desert Border BG Trial 1 Image Asset` - 1 edges
10. `Desert Border Trial 1 Image Asset` - 1 edges

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

## Hyperedges (group relationships)
- **Game UI & Environment Themes** — ui_theme_desert, ui_theme_grass, ui_theme_ice, ui_theme_textures, ui_theme_menus [INFERRED 0.85]

## Communities (11 total, 6 thin omitted)

### Community 0 - "3D Model Textures & Colormaps"
Cohesion: 0.12
Nodes (16): flower Image Asset, grass_round Image Asset, grass_thin Image Asset, leaf_alpha Image Asset, leaf_particle Image Asset, Leaves001-03 Image Asset, Leaves001-04 Image Asset, rock_color Image Asset (+8 more)

### Community 1 - "Desert UI Theme Assets"
Cohesion: 0.17
Nodes (12): Desert 7 Image Asset, Desert Border BG Trial 1 Image Asset, Desert Border Trial 1 Image Asset, Desert Togle 3 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset (+4 more)

### Community 2 - "Grass UI Theme Assets"
Cohesion: 0.20
Nodes (10): Grass 1 Image Asset, Grass Toggle 3 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset, Sprite-0006 Image Asset, Sprite-0007 Image Asset (+2 more)

### Community 3 - "Ice & Snow UI Theme Assets"
Cohesion: 0.20
Nodes (10): Snow Hotbar 2 Image Asset, Snow Toggle 2 Image Asset, Sprite-0002 Image Asset, Sprite-0003 Image Asset, Sprite-0004 Image Asset, Sprite-0005 Image Asset, Sprite-0006 Image Asset, Sprite-0007 Image Asset (+2 more)

### Community 4 - "Menu & UI Grid Assets"
Cohesion: 0.67
Nodes (3): grid Image Asset, IMG-20230621-WA0013 Image Asset, menus Visual Assets Theme

## Knowledge Gaps
- **53 isolated node(s):** `Graphify Rule Definition`, `Graphify Workflow Command`, `IGI Code Circus Project Overview`, `Asset License Terms`, `Biomes & Environments Documentation` (+48 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `Graphify Rule Definition`, `Graphify Workflow Command`, `IGI Code Circus Project Overview` to the rest of the system?**
  _53 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `3D Model Textures & Colormaps` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._