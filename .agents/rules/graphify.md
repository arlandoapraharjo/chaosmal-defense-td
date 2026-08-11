---
trigger: always_on
description: Consult the graphify knowledge graph and Godot indexes at graphify-out/ for codebase and architecture questions.
---

## graphify

This project has a graphify knowledge graph and Godot custom indexes at graphify-out/.

Rules:
- **Godot Index First**: For tasks involving GDScript (`.gd`) or Scene (`.tscn`) files, consult `graphify-out/gd_index.json` and `graphify-out/tscn_index.json` *before* reading raw source files to preserve context window tokens.
- **Querying the Graph**: For codebase or architecture questions, first run `graphify query "<question>"` (CLI) or `query_graph` (MCP) to traverse the merged graph (which contains GDScript and scene nodes). Use `graphify path` for relationships and `graphify explain` for concepts.
- **Index Freshness Check**: At the start of a session, check if indexes are fresh using:
  `python graphify-out/godot_index.py --check`
- **Rebuilding after changes**: After modifying any code or scene files in this session, keep the graph and indexes current by running the `refresh-graph` workflow, which runs:
  `python graphify-out/godot_index.py --force`
  `python graphify-out/merge_to_graph.py --force-update`
