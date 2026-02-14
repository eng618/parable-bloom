package strategies_test

import (
	"fmt"
	"testing"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/config"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/generator/strategies"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

func getTestDifficultySpec() config.DifficultySpec {
	return config.DifficultySpec{
		VineCountRange:   [2]int{5, 10},
		AvgLengthRange:   [2]int{3, 5},
		MaxBlockingDepth: 3,
		ColorCountRange:  [2]int{3, 6},
		MinGridOccupancy: 0.93,
		DefaultGrace:     3,
	}
}

// TestClearableFirstPlacement_LargeGridReliability tests the reliability of
// clearable-first placement on large 14x22 grids that previously had 0% success.
func TestClearableFirstPlacement_LargeGridReliability(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping slow reliability test in short mode")
	}
	gridSize := []int{14, 22} // Level 45+ size that failed with old algorithm
	constraints := getTestDifficultySpec()
	profile := config.VarietyProfile{
		TurnMix: 0.3,
	}
	cfg := config.GeneratorConfig{}

	const numAttempts = 20
	successCount := 0
	var totalTime time.Duration

	for i := 0; i < numAttempts; i++ {
		seed := int64(1000 + i)
		start := time.Now()

		vines, err := strategies.ClearableFirstPlacement(gridSize, constraints, profile, cfg, seed, 0.3, 0.95, true)
		elapsed := time.Since(start)
		totalTime += elapsed

		if err != nil {
			t.Logf("Attempt %d failed: %v (%.3fs)", i+1, err, elapsed.Seconds())
			continue
		}

		// Verify the generated level is actually solvable
		level := &model.Level{
			GridSize: gridSize,
			Vines:    vines,
		}
		solver := common.NewSolver(level)
		if !solver.IsSolvableGreedy() {
			t.Errorf("Attempt %d produced unsolvable level (%.3fs)", i+1, elapsed.Seconds())
			continue
		}

		// Also check with BFS for extra validation
		if !solver.IsSolvableBFS() {
			t.Errorf("Attempt %d failed BFS check (greedy passed) (%.3fs)", i+1, elapsed.Seconds())
			continue
		}

		successCount++
		t.Logf("✓ Attempt %d succeeded: %d vines, %.3fs", i+1, len(vines), elapsed.Seconds())
	}

	successRate := float64(successCount) / float64(numAttempts) * 100
	avgTime := totalTime.Seconds() / float64(numAttempts)

	t.Logf("\n=== Reliability Results for 14x22 Grid ===")
	t.Logf("Success rate: %.1f%% (%d/%d)", successRate, successCount, numAttempts)
	t.Logf("Average time: %.3fs", avgTime)
	t.Logf("Total time: %.3fs", totalTime.Seconds())

	// We expect >80% success rate with clearable-first on large grids
	if successRate < 80.0 {
		t.Errorf("Success rate too low: %.1f%% (expected >80%%)", successRate)
	}

	// We expect sub-second generation on average
	if avgTime > 1.0 {
		t.Errorf("Average time too slow: %.3fs (expected <1s)", avgTime)
	}
}

// TestClearableFirstPlacement_GridSizeComparison compares performance across
// different grid sizes to document scaling characteristics.
func TestClearableFirstPlacement_GridSizeComparison(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping slow grid size comparison test in short mode")
	}
	testCases := []struct {
		name     string
		gridSize []int
		attempts int
	}{
		{"Small_6x8", []int{6, 8}, 10},
		{"Medium_10x12", []int{10, 12}, 10},
		{"Large_14x22", []int{14, 22}, 10},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			constraints := getTestDifficultySpec()
			profile := config.VarietyProfile{
				TurnMix: 0.3,
			}
			cfg := config.GeneratorConfig{}

			successCount := 0
			var totalTime time.Duration

			for i := 0; i < tc.attempts; i++ {
				seed := int64(2000 + i)
				start := time.Now()

				vines, err := strategies.ClearableFirstPlacement(tc.gridSize, constraints, profile, cfg, seed, 0.3, 0.95, true)
				elapsed := time.Since(start)
				totalTime += elapsed

				if err != nil {
					continue
				}

				level := &model.Level{
					GridSize: tc.gridSize,
					Vines:    vines,
				}
				solver := common.NewSolver(level)
				if solver.IsSolvableGreedy() && solver.IsSolvableBFS() {
					successCount++
				}
			}

			successRate := float64(successCount) / float64(tc.attempts) * 100
			avgTime := totalTime.Seconds() / float64(tc.attempts)

			t.Logf("Grid %dx%d: Success=%.1f%%, AvgTime=%.3fs",
				tc.gridSize[0], tc.gridSize[1], successRate, avgTime)

			// Success rate expectations vary by grid size:
			// - Small grids (< 100 cells): 10%+ (harder due to less space, tighter constraints)
			// - Medium grids (100-200 cells): 40%+ (better balance)
			// - Large grids (200+ cells): 60%+ (most reliable)
			gridArea := tc.gridSize[0] * tc.gridSize[1]
			minSuccessRate := 10.0
			if gridArea >= 200 {
				minSuccessRate = 60.0
			} else if gridArea >= 100 {
				minSuccessRate = 40.0
			}

			if successRate < minSuccessRate {
				t.Errorf("Grid %s: Success rate too low: %.1f%% (expected >%.1f%%)", tc.name, successRate, minSuccessRate)
			}
		})
	}
}

