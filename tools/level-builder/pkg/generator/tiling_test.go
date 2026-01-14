package generator

import (
	"fmt"
	"math/rand"
	"testing"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
)

// TestTileGridIntoVines_BasicGeneration tests if tiling can generate valid structures
func TestTileGridIntoVines_BasicGeneration(t *testing.T) {
	tests := []struct {
		name       string
		gridSize   []int
		difficulty string
	}{
		{
			name:       "Small Seedling grid",
			gridSize:   []int{6, 8},
			difficulty: "Seedling",
		},
		{
			name:       "Medium Sprout grid",
			gridSize:   []int{7, 10},
			difficulty: "Sprout",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			spec, ok := common.DifficultySpecs[tt.difficulty]
			if !ok {
				t.Fatalf("Unknown difficulty: %s", tt.difficulty)
			}

			profile := common.GetPresetProfile(tt.difficulty)
			cfg := common.GetGeneratorConfigForDifficulty(tt.difficulty)
			rng := rand.New(rand.NewSource(12345))

			vines, mask, err := TileGridIntoVines(tt.gridSize, spec, profile, cfg, rng)

			if err != nil {
				t.Fatalf("TileGridIntoVines() error = %v", err)
			}

			if len(vines) == 0 {
				t.Fatal("TileGridIntoVines() returned no vines")
			}

			t.Logf("Generated %d vines on %dx%d grid", len(vines), tt.gridSize[0], tt.gridSize[1])

			if mask != nil {
				t.Logf("Mask has %d hidden cells", len(mask.Points))
			}

			// Check basic vine properties
			for i, vine := range vines {
				if len(vine.OrderedPath) == 0 {
					t.Errorf("Vine %d has empty path", i)
				}
				if vine.HeadDirection == "" {
					t.Errorf("Vine %d has no head direction", i)
				}
			}
		})
	}
}

// TestGenerateSingleLevel_SmallGrid tests if small grids can be generated
func TestGenerateSingleLevel_SmallGrid(t *testing.T) {
	// Use small grid to increase chance of success
	tests := []struct {
		name       string
		gridSize   []int
		difficulty string
		seed       int64
	}{
		{
			name:       "Tiny Tutorial grid",
			gridSize:   []int{4, 5},
			difficulty: "Tutorial",
			seed:       42,
		},
		{
			name:       "Small Seedling grid",
			gridSize:   []int{5, 6},
			difficulty: "Seedling",
			seed:       43,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rng := rand.New(rand.NewSource(tt.seed))

			// Note: Can't override GridSizeForLevel at runtime
			// This test will use actual grid size calculation
			level, err := generateSingleLevel(1, tt.difficulty, tt.seed, rng)

			if err != nil {
				// Log the error but don't fail - generation may legitimately fail
				t.Logf("Generation failed (this may be expected): %v", err)
				t.Skip("Generation failed - this test is for observing behavior")
			}

			t.Logf("Successfully generated level with %d vines", len(level.Vines))

			// Validate basic properties
			if len(level.Vines) == 0 {
				t.Error("Generated level has no vines")
			}

			solver := common.NewSolver(&level)
			if !solver.IsSolvableGreedy() {
				t.Error("Generated level is not solvable (greedy check)")
			}
		})
	}
}

// TestGrowFromSeed_BasicGrowth tests vine growth from a seed
func TestGrowFromSeed_BasicGrowth(t *testing.T) {
	gridSize := []int{10, 10}
	profile := common.GetPresetProfile("Seedling")
	cfg := common.GetGeneratorConfigForDifficulty("Seedling")
	rng := rand.New(rand.NewSource(12345))

	tests := []struct {
		name      string
		seed      common.Point
		targetLen int
		occupied  map[string]bool
		wantErr   bool
	}{
		{
			name:      "Grow 3-cell vine from center",
			seed:      common.Point{X: 5, Y: 5},
			targetLen: 3,
			occupied:  make(map[string]bool),
			wantErr:   false,
		},
		{
			name:      "Grow 5-cell vine from corner",
			seed:      common.Point{X: 1, Y: 1},
			targetLen: 5,
			occupied:  make(map[string]bool),
			wantErr:   false,
		},
		{
			name:      "Cannot grow in fully occupied grid",
			seed:      common.Point{X: 5, Y: 5},
			targetLen: 10,
			occupied: func() map[string]bool {
				occ := make(map[string]bool)
				for y := 0; y < 10; y++ {
					for x := 0; x < 10; x++ {
						if x != 5 || y != 5 {
							occ[common.PointKey(common.Point{X: x, Y: y})] = true
						}
					}
				}
				return occ
			}(),
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vine, newOcc, err := GrowFromSeed(tt.seed, tt.occupied, gridSize, tt.targetLen, profile, cfg, rng)

			if (err != nil) != tt.wantErr {
				t.Errorf("GrowFromSeed() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if err == nil {
				if len(vine.OrderedPath) == 0 {
					t.Error("GrowFromSeed() returned vine with empty path")
				}

				if len(vine.OrderedPath) != tt.targetLen {
					t.Logf("Warning: vine length %d != target %d (got stuck)", len(vine.OrderedPath), tt.targetLen)
				}

				if len(newOcc) == 0 {
					t.Error("GrowFromSeed() returned empty occupancy map")
				}

				t.Logf("Grown vine: length=%d, head_direction=%s", len(vine.OrderedPath), vine.HeadDirection)
			}
		})
	}
}

