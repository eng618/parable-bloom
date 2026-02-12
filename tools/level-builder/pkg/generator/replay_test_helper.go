package generator

import (
	"encoding/json"
	"math/rand"
	"os"
)

// LoadFixture loads a failing JSON dump fixture and returns a GenerationConfig and rand seeded instance.
func LoadFixture(path string) (GenerationConfig, *rand.Rand, error) {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return GenerationConfig{}, nil, err
	}
	var dump map[string]interface{}
	if err := json.Unmarshal(bytes, &dump); err != nil {
		return GenerationConfig{}, nil, err
	}
	levelID := int(dump["level_id"].(float64))
	grid := dump["grid"].([]interface{})
	w := int(grid[0].(float64))
	h := int(grid[1].(float64))
	seed := int64(dump["seed"].(float64))

	config := GenerationConfig{
		LevelID:     levelID,
		GridWidth:   w,
		GridHeight:  h,
		VineCount:   10, // fixture-driven tests assume default vine count per difficulty
		MaxMoves:    20,
		Randomize:   false,
		Seed:        seed,
		Overwrite:   true,
		MinCoverage: 1.0,
		Difficulty:  "Seedling",
	}

	rng := rand.New(rand.NewSource(seed))
	return config, rng, nil
}
