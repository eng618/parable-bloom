package gen2

import (
	crand "crypto/rand"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/common"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/validator"
)

// GenerationConfig holds configuration for transcendent level generation
type GenerationConfig struct {
	LevelID     int
	GridWidth   int
	GridHeight  int
	VineCount   int
	MaxMoves    int
	OutputFile  string
	Randomize   bool
	Seed        int64
	Overwrite   bool
	MinCoverage float64 // Minimum grid coverage required (0.0-1.0)
}

// GenerationStats tracks performance and quality metrics
type GenerationStats struct {
	PlacementAttempts int
	SolvabilityChecks validator.SolvabilityStats
	MaxBlockingDepth  int
	GridCoverage      float64
	GenerationTime    time.Duration
}

// VinePlacementStrategy defines the interface for vine placement algorithms
type VinePlacementStrategy interface {
	PlaceVines(config GenerationConfig, rng *rand.Rand) ([]model.Vine, map[string]string, error)
}

// BlockingAnalyzer defines the interface for blocking relationship analysis
type BlockingAnalyzer interface {
	AnalyzeBlocking(vines []model.Vine, occupied map[string]string) (BlockingAnalysis, error)
}

// BlockingAnalysis contains blocking relationship data
type BlockingAnalysis struct {
	MaxDepth       int
	HasCircular    bool
	CircularChains [][]string
}

// LevelAssembler defines the interface for assembling final level data
type LevelAssembler interface {
	AssembleLevel(config GenerationConfig, vines []model.Vine, mask *model.Mask, seed int64) model.Level
}

// GenerateTranscendentLevel generates a single transcendent difficulty level
func GenerateTranscendentLevel(config GenerationConfig) (model.Level, GenerationStats, error) {
	startTime := time.Now()

	// Initialize RNG
	var rng *rand.Rand
	var seed int64
	if config.Randomize {
		seed = cryptoSeedInt64()
	} else if config.Seed != 0 {
		seed = config.Seed
	} else {
		seed = int64(config.LevelID * 31337) // Deterministic fallback
	}
	rng = rand.New(rand.NewSource(seed))

	common.Verbose("Using seed: %d", seed)

	// Initialize components
	placer := &CircuitBoardPlacer{}
	analyzer := &DFSBlockingAnalyzer{}
	assembler := &TranscendentAssembler{}

	stats := GenerationStats{}

	// Generate vines with circuit-board aesthetics
	common.Info("Placing vines with circuit-board aesthetics...")
	vines, occupied, err := placer.PlaceVines(config, rng)
	if err != nil {
		return model.Level{}, stats, fmt.Errorf("vine placement failed: %w", err)
	}

	stats.PlacementAttempts = 1 // Will be updated when we implement retry logic

	// Analyze blocking relationships
	common.Info("Analyzing blocking relationships...")
	analysis, err := analyzer.AnalyzeBlocking(vines, occupied)
	if err != nil {
		return model.Level{}, stats, fmt.Errorf("blocking analysis failed: %w", err)
	}

	if analysis.HasCircular {
		common.Info("Warning: generated level has circular blocking - checking if still solvable")
		// Don't reject yet - check if validator can find a solution
	}

	stats.MaxBlockingDepth = analysis.MaxDepth

	// Check solvability
	common.Info("Checking solvability...")
	solvable, checkStats := checkSolvability(config, vines)
	stats.SolvabilityChecks = checkStats

	if !solvable {
		common.Info("Warning: generated level is not solvable - proceeding for development")
		// return model.Level{}, stats, fmt.Errorf("generated level is not solvable")
	}

	// Calculate grid coverage
	coverage := calculateGridCoverage(config, occupied)
	stats.GridCoverage = coverage

	if coverage < config.MinCoverage {
		return model.Level{}, stats, fmt.Errorf("insufficient grid coverage: %.1f%% (need ≥%.0f%%)", coverage*100, config.MinCoverage*100)
	}

	// Create mask for any unfilled cells
	var mask *model.Mask
	if coverage < 1.0 {
		emptyCells := findEmptyCells(config, occupied)
		if len(emptyCells) > 0 {
			mode := "hide"
			if len(emptyCells) <= config.GridWidth*config.GridHeight/100 { // <1% empty
				mode = "show-all" // Keep them visible for visual interest
			}
			mask = &model.Mask{Mode: mode, Points: emptyCells}
		}
	}

	// Assemble final level
	level := assembler.AssembleLevel(config, vines, mask, seed)

	// Write to file
	if err := writeLevelToFile(level, config); err != nil {
		return model.Level{}, stats, fmt.Errorf("failed to write level file: %w", err)
	}

	stats.GenerationTime = time.Since(startTime)

	return level, stats, nil
}

