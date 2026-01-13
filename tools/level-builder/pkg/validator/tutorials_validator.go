package validator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

const (
	LessonsDir = "../../assets/lessons"
)

// ValidateTutorials validates lesson files (tutorials) with relaxed rules compared to main levels.
// If checkSolvable is true, also run solvability checks with the provided maxStates.
func ValidateTutorials(checkSolvable bool, maxStates int) error {
	files, err := filepath.Glob(filepath.Join(LessonsDir, "lesson_*.json"))
	if err != nil {
		return err
	}
	if len(files) == 0 {
		fmt.Println("No lesson files found to validate.")
		return nil
	}

	for _, f := range files {
		if err := validateLessonFile(f); err != nil {
			return fmt.Errorf("lesson %s validation failed: %w", filepath.Base(f), err)
		}

		if checkSolvable {
			// Convert lesson to level model and run solvability
			bytes, err := os.ReadFile(f)
			if err != nil {
				return err
			}
			var lvl model.Level
			if err := json.Unmarshal(bytes, &lvl); err != nil {
				return err
			}
			ok, err := IsSolvable(lvl, maxStates)
			if err != nil {
				return fmt.Errorf("solvability check failed for %s: %w", filepath.Base(f), err)
			}
			if !ok {
				return fmt.Errorf("lesson %s appears UNSOLVABLE (maxStates=%d)", filepath.Base(f), maxStates)
			}
		}
	}

	fmt.Println("All lessons validated successfully.")
	return nil
}

func validateLessonFile(path string) error {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var lvl model.Level
	if err := json.Unmarshal(bytes, &lvl); err != nil {
		return err
	}

	// 1. Check ID matches filename
	base := filepath.Base(path)
	expectedName := fmt.Sprintf("lesson_%d.json", lvl.ID)
	if base != expectedName {
		return fmt.Errorf("filename %s does not match ID %d", base, lvl.ID)
	}

	// 2. Check Grid Size (>=2x2)
	if len(lvl.GridSize) != 2 || lvl.GridSize[0] < 2 || lvl.GridSize[1] < 2 {
		return fmt.Errorf("invalid grid size")
	}

	// 3. In-bounds and no overlaps (relaxed occupancy: not required to be 100%)
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	seen := make(map[int]bool)
	for _, v := range lvl.Vines {
		for _, p := range v.OrderedPath {
			if p.X < 0 || p.X >= w || p.Y < 0 || p.Y >= h {
				return fmt.Errorf("out of bounds cell (%d,%d)", p.X, p.Y)
			}
			idx := p.Y*w + p.X
			if seen[idx] {
				return fmt.Errorf("overlap at (%d,%d)", p.X, p.Y)
			}
			seen[idx] = true
		}
	}

	// 4. Colors: if color_scheme present, enforce bounds; else skip
	if len(lvl.ColorScheme) > 0 {
		for _, v := range lvl.Vines {
			if v.ColorIndex >= len(lvl.ColorScheme) {
				return fmt.Errorf("vine %s color_index out of bounds", v.ID)
			}
		}
	}

	// 5. Structure: require max_moves >= 1
	if lvl.MaxMoves < 1 {
		return fmt.Errorf("invalid max_moves")
	}

	return nil
}
