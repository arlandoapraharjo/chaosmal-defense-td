# Graph Report - IGI-Code-Circus  (2026-08-12)

## Corpus Check
- 7 files · ~23,033 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 26 nodes · 19 edges · 8 communities (4 shown, 4 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a8b9540b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Project Documentation & Recent Updates
- Biome Setup Guide
- How to create a new BiomeData resource
- rules/graphify.md
- workflows/graphify.md
- refresh_graph.md
- update_viz.md

## God Nodes (most connected - your core abstractions)
1. `Project Documentation & Recent Updates` - 6 edges
2. `Biome Setup Guide` - 4 edges
3. `How to create a new BiomeData resource` - 4 edges
4. `Known biome asset paths` - 3 edges
5. `graphify` - 1 edges
6. `Workflow: graphify` - 1 edges
7. `Workflow: refresh-graph` - 1 edges
8. `Workflow: update-viz` - 1 edges
9. `Biome System & Map Generation` - 1 edges
10. `Enemy Pathing & Coordinate Alignment` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (8 total, 4 thin omitted)

### Community 1 - "Project Documentation & Recent Updates"
Cohesion: 0.29
Nodes (6): Asset Imports & Fixing Missing Textures, Biome System & Map Generation, Biome Tree Rotation, Enemy Movement, Enemy Pathing & Coordinate Alignment, Project Documentation & Recent Updates

### Community 2 - "Biome Setup Guide"
Cohesion: 0.33
Nodes (5): Biome Setup Guide, Desert / Grass, Environment Audit Checklist (Item 2), Known biome asset paths, Snow (confirmed working)

### Community 3 - "How to create a new BiomeData resource"
Cohesion: 0.50
Nodes (4): Decorations group, How to create a new BiomeData resource, Look & Feel group, Tiles group

## Knowledge Gaps
- **15 isolated node(s):** `graphify`, `Workflow: graphify`, `Workflow: refresh-graph`, `Workflow: update-viz`, `Biome System & Map Generation` (+10 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Biome Setup Guide` connect `Biome Setup Guide` to `How to create a new BiomeData resource`?**
  _High betweenness centrality (0.090) - this node is a cross-community bridge._
- **Why does `How to create a new BiomeData resource` connect `How to create a new BiomeData resource` to `Biome Setup Guide`?**
  _High betweenness centrality (0.070) - this node is a cross-community bridge._
- **What connects `graphify`, `Workflow: graphify`, `Workflow: refresh-graph` to the rest of the system?**
  _15 weakly-connected nodes found - possible documentation gaps or missing edges._