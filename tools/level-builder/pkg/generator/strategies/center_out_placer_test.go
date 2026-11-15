package strategies

import (
	"math/rand"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
)

func TestCalculateVineLengthsRespectsSpecMax(t *testing.T) {
	p := &CenterOutPlacer{}
	cfg := config.GenerationConfig{
		Difficulty:  "Seedling",
		GridWidth:   9,
		GridHeight:  12,
		VineCount:   200,
		MinCoverage: 0.97,
	}
	lengths := p.calculateVineLengths(cfg, rand.New(rand.NewSource(1)))
	if len(lengths) == 0 || len(lengths) > 24 {
		t.Fatalf("got %d lengths, want 1..24", len(lengths))
	}
}

func TestPlaceVinesStaysWithinSeedlingCap(t *testing.T) {
	p := &CenterOutPlacer{}
	cfg := config.GenerationConfig{
		Difficulty:  "Seedling",
		GridWidth:   9,
		GridHeight:  12,
		VineCount:   200,
		MinCoverage: 0.97,
		LevelID:     1,
	}
	vines, _, err := p.PlaceVines(cfg, rand.New(rand.NewSource(1)), &config.GenerationStats{})
	if err != nil {
		t.Fatal(err)
	}
	if len(vines) == 0 || len(vines) > 24 {
		t.Fatalf("placed %d vines, want 1..24", len(vines))
	}
}

func TestVineCountCapUnknownDifficultyIsUnlimited(t *testing.T) {
	if got := vineCountCap("not-a-tier"); got != 0 {
		t.Fatalf("unknown difficulty cap = %d, want 0", got)
	}
	if got := vineCountCap("Seedling"); got != 24 {
		t.Fatalf("Seedling cap = %d, want 24", got)
	}
}