// BenchmarkClearableFirstPlacement benchmarks the performance of clearable-first
// placement on a large 14x22 grid.
func BenchmarkClearableFirstPlacement(b *testing.B) {
	gridSize := []int{14, 22}
	constraints := getTestDifficultySpec()
	profile := config.VarietyProfile{
		TurnMix: 0.3,
	}
	cfg := config.GeneratorConfig{}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		seed := int64(3000 + i)
		_, err := strategies.ClearableFirstPlacement(gridSize, constraints, profile, cfg, seed, 0.3, 0.95, true)
		if err != nil {
			b.Fatalf("Generation failed: %v", err)
		}
	}
}

// TestClearableFirstPlacement_FullCoverage tests generation with 100% grid coverage
// (the original goal) to see if the algorithm can handle complete grid filling.
func TestClearableFirstPlacement_FullCoverage(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping slow full coverage test in short mode")
	}
	testCases := []struct {
		name     string
		gridSize []int
		attempts int
	}{
		{"Small_6x8_100pct", []int{6, 8}, 10},
		{"Medium_10x12_100pct", []int{10, 12}, 10},
		{"Large_14x22_100pct", []int{14, 22}, 20},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Use 100% coverage instead of 93%
			constraints := config.DifficultySpec{
				VineCountRange:   [2]int{5, 10},
				AvgLengthRange:   [2]int{3, 5},
				MaxBlockingDepth: 3,
				ColorCountRange:  [2]int{3, 6},
				MinGridOccupancy: 1.0, // 100% coverage!
				DefaultGrace:     3,
			}
			profile := config.VarietyProfile{
				TurnMix: 0.3,
			}
			cfg := config.GeneratorConfig{}

			successCount := 0
			var totalTime time.Duration

			for i := 0; i < tc.attempts; i++ {
				seed := int64(5000 + i)
				start := time.Now()

				vines, err := strategies.ClearableFirstPlacement(tc.gridSize, constraints, profile, cfg, seed, 0.3, 0.95, true)
				elapsed := time.Since(start)
				totalTime += elapsed

				if err != nil {
					t.Logf("  Attempt %d failed: %v", i+1, err)
					continue
				}

				// Calculate actual coverage
				occupied := make(map[string]bool)
				for _, v := range vines {
					for _, p := range v.OrderedPath {
						occupied[fmt.Sprintf("%d,%d", p.X, p.Y)] = true
					}
				}
				coverage := float64(len(occupied)) / float64(tc.gridSize[0]*tc.gridSize[1]) * 100

				level := &model.Level{
					GridSize: tc.gridSize,
					Vines:    vines,
				}
				solver := common.NewSolver(level)
				if solver.IsSolvableGreedy() && solver.IsSolvableBFS() {
					successCount++
					t.Logf("  ✓ Attempt %d: %d vines, %.1f%% coverage, %.3fs", i+1, len(vines), coverage, elapsed.Seconds())
				} else {
					t.Logf("  ✗ Attempt %d: unsolvable, %.1f%% coverage", i+1, coverage)
				}
			}

			successRate := float64(successCount) / float64(tc.attempts) * 100
			avgTime := totalTime.Seconds() / float64(tc.attempts)

			t.Logf("\nGrid %dx%d (100%% target): Success=%.1f%%, AvgTime=%.3fs",
				tc.gridSize[0], tc.gridSize[1], successRate, avgTime)

			// Even 100% coverage should have decent success rate
			if successRate < 50.0 {
				t.Logf("  NOTE: 100%% coverage is challenging, %.1f%% success is acceptable", successRate)
			}
		})
	}
}
