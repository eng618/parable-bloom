package repair

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

var (
	directoryFlag string
	overwriteFlag bool
	dryRunFlag    bool
	fixDuplicates bool
)

var levelFileRE = regexp.MustCompile(`^level_(\d+)\.json$`)

// RepairCmd repairs corrupted or truncated level files by regenerating them.
var RepairCmd = &cobra.Command{
	Use:   "repair",
	Short: "Repair corrupted level JSON files by regenerating them",
	Long: `Scan a levels directory and regenerate any files that fail to parse.
This helps recover from partial writes or corrupted files produced by earlier runs.

Examples:
  level-builder repair
  level-builder repair --directory assets/levels
  level-builder repair --dry-run
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
	RepairCmd.Flags().StringVarP(&directoryFlag, "directory", "d", "", "Directory containing level files to repair (default: ../../assets/levels)")
	RepairCmd.Flags().BoolVarP(&overwriteFlag, "overwrite", "o", true, "Overwrite repaired files")
	RepairCmd.Flags().BoolVarP(&dryRunFlag, "dry-run", "n", false, "Scan and report without writing files")
	RepairCmd.Flags().BoolVar(&fixDuplicates, "fix-duplicates", false, "Automatically fix duplicate vine IDs and duplicate entries (keeps first occurrence)")
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

		repaired, repairErr := repairFileIfNeeded(path, m[1], overwrite, dryRun)
		if repaired {
			if repairErr != nil {
				failed++
			} else {
				fixed++
			}
		}

		// If structural issues and user requested fixDuplicates, attempt a sanitize
		if fixDuplicates {
			lvl, err := common.ReadLevel(path)
			if err == nil {
				if sErrs := validator.ValidateStructural(*lvl); len(sErrs) > 0 {
					// If structural errors include overlaps, attempt to sanitize duplicate IDs
					hasOverlap := false
					for _, se := range sErrs {
						if strings.Contains(se.Error(), "overlaps") || strings.Contains(se.Error(), "overlap") {
							hasOverlap = true
							break
						}
					}
					if hasOverlap {
						common.Info("Attempting to fix duplicates in %s", path)
						if dryRun {
							fixed++
						} else {
							if err := sanitizeLevelDuplicateIDs(path); err != nil {
								common.Warning("Failed to sanitize %s: %v", path, err)
								failed++
							} else {
								fixed++
							}
						}
					}
				}
			}
		}
	}

	common.Info("Repair summary: checked=%d repaired=%d failed=%d", checked, fixed, failed)
	if failed > 0 {
		return fmt.Errorf("failed to repair %d files", failed)
	}
	return nil
}

// repairFileIfNeeded checks a single file and regenerates if parsing fails.
func repairFileIfNeeded(path, idStr string, overwrite, dryRun bool) (bool, error) {
	_, err := common.ReadLevel(path)
	if err == nil {
		return false, nil
	}

	common.Warning("Failed to parse %s: %v (scheduling regenerate)", path, err)
	id, _ := strconv.Atoi(idStr)

	if dryRun {
		common.Info("Would regenerate level %d -> %s", id, path)
		return true, nil
	}

	// Use the generator package to regenerate the level
	// This ensures consistency with the generation algorithm
	difficulty := common.DifficultyForLevel(id)
	gridSize := utils.GridSizeForLevel(id)
	levelSeed := int64(id) * 31337

	common.Verbose("Regenerating level %d (difficulty: %s, grid: %dx%d)", id, difficulty, gridSize[0], gridSize[1])

	// Get difficulty spec
	spec, ok := config.DifficultySpecs[difficulty]
	if !ok {
		return true, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	// Use a deterministic variety profile based on level ID
	profile := config.VarietyProfile{
		LengthMix: map[string]float64{
			"short":  0.3,
			"medium": 0.5,
			"long":   0.2,
		},
		TurnMix:    0.3,
		RegionBias: "balanced",
		DirBalance: map[string]float64{
			"right": 0.25,
			"left":  0.25,
			"up":    0.25,
			"down":  0.25,
		},
	}

	// Generator config
	cfg := config.GeneratorConfig{
		MaxSeedRetries:    50,
		LocalRepairRadius: 3,
		RepairRetries:     10,
	}

	// Generate vines using tiling algorithm
	vines, genErr := strategies.ClearableFirstPlacement(gridSize, spec, profile, cfg, levelSeed, 0.3, common.MinGridCoverage, true)
	if genErr != nil {
		return true, fmt.Errorf("failed to generate vines for level %d: %w", id, genErr)
	}

	// Calculate empty cells for masking
	occupied := make(map[string]bool)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			occupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
		}
	}

	var maskedPoints []model.Point
	for y := 0; y < gridSize[1]; y++ {
		for x := 0; x < gridSize[0]; x++ {
			if !occupied[fmt.Sprintf("%d,%d", x, y)] {
				maskedPoints = append(maskedPoints, model.Point{X: x, Y: y})
			}
		}
	}

	mask := &model.Mask{
		Mode:   "hide",
		Points: maskedPoints,
	}

	level := model.Level{
		ID:          id,
		Name:        fmt.Sprintf("Level %d", id),
		Difficulty:  difficulty,
		GridSize:    gridSize,
		Vines:       vines,
		MaxMoves:    10,
		MinMoves:    1,
		Complexity:  difficulty,
		Grace:       utils.GraceForDifficulty(difficulty),
		ColorScheme: config.ColorPalette,
		Mask:        mask,
	}

	// Validate solvability
	solver := common.NewSolver(&level)
	if !solver.IsSolvableGreedy() {
		return true, fmt.Errorf("generated level %d is not solvable", id)
	}

	// Write the repaired level
	err = common.WriteLevel(path, &level, overwrite)
	if err != nil {
		common.Error("Failed to write regenerated level %d to %s: %v", id, path, err)
		return true, err
	}

	common.Info("Repaired level %d", id)

	return true, nil
}

// sanitizeLevelDuplicateIDs removes duplicate vine entries (same ID) keeping the
// first occurrence, and renames duplicates with differing ordered_path to a
// new unique vine_N id to avoid overlap collisions.
func sanitizeLevelDuplicateIDs(path string) error {
	lvl, err := common.ReadLevel(path)
	if err != nil {
		return err
	}

	// Determine next available vine index
	maxIdx := 0
	for _, v := range lvl.Vines {
		var idx int
		if n, _ := fmt.Sscanf(v.ID, "vine_%d", &idx); n == 1 {
			if idx > maxIdx {
				maxIdx = idx
			}
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
