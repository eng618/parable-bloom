package repair

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/metrics"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

var (
	directoryFlag    string
	overwriteFlag    bool
	dryRunFlag       bool
	fixDuplicates    bool
	checkSolvable    bool
	maxStates        int
	aggressiveRepair bool
)

var levelFileRE = regexp.MustCompile(`^level_(\d+)\.json$`)

// RepairCmd repairs corrupted or invalid level files by regenerating them.
var RepairCmd = &cobra.Command{
	Use:   "repair",
	Short: "Repair corrupted or invalid level JSON files by regenerating them",
	Long: `Scan a levels directory and regenerate files that fail to parse or,
with --check-solvable (default), files that fail structural validation or
solvability checks. Regeneration is deterministic (seed = levelID * 31337)
and honors the canonical difficulty lock, so repaired levels match what
batch generation would produce.

Examples:
  level-builder repair
  level-builder repair --directory assets/levels
  level-builder repair --dry-run
  level-builder repair --check-solvable=false   # parse failures only
`,
	RunE: func(cmd *cobra.Command, args []string) error {
		if directoryFlag == "" {
			var err error
			directoryFlag, err = common.LevelsDir()
			if err != nil {
				return fmt.Errorf("failed to resolve levels directory: %w", err)
			}
		}

		return repairDirectory(directoryFlag, overwriteFlag, dryRunFlag)
	},
}

func init() {
	RepairCmd.Flags().StringVarP(&directoryFlag, "directory", "d", "", "Directory containing level files to repair (default: resolved assets levels dir)")
	RepairCmd.Flags().BoolVarP(&overwriteFlag, "overwrite", "o", true, "Overwrite repaired files")
	RepairCmd.Flags().BoolVarP(&dryRunFlag, "dry-run", "n", false, "Scan and report without writing files")
	RepairCmd.Flags().BoolVar(&fixDuplicates, "fix-duplicates", false, "Automatically fix duplicate vine IDs (keeps first occurrence)")
	RepairCmd.Flags().BoolVar(&checkSolvable, "check-solvable", true, "Also repair files failing structural validation or solvability checks")
	RepairCmd.Flags().IntVar(&maxStates, "max-states", 1000000, "Solver state budget for repair solvability checks")
	RepairCmd.Flags().BoolVar(&aggressiveRepair, "aggressive", false, "Use stronger backtracking settings when regenerating")
}

func repairDirectory(dir string, overwrite, dryRun bool) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return fmt.Errorf("failed to read directory %s: %w", dir, err)
	}

	fixed := 0
	failed := 0
	checked := 0

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		m := levelFileRE.FindStringSubmatch(name)
		if m == nil {
			continue
		}
		checked++
		path := filepath.Join(dir, name)
		common.Verbose("Checking %s", path)

		id, _ := strconv.Atoi(m[1])
		reason := assessFile(path, id)
		if reason == "" {
			// If structural issues and user requested fixDuplicates, attempt a sanitize
			if fixDuplicates {
				if fixedOne, failedOne := maybeSanitizeDuplicates(path, dryRun); fixedOne || failedOne {
					if failedOne {
						failed++
					} else {
						fixed++
					}
				}
			}
			continue
		}

		common.Warning("Level %d needs repair (%s)", id, reason)
		if dryRun {
			common.Info("Would regenerate level %d -> %s", id, path)
			fixed++
			continue
		}

		if err := regenerateLevel(path, id, overwrite); err != nil {
			common.Warning("Failed to repair level %d: %v", id, err)
			failed++
			continue
		}
		fixed++
	}

	common.Info("Repair summary: checked=%d repaired=%d failed=%d", checked, fixed, failed)
	if failed > 0 {
		return fmt.Errorf("failed to repair %d files", failed)
	}
	return nil
}

