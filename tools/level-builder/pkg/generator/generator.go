package generator

import (
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

const (
	AssetsDir   = "../../assets"
	LevelsDir   = AssetsDir + "/levels"
	DataDir     = AssetsDir + "/data"
	ModulesFile = DataDir + "/modules.json"
)

// GenerationConfig holds configuration for level generation
type GenerationConfig struct {
	Count         int
	BaseSeed      int64
	UseRandomSeed bool
	ModuleID      int
	Difficulty    string
	WorkingDir    string
}

// Clean removes generated level and module files used by the level builder.
func Clean() error {
	files, err := filepath.Glob(filepath.Join(LevelsDir, "level_*.json"))
	if err != nil {
		return err
	}
	for _, f := range files {
		os.Remove(f)
	}
	os.Remove(ModulesFile)
	return nil
}

// Generate creates count levels with the given configuration.
// This is the main entry point called from the generate command.
func Generate(count int, baseSeed int64, useRandomSeed bool, moduleID int, difficulty string) error {
	cwd, _ := os.Getwd()
	common.Verbose("Generating %d levels (CWD: %s)...", count, cwd)

	// Ensure output directories exist
	if err := os.MkdirAll(LevelsDir, 0755); err != nil {
		return err
	}
	if err := os.MkdirAll(DataDir, 0755); err != nil {
		return err
	}

	cfg := GenerationConfig{
		Count:         count,
		BaseSeed:      baseSeed,
		UseRandomSeed: useRandomSeed,
		ModuleID:      moduleID,
		Difficulty:    difficulty,
		WorkingDir:    cwd,
	}

	// Determine the starting level ID
	startID := 1
	existingLevels, err := common.ReadLevelsFromDir(LevelsDir)
	if err == nil && len(existingLevels) > 0 {
		maxID := 0
		for _, lvl := range existingLevels {
			if lvl.ID > maxID {
				maxID = lvl.ID
			}
		}
		startID = maxID + 1
		common.Verbose("Found existing levels, starting from ID %d", startID)
	}

	// Generate levels
	for i := 0; i < count; i++ {
		levelID := startID + i

		// Determine seed for this level
		var levelSeed int64
		if cfg.UseRandomSeed {
			levelSeed = time.Now().UnixNano() + int64(i)
		} else if cfg.BaseSeed != 0 {
			levelSeed = cfg.BaseSeed + int64(i)
		} else {
			levelSeed = int64(levelID) * 31337 // Deterministic default
		}

		rng := rand.New(rand.NewSource(levelSeed))

		// Determine difficulty tier
		var difficultyTier string
		if cfg.Difficulty != "" {
			difficultyTier = cfg.Difficulty
		} else {
			difficultyTier = common.DifficultyForLevel(levelID)
		}

		// Generate level with retries
		level, err := generateSingleLevel(levelID, difficultyTier, levelSeed, rng)
		if err != nil {
			return fmt.Errorf("failed to generate level %d: %w", levelID, err)
		}

		// Write level to disk
		filePath := filepath.Join(LevelsDir, fmt.Sprintf("level_%d.json", levelID))
		if err := common.WriteLevel(filePath, &level, false); err != nil {
			return fmt.Errorf("failed to write level %d: %w", levelID, err)
		}

		if (i+1)%10 == 0 || (i+1) == count {
			common.Info("Generated %d/%d levels...", i+1, count)
		}
	}

	common.Info("Successfully generated %d levels", count)
	return nil
}

// generateSingleLevel creates a single level with the given parameters.
// It uses the tiling algorithm and validates solvability.
func generateSingleLevel(id int, difficulty string, seed int64, rng *rand.Rand) (common.Level, error) {
	const maxAttempts = 1000

	// Get difficulty-specific constraints
	spec, ok := common.DifficultySpecs[difficulty]
	if !ok {
		return common.Level{}, fmt.Errorf("unknown difficulty: %s", difficulty)
	}

	// Get grid size for this level
	gridSize := common.GridSizeForLevel(id)

	// Get variety profile and generator config for this difficulty
	profile := common.GetPresetProfile(difficulty)
	generatorCfg := common.GetGeneratorConfigForDifficulty(difficulty)

	common.Verbose("Level %d: difficulty=%s, grid=%dx%d", id, difficulty, gridSize[0], gridSize[1])

	var level common.Level
	var attempts int

	for attempts = 0; attempts < maxAttempts; attempts++ {
		// Use tiling algorithm to partition grid into vines
		vines, mask, err := TileGridIntoVines(gridSize, spec, profile, generatorCfg, rng)
		if err != nil {
			common.Verbose("Attempt %d failed: %v", attempts+1, err)
			continue
		}

		// Assign color indices from palette
		assignColorIndices(vines, len(common.ColorPalette), rng)

		// Build level
		level = common.Level{
			ID:          id,
			Name:        fmt.Sprintf("Level %d", id),
			Difficulty:  difficulty,
			GridSize:    gridSize,
			Vines:       vines,
			MaxMoves:    0, // Will calculate below
			MinMoves:    0, // Will calculate below
			Complexity:  common.ComplexityForDifficulty(difficulty),
			Grace:       common.GraceForDifficulty(difficulty),
			ColorScheme: common.ColorPalette, // Use standard palette
			Mask:        mask,
		}

		// Validate solvability using the solver
		solver := common.NewSolver(&level)
		if !solver.IsSolvableGreedy() {
			common.Verbose("Attempt %d: Level not solvable (greedy check)", attempts+1)
			continue
		}

		// For higher difficulties, also check with BFS
		if difficulty == "Nurturing" || difficulty == "Flourishing" || difficulty == "Transcendent" {
			if !solver.IsSolvableBFS() {
				common.Verbose("Attempt %d: Level not solvable (BFS check)", attempts+1)
				continue
			}
		}

		// Calculate min/max moves based on vine count
		vineCount := len(vines)
		level.MinMoves = vineCount
		level.MaxMoves = int(float64(vineCount) * 1.5)
		if level.MaxMoves < 5 {
			level.MaxMoves = 5
		}

		common.Verbose("✓ Level %d generated successfully after %d attempts", id, attempts+1)
		return level, nil
	}

	return common.Level{}, fmt.Errorf("failed to generate solvable level after %d attempts", attempts)
}

// assignColorIndices assigns random color indices to vines from the palette.
func assignColorIndices(vines []common.Vine, paletteSize int, rng *rand.Rand) {
	for i := range vines {
		vines[i].ColorIndex = rng.Intn(paletteSize)
	}
}
