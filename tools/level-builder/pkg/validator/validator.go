package validator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

const (
	LevelsDir   = "../../assets/levels"
	ModulesFile = "../../assets/data/modules.json"
)

func Validate(checkSolvable bool, maxStates int) error {
	// 1. Validate Modules
	if err := validateModules(); err != nil {
		return fmt.Errorf("module validation failed: %w", err)
	}

	// 2. Validate Levels
	files, err := filepath.Glob(filepath.Join(LevelsDir, "level_*.json"))
	if err != nil {
		return err
	}

	for _, f := range files {
		lvl, err := readLevelFile(f)
		if err != nil {
			return fmt.Errorf("level %s validation failed: %w", filepath.Base(f), err)
		}
		if checkSolvable {
			ok, err := IsSolvable(lvl, maxStates)
			if err != nil {
				return fmt.Errorf("solvability check failed for %s: %w", filepath.Base(f), err)
			}
			if !ok {
				return fmt.Errorf("level %s appears UNSOLVABLE (maxStates=%d)", filepath.Base(f), maxStates)
			}
		}
	}

	fmt.Println("All levels and modules validated successfully.")
	return nil
}

func validateModules() error {
	bytes, err := os.ReadFile(ModulesFile)
	if err != nil {
		return err
	}
	var reg model.ModuleRegistry
	if err := json.Unmarshal(bytes, &reg); err != nil {
		return err
	}

	// Check for duplicates
	seen := make(map[int]bool)
	for _, m := range reg.Modules {
		for _, lid := range m.Levels {
			if seen[lid] {
				return fmt.Errorf("level %d appears in multiple modules", lid)
			}
			seen[lid] = true
		}
		if seen[m.ChallengeLevel] {
			return fmt.Errorf("level %d appears in multiple modules", m.ChallengeLevel)
		}
		seen[m.ChallengeLevel] = true

		if m.ThemeSeed == "" {
			return fmt.Errorf("module %d missing theme_seed", m.ID)
		}
	}

	return nil
}

func readLevelFile(path string) (model.Level, error) {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return model.Level{}, err
	}
	var lvl model.Level
	if err := json.Unmarshal(bytes, &lvl); err != nil {
		return model.Level{}, err
	}

	// 1. Check ID matches filename
	base := filepath.Base(path)
	expectedName := fmt.Sprintf("level_%d.json", lvl.ID)
	if base != expectedName {
		return model.Level{}, fmt.Errorf("filename %s does not match ID %d", base, lvl.ID)
	}

	// 2. Check Grid Size
	if len(lvl.GridSize) != 2 || lvl.GridSize[0] < 2 || lvl.GridSize[1] < 2 {
		return model.Level{}, fmt.Errorf("invalid grid size")
	}

	// 3. Check Occupancy (Strict 100% or Mask)
	if !checkOccupancy(lvl) {
		return model.Level{}, fmt.Errorf("grid not 100%% occupied")
	}

	// 4. Check Colors
	if len(lvl.ColorScheme) < 1 {
		return model.Level{}, fmt.Errorf("missing color_scheme")
	}
	for _, v := range lvl.Vines {
		if v.ColorIndex >= len(lvl.ColorScheme) {
			return model.Level{}, fmt.Errorf("vine %s color_index out of bounds", v.ID)
		}
	}

	// 5. Structure
	if lvl.MaxMoves < 1 {
		return model.Level{}, fmt.Errorf("invalid max_moves")
	}

	return lvl, nil
}

func checkOccupancy(lvl model.Level) bool {
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	grid := make([]bool, w*h)

	// Mark occupied
	count := 0
	for _, v := range lvl.Vines {
		for _, p := range v.OrderedPath {
			if p.X < 0 || p.X >= w || p.Y < 0 || p.Y >= h {
				return false // Out of bounds
			}
			idx := p.Y*w + p.X
			if grid[idx] {
				return false // Overlap
			}
			grid[idx] = true
			count++
		}
	}

	return count == w*h
	// TODO: Handle Mask if present
}
