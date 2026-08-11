---
name: update-viz
description: Regenerate graph.json and update graph.html visualization with all nodes
---

# Workflow: update-viz

This workflow regenerates the index data, updates the main knowledge graph, and builds a comprehensive interactive HTML visualization (`graph.html`) including all custom Godot GDScript and TSCN nodes.

```powershell
# 1. Ensure indexes are up to date
python graphify-out/godot_index.py

# 2. Merge indexes and generate the graph.html visualization directly
python graphify-out/merge_to_graph.py --force-update --viz
```