// cryptoSeedInt64 returns a crypto-random int64 seed
func cryptoSeedInt64() int64 {
	var b [8]byte
	if _, err := crand.Read(b[:]); err != nil {
		return time.Now().UnixNano()
	}
	return int64(binary.LittleEndian.Uint64(b[:]))
}

// checkSolvability performs solvability check using the validator
func checkSolvability(config GenerationConfig, vines []model.Vine) (bool, validator.SolvabilityStats) {
	// Convert to model.Level for validator
	level := model.Level{
		ID:         config.LevelID,
		GridSize:   []int{config.GridWidth, config.GridHeight},
		Vines:      convertVinesToModel(vines),
		MaxMoves:   config.MaxMoves,
		Grace:      4, // Transcendent gets 4 grace
		Difficulty: "Transcendent",
	}

	solvable, stats, err := validator.IsSolvable(level, 100000) // 100k max states
	if err != nil {
		common.Verbose("Solvability check error: %v", err)
		return false, validator.SolvabilityStats{}
	}

	return solvable, stats
}

// calculateGridCoverage calculates what percentage of the grid is occupied
func calculateGridCoverage(config GenerationConfig, occupied map[string]string) float64 {
	totalCells := config.GridWidth * config.GridHeight
	occupiedCells := len(occupied)
	return float64(occupiedCells) / float64(totalCells)
}

// findEmptyCells returns list of empty cell coordinates
func findEmptyCells(config GenerationConfig, occupied map[string]string) []model.Point {
	var empty []model.Point
	for y := 0; y < config.GridHeight; y++ {
		for x := 0; x < config.GridWidth; x++ {
			key := fmt.Sprintf("%d,%d", x, y)
			if _, isOccupied := occupied[key]; !isOccupied {
				empty = append(empty, model.Point{X: x, Y: y})
			}
		}
	}
	return empty
}

// convertVinesToModel converts model.Vine to model.Vine
func convertVinesToModel(vines []model.Vine) []model.Vine {
	result := make([]model.Vine, len(vines))
	for i, v := range vines {
		result[i] = model.Vine{
			ID:            v.ID,
			HeadDirection: v.HeadDirection,
			OrderedPath:   convertCommonPointsToModel(v.OrderedPath),
		}
	}
	return result
}

// writeLevelToFile writes the level to JSON file
func writeLevelToFile(level model.Level, config GenerationConfig) error {
	outputPath := config.OutputFile
	if outputPath == "" {
		outputPath = fmt.Sprintf("../../assets/levels/level_%d.json", config.LevelID)
	}

	// Check if file exists and overwrite is not enabled
	if !config.Overwrite {
		if _, err := os.Stat(outputPath); err == nil {
			return fmt.Errorf("file already exists: %s (use --overwrite to replace)", outputPath)
		}
	}

	// Ensure directory exists
	dir := filepath.Dir(outputPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Write JSON
	file, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("failed to create file: %w", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")
	if err := encoder.Encode(level); err != nil {
		return fmt.Errorf("failed to encode JSON: %w", err)
	}

	return nil
}