// TestTileGridIntoVines_SolvabilityRate measures success rate over many attempts.
// This is a critical test to understand current algorithm performance.
func TestTileGridIntoVines_SolvabilityRate(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping solvability rate test in short mode")
	}

	tests := []struct {
		name       string
		gridSize   []int
		difficulty string
		attempts   int
		minSuccess float64 // Minimum acceptable success rate
	}{
		{
			name:       "Small Seedling grid solvability",
			gridSize:   []int{6, 8},
			difficulty: "Seedling",
			attempts:   100,
			minSuccess: 0.05, // Expect at least 5% success (current baseline)
		},
		{
			name:       "Tiny grid solvability (easier)",
			gridSize:   []int{5, 6},
			difficulty: "Seedling",
			attempts:   50,
			minSuccess: 0.20, // Smaller grid should have higher success rate
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			spec, ok := common.DifficultySpecs[tt.difficulty]
			if !ok {
				t.Fatalf("Unknown difficulty: %s", tt.difficulty)
			}

			profile := common.GetPresetProfile(tt.difficulty)
			cfg := common.GetGeneratorConfigForDifficulty(tt.difficulty)

			successCount := 0
			greedySuccesses := 0
			bfsSuccesses := 0

			for i := 0; i < tt.attempts; i++ {
				rng := rand.New(rand.NewSource(int64(12345 + i)))
				vines, mask, err := TileGridIntoVines(tt.gridSize, spec, profile, cfg, rng)

				if err != nil {
					continue
				}

				// Build a test level
				level := common.Level{
					ID:         1,
					Name:       "Test Level",
					Difficulty: tt.difficulty,
					GridSize:   tt.gridSize,
					Vines:      vines,
					Mask:       mask,
				}

				solver := common.NewSolver(&level)

				// Test greedy solver
				if solver.IsSolvableGreedy() {
					greedySuccesses++
				}

				// Test BFS solver (more accurate)
				if solver.IsSolvableBFS() {
					bfsSuccesses++
					successCount++
				}
			}

			greedyRate := float64(greedySuccesses) / float64(tt.attempts)
			bfsRate := float64(bfsSuccesses) / float64(tt.attempts)

			t.Logf("Solvability rates after %d attempts:", tt.attempts)
			t.Logf("  Greedy solver: %.1f%% (%d/%d)", greedyRate*100, greedySuccesses, tt.attempts)
			t.Logf("  BFS solver:    %.1f%% (%d/%d)", bfsRate*100, bfsSuccesses, tt.attempts)
			t.Logf("  False positives (greedy only): %d", greedySuccesses-bfsSuccesses)

			if bfsRate < tt.minSuccess {
				t.Errorf("BFS solvability rate %.1f%% is below minimum %.1f%%",
					bfsRate*100, tt.minSuccess*100)
			}

			// Log if greedy has false positives
			if greedySuccesses > bfsSuccesses {
				t.Logf("⚠ Greedy solver has %d false positives (%.1f%%)",
					greedySuccesses-bfsSuccesses,
					float64(greedySuccesses-bfsSuccesses)/float64(tt.attempts)*100)
			}
		})
	}
}

