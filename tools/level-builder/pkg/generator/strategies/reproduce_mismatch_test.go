package strategies

import (
	"fmt"
	"math/rand"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/utils"
	//"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func TestClearableSecondPhaseMismatch(t *testing.T) {
	// Setup config for Level 17 (Flourishing)
	difficulty := "Flourishing"
	spec := config.DifficultySpecs[difficulty]
	// Use strict occupancy to mimic original failure condition
	spec.MinGridOccupancy = 0.95
	profile := utils.GetPresetProfile(difficulty)
	genCfg := utils.GetGeneratorConfigForDifficulty(difficulty)
	gridSize := []int{14, 22}

	// Specific failing base seed
	baseSeed := int64(569780)

	// Try first 100 attempts to be safe (generator tries up to 10000)
	for attempt := 0; attempt <= 100; attempt++ {
		attemptSeed := baseSeed + int64(attempt)*7919
		rng := rand.New(rand.NewSource(attemptSeed))

		// The generator uses the first Int63() as the seed for ClearableFirst
		// BUT wait, it calls attemptRng.Int63() as argument to ClearableFirstPlacement.
		// So we do:
		seed := rng.Int63()

		fmt.Printf("Testing attempt %d with attemptSeed %d -> actualSeed %d\n", attempt, attemptSeed, seed)
		vines, err := ClearableFirstPlacement(gridSize, spec, profile, genCfg, seed, 0.3, spec.MinGridOccupancy, true)
		if err != nil {
			common.Verbose("Attempt %d failed: %v", attempt, err)
			continue
		}

		for _, v := range vines {
			if len(v.OrderedPath) < 2 {
				continue
			}
			head := v.OrderedPath[0]
			neck := v.OrderedPath[1]
			dx := head.X - neck.X
			dy := head.Y - neck.Y

			// Validate direction
			var expectedDx, expectedDy int
			switch v.HeadDirection {
			case "up":
				expectedDx, expectedDy = 0, 1
			case "down":
				expectedDx, expectedDy = 0, -1
			case "left":
				expectedDx, expectedDy = -1, 0
			case "right":
				expectedDx, expectedDy = 1, 0
			}

			if dx != expectedDx || dy != expectedDy {
				t.Fatalf("MISMATCH DETECTED in attempt %d vine %s: head=%v neck=%v dir=%s (dx=%d dy=%d)",
					attempt, v.ID, head, neck, v.HeadDirection, dx, dy)
			}
		}
	}
}
