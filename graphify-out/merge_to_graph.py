#!/usr/bin/env python3
"""
merge_to_graph.py  --  Merge GDScript + TSCN nodes into graphify's graph.json

Reads gd_index.json and tscn_index.json (produced by godot_index.py),
converts them into graphify-compatible node+edge records, and merges them
into graph.json -- so `graphify query` can navigate scripts and scenes
alongside image/doc nodes.

Idempotent: nodes already present (matched by id) are skipped.
A backup of graph.json is written to graph.json.bak before any change.

Usage:
    python merge_to_graph.py                    # use defaults
    python merge_to_graph.py --dry-run          # show what would change, no write
    python merge_to_graph.py --force-update     # overwrite existing nodes too
    python merge_to_graph.py --graph path/to/graph.json
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

# ── defaults (relative to this script) ───────────────────────────────────────
SCRIPT_DIR      = Path(__file__).parent          # graphify-out/
DEFAULT_GRAPH   = SCRIPT_DIR / "graph.json"
DEFAULT_GD_IDX  = SCRIPT_DIR / "gd_index.json"
DEFAULT_TSCN_IDX = SCRIPT_DIR / "tscn_index.json"
PROJECT_ROOT    = SCRIPT_DIR.parent

# Community IDs to assign — pick one that won't collide with existing communities.
# graphify uses integers; we'll use 99 as a "GDScript/Scene" community placeholder.
GDSCRIPT_COMMUNITY = 99
TSCN_COMMUNITY     = 98


# ── helpers ───────────────────────────────────────────────────────────────────
def slugify(text: str) -> str:
    return re.sub(r"[^a-zA-Z0-9]+", "_", text).strip("_").lower()


def make_gd_node_id(rel_path: str) -> str:
    stem = rel_path.rsplit(".", 1)[0]
    return f"gdscript_{slugify(stem)}"


def make_tscn_node_id(rel_path: str) -> str:
    stem = rel_path.rsplit(".", 1)[0]
    return f"tscn_{slugify(stem)}"


def load_json(path: Path) -> dict:
    if not path.exists():
        print(f"  [WARN] Not found: {path}")
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


# ── node builders ─────────────────────────────────────────────────────────────
def gd_script_to_node(script: dict) -> dict:
    """Convert a gd_index.json script entry to a graphify node."""
    rel_path   = script["file"]
    node_id    = make_gd_node_id(rel_path)
    label      = script.get("class_name") or Path(rel_path).stem
    extends    = script.get("extends") or ""
    fn_names   = [f["name"] for f in script.get("functions", [])]
    sig_names  = [s["name"] for s in script.get("signals", [])]

    description_parts = []
    if extends:
        description_parts.append(f"extends {extends}")
    if fn_names:
        description_parts.append(f"funcs: {', '.join(fn_names[:6])}" + (" ..." if len(fn_names) > 6 else ""))
    if sig_names:
        description_parts.append(f"signals: {', '.join(sig_names)}")

    return {
        "id": node_id,
        "label": label,
        "file_type": "code",
        "source_file": rel_path,
        "source_location": "L1",
        "_origin": "ast",
        "community": GDSCRIPT_COMMUNITY,
        "community_name": "GDScript Gameplay Logic",
        "norm_label": label.lower(),
        "description": " | ".join(description_parts) if description_parts else None,
        # extra metadata (graphify ignores unknown fields)
        "_gd_extends": extends or None,
        "_gd_functions": fn_names,
        "_gd_signals": sig_names,
        "_gd_exports": [e["name"] for e in script.get("exports", [])],
    }


def tscn_scene_to_node(scene: dict) -> dict:
    """Convert a tscn_index.json scene entry to a graphify node."""
    rel_path = scene["file"]
    node_id  = make_tscn_node_id(rel_path)
    label    = Path(rel_path).stem.replace("_", " ").replace("-", " ").title()
    res_count = len(scene.get("ext_resources", []))

    return {
        "id": node_id,
        "label": f"{label} Scene",
        "file_type": "code",
        "source_file": rel_path,
        "source_location": "L1",
        "_origin": "ast",
        "community": TSCN_COMMUNITY,
        "community_name": "Godot Scenes",
        "norm_label": label.lower() + " scene",
        "description": f"Scene with {res_count} ext_resource(s)",
        "_scene_uid": scene.get("scene_uid"),
        "_ext_resource_count": res_count,
    }


# ── edge builders ─────────────────────────────────────────────────────────────
def build_gd_edges(scripts: list, existing_node_ids: set) -> list:
    """Build 'loads' edges from GDScript nodes to any nodes already in the graph."""
    edges = []
    for script in scripts:
        src_id = make_gd_node_id(script["file"])
        for load_entry in script.get("loads", []):
            target_path = load_entry["path"]
            # Try to find matching node by source_file
            # We'll store a path->id lookup passed in as existing_node_ids (actually a dict)
            target_id = existing_node_ids.get(target_path)
            if target_id:
                edges.append({
                    "relation": "loads",
                    "confidence": "EXTRACTED",
                    "confidence_score": 1.0,
                    "source_file": script["file"],
                    "source_location": f"L{load_entry['line']}",
                    "weight": 1.0,
                    "_origin": "ast",
                    "source": src_id,
                    "target": target_id,
                })
    return edges


def build_tscn_edges(scenes: list, existing_node_ids: dict, tscn_node_ids: set) -> list:
    """Build 'references' edges from TSCN scene nodes to their ext_resources."""
    edges = []
    for scene in scenes:
        src_id = make_tscn_node_id(scene["file"])
        for res in scene.get("ext_resources", []):
            target_path = res["path"]
            # check graph nodes
            target_id = existing_node_ids.get(target_path)
            # check if target is itself a tscn or gd node we just created
            if not target_id:
                if target_path.endswith(".tscn"):
                    target_id = make_tscn_node_id(target_path)
                    if target_id not in tscn_node_ids:
                        target_id = None
                elif target_path.endswith(".gd"):
                    target_id = make_gd_node_id(target_path)

            if target_id:
                edges.append({
                    "relation": "references",
                    "confidence": "EXTRACTED",
                    "confidence_score": 1.0,
                    "source_file": scene["file"],
                    "source_location": "L1",
                    "weight": 1.0,
                    "_origin": "ast",
                    "source": src_id,
                    "target": target_id,
                    "_resource_type": res.get("type"),
                })
    return edges


# ── main merge logic ──────────────────────────────────────────────────────────
def merge(
    graph_path: Path,
    gd_idx_path: Path,
    tscn_idx_path: Path,
    dry_run: bool = False,
    force_update: bool = False,
):
    print(f"Loading graph    : {graph_path}")
    graph = load_json(graph_path)
    if not graph:
        print("ERROR: graph.json is empty or missing.", file=sys.stderr)
        sys.exit(1)

    gd_idx   = load_json(gd_idx_path)
    tscn_idx = load_json(tscn_idx_path)

    if not gd_idx and not tscn_idx:
        print("No index files found. Run: python godot_index.py --force")
        sys.exit(1)

    # Build lookup: source_file -> node_id (from existing graph)
    path_to_id: dict = {}
    existing_ids: set = set()
    for node in graph.get("nodes", []):
        existing_ids.add(node["id"])
        sf = node.get("source_file")
        if sf:
            path_to_id[sf.replace("\\", "/")] = node["id"]

    # ── process GDScript nodes ────────────────────────────────────────────────
    gd_scripts   = gd_idx.get("scripts", [])
    new_gd_nodes = []
    skipped_gd   = 0

    for script in gd_scripts:
        node     = gd_script_to_node(script)
        node_id  = node["id"]
        if node_id in existing_ids and not force_update:
            skipped_gd += 1
            continue
        new_gd_nodes.append(node)
        existing_ids.add(node_id)
        path_to_id[script["file"]] = node_id  # register for edge building

    # ── process TSCN nodes ────────────────────────────────────────────────────
    tscn_scenes   = tscn_idx.get("scenes", [])
    new_tscn_nodes = []
    skipped_tscn   = 0
    tscn_new_ids: set = set()

    for scene in tscn_scenes:
        node    = tscn_scene_to_node(scene)
        node_id = node["id"]
        if node_id in existing_ids and not force_update:
            skipped_tscn += 1
            continue
        new_tscn_nodes.append(node)
        existing_ids.add(node_id)
        tscn_new_ids.add(node_id)
        path_to_id[scene["file"]] = node_id

    # ── build edges ───────────────────────────────────────────────────────────
    new_gd_edges   = build_gd_edges(gd_scripts, path_to_id)
    new_tscn_edges = build_tscn_edges(tscn_scenes, path_to_id, existing_ids)

    # deduplicate edges by (source, target, relation)
    existing_edge_keys: set = set()
    for edge in graph.get("links", []):
        existing_edge_keys.add((edge.get("source"), edge.get("target"), edge.get("relation")))

    fresh_gd_edges   = [e for e in new_gd_edges   if (e["source"], e["target"], e["relation"]) not in existing_edge_keys]
    fresh_tscn_edges = [e for e in new_tscn_edges if (e["source"], e["target"], e["relation"]) not in existing_edge_keys]

    # ── summary ───────────────────────────────────────────────────────────────
    print(f"\nMerge summary:")
    print(f"  GDScript nodes  : +{len(new_gd_nodes)} new, {skipped_gd} already present")
    print(f"  TSCN nodes      : +{len(new_tscn_nodes)} new, {skipped_tscn} already present")
    print(f"  GD load edges   : +{len(fresh_gd_edges)} new")
    print(f"  TSCN ref edges  : +{len(fresh_tscn_edges)} new")

    total_new_nodes = len(new_gd_nodes) + len(new_tscn_nodes)
    total_new_edges = len(fresh_gd_edges) + len(fresh_tscn_edges)

    if total_new_nodes == 0 and total_new_edges == 0:
        print("\nNothing to merge -- graph already up to date.")
        return

    if dry_run:
        print("\n[DRY RUN] No files written.")
        return

    # ── backup + write ────────────────────────────────────────────────────────
    bak_path = graph_path.with_suffix(".json.bak")
    shutil.copy2(graph_path, bak_path)
    print(f"\nBackup written : {bak_path}")

    # Merge into graph
    all_nodes = graph.get("nodes", []) + new_gd_nodes + new_tscn_nodes
    all_links = graph.get("links", []) + fresh_gd_edges + fresh_tscn_edges

    graph["nodes"] = all_nodes
    graph["links"] = all_links

    save_json(graph_path, graph)
    print(f"graph.json updated: {len(all_nodes)} nodes total, {len(all_links)} edges total")

    # ── trigger graphify cluster-only to regenerate HTML + report ────────────
    py_file = SCRIPT_DIR / ".graphify_python"
    py_exe  = None
    if py_file.exists():
        py_exe = py_file.read_text(encoding="utf-8").strip()
    if not py_exe:
        # fallback: use same Python that is running this script
        py_exe = sys.executable

    print(f"\nRunning: graphify cluster-only to regenerate GRAPH_REPORT.md ...")
    try:
        cmd = [py_exe, "-m", "graphify", "cluster-only", str(PROJECT_ROOT), "--no-viz"]
        result = subprocess.run(
            cmd,
            capture_output=True, text=True, timeout=120,
            cwd=str(PROJECT_ROOT),
        )
        out = (result.stdout + result.stderr).strip()
        if "Done" in out or result.returncode == 0:
            print("  graphify cluster-only: OK")
            for line in out.splitlines()[-4:]:
                print(f"  {line}")
        else:
            print(f"  [WARN] graphify cluster-only exited {result.returncode}")
            for line in out.splitlines()[-6:]:
                print(f"  {line}")
            print("  Run manually: python -m graphify cluster-only . --no-viz")
    except Exception as e:
        print(f"  [WARN] Could not run graphify cluster-only: {e}")
        print("  Run manually: python -m graphify cluster-only . --no-viz")


# ── CLI ───────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--graph",        default=str(DEFAULT_GRAPH),    help=f"Path to graph.json (default: {DEFAULT_GRAPH})")
    parser.add_argument("--gd-index",     default=str(DEFAULT_GD_IDX),   help=f"Path to gd_index.json")
    parser.add_argument("--tscn-index",   default=str(DEFAULT_TSCN_IDX), help=f"Path to tscn_index.json")
    parser.add_argument("--dry-run",      action="store_true",            help="Show what would change without writing")
    parser.add_argument("--force-update", action="store_true",            help="Overwrite existing nodes (re-merge)")
    args = parser.parse_args()

    merge(
        graph_path   = Path(args.graph),
        gd_idx_path  = Path(args.gd_index),
        tscn_idx_path = Path(args.tscn_index),
        dry_run      = args.dry_run,
        force_update = args.force_update,
    )


if __name__ == "__main__":
    main()