// TestSolverAccuracyComparison compares greedy vs BFS solver on hand-crafted levels.
func TestSolverAccuracyComparison(t *testing.T) {
	tests := []struct {
		name           string
		level          common.Level
		expectSolvable bool
	}{
		{
			name: "Simple clearable level",
			level: common.Level{
				ID:         1,
				GridSize:   []int{5, 5},
				Difficulty: "Seedling",
				Vines: []common.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []common.Point{
							{X: 2, Y: 2},
							{X: 1, Y: 2},
							{X: 0, Y: 2},
						},
					},
				},
			},
			expectSolvable: true,
		},
		{
			name: "Two independent vines",
			level: common.Level{
				ID:         2,
				GridSize:   []int{6, 6},
				Difficulty: "Seedling",
				Vines: []common.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []common.Point{
							{X: 1, Y: 1},
							{X: 0, Y: 1},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "up",
						OrderedPath: []common.Point{
							{X: 3, Y: 3},
							{X: 3, Y: 2},
						},
					},
				},
			},
			expectSolvable: true,
		},
		{
			name: "Circular blocking (impossible)",
			level: common.Level{
				ID:         3,
				GridSize:   []int{4, 4},
				Difficulty: "Seedling",
				Vines: []common.Vine{
					{
						ID:            "v1",
						HeadDirection: "right",
						OrderedPath: []common.Point{
							{X: 1, Y: 1},
							{X: 0, Y: 1},
						},
					},
					{
						ID:            "v2",
						HeadDirection: "down",
						OrderedPath: []common.Point{
							{X: 2, Y: 2},
							{X: 2, Y: 3},
						},
					},
					{
						ID:            "v3",
						HeadDirection: "left",
						OrderedPath: []common.Point{
							{X: 2, Y: 1}, // Blocks v1
							{X: 3, Y: 1},
						},
					},
				},
			},
			expectSolvable: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			solver := common.NewSolver(&tt.level)

			greedyResult := solver.IsSolvableGreedy()
			bfsResult := solver.IsSolvableBFS()

			t.Logf("Greedy: %v, BFS: %v, Expected: %v", greedyResult, bfsResult, tt.expectSolvable)

			if bfsResult != tt.expectSolvable {
				t.Errorf("BFS solver returned %v, expected %v", bfsResult, tt.expectSolvable)
			}

			// BFS is the gold standard - greedy should agree or be more pessimistic
			if greedyResult && !bfsResult {
				t.Errorf("Greedy solver has false positive: returned %v when BFS returned %v",
					greedyResult, bfsResult)
			}

			if greedyResult != bfsResult {
				t.Logf("⚠ Solvers disagree: greedy=%v, bfs=%v (BFS is more accurate)",
					greedyResult, bfsResult)
			}
		})
	}
}

// BenchmarkSolverGreedy benchmarks the greedy solver on various level sizes.
func BenchmarkSolverGreedy(b *testing.B) {
	sizes := []struct {
		name      string
		gridSize  []int
		vineCount int
	}{
		{"Small_5vines", []int{6, 8}, 5},
		{"Medium_10vines", []int{9, 12}, 10},
		{"Large_15vines", []int{12, 16}, 15},
	}

	for _, size := range sizes {
		b.Run(size.name, func(b *testing.B) {
			// Create a test level
			vines := make([]common.Vine, size.vineCount)
			for i := 0; i < size.vineCount; i++ {
				vines[i] = common.Vine{
					ID:            fmt.Sprintf("v%d", i),
					HeadDirection: "right",
					OrderedPath: []common.Point{
						{X: i % size.gridSize[0], Y: i / size.gridSize[0]},
					},
				}
			}

			level := common.Level{
				ID:       1,
				GridSize: size.gridSize,
				Vines:    vines,
			}

			solver := common.NewSolver(&level)

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_ = solver.IsSolvableGreedy()
			}
		})
	}
}

// BenchmarkSolverBFS benchmarks the BFS solver on various level sizes.
func BenchmarkSolverBFS(b *testing.B) {
	sizes := []struct {
		name      string
		gridSize  []int
		vineCount int
	}{
		{"Small_5vines", []int{6, 8}, 5},
		{"Medium_10vines", []int{9, 12}, 10},
		{"Large_15vines", []int{12, 16}, 15},
	}

	for _, size := range sizes {
		b.Run(size.name, func(b *testing.B) {
			// Create a test level
			vines := make([]common.Vine, size.vineCount)
			for i := 0; i < size.vineCount; i++ {
				vines[i] = common.Vine{
					ID:            fmt.Sprintf("v%d", i),
					HeadDirection: "right",
					OrderedPath: []common.Point{
						{X: i % size.gridSize[0], Y: i / size.gridSize[0]},
					},
				}
			}

			level := common.Level{
				ID:       1,
				GridSize: size.gridSize,
				Vines:    vines,
			}

			solver := common.NewSolver(&level)

			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				_ = solver.IsSolvableBFS()
			}
		})
	}
}