// assessFile returns "" when the file is healthy, otherwise a short reason.
// Parse failures always qualify. Structural/solvability failures qualify only
// when --check-solvable is enabled.
func assessFile(path string, id int) string {
	lvl, err := common.ReadLevel(path)
	if err != nil {
		return fmt.Sprintf("parse failure: %v", err)
	}
	if lvl.ID != id {
		return fmt.Sprintf("ID %d mismatches filename", lvl.ID)
	}
	if !checkSolvable {
		return ""
	}
	if want := common.ExpectedDifficulty(id); lvl.Difficulty != "" && lvl.Difficulty != want {
		return fmt.Sprintf("difficulty %s mismatches canonical %s", lvl.Difficulty, want)
	}
	if errs := validator.ValidateStructural(*lvl); len(errs) > 0 {
		return fmt.Sprintf("structural: %v", errs[0])
	}
	ok, stats, err := validator.IsSolvable(*lvl, maxStates)
	if err != nil {
		return fmt.Sprintf("solvability check error: %v", err)
	}
	if !ok || stats.GaveUp {
		return fmt.Sprintf("not solvable (solver=%s states=%d gave_up=%v)", stats.Solver, stats.StatesExplored, stats.GaveUp)
	}
	if errs := validator.ValidateDesignConstraints(*lvl); len(errs) > 0 {
		return fmt.Sprintf("design constraints: %v", errs[0])
	}
	return ""
}

// maybeSanitizeDuplicates attempts the cheap duplicate-ID fix. It reports
// (fixed, failed); files still failing structural checks afterwards fall
// through to full regeneration by the caller.
func maybeSanitizeDuplicates(path string, dryRun bool) (bool, bool) {
	lvl, err := common.ReadLevel(path)
	if err != nil {
		return false, false
	}
	if sErrs := validator.ValidateStructural(*lvl); len(sErrs) == 0 {
		return false, false
	}
	common.Info("Attempting to fix duplicates in %s", path)
	if dryRun {
		return true, false
	}
	if err := sanitizeLevelDuplicateIDs(path); err != nil {
		common.Warning("Failed to sanitize %s: %v", path, err)
		return false, true
	}
	return true, false
}

// regenerateLevel rebuilds a level deterministically through the canonical
// pipeline inputs (difficulty lock, preset profile) and enforces the same
// acceptance gates batch generation uses before writing. Placement has
// inherent variance, so it retries with derived seeds until acceptance
// passes (mirroring batch retry behavior).
func regenerateLevel(path string, id int, overwrite bool) error {
	const maxAttempts = 10
	baseSeed := int64(id) * 31337

	var lastErr error
	for attempt := 0; attempt < maxAttempts; attempt++ {
		if err := tryRegenerate(path, id, baseSeed+int64(attempt*12345), overwrite); err != nil {
			lastErr = err
			common.Verbose("Repair attempt %d/%d for level %d failed: %v", attempt+1, maxAttempts, id, err)
			continue
		}
		return nil
	}
	return fmt.Errorf("failed to regenerate level %d after %d attempts: %w", id, maxAttempts, lastErr)
}

