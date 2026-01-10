package validator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

const (
	TutorialsDir = "../../assets/tutorials"
)

// ValidateTutorials validates tutorial levels with relaxed rules compared to main levels.
func ValidateTutorials() error {
	files, err := filepath.Glob(filepath.Join(TutorialsDir, "tutorial_*.json"))
	if err != nil {
		return err
	}
	if len(files) == 0 {
		fmt.Println("No tutorial files found to validate.")
		return nil
	}

	for _, f := range files {
		if err := validateTutorialFile(f); err != nil {
			return fmt.Errorf("tutorial %s validation failed: %w", filepath.Base(f), err)
		}
	}

	fmt.Println("All tutorials validated successfully.")
	return nil
}

func validateTutorialFile(path string) error {
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
	expectedName := fmt.Sprintf("tutorial_%d.json", lvl.ID)
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
