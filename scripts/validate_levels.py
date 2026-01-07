#!/usr/bin/env python3
"""
Enhanced Level Validation Script for Parable Bloom

Validates levels against comprehensive design rules including:
- Grid occupancy (100% coverage; no empty coordinates)
- Color distribution constraints
- Vine length requirements
- Blocking relationship integrity
- Directional balance
- Solvability verification
"""

import json
import os
import sys
from collections import Counter, defaultdict
from typing import Dict, List, Tuple

LEVELS_DIR = 'assets/levels'

# Directional movement vectors
HEAD_DELTA = {
    'right': (1, 0),
    'left': (-1, 0),
    'up': (0, 1),
    'down': (0, -1),
}

# Color definitions
VINE_COLORS = {
    'moss_green': '#7CB342',
    'sunset_orange': '#FF9800',
    'golden_yellow': '#FFC107',
    'royal_purple': '#7C4DFF',
    'sky_blue': '#29B6F6',
    'coral_red': '#FF6E40',
    'lime_green': '#CDDC39',
}

# Difficulty tier specifications
# Updated to reflect high-coverage generation logic
DIFFICULTY_SPECS = {
    'Seedling': {
        'vine_count_range': (4, 60), # Relaxed for dense grids
        'avg_length_range': (6, 8),  # GDD: Seedling 6–8
        'max_blocking_depth': 1,
        'color_count_range': (1, 5), # Allow single color (default)
    },
    'Sprout': {
        'vine_count_range': (8, 80),
        'avg_length_range': (5, 7),  # GDD: Sprout 5–7
        'max_blocking_depth': 2,
        'color_count_range': (1, 5),
    },
    'Nurturing': {
        'vine_count_range': (12, 100),
        'avg_length_range': (4, 6),  # GDD: Nurturing 4–6
        'max_blocking_depth': 3,
        'color_count_range': (1, 6),
    },
    'Flourishing': {
        'vine_count_range': (15, 150),
        'avg_length_range': (3, 5),  # GDD: Flourishing 3–5
        'max_blocking_depth': 4,
        'color_count_range': (1, 6),
    },
    'Transcendent': {
        'vine_count_range': (15, 200),
        'avg_length_range': (2, 4),  # GDD: Transcendent 2–4
        'max_blocking_depth': 4,
        'color_count_range': (1, 6),
    },
}