func tryRegenerate(path string, id int, levelSeed int64, overwrite bool) error {
	// Canonical difficulty for this ID (matches batch + validator lock).
	difficulty := common.ExpectedDifficulty(id)
	gridSize := utils.GridSizeForLevel(id)

	common.Verbose("Regenerating level %d (difficulty: %s, grid: %dx%d, seed: %d)", id, difficulty, gridSize[0], gridSize[1], levelSeed)

	spec, ok := config.DifficultySpecs[difficulty]
	if !ok {
		return fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	profile := utils.GetPresetProfile(difficulty)
	genCfg := config.GeneratorConfig{
		MaxSeedRetries:    50,
		LocalRepairRadius: 3,
		RepairRetries:     10,
	}
	if aggressiveRepair {
		genCfg.MaxSeedRetries = 120
		genCfg.LocalRepairRadius = 5
		genCfg.RepairRetries = 12
	}

	vines, genErr := strategies.ClearableFirstPlacement(gridSize, spec, profile, genCfg, levelSeed, 0.3, common.MinGridCoverage, true)
	if genErr != nil {
		return fmt.Errorf("failed to generate vines for level %d: %w", id, genErr)
	}

	occupied := make(map[string]struct{}, len(vines)*8)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			occupied[common.PointKey(p)] = struct{}{}
		}
	}

	var maskedPoints []model.Point
	for y := 0; y < gridSize[1]; y++ {
		for x := 0; x < gridSize[0]; x++ {
			if _, ok := occupied[common.PointKey(model.Point{X: x, Y: y})]; !ok {
				maskedPoints = append(maskedPoints, model.Point{X: x, Y: y})
			}
		}
	}

	var mask *model.Mask
	if len(maskedPoints) > 0 {
		mask = &model.Mask{Mode: "hide", Points: maskedPoints}
	}

	// Round-robin color assignment matches the canonical assembler.
	colorCount := spec.ColorCountRange[1]
	if colorCount < 1 {
		colorCount = 5
	}
	for i := range vines {
		vines[i].ColorIndex = i % colorCount
	}
	colorScheme := make([]string, 0, colorCount)
	for i := 0; i < colorCount && i < len(config.ColorPalette); i++ {
		colorScheme = append(colorScheme, config.ColorPalette[i])
	}

	level := model.Level{
		ID:          id,
		Name:        fmt.Sprintf("Level %d", id),
		Difficulty:  difficulty,
		GridSize:    gridSize,
		Vines:       vines,
		MaxMoves:    len(vines) * 2,
		MinMoves:    len(vines),
		Complexity:  common.ComplexityForDifficulty(difficulty),
		Grace:       utils.GraceForDifficulty(difficulty),
		ColorScheme: colorScheme,
		Mask:        mask,
	}

	// Same acceptance gates as batch generation.
	if errs := validator.ValidateStructural(level); len(errs) > 0 {
		return fmt.Errorf("regenerated level %d failed structural validation: %v", id, errs[0])
	}
	ok, stats, err := validator.IsSolvable(level, maxStates)
	if err != nil {
		return fmt.Errorf("regenerated level %d solvability check error: %w", id, err)
	}
	if !ok || stats.GaveUp {
		return fmt.Errorf("regenerated level %d is not solvable (solver=%s states=%d gave_up=%v)", id, stats.Solver, stats.StatesExplored, stats.GaveUp)
	}
	if errs := validator.ValidateDesignConstraints(level); len(errs) > 0 {
		return fmt.Errorf("regenerated level %d failed design constraints: %v", id, errs[0])
	}
	quality := metrics.AnalyzeQuality(level)
	common.Verbose("Regenerated level %d: coverage=%.1f%% vines=%d colors=%d variety=%d",
		id, quality.PlayableCoverage*100, quality.VineCount, quality.DistinctColors, quality.LengthVariety)

	if err := common.WriteLevel(path, &level, overwrite); err != nil {
		common.Error("Failed to write regenerated level %d to %s: %v", id, path, err)
		return err
	}

	common.Info("Repaired level %d", id)
	return nil
}

// sanitizeLevelDuplicateIDs removes duplicate vine entries (same ID) keeping the
// first occurrence, and renames duplicates with differing ordered_path to a
// new unique vine_N id to avoid overlap collisions.
func sanitizeLevelDuplicateIDs(path string) error {
	lvl, err := common.ReadLevel(path)
	if err != nil {
		return err
	}

	// Determine next available vine index (robust to malformed IDs).
	maxIdx := 0
	for _, v := range lvl.Vines {
		var idx int
		if n, _ := fmt.Sscanf(v.ID, "vine_%d", &idx); n == 1 && idx > maxIdx {
			maxIdx = idx
		}
	}
	nextIdx := maxIdx + 1

	seen := map[string]model.Vine{}
	out := make([]model.Vine, 0, len(lvl.Vines))
	for _, v := range lvl.Vines {
		if existing, ok := seen[v.ID]; ok {
			// If paths are identical, skip duplicate entry
			if len(existing.OrderedPath) == len(v.OrderedPath) {
				same := true
				for i := range v.OrderedPath {
					if existing.OrderedPath[i] != v.OrderedPath[i] {
						same = false
						break
					}
				}
				if same {
					common.Warning("Removing duplicate vine entry %s in %s", v.ID, path)
					continue
				}
			}

			// Otherwise rename duplicate to new unique id
			newID := fmt.Sprintf("vine_%d", nextIdx)
			nextIdx++
			common.Warning("Renaming duplicate vine id %s -> %s in %s", v.ID, newID, path)
			v.ID = newID
			seen[v.ID] = v
			out = append(out, v)
			continue
		}
		seen[v.ID] = v
		out = append(out, v)
	}

	// Replace vines and write back
	lvl.Vines = out
	if err := common.WriteLevel(path, lvl, true); err != nil {
		return err
	}

	// Re-run structural check
	if errs := validator.ValidateStructural(*lvl); len(errs) > 0 {
		return fmt.Errorf("post-sanitize structural validation failed: %v", errs)
	}

	common.Info("Sanitized duplicate vine entries in %s", path)
	return nil
}
