package common

import (
	"fmt"
	"math/rand"
	"sort"
)

// GenerateLevelID generates a unique level ID starting from a base value.
func GenerateLevelID(baseDir string, start int) int {
	// Find next available ID
	for id := start; id < 100000; id++ {
		path := GetLevelFilePath(id, baseDir)
		if !FileExists(path) {
			return id
		}
	}
	return start
}

// ComputeOccupancy calculates the grid occupancy percentage for a level.
func ComputeOccupancy(level *Level) float64 {
	total := level.GetTotalCells()
	if total == 0 {
		return 0
	}
	occupied := level.GetOccupiedCells()
	return float64(occupied) / float64(total)
}

// DetectCircularBlocking detects circular dependencies in blocking relationships.
// NOTE: Blocking relationships are now computed dynamically rather than stored,
// so this function expects them to be passed in or computed first.
func DetectCircularBlocking(blockingGraph map[string][]string) bool {
	vineIDSet := make(map[string]bool)
	for id := range blockingGraph {
		vineIDSet[id] = true
	}

	// DFS to detect cycle
	visited := make(map[string]bool)
	stack := make(map[string]bool)

	var hasCycle func(id string) bool
	hasCycle = func(id string) bool {
		visited[id] = true
		stack[id] = true

		for _, next := range blockingGraph[id] {
			if !visited[next] {
				if hasCycle(next) {
					return true
				}
			} else if stack[next] {
				return true
			}
		}

		stack[id] = false
		return false
	}

	for vineID := range vineIDSet {
		if !visited[vineID] {
			if hasCycle(vineID) {
				return true
			}
		}
	}

	return false
}

// GetAverageVineLength computes average vine length.
func GetAverageVineLength(vines []Vine) float64 {
	if len(vines) == 0 {
		return 0
	}
	total := 0
	for _, vine := range vines {
		total += vine.Length()
	}
	return float64(total) / float64(len(vines))
}

// GetMinimumVineLength returns the shortest vine length.
func GetMinimumVineLength(vines []Vine) int {
	if len(vines) == 0 {
		return 0
	}
	minLen := vines[0].Length()
	for _, vine := range vines {
		if vine.Length() < minLen {
			minLen = vine.Length()
		}
	}
	return minLen
}

// GetMaximumVineLength returns the longest vine length.
func GetMaximumVineLength(vines []Vine) int {
	if len(vines) == 0 {
		return 0
	}
	maxLen := vines[0].Length()
	for _, vine := range vines {
		if vine.Length() > maxLen {
			maxLen = vine.Length()
		}
	}
	return maxLen
}

// ShuffleVines randomly shuffles a slice of vines using a deterministic seed.
func ShuffleVines(vines []Vine, seed int64) []Vine {
	result := make([]Vine, len(vines))
	copy(result, vines)

	rng := rand.New(rand.NewSource(seed))
	for i := len(result) - 1; i > 0; i-- {
		j := rng.Intn(i + 1)
		result[i], result[j] = result[j], result[i]
	}

	return result
}

// FindVineByID finds a vine by its ID.
func FindVineByID(vines []Vine, id string) *Vine {
	for i := range vines {
		if vines[i].ID == id {
			return &vines[i]
		}
	}
	return nil
}

// CountVinesByColorIndex counts how many vines use each color index.
func CountVinesByColorIndex(vines []Vine) map[int]int {
	counts := make(map[int]int)
	for _, vine := range vines {
		counts[vine.ColorIndex]++
	}
	return counts
}

// CountVinesByDirection counts how many vines face each direction.
func CountVinesByDirection(vines []Vine) map[string]int {
	counts := make(map[string]int)
	for _, vine := range vines {
		counts[vine.HeadDirection]++
	}
	return counts
}

// SortVinesByID returns vines sorted by ID.
func SortVinesByID(vines []Vine) []Vine {
	result := make([]Vine, len(vines))
	copy(result, vines)
	sort.Slice(result, func(i, j int) bool {
		return result[i].ID < result[j].ID
	})
	return result
}

// ComplexityForDifficulty returns the recommended complexity level.
func ComplexityForDifficulty(difficulty string) string {
	switch difficulty {
	case "Tutorial":
		return "tutorial"
	case "Seedling":
		return "low"
	case "Sprout":
		return "low"
	case "Nurturing":
		return "medium"
	case "Flourishing":
		return "high"
	case "Transcendent":
		return "extreme"
	default:
		return "medium"
	}
}

// GraceForDifficulty returns the default grace value for a difficulty.
func GraceForDifficulty(difficulty string) int {
	if spec, ok := DifficultySpecs[difficulty]; ok {
		return spec.DefaultGrace
	}
	return 3
}

// DefaultGridSize returns default grid size for a difficulty (used when not specified).
func DefaultGridSize(difficulty string) []int {
	ranges, ok := GridSizeRanges[difficulty]
	if !ok {
		return []int{9, 12}
	}
	// Return middle of range
	w := (ranges.MinW + ranges.MaxW) / 2
	h := (ranges.MinH + ranges.MaxH) / 2
	return []int{w, h}
}

// DifficultyForLevel returns the difficulty tier for a given level ID.
// Levels 1-10: Seedling
// Levels 11-20: Sprout
// Levels 21-40: Nurturing
// Levels 41-70: Flourishing
// Levels 71+: Transcendent
func DifficultyForLevel(levelID int) string {
	if levelID <= 0 {
		return "Seedling"
	}
	if levelID <= 10 {
		return "Seedling"
	}
	if levelID <= 20 {
		return "Sprout"
	}
	if levelID <= 40 {
		return "Nurturing"
	}
	if levelID <= 70 {
		return "Flourishing"
	}
	return "Transcendent"
}

// GridSizeForLevel returns the appropriate grid size for a level ID.
func GridSizeForLevel(levelID int) []int {
	difficulty := DifficultyForLevel(levelID)
	return DefaultGridSize(difficulty)
}

// PointKey creates a unique key for a point (used in maps).
func PointKey(pt Point) string {
	return fmt.Sprintf("%d,%d", pt.X, pt.Y)
}

// ParsePointKey parses a point key back to coordinates.
func ParsePointKey(key string) (x, y int) {
	var n int
	n, _ = fmt.Sscanf(key, "%d,%d", &x, &y)
	if n != 2 {
		// return zeros if parsing failed
		return 0, 0
	}
	return x, y
}