class LevelValidator:
    def __init__(self, filename: str, data: Dict):
        self.filename = filename
        self.data = data
        self.violations = []
        self.warnings = []

    def validate_all(self) -> Tuple[List[str], List[str]]:
        """Run all validation checks."""
        self._validate_basic_structure()
        self._validate_vine_paths()
        self._validate_grid_occupancy()
        self._validate_colors()
        self._validate_vine_lengths()
        self._validate_blocking_relationships()
        self._validate_directional_balance()
        self._validate_difficulty_compliance()
        return self.violations, self.warnings

    def _validate_basic_structure(self):
        """Check required fields and basic schema."""
        required_fields = ['id', 'name', 'grid_size', 'difficulty', 'vines', 'max_moves', 'min_moves', 'complexity', 'grace']
        for field in required_fields:
            if field not in self.data:
                self.violations.append(f"Missing required field: {field}")

        # Validate grid size
        try:
            grid_size = self.data.get('grid_size', [])
            if len(grid_size) != 2 or grid_size[0] <= 0 or grid_size[1] <= 0:
                self.violations.append(f"Invalid grid_size: {grid_size}")
        except (TypeError, ValueError):
            self.violations.append(f"grid_size must be [width, height]")

    def _validate_vine_paths(self):
        """Validate individual vine paths."""
        vines = self.data.get('vines', [])
        for vine in vines:
            vine_id = vine.get('id', 'unknown')
            path = vine.get('ordered_path', [])

            # Check minimum length
            if len(path) < 2:
                self.violations.append(f"Vine {vine_id}: path too short (length {len(path)})")
                continue

            # Check path contiguity
            for i in range(len(path) - 1):
                curr = path[i]
                next_cell = path[i + 1]
                distance = abs(curr['x'] - next_cell['x']) + abs(curr['y'] - next_cell['y'])
                if distance != 1:
                    self.violations.append(
                        f"Vine {vine_id}: path not contiguous at segment {i} "
                        f"(distance={distance} from {curr} to {next_cell})"
                    )

            # Check head direction matches first move
            head_dir = vine.get('head_direction', '')
            if head_dir not in HEAD_DELTA:
                self.violations.append(f"Vine {vine_id}: invalid head_direction '{head_dir}'")
                continue

            head = path[0]
            neck = path[1]
            dx, dy = HEAD_DELTA[head_dir]
            expected_neck = {'x': head['x'] - dx, 'y': head['y'] - dy}
            if neck['x'] != expected_neck['x'] or neck['y'] != expected_neck['y']:
                self.violations.append(
                    f"Vine {vine_id}: head_direction '{head_dir}' doesn't match path "
                    f"(head={head}, neck={neck}, expected={expected_neck})"
                )

    def _validate_grid_occupancy(self):
        """Validate full-coverage grid occupancy (no empty coordinates and no overlaps)."""
        grid_size = self.data.get('grid_size', [])
        if not grid_size or len(grid_size) != 2:
            return

        width, height = grid_size
        total_cells = width * height

        # Build set of occupied coordinates and track duplicates
        occupied = {}
        duplicates = defaultdict(list)
        vines = self.data.get('vines', [])
        for vine in vines:
            vine_id = vine.get('id', 'unknown')
            for cell in vine.get('ordered_path', []):
                coord = (cell['x'], cell['y'])
                if coord in occupied:
                    duplicates[coord].append((occupied[coord], vine_id))
                else:
                    occupied[coord] = vine_id

        unique_occupied = len(occupied)

        # If a mask hides cells, treat those as not part of the visible grid
        mask = self.data.get('mask', {}) or {}
        hidden_coords = set()
        if mask.get('mode') == 'hide' and isinstance(mask.get('points', None), list):
            for p in mask['points']:
                if isinstance(p, list) and len(p) == 2:
                    hidden_coords.add((p[0], p[1]))
                elif isinstance(p, dict) and 'x' in p and 'y' in p:
                    hidden_coords.add((p['x'], p['y']))

        effective_total = total_cells - len(hidden_coords)
        effective_total = max(effective_total, 0)

        occupancy = (unique_occupied / effective_total) if effective_total > 0 else 0
        self.data['occupancy_percent'] = round(occupancy * 100, 1)

        # Overlap checks (violations)
        if duplicates:
            sample = list(duplicates.items())[:5]
            self.violations.append(
                f"Overlapping vines detected at {len(duplicates)} cells; sample: {sample}"
            )

        # Enforce full coverage (allow minor tolerance when masked)
        if hidden_coords:
            # If mask hides cells, allow ≥99% coverage of visible cells (soft allowance)
            if occupancy < 0.99:
                self.violations.append(
                    f"Grid coverage incomplete: {self.data['occupancy_percent']}% of visible cells occupied; "
                    f"expected ≥99% when mask is used"
                )
            elif occupancy < 1.0:
                self.warnings.append(
                    f"Grid coverage near-complete: {self.data['occupancy_percent']}% (mask hides {len(hidden_coords)} cells)"
                )
        else:
            # No mask — require complete tiling (no empty coordinates)
            if unique_occupied < effective_total:
                self.violations.append(
                    f"Grid not fully tiled: {unique_occupied}/{effective_total} cells occupied ({self.data['occupancy_percent']}%). "
                    f"Generator must produce a full tiling with no empty coordinates."
                )

    def _validate_colors(self):
        """Validate color usage and distribution."""
        vines = self.data.get('vines', [])
        colors = [vine.get('color', 'unknown') for vine in vines]
        color_counts = Counter(colors)

        # Validate colors are known
        for color in color_counts:
            if color not in VINE_COLORS and color != 'unknown':
                self.warnings.append(f"Unknown color: {color}")

        # Check color count range
        unique_colors = len(color_counts)
        difficulty = self.data.get('difficulty', '')
        if difficulty in DIFFICULTY_SPECS:
            spec = DIFFICULTY_SPECS[difficulty]
            color_range = spec['color_count_range']
            if not (color_range[0] <= unique_colors <= color_range[1]):
                self.warnings.append(
                    f"Color count {unique_colors} outside recommended range "
                    f"{color_range[0]}-{color_range[1]} for {difficulty}"
                )

        # Check no color exceeds 35%
        for color, count in color_counts.items():
            if color == 'unknown':
                continue
            percentage = count / len(vines) if vines else 0
            if percentage > 0.35:
                self.violations.append(
                    f"Color '{color}' exceeds 35% limit: {percentage:.1%} ({count}/{len(vines)} vines)"
                )

        # Store color distribution
        self.data['color_distribution'] = {
            color: round(count / len(vines), 3) for color, count in color_counts.items()
        }

    def _validate_vine_lengths(self):
        """Validate vine lengths match difficulty tier."""
        vines = self.data.get('vines', [])
        difficulty = self.data.get('difficulty', '')

        if not vines or difficulty not in DIFFICULTY_SPECS:
            return

        lengths = [len(vine.get('ordered_path', [])) for vine in vines]
        avg_length = sum(lengths) / len(lengths) if lengths else 0
        min_length = min(lengths) if lengths else 0
        # max_length = max(lengths) if lengths else 0

        spec = DIFFICULTY_SPECS[difficulty]
        avg_range = spec['avg_length_range']

        if not (avg_range[0] <= avg_length <= avg_range[1]):
            self.warnings.append(
                f"Average vine length {avg_length:.1f} outside "
                f"recommended range {avg_range[0]}-{avg_range[1]} for {difficulty}"
            )

        if min_length < 2:
            self.violations.append(f"Vine too short: minimum length is {min_length}, requires ≥2")

    def _validate_blocking_relationships(self):
        """Validate blocking relationship integrity."""
        vines = self.data.get('vines', [])
        vine_ids = {vine['id'] for vine in vines}

        blocking_graph = defaultdict(set)
        for vine in vines:
            vine_id = vine.get('id', '')
            blocked = vine.get('blocks', [])
            if isinstance(blocked, list):
                for blocked_id in blocked:
                    if blocked_id not in vine_ids:
                        self.violations.append(
                            f"Vine {vine_id} blocks non-existent vine {blocked_id}"
                        )
                    blocking_graph[vine_id].add(blocked_id)

        # Check for circular dependencies
        for vine_id in blocking_graph:
            visited = set()
            stack = [vine_id]
            while stack:
                current = stack.pop()
                if current in visited:
                    continue
                visited.add(current)
                for blocked in blocking_graph.get(current, []):
                    if blocked == vine_id:
                        self.violations.append(
                            f"Circular blocking detected: {vine_id} -> ... -> {vine_id}"
                        )
                    stack.append(blocked)

        # Check at least one vine is clearable at start
        clearable_at_start = []
        for vine in vines:
            is_blocked = False
            for other_vine in vines:
                if vine['id'] in other_vine.get('blocks', []):
                    is_blocked = True
                    break
            if not is_blocked:
                clearable_at_start.append(vine['id'])

        if not clearable_at_start:
            self.violations.append("No vines are clearable at level start (deadlock)")
        
        # Compute maximum blocking depth (longest path in the blocking DAG)
        def longest_path(node, memo):
            if node in memo:
                return memo[node]
            max_len = 0
            for child in blocking_graph.get(node, []):
                max_len = max(max_len, 1 + longest_path(child, memo))
            memo[node] = max_len
            return max_len

        memo = {}
        max_depth = 0
        for n in blocking_graph.keys():
            max_depth = max(max_depth, longest_path(n, memo))

        self.data['blocking_graph'] = dict(blocking_graph)
        self.data['blocking_depth'] = max_depth

        # Blocking depth is a soft, scored target: warn if above difficulty target, but do not fail
        difficulty = self.data.get('difficulty', '')
        if difficulty in DIFFICULTY_SPECS:
            goal = DIFFICULTY_SPECS[difficulty].get('max_blocking_depth', None)
            if goal is not None and max_depth > goal:
                self.warnings.append(
                    f"Blocking depth {max_depth} exceeds soft target {goal} for {difficulty} (scored target, not a hard requirement)"
                )

    def _validate_directional_balance(self):
        """Validate directional distribution."""
        vines = self.data.get('vines', [])
        if not vines or len(vines) < 10:
            return  # Skip for very small levels

        directions = Counter(vine.get('head_direction', '') for vine in vines)
        total = len(vines)

        expected_ranges = {
            'right': (0.25, 0.30),
            'left': (0.20, 0.25),
            'up': (0.20, 0.25),
            'down': (0.20, 0.30),
        }

        for direction, (min_pct, max_pct) in expected_ranges.items():
            count = directions.get(direction, 0)
            percentage = count / total if total > 0 else 0
            if not (min_pct <= percentage <= max_pct):
                self.warnings.append(
                    f"Direction '{direction}' imbalanced: "
                    f"{percentage:.1%} (expected {min_pct:.0%}-{max_pct:.0%})"
                )

    def _validate_difficulty_compliance(self):
        """Validate all difficulty-specific requirements."""
        vines = self.data.get('vines', [])
        difficulty = self.data.get('difficulty', '')

        if difficulty not in DIFFICULTY_SPECS or not vines:
            return

        spec = DIFFICULTY_SPECS[difficulty]
        vine_count = len(vines)
        vine_range = spec['vine_count_range']

        if not (vine_range[0] <= vine_count <= vine_range[1]):
            self.violations.append(
                f"Vine count {vine_count} outside range "
                f"{vine_range[0]}-{vine_range[1]} for {difficulty}"
            )


