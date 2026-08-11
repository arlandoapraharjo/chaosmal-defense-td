#!/usr/bin/env python3
"""
scan_gd_assets.py

Read-only scanner untuk project Godot.
Mencari semua panggilan load()/preload() di file .gd, lalu mencocokkan
path asset yang dipanggil dengan node yang SUDAH ADA di graph.json
(hasil export graphify), supaya edge baru bisa langsung dipakai tanpa
merusak schema graph yang sudah ada.

TIDAK mengubah file .gd maupun graph.json asli.
Menghasilkan file baru: gd_edges.json (bisa dicek dulu / di-merge manual).

Usage:
    python3 scan_gd_assets.py --root . --graph graph.json --out gd_edges.json
    python3 scan_gd_assets.py --root . --out gd_edges.json   # tanpa graph.json, pakai path mentah
"""

import argparse
import json
import re
from pathlib import Path

# Menangkap load("res://...") dan preload("res://...")
LOAD_PATTERN = re.compile(
    r'\b(?:load|preload)\s*\(\s*["\']([^"\']+)["\']\s*\)'
)

# Menangkap deklarasi node script sendiri, misal:
# extends Node2D  class_name TurretHotbar
CLASS_NAME_PATTERN = re.compile(r'^\s*class_name\s+(\w+)', re.MULTILINE)


def find_gd_files(root: Path):
    """Cari semua file .gd di bawah root, skip folder non-source."""
    skip_dirs = {".git", ".godot", ".graphify", "node_modules", "graphify-out"}
    for path in root.rglob("*.gd"):
        if any(part in skip_dirs for part in path.parts):
            continue
        yield path


def load_graph(graph_path: Path):
    """
    Baca graph.json, bangun index: source_file -> node id.
    Mengembalikan dict kosong kalau graph_path tidak ada / gagal parse.
    """
    if not graph_path or not graph_path.exists():
        return {}

    try:
        data = json.loads(graph_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"  [WARN] Gagal baca graph.json: {e}")
        return {}

    index = {}
    for node in data.get("nodes", []):
        src = node.get("source_file")
        if src:
            # Normalisasi separator supaya cocok dengan res:// path (selalu forward slash)
            norm_src = src.replace("\\", "/")
            index[norm_src] = node.get("id")

    print(f"  Index graph.json: {len(index)} node dengan source_file")
    return index


def resolve_target_id(res_path: str, graph_index: dict):
    """
    res_path contoh: res://UI/Desert/Desert 7.png
    Cocokkan ke source_file di graph_index. Kalau tidak ketemu, return None
    (berarti target belum ada sebagai node di graph, perlu ditambahkan manual).
    """
    clean = res_path.replace("res://", "").strip()
    return graph_index.get(clean), clean


def make_script_node_id(rel_path: str):
    """Buat id konsisten untuk node script .gd, mirip gaya id graphify (snake_case dari path)."""
    stem = rel_path.rsplit(".", 1)[0]
    slug = re.sub(r'[^a-zA-Z0-9]+', '_', stem).strip('_').lower()
    return f"gdscript_{slug}"


def extract_edges(gd_file: Path, root: Path, graph_index: dict):
    """Baca satu file .gd, kembalikan (script_node, list_edges, list_unmatched)."""
    edges = []
    unmatched = []

    try:
        text = gd_file.read_text(encoding="utf-8", errors="ignore")
    except Exception as e:
        print(f"  [WARN] Gagal baca {gd_file}: {e}")
        return None, edges, unmatched

    rel_source = str(gd_file.relative_to(root)).replace("\\", "/")
    script_node_id = make_script_node_id(rel_source)

    class_match = CLASS_NAME_PATTERN.search(text)
    class_name = class_match.group(1) if class_match else gd_file.stem

    script_node = {
        "id": script_node_id,
        "label": class_name,
        "file_type": "code",
        "source_file": rel_source,
        "_origin": "ast",
    }

    for line_no, line in enumerate(text.splitlines(), start=1):
        for match in LOAD_PATTERN.finditer(line):
            raw_path = match.group(1)
            target_id, clean_path = resolve_target_id(raw_path, graph_index)

            if target_id:
                edges.append({
                    "relation": "loads",
                    "confidence": "EXTRACTED",
                    "confidence_score": 1.0,
                    "source_file": rel_source,
                    "source_location": f"L{line_no}",
                    "weight": 1.0,
                    "_origin": "ast",
                    "source": script_node_id,
                    "target": target_id,
                })
            else:
                # Target belum ada sebagai node di graph.json — dicatat terpisah
                unmatched.append({
                    "gd_file": rel_source,
                    "line": line_no,
                    "raw_path": raw_path,
                    "normalized_path": clean_path,
                })

    return script_node, edges, unmatched


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Root folder project Godot (default: .)")
    parser.add_argument("--graph", default=None, help="Path ke graph.json graphify (opsional, untuk matching id node)")
    parser.add_argument("--out", default="gd_edges.json", help="Path file output JSON")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    graph_index = load_graph(Path(args.graph)) if args.graph else {}

    gd_files = list(find_gd_files(root))
    print(f"Scanning {len(gd_files)} file .gd di bawah {root} ...")

    all_script_nodes = []
    all_edges = []
    all_unmatched = []

    for gd_file in gd_files:
        script_node, edges, unmatched = extract_edges(gd_file, root, graph_index)
        if script_node is None:
            continue
        if edges or unmatched:
            print(f"  {script_node['source_file']}: {len(edges)} edge matched, {len(unmatched)} unmatched")
        if edges:
            all_script_nodes.append(script_node)
        all_edges.extend(edges)
        all_unmatched.extend(unmatched)

    output = {
        "new_nodes": all_script_nodes,
        "new_edges": all_edges,
        "unmatched_targets": all_unmatched,
    }

    out_path = Path(args.out)
    out_path.write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"\nSelesai.")
    print(f"  - {len(all_script_nodes)} node script baru")
    print(f"  - {len(all_edges)} edge baru (cocok dengan node graph.json yang ada)")
    print(f"  - {len(all_unmatched)} referensi asset tidak ketemu node-nya di graph.json")
    print(f"Output ditulis ke: {out_path}")
    print("File .gd dan graph.json ASLI tidak diubah (read-only).")

    if all_unmatched:
        print("\nContoh unmatched (perlu dicek manual, mungkin path res:// beda format):")
        for u in all_unmatched[:5]:
            print(f"  {u['gd_file']}:{u['line']} -> {u['normalized_path']}")


if __name__ == "__main__":
    main()