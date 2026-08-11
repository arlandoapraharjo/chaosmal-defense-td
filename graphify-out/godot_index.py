#!/usr/bin/env python3
"""
godot_index.py  —  Lightweight Godot project indexer (read-only)

Menghasilkan dua file index ringkas:
  - gd_index.json   : class_name, fungsi publik, signals, load/preload, extends
  - tscn_index.json : asset ExtResource per scene

Freshness check otomatis: hanya rebuild kalau ada file .gd / .tscn yang
lebih baru dari index yang sudah ada.

Usage:
    python godot_index.py                          # rebuild kalau stale
    python godot_index.py --force                  # selalu rebuild
    python godot_index.py --root D:/Godot/Game/X   # root custom
    python godot_index.py --check                  # cek status, tanpa rebuild
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Optional

# ── konstanta ────────────────────────────────────────────────────────────────
ROOT_DEFAULT     = Path(__file__).parent.parent  # graphify-out/../ = project root
OUT_DIR          = Path(__file__).parent          # graphify-out/
GD_INDEX_PATH    = OUT_DIR / "gd_index.json"
TSCN_INDEX_PATH  = OUT_DIR / "tscn_index.json"

SKIP_DIRS = {".git", ".godot", "graphify-out", "Python_Venv", "node_modules"}

# ── regex patterns ────────────────────────────────────────────────────────────
RE_CLASS_NAME  = re.compile(r'^\s*class_name\s+(\w+)', re.MULTILINE)
RE_EXTENDS     = re.compile(r'^\s*extends\s+(\S+)', re.MULTILINE)
RE_SIGNAL      = re.compile(r'^\s*signal\s+(\w+)(?:\(([^)]*)\))?', re.MULTILINE)
# fungsi publik: "func name(" — tidak dimulai _ (konvensi private GDScript)
RE_FUNC_PUBLIC = re.compile(r'^\s*func\s+([a-zA-Z][a-zA-Z0-9_]*)\s*\(([^)]*)\)', re.MULTILINE)
# load("res://...") dan preload("res://...")
RE_LOAD        = re.compile(r'\b(?:load|preload)\s*\(\s*["\']([^"\']+)["\']\s*\)')
# @export var name: Type — properti publik penting
RE_EXPORT_VAR  = re.compile(r'^\s*@export\s+var\s+(\w+)\s*(?::\s*(\w+))?', re.MULTILINE)

# TSCN: ExtResource path / uid
RE_EXT_RES     = re.compile(r'\[ext_resource\s[^\]]*\]')
RE_EXT_PATH    = re.compile(r'path="([^"]+)"')
RE_EXT_TYPE    = re.compile(r'type="([^"]+)"')
RE_EXT_UID     = re.compile(r'uid="([^"]+)"')
RE_EXT_ID      = re.compile(r'\bid="([^"]+)"')
RE_SCENE_UID   = re.compile(r'\[gd_scene[^\]]*uid="([^"]+)"')
RE_SCENE_NAME  = re.compile(r'\[node name="([^"]+)"\s+type="([^"]+)"[^\]]*?\](?!\s*\n\s*\[)', re.MULTILINE)


# ── helpers ───────────────────────────────────────────────────────────────────
def find_files(root: Path, extension: str):
    """Rekursif cari file berekstensi tertentu, skip SKIP_DIRS."""
    for path in root.rglob(f"*{extension}"):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        yield path


def rel(path: Path, root: Path) -> str:
    """Relative path dengan forward slash."""
    return str(path.relative_to(root)).replace("\\", "/")


def max_mtime(files) -> float:
    """mtime terbesar dari daftar Path."""
    mt = 0.0
    for f in files:
        try:
            mt = max(mt, f.stat().st_mtime)
        except OSError:
            pass
    return mt


def index_mtime(index_path: Path) -> float:
    try:
        return index_path.stat().st_mtime
    except OSError:
        return 0.0


def is_stale(index_path: Path, source_files) -> bool:
    """True kalau index tidak ada atau ada source file yang lebih baru."""
    if not index_path.exists():
        return True
    idx_mt = index_mtime(index_path)
    for f in source_files:
        try:
            if f.stat().st_mtime > idx_mt:
                return True
        except OSError:
            pass
    return False


# ── GDScript extractor ────────────────────────────────────────────────────────
def parse_gd_file(gd_path: Path, root: Path) -> dict:
    """Extract metadata dari satu file .gd."""
    try:
        text = gd_path.read_text(encoding="utf-8", errors="ignore")
    except OSError as e:
        return {"error": str(e)}

    rel_path = rel(gd_path, root)

    # class_name & extends
    cm = RE_CLASS_NAME.search(text)
    em = RE_EXTENDS.search(text)

    # signals
    signals = []
    for m in RE_SIGNAL.finditer(text):
        sig = {"name": m.group(1)}
        if m.group(2) and m.group(2).strip():
            sig["params"] = [p.strip() for p in m.group(2).split(",") if p.strip()]
        signals.append(sig)

    # fungsi publik (tidak diawali _)
    functions = []
    for m in RE_FUNC_PUBLIC.finditer(text):
        fn_name = m.group(1)
        if fn_name.startswith("_"):
            continue  # skip private/lifecycle
        params_raw = m.group(2).strip()
        params = [p.strip().split(":")[0].strip() for p in params_raw.split(",") if p.strip()] if params_raw else []
        functions.append({"name": fn_name, "params": params})

    # load / preload calls
    loads = []
    for line_no, line in enumerate(text.splitlines(), 1):
        for m in RE_LOAD.finditer(line):
            raw = m.group(1)
            loads.append({
                "line": line_no,
                "raw": raw,
                "path": raw.replace("res://", ""),
                "call": "preload" if "preload" in line[max(0, m.start()-3):m.start()+7] else "load",
            })

    # @export vars (properti publik)
    exports = []
    for m in RE_EXPORT_VAR.finditer(text):
        entry = {"name": m.group(1)}
        if m.group(2):
            entry["type"] = m.group(2)
        exports.append(entry)

    return {
        "file": rel_path,
        "class_name": cm.group(1) if cm else None,
        "extends": em.group(1) if em else None,
        "signals": signals,
        "functions": functions,
        "loads": loads,
        "exports": exports,
    }


def build_gd_index(root: Path) -> dict:
    gd_files = list(find_files(root, ".gd"))
    scripts = []
    for gd in sorted(gd_files, key=lambda p: str(p)):
        scripts.append(parse_gd_file(gd, root))

    return {
        "_meta": {
            "generated_by": "godot_index.py",
            "total_scripts": len(scripts),
            "root": str(root),
        },
        "scripts": scripts,
    }


# ── TSCN extractor ────────────────────────────────────────────────────────────
def parse_tscn_file(tscn_path: Path, root: Path) -> dict:
    """Extract ext_resource references dari satu .tscn."""
    try:
        text = tscn_path.read_text(encoding="utf-8", errors="ignore")
    except OSError as e:
        return {"error": str(e)}

    rel_path = rel(tscn_path, root)

    # uid scene
    uid_m = RE_SCENE_UID.search(text)

    # ext_resources
    resources = []
    for block in RE_EXT_RES.findall(text):
        path_m = RE_EXT_PATH.search(block)
        type_m = RE_EXT_TYPE.search(block)
        uid_m2 = RE_EXT_UID.search(block)
        id_m   = RE_EXT_ID.search(block)
        if path_m:
            entry = {
                "path": path_m.group(1).replace("res://", ""),
                "raw_path": path_m.group(1),
            }
            if type_m:
                entry["type"] = type_m.group(1)
            if uid_m2:
                entry["uid"] = uid_m2.group(1)
            if id_m:
                entry["id"] = id_m.group(1)
            resources.append(entry)

    # top-level node type
    nodes_preview = []
    for m in RE_SCENE_NAME.finditer(text):
        nodes_preview.append({"name": m.group(1), "type": m.group(2)})
        if len(nodes_preview) >= 5:
            break

    return {
        "file": rel_path,
        "scene_uid": uid_m.group(1) if uid_m else None,
        "ext_resources": resources,
        "nodes_preview": nodes_preview,
    }


def build_tscn_index(root: Path) -> dict:
    tscn_files = list(find_files(root, ".tscn"))
    scenes = []
    for tscn in sorted(tscn_files, key=lambda p: str(p)):
        scenes.append(parse_tscn_file(tscn, root))

    # cross-reference: asset path → list of scenes yang memakainya
    asset_to_scenes: dict = {}
    for scene in scenes:
        for res in scene.get("ext_resources", []):
            p = res["path"]
            if p not in asset_to_scenes:
                asset_to_scenes[p] = []
            asset_to_scenes[p].append(scene["file"])

    return {
        "_meta": {
            "generated_by": "godot_index.py",
            "total_scenes": len(scenes),
            "root": str(root),
        },
        "scenes": scenes,
        "asset_to_scenes": asset_to_scenes,  # index terbalik — "PNG X dipakai di scene mana?"
    }


# ── freshness check & rebuild ─────────────────────────────────────────────────
def check_and_rebuild(root: Path, force: bool = False, check_only: bool = False) -> tuple[bool, bool]:
    """
    Returns (gd_rebuilt, tscn_rebuilt).
    Kalau check_only=True, hanya print status tanpa rebuild.
    """
    gd_files   = list(find_files(root, ".gd"))
    tscn_files = list(find_files(root, ".tscn"))

    gd_stale   = force or is_stale(GD_INDEX_PATH, gd_files)
    tscn_stale = force or is_stale(TSCN_INDEX_PATH, tscn_files)

    print(f"GDScript files  : {len(gd_files)}")
    print(f"TSCN files      : {len(tscn_files)}")
    gd_status   = 'STALE/MISSING -> will rebuild' if gd_stale else 'fresh [OK]'
    tscn_status = 'STALE/MISSING -> will rebuild' if tscn_stale else 'fresh [OK]'
    print(f"gd_index.json   : {gd_status}")
    print(f"tscn_index.json : {tscn_status}")

    if check_only:
        return False, False

    gd_rebuilt = tscn_rebuilt = False

    if gd_stale:
        print("\nBuilding gd_index.json ...")
        idx = build_gd_index(root)
        GD_INDEX_PATH.write_text(json.dumps(idx, indent=2, ensure_ascii=False), encoding="utf-8")
        total_funcs = sum(len(s.get("functions", [])) for s in idx["scripts"])
        total_loads = sum(len(s.get("loads", [])) for s in idx["scripts"])
        print(f"  OK {len(idx['scripts'])} scripts | {total_funcs} public funcs | {total_loads} load/preload calls")
        gd_rebuilt = True

    if tscn_stale:
        print("\nBuilding tscn_index.json ...")
        idx = build_tscn_index(root)
        TSCN_INDEX_PATH.write_text(json.dumps(idx, indent=2, ensure_ascii=False), encoding="utf-8")
        total_res = sum(len(s.get("ext_resources", [])) for s in idx["scenes"])
        print(f"  OK {len(idx['scenes'])} scenes | {total_res} ext_resource refs | {len(idx['asset_to_scenes'])} unique assets")
        tscn_rebuilt = True

    if not gd_stale and not tscn_stale:
        print("\nSemua index masih fresh — tidak perlu rebuild.")

    return gd_rebuilt, tscn_rebuilt


# ── main ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root",  default=str(ROOT_DEFAULT), help="Root project Godot (default: parent folder script ini)")
    parser.add_argument("--force", action="store_true",       help="Paksa rebuild meski index masih fresh")
    parser.add_argument("--check", action="store_true",       help="Hanya cek status freshness, tanpa rebuild")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"ERROR: root tidak ditemukan: {root}", file=sys.stderr)
        sys.exit(1)

    print(f"Root  : {root}")
    print(f"Output: {OUT_DIR}\n")

    gd_rebuilt, tscn_rebuilt = check_and_rebuild(root, force=args.force, check_only=args.check)

    if gd_rebuilt or tscn_rebuilt:
        print(f"\nOutput:")
        if gd_rebuilt:
            sz = GD_INDEX_PATH.stat().st_size
            print(f"  {GD_INDEX_PATH}  ({sz:,} bytes)")
        if tscn_rebuilt:
            sz = TSCN_INDEX_PATH.stat().st_size
            print(f"  {TSCN_INDEX_PATH}  ({sz:,} bytes)")
        print("\nBaca index ini sebelum menyentuh .gd/.tscn apapun — hemat token!")


if __name__ == "__main__":
    main()