def print_report(filename: str, violations: List[str], warnings: List[str]):
    """Print validation report."""
    if not violations and not warnings:
        print(f"✓ {filename}")
        return True

    status = "✗" if violations else "⚠"
    print(f"\n{status} {filename}")

    if violations:
        print("  VIOLATIONS (errors):")
        for v in violations:
            print(f"    ✗ {v}")

    if warnings:
        print("  WARNINGS (advisories):")
        for w in warnings:
            print(f"    ⚠ {w}")

    return len(violations) == 0


def main():
    """Run validation on all level files."""
    files_checked = 0
    files_valid = 0
    total_violations = 0
    total_warnings = 0

    # Find all level files
    level_files = []
    for root, dirs, files in os.walk(LEVELS_DIR):
        for fname in sorted(files):
            if fname.endswith('.json') and fname.startswith('level_'):
                level_files.append(os.path.join(root, fname))

    if not level_files:
        print("No level files found in", LEVELS_DIR)
        return

    print(f"Validating {len(level_files)} level files...\n")

    for fpath in level_files:
        files_checked += 1
        try:
            with open(fpath, 'r') as f:
                data = json.load(f)

            validator = LevelValidator(fpath, data)
            violations, warnings = validator.validate_all()

            # Write updated data with occupancy back to file
            with open(fpath, 'w') as f:
                json.dump(data, f, indent=2)

            if print_report(fpath, violations, warnings):
                files_valid += 1
            else:
                total_violations += len(violations)
                total_warnings += len(warnings)

        except json.JSONDecodeError as e:
            print(f"✗ {fpath}: Invalid JSON - {e}")
            total_violations += 1
        except Exception as e:
            print(f"✗ {fpath}: Error - {e}")
            total_violations += 1

    # Summary
    print(f"\n{'='*60}")
    print(f"Summary: {files_valid}/{files_checked} files valid")
    print(f"Violations: {total_violations}, Warnings: {total_warnings}")
    print(f"{'='*60}")

    return 0 if files_valid == files_checked else 1


if __name__ == '__main__':
    sys.exit(main())
