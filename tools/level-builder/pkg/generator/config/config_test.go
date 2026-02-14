package config

import (
	"testing"
)

func TestDifficultySpecs(t *testing.T) {
	expectedTiers := []string{
		"Tutorial", "Seedling", "Sprout",
		"Nurturing", "Flourishing", "Transcendent",
	}

	for _, tier := range expectedTiers {
		spec, ok := DifficultySpecs[tier]
		if !ok {
			t.Errorf("Missing difficulty spec for tier: %s", tier)
			continue
		}

		if spec.VineCountRange[0] > spec.VineCountRange[1] {
			t.Errorf("Invalid VineCountRange for %s: %v", tier, spec.VineCountRange)
		}
		if spec.AvgLengthRange[0] > spec.AvgLengthRange[1] {
			t.Errorf("Invalid AvgLengthRange for %s: %v", tier, spec.AvgLengthRange)
		}
		if spec.MinGridOccupancy <= 0 || spec.MinGridOccupancy > 1 {
			t.Errorf("Invalid MinGridOccupancy for %s: %f", tier, spec.MinGridOccupancy)
		}
	}
}

func TestColorPalette(t *testing.T) {
	if len(ColorPalette) == 0 {
		t.Error("ColorPalette is empty")
	}
	for _, color := range ColorPalette {
		if len(color) != 7 || color[0] != '#' {
			t.Errorf("Invalid color format: %s", color)
		}
	}
}

func TestGridSizeRanges(t *testing.T) {
	for tier, sizes := range GridSizeRanges {
		if sizes.MinW > sizes.MaxW {
			t.Errorf("Invalid width range for %s: %d-%d", tier, sizes.MinW, sizes.MaxW)
		}
		if sizes.MinH > sizes.MaxH {
			t.Errorf("Invalid height range for %s: %d-%d", tier, sizes.MinH, sizes.MaxH)
		}
	}
}
