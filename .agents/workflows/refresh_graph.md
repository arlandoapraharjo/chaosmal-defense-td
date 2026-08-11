---
name: refresh-graph
description: Rebuild Godot GDScript + TSCN indexes and merge them into graphify's graph.json
---

# Workflow: refresh-graph

Follow these steps to regenerate the Godot indices and merge them into the knowledge graph:

```powershell
# 1. Rebuild indexes
python graphify-out/godot_index.py --force

# 2. Merge indexes into graph.json and regenerate report
python graphify-out/merge_to_graph.py --force-update
```
