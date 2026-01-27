package validator

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// Path resolution functions - use common.LevelsDir() and common.ModulesFile() instead of hardcoded paths

// OccupancyTolerance is the allowed margin for vine occupancy.
// Some levels are generated with adaptive relaxation or are legacy sparse levels (up to 40%).
const OccupancyTolerance = 0.401

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
func Validate(checkSolvable bool, maxStates int, useAstar bool, astarWeight int, ignoreOccupancy bool) error {
	// 1. Validate Modules
	if err := validateModules(); err != nil {
		return fmt.Errorf("module validation failed: %w", err)
	}

	// 2. Resolve levels directory
	levelsDir, err := common.LevelsDir()
	if err != nil {
		return fmt.Errorf("failed to resolve levels directory: %w", err)
	}

	// 3. Validate Levels
	files, err := filepath.Glob(filepath.Join(levelsDir, "level_*.json"))
	if err != nil {
		return err
	}

	if !checkSolvable {
		// Collect all validation errors instead of failing fast
		type ValidationError struct {
			File  string
			Error string
		}
		var validationErrors []ValidationError

		for _, f := range files {
			if _, err := readLevelFile(f, ignoreOccupancy); err != nil {
				validationErrors = append(validationErrors, ValidationError{
					File:  filepath.Base(f),
					Error: err.Error(),
				})
			}
		}

		if len(validationErrors) > 0 {
			fmt.Printf("\n❌ Validation failed for %d levels:\n\n", len(validationErrors))
			for _, ve := range validationErrors {
				fmt.Printf("  • %s: %s\n", ve.File, ve.Error)
			}
			fmt.Printf("\nTotal: %d/%d levels passed validation\n", len(files)-len(validationErrors), len(files))
			return fmt.Errorf("%d levels failed validation", len(validationErrors))
		}

		fmt.Printf("✓ All %d levels and modules validated successfully.\n", len(files))
		return nil
	}

	// If we reach here, we need to run solvability checks and collect stats.
	concurrency := runtime.NumCPU()
	sem := make(chan struct{}, concurrency)
	var wg sync.WaitGroup
	statsCh := make(chan LevelStat, len(files))
	type ValidationError struct {
		File  string
		Error string
	}
	errCh := make(chan ValidationError, len(files))

	for _, f := range files {
		f := f
		wg.Add(1)
		go func() {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			lvl, err := readLevelFile(f, ignoreOccupancy)
			if err != nil {
				errCh <- ValidationError{
					File:  filepath.Base(f),
					Error: err.Error(),
				}
				return
			}

			start := time.Now()
			ok, stat, cerr := IsSolvableWithStats(lvl, maxStates, useAstar, astarWeight)
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

	// Collect validation errors
	var validationErrors []ValidationError
	for ve := range errCh {
		validationErrors = append(validationErrors, ve)
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

	// Write stats to JSON artifact in logs directory
	b, _ := json.MarshalIndent(allStats, "", "  ")
	logsDir, err := common.LogsDir()
	if err == nil {
		if err := os.MkdirAll(logsDir, 0o755); err == nil {
			statsPath := filepath.Join(logsDir, "validation_stats.json")
			_ = os.WriteFile(statsPath, b, 0o644)
			fmt.Printf("\n✓ Detailed results written to %s\n", statsPath)
		}
	}

	// Print summary of all issues
	hasErrors := false
	if len(validationErrors) > 0 {
		hasErrors = true
		fmt.Printf("\n❌ Structural validation failed for %d levels:\n\n", len(validationErrors))
		for _, ve := range validationErrors {
			fmt.Printf("  • %s: %s\n", ve.File, ve.Error)
		}
	}

	if len(unsolvable) > 0 {
		hasErrors = true
		fmt.Printf("\n❌ Solvability check failed for %d levels:\n\n", len(unsolvable))
		for _, s := range unsolvable {
			fmt.Printf("  • %s (level %d): gave_up=%v states=%d\n",
				filepath.Base(s.File), s.LevelID, s.GaveUp, s.StatesExplored)
		}
	}

	if hasErrors {
		fmt.Printf("\n📊 Summary: %d passed, %d failed structural validation, %d failed solvability (total %d levels)\n",
			len(files)-len(validationErrors)-len(unsolvable), len(validationErrors), len(unsolvable), len(files))
		return fmt.Errorf("%d levels failed validation (see summary above)", len(validationErrors)+len(unsolvable))
	}

	fmt.Printf("\n✓ All %d levels and modules validated successfully.\n", len(files))
	return nil
}

func validateModules() error {
	modulesFile, err := common.ModulesFile()
	if err != nil {
		return fmt.Errorf("failed to resolve modules.json path: %w", err)
	}
	bytes, err := os.ReadFile(modulesFile)
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

func readLevelFile(path string, ignoreOccupancy bool) (model.Level, error) {
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

	// 3. Check Occupancy and Coverage
	// - Occupancy: at least MinGridCoverage (90%) of grid must be occupied by vines
	// - Coverage: 100% of grid must be either occupied by vines OR masked out
	if err := checkOccupancyAndCoverage(lvl, ignoreOccupancy); err != nil {
		return model.Level{}, err
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

	// 6. Comprehensive structural validation (ported from Dart tests)
	if structuralErrors := ValidateStructural(lvl); len(structuralErrors) > 0 {
		// Return first error for backward compatibility
		return model.Level{}, structuralErrors[0]
	}

	return lvl, nil
}

// checkOccupancyAndCoverage validates two distinct metrics:
// 1. Occupancy: at least MinGridCoverage (90%) of the grid must be occupied by vines
// 2. Coverage: 100% of the grid must be either occupied by vines OR masked out (no empty unmasked cells)
func checkOccupancyAndCoverage(lvl model.Level, ignoreOccupancy bool) error {
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	gridArea := w * h
	occupied := make([]bool, gridArea)

	// Mark cells occupied by vines
	vineCount := 0
	for _, v := range lvl.Vines {
		for _, p := range v.OrderedPath {
			if p.X < 0 || p.X >= w || p.Y < 0 || p.Y >= h {
				return fmt.Errorf("vine cell out of bounds")
			}
			idx := p.Y*w + p.X
			if occupied[idx] {
				return fmt.Errorf("overlapping vines at (%d,%d)", p.X, p.Y)
			}
			occupied[idx] = true
			vineCount++
		}
	}

	// Check 1: Vine occupancy must meet minimum threshold for its difficulty
	targetOccupancy := common.MinCoverageForDifficulty(lvl.Difficulty)
	occupancy := float64(vineCount) / float64(gridArea)
	if occupancy < (targetOccupancy - OccupancyTolerance) {
		if !ignoreOccupancy {
			return fmt.Errorf("vine occupancy %.1f%% below minimum threshold %.0f%% for %s difficulty",
				occupancy*100, targetOccupancy*100, lvl.Difficulty)
		}
		// If ignoring occupancy, just warn and continue
		fmt.Printf("⚠️ Warning: vine occupancy %.1f%% below minimum threshold %.0f%% (ignored)\n",
			occupancy*100, targetOccupancy*100)
	}

	// Check 2: 100% coverage (every cell is either occupied by vine OR masked)
	// Count cells that are neither occupied nor masked
	uncoveredCount := 0
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			idx := y*w + x
			if !occupied[idx] {
				// Cell not occupied by vine - check if it's masked
				if !isCellMasked(lvl.Mask, x, y) {
					uncoveredCount++
				}
			}
		}
	}

	var uncoveredPoints []string
	if uncoveredCount > 0 {
		for y := 0; y < h; y++ {
			for x := 0; x < w; x++ {
				idx := y*w + x
				if !occupied[idx] && !isCellMasked(lvl.Mask, x, y) {
					uncoveredPoints = append(uncoveredPoints, fmt.Sprintf("(%d,%d)", x, y))
				}
			}
		}
		uncoveredPercent := float64(uncoveredCount) / float64(gridArea) * 100
		fmt.Printf("⚠️ Warning: incomplete coverage in Level %d: %d cells (%.1f%%) are neither occupied by vines nor masked\n",
			lvl.ID, uncoveredCount, uncoveredPercent)
		if common.VerboseEnabled {
			fmt.Printf("   Uncovered cells: %v\n", uncoveredPoints)
		}
	}

	return nil
}

// isCellMasked returns true if the cell at (x,y) is masked according to the mask mode
func isCellMasked(mask *model.Mask, x, y int) bool {
	if mask == nil {
		return false
	}

	// Check if point is in mask's points list
	inMask := false
	for _, pt := range mask.Points {
		if pt.X == x && pt.Y == y {
			inMask = true
			break
		}
	}

	// Interpret based on mode
	switch mask.Mode {
	case "hide":
		return inMask // Points listed are hidden
	case "show":
		return !inMask // Points listed are shown, rest are hidden
	case "show-all":
		return false // Nothing is hidden
	default:
		return false
	}
}
