package validator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

const (
	LevelsDir   = "../../assets/levels"
	ModulesFile = "../../assets/data/modules.json"
)

type LevelStat struct {
	File           string `json:"file"`
	LevelID        int    `json:"level_id"`
	Solvable       bool   `json:"solvable"`
	Solver         string `json:"solver"` // "exact" or "heuristic"
	StatesExplored int    `json:"states_explored"`
	MaxStates      int    `json:"max_states"`
	TimeMs         int64  `json:"time_ms"`
	GaveUp         bool   `json:"gave_up"`
	Error          string `json:"error,omitempty"`
}

// Validate validates the level builder's modules and level files, and optionally runs solvability checks.
//
// When checkSolvable is false, Validate only validates modules and parses all level files matching
// LevelsDir/level_*.json, returning an error on the first failure. When checkSolvable is true, it
// additionally runs solvability checks for each parsed level by calling IsSolvableWithStats with the
// provided maxStates budget. Solvability checks are executed concurrently (bounded by runtime.NumCPU).
//
// For each level, Validate records a LevelStat (including fields such as LevelID, File, Solver,
// StatesExplored, TimeMs, MaxStates, Solvable, GaveUp and any Error string), prints a per-level summary to
// stdout, and writes all collected stats to validation_stats.json in the current working directory. A level
// that reports GaveUp is treated as not solvable under the given budget. If any module validation or level
// parsing fails, or if one or more levels are determined not solvable, Validate returns a non-nil error
// (for unsolvable levels the error includes the count of such levels). On success it prints a confirmation
// message and returns nil.
//
// Note: this function has side effects (printing to stdout and writing validation_stats.json) and performs
// concurrent work that blocks until all checks complete.
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

	if !checkSolvable {
		for _, f := range files {
			if _, err := readLevelFile(f); err != nil {
				return fmt.Errorf("level %s validation failed: %w", filepath.Base(f), err)
			}
		}

		fmt.Println("All levels and modules validated successfully.")
		return nil
	}

	// If we reach here, we need to run solvability checks and collect stats.
	concurrency := runtime.NumCPU()
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup
	statsCh := make(chan LevelStat, len(files))
	errCh := make(chan error, len(files))

	for _, f := range files {
		f := f
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			lvl, err := readLevelFile(f)
			if err != nil {
				errCh <- fmt.Errorf("level %s validation failed: %w", filepath.Base(f), err)
				return
			}

			start := time.Now()
			ok, stat, cerr := IsSolvableWithStats(lvl, maxStates)
			dur := time.Since(start)
			stat.TimeMs = dur.Milliseconds()
			stat.File = f
			stat.LevelID = lvl.ID
			stat.MaxStates = maxStates
			stat.Solvable = ok
			if cerr != nil {
				stat.Error = cerr.Error()
			}

			if stat.GaveUp {
				// mark as not solvable under budget
				stat.Solvable = false
			}

			statsCh <- stat
		}()
	}

	wg.Wait()
	close(statsCh)
	close(errCh)

	if len(errCh) > 0 {
		return <-errCh
	}

	// Collect stats
	var allStats []LevelStat
	unsolvable := []LevelStat{}
	for s := range statsCh {
		allStats = append(allStats, s)
		fmt.Printf("Level %d (%s): solvable=%v solver=%s states=%d time=%dms gave_up=%v\n",
			s.LevelID, filepath.Base(s.File), s.Solvable, s.Solver, s.StatesExplored, s.TimeMs, s.GaveUp)
		if !s.Solvable {
			unsolvable = append(unsolvable, s)
		}
	}

	// Write stats to JSON artifact
	b, _ := json.MarshalIndent(allStats, "", "  ")
	_ = os.WriteFile("validation_stats.json", b, 0644)

	if len(unsolvable) > 0 {
		return fmt.Errorf("%d levels appear unsolvable (check validation_stats.json for details)", len(unsolvable))
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
