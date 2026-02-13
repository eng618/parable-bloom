package strategies_test

import (
	"math/rand"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// generateSingleLevel creates a level using the standard tiling strategy for testing purposes.
// This helper replaces internal access to strategy functions from integration tests.
func generateSingleLevel(levelID int, difficulty string, seed int64, rng *rand.Rand) (model.Level, error) {
	spec, ok := config.DifficultySpecs[difficulty]
	if !ok {
		// Fallback to default if not found, to match test expectations
		spec = config.DifficultySpecs["Seedling"]
	}

	profile := utils.GetPresetProfile(difficulty)
	cfg := utils.GetGeneratorConfigForDifficulty(difficulty)

	// Determine grid size based on difficulty/levelID logic if needed,
	// but here we use config defaults as tests usually expect specific sizes or defaults with override.
	// Actually, tests pass in seed and difficulty, assuming standard grid size for that difficulty?
	// Tiling test passes explicit grid size in some tests, but this helper is called by TestGenerateSingleLevel_SmallGrid
	// on line 100 with (1, tt.difficulty, tt.seed, rng).
	// That test expects grid size to be calculated naturally.

	gridSize := utils.DefaultGridSize(difficulty)
	// Note: In real generator, grid size comes from level ranges. Here we use config defaults.

	vines, mask, err := strategies.TileGridIntoVines(gridSize, spec, profile, cfg, rng)
	if err != nil {
		return model.Level{}, err
	}

	level := model.Level{
		ID:         levelID,
		Name:       "Generated Level",
		Difficulty: difficulty,
		GridSize:   gridSize,
		Vines:      vines,
		Mask:       mask,
	}

	return level, nil
}
