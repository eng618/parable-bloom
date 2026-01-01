import json
import os

import sys
import shutil

LEVELS_DIR = 'assets/levels'

head_delta = {
    'right': (1, 0),
    'left': (-1, 0),
    'up': (0, 1),
    'down': (0, -1),
}


def find_violations(data):
    violations = []
    vines = data.get('vines', [])
    for vine in vines:
        vid = vine.get('id')
        hd = vine.get('head_direction')
        path_list = vine.get('ordered_path', [])
        if len(path_list) < 2:
            violations.append((vid, 'too_short', f'ordered_path length {len(path_list)}'))
            continue
        head = path_list[0]
        neck = path_list[1]
        if hd not in head_delta:
            violations.append((vid, 'unknown_head_direction', hd))
            continue
        dx, dy = head_delta[hd]
        expected_neck_x = head['x'] - dx
        expected_neck_y = head['y'] - dy
        if neck['x'] != expected_neck_x or neck['y'] != expected_neck_y:
            violations.append((vid, 'neck_mismatch', {
                'head': head, 'neck': neck, 'expected_neck': {'x': expected_neck_x, 'y': expected_neck_y}, 'head_direction': hd
            }))
    return violations


def main():
    fix_mode = '--fix' in sys.argv
    backup_dir = os.path.join('scripts', 'backups')
    if fix_mode and not os.path.exists(backup_dir):
        os.makedirs(backup_dir)

    violations = []
    files_checked = 0

    for fname in sorted(os.listdir(LEVELS_DIR)):
        if not fname.startswith('level_') or not fname.endswith('.json'):
            continue
        path = os.path.join(LEVELS_DIR, fname)
        files_checked += 1
        with open(path, 'r') as f:
            data = json.load(f)

        file_violations = find_violations(data)
        if file_violations:
            for v in file_violations:
                violations.append((fname, v[0], v[1], v[2]))

            if fix_mode:
                # backup original
                shutil.copy(path, os.path.join(backup_dir, fname + '.bak'))
                # attempt to fix by reversing offending vines where neck_mismatch or too_short
                changed = False
                for vine in data.get('vines', []):
                    vid = vine.get('id')
                    for v in file_violations:
                        if v[0] == vid and v[1] in ('neck_mismatch', 'too_short'):
                            # reverse ordered_path to put head at index 0
                            vine['ordered_path'] = list(reversed(vine.get('ordered_path', [])))
                            changed = True
                            break
                if changed:
                    with open(path, 'w') as f:
                        json.dump(data, f, indent=2)

    # Print results
    if not violations:
        print(f'OK: Checked {files_checked} level files — no head/neck orientation violations found.')
        return 0
    else:
        print(f'Found {len(violations)} violations in {files_checked} level files:')
        for v in violations:
            fname, vid, code, info = v
            print(f'- {fname} vine {vid}: {code} -> {info}')
        if fix_mode:
            print('\nAuto-fix mode applied: backed up originals to scripts/backups and reversed offending ordered_path entries. Re-run this script without --fix to verify no remaining violations.')
            # Re-run to verify
            return 1
        return 2


if __name__ == '__main__':
    sys.exit(main())
