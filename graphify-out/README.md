# graphify-out — Godot Project Knowledge Graph

This folder is managed by two systems working together:

1. **[graphify](https://pypi.org/project/graphify/)** (pip package) — builds a semantic knowledge graph (`graph.json`) from images, documents, and code files it natively supports.
2. **Custom Python scripts** (in this folder) — extend the graph with GDScript (`.gd`) and scene (`.tscn`) files, which graphify does not support natively.

Together they give you a single queryable map of the entire project.

---

## File Map

| File / Folder | What it is |
|---|---|
| `graph.json` | The main knowledge graph — nodes + edges for all project files |
| `GRAPH_REPORT.md` | Human-readable summary of communities, god-nodes, surprising connections |
| `graph.html` | Interactive visualization (open in browser; may be absent if `--no-viz` was used) |
| `gd_index.json` | Lightweight GDScript index: class names, public functions, signals, load/preload |
| `tscn_index.json` | Lightweight scene index: ext_resources per scene + reverse asset→scene lookup |
| `godot_index.py` | **Builds** gd_index.json and tscn_index.json with freshness checking |
| `merge_to_graph.py` | **Merges** gd_index + tscn_index nodes/edges INTO graph.json |
| `.graphify_python` | Path to the Python executable graphify uses (auto-set by graphify install) |
| `.graphify_labels.json` | Community name cache from the last LLM labeling run |
| `manifest.json` | graphify internal: file hashes for change detection |
| `cost.json` | LLM API cost log from graphify runs |
| `graph.json.bak` | Backup of graph.json before last merge (auto-created by merge_to_graph.py) |
| `2026-08-*/` | Backup folders created by graphify on each cluster run |
| `cache/` | graphify internal extraction cache |

---

## Setup

### Requirements
- Python 3.10+
- graphify: `pip install graphify`
- An LLM API key for semantic extraction (only needed for the initial graphify build, not for index rebuilds)

### First-time build (if graphify-out is empty or missing)
```powershell
# 1. Build the graphify knowledge graph (requires LLM key)
python -m graphify .

# 2. Build GDScript + TSCN indexes (no LLM needed, runs in <1s)
python graphify-out/godot_index.py

# 3. Merge GD+TSCN nodes into graph.json
python graphify-out/merge_to_graph.py
```

---

## Usage: `godot_index.py`

Scans all `.gd` and `.tscn` files and outputs two **JSON index files** (`gd_index.json`, `tscn_index.json`).

> **Note:** `godot_index.py` does NOT generate `graph.html`. The interactive visualization is
> produced by graphify itself. To regenerate it run:
> ```powershell
> python -m graphify cluster-only .
> ```
> Use `--no-viz` to skip HTML generation (faster, useful in CI or when only the JSON graph matters).
>
> Alternatively, to generate `graph.html` containing all merged Godot nodes (which graphify's standard command skips due to safety checks), use:
> ```powershell
> python graphify-out/merge_to_graph.py --force-update --viz
> ```


```powershell
# Check if indexes are fresh (safe, no rebuild)
python graphify-out/godot_index.py --check


# Rebuild only if stale (default behavior)
python graphify-out/godot_index.py

# Force rebuild regardless of freshness
python graphify-out/godot_index.py --force

# Custom project root and output directory
python graphify-out/godot_index.py --root D:/Other/Project --out-dir D:/Other/Project/graphify-out
```

### What `gd_index.json` contains (per script)

```json
{
  "file": "scripts/Enemy.gd",
  "class_name": null,
  "extends": "Node3D",
  "signals": [{ "name": "reached_end" }, { "name": "enemy_defeated" }],
  "functions": [
    { "name": "setup", "params": ["enemy_type"] },
    { "name": "take_damage", "params": ["amount"] }
  ],
  "loads": [
    { "line": 7, "path": "scenes/explosion.tscn", "call": "preload" }
  ],
  "exports": [{ "name": "max_health", "type": "float" }]
}
```

### What `tscn_index.json` contains (per scene)

```json
{
  "file": "scenes/main.tscn",
  "scene_uid": "uid://abc123",
  "ext_resources": [
    { "path": "scripts/MapGenerator.gd", "type": "Script" },
    { "path": "assets/Models/GLB format/enemy-ufo-a.glb", "type": "PackedScene" }
  ],
  "nodes_preview": [{ "name": "Main", "type": "Node3D" }]
}
```

It also includes a reverse lookup `asset_to_scenes` — useful for "which scenes use this asset?":

```python
import json
tscn = json.load(open("graphify-out/tscn_index.json"))
print(tscn["asset_to_scenes"]["assets/Models/GLB format/enemy-ufo-a.glb"])
# -> ["scenes/main.tscn", "scenes/wave_test.tscn"]
```

---

## Usage: `merge_to_graph.py`

Merges GDScript and scene nodes from the indexes into graphify's `graph.json`, enabling `graphify query` to find scripts and scenes alongside image/document nodes.

```powershell
# Preview what would be merged (no files written)
python graphify-out/merge_to_graph.py --dry-run

# Run the merge (backs up graph.json.bak first)
python graphify-out/merge_to_graph.py

# Re-merge after .gd/.tscn changes (overwrites existing GD/TSCN nodes)
python graphify-out/merge_to_graph.py --force-update
```

After merging, the script automatically runs `graphify cluster-only` to regenerate `GRAPH_REPORT.md` with updated community assignments.

> **Note:** Merging adds new communities (`GDScript Gameplay Logic` = 99, `Godot Scenes` = 98). Run `python -m graphify label .` to give them proper LLM-generated names.

---

## Using `graphify query` / `explain` / `path`

Once graph.json includes GD+TSCN nodes, you can query across the whole project:

```powershell
# Find all nodes related to a concept
python -m graphify query "TurretHotbar biome theme"

# Explain a specific node
python -m graphify explain "Enemy GDScript"

# Shortest path between two nodes
python -m graphify path "CurrencyManager GDScript" "WaveManager GDScript"

# Find what depends on a node
python -m graphify affected "MapGenerator"
```

---

## Agent Workflow — When to Use Which File

```
Task involves gameplay logic (.gd)?
  → Read gd_index.json first
  → Only open the .gd file itself if index is insufficient

Task involves scene composition or which assets a scene loads?
  → Read tscn_index.json first (check ext_resources or asset_to_scenes)

Task involves conceptual/thematic relationships (image themes, doc communities)?
  → Use graphify query / explain / path on graph.json

Task spans multiple systems (e.g., "how does Enemy connect to WaveManager")?
  → Use graphify path "Enemy" "WaveManager" (works after merge)

Freshness check at session start:
  python graphify-out/godot_index.py --check
```

**Token budget rule:** Read full file contents only when the index says it exists and you need implementation details. The indexes + `graphify query` cover 90% of navigation needs.

---

## Agent Workflows & Commands (Quick Commands)

These commands are registered as IDE shortcuts/workflows. You can run them to perform quick tasks:

| IDE Command | Underlying Action | What it does | When to use |
|---|---|---|---|
| **`/refresh-graph`** | `godot_index.py --force`<br>`merge_to_graph.py --force-update` | Updates `gd_index.json`, `tscn_index.json`, and merges them into `graph.json` | When you want the **Agent IDE** to have the latest gameplay code reference (faster, does not build HTML). |
| **`/update-viz`** | `godot_index.py`<br>`merge_to_graph.py --force-update --viz` | Updates indices, merges, and generates/updates `graph.html` visualizer | When you want to **open the visual graph in your browser** to inspect relations. |

> **Note:** `/update-viz` already includes the refresh step automatically! There is **no need** to run `/refresh-graph` before running `/update-viz`.

---

## Recommended Manual Workflow (Full Rebuild)

If you have major updates to images, documents, or need a fresh semantic extraction:

```powershell
# 1. If images/docs changed, run full graphify update (uses LLM)
python -m graphify update .

# 2. Re-label communities (uses LLM)
python -m graphify label .

# 3. Rebuild indexes and merge GDScript + TSCN (no LLM, fast)
python graphify-out/godot_index.py --force
python graphify-out/merge_to_graph.py --force-update --viz
```

---

## Troubleshooting

### UnicodeEncodeError on Windows
If you see `charmap codec can't encode character`, your terminal is using cp1252.
All scripts in this folder use only ASCII in print statements. If a third-party script fails:
```powershell
$env:PYTHONUTF8 = "1"
python graphify-out/godot_index.py
```

### graphify command not found
```powershell
# Install graphify
pip install graphify

# Or use module syntax
python -m graphify query "your question"
```

### merge_to_graph.py: "graph.json is empty or missing"
Run `python -m graphify .` first to build the initial graph, then run merge.

### After merge, graphify query can't find GD nodes
The GDScript/TSCN community names are numeric placeholders (98/99) until you run:
```powershell
python -m graphify label .
```

### graph.json got corrupted
Restore from backup:
```powershell
Copy-Item graphify-out/graph.json.bak graphify-out/graph.json
```
