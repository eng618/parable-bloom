package repair

import (
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"regexp"
	"strconv"

	"github.com/spf13/cobra"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

var (
	directoryFlag string
	overwriteFlag bool
	dryRunFlag    bool
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
			directoryFlag = "../../assets/levels"
		}

		return repairDirectory(directoryFlag, overwriteFlag, dryRunFlag)
	},
}

func init() {
	RepairCmd.Flags().StringVarP(&directoryFlag, "directory", "d", "", "Directory containing level files to repair (default: ../../assets/levels)")
	RepairCmd.Flags().BoolVarP(&overwriteFlag, "overwrite", "o", true, "Overwrite repaired files")
	RepairCmd.Flags().BoolVarP(&dryRunFlag, "dry-run", "n", false, "Scan and report without writing files")
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
	gridSize := generator.GridSizeForLevel(id)
	levelSeed := int64(id) * 31337

	common.Verbose("Regenerating level %d (difficulty: %s, grid: %dx%d)", id, difficulty, gridSize[0], gridSize[1])

	// Get difficulty spec
	spec, ok := generator.DifficultySpecs[difficulty]
	if !ok {
		return true, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	// Use a deterministic variety profile based on level ID
	profile := generator.VarietyProfile{
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
	cfg := generator.GeneratorConfig{
		MaxSeedRetries:    50,
		LocalRepairRadius: 3,
		RepairRetries:     10,
	}

	// Generate vines using tiling algorithm
	rng := rand.New(rand.NewSource(levelSeed))
	vines, mask, genErr := generator.TileGridIntoVines(gridSize, spec, profile, cfg, rng)
	if genErr != nil {
		return true, fmt.Errorf("failed to generate vines for level %d: %w", id, genErr)
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
		Grace:       generator.GraceForDifficulty(difficulty),
		ColorScheme: generator.ColorPalette,
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
