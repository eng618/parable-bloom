#!/usr/bin/env python3
import json
from pathlib import Path

levels_dir = Path("assets/levels")
violations = []

for level_file in sorted(levels_dir.glob("level_*.json")):
    with open(level_file) as f:
        level = json.load(f)
    
    level_id = level["id"]
    grid_size = level["grid_size"]
    width, height = grid_size[0], grid_size[1]
    total_cells = width * height
    
    # Count occupied cells
    occupied = set()
    for vine in level.get("vines", []):
        for pt in vine.get("ordered_path", []):
            x, y = pt["x"], pt["y"]
            occupied.add((x, y))
    
    coverage = len(occupied) / total_cells if total_cells > 0 else 0
    
    if coverage < 0.75:
        violations.append({
            "level": level_id,
            "coverage": coverage,
            "occupied": len(occupied),
            "total": total_cells,
        })

if violations:
    print(f"Found {len(violations)} levels with coverage < 75%:")
    for v in violations:
        print(f"  Level {v['level']:3d}: {v['coverage']*100:5.1f}% ({v['occupied']}/{v['total']})")
else:
    print("All levels have coverage >= 75%")
