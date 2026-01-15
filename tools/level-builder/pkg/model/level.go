package model

// Level represents a complete game level.
// NOTE: Uses ColorScheme ([]string) at level-level instead of global VineColors map.
// NOTE: Module uses Levels ([]int) + ChallengeLevel (int) instead of LevelRange ([2]int).
type Level struct {
	// Core fields
	ID          int      `json:"id"`
	Name        string   `json:"name,omitempty"`
	Difficulty  string   `json:"difficulty,omitempty"` // "Tutorial", "Seedling", "Sprout", "Nurturing", "Flourishing", "Transcendent"
	GridSize    []int    `json:"grid_size"`            // [width, height]
	Mask        *Mask    `json:"mask,omitempty"`
	Vines       []Vine   `json:"vines"`
	MaxMoves    int      `json:"max_moves"`
	MinMoves    int      `json:"min_moves,omitempty"`
	Complexity  string   `json:"complexity,omitempty"` // "tutorial", "low", "medium", "high", "extreme"
	Grace       int      `json:"grace"`                // 3 or 4
	ColorScheme []string `json:"color_scheme"`         // Color codes for this level

	// Generation metadata persisted for reproducibility & diagnostics
	GenerationSeed      int64   `json:"generation_seed,omitempty"`
	GenerationAttempts  int     `json:"generation_attempts,omitempty"`
	GenerationElapsedMS int64   `json:"generation_elapsed_ms,omitempty"`
	GenerationScore     float64 `json:"generation_score,omitempty"`

	// Seed for reproducible generation (gen2 transcendent levels)
	Seed int64 `json:"seed,omitempty"`

	// These are populated during validation but not persisted
	OccupancyPercent  float64             `json:"-"`
	ColorDistribution map[string]float64  `json:"-"`
	BlockingGraph     map[string][]string `json:"-"`
}

// GetGridWidth returns the width of the grid.
func (l *Level) GetGridWidth() int {
	if len(l.GridSize) > 0 {
		return l.GridSize[0]
	}
	return 0
}

// GetGridHeight returns the height of the grid.
func (l *Level) GetGridHeight() int {
	if len(l.GridSize) > 1 {
		return l.GridSize[1]
	}
	return 0
}

// GetTotalCells returns the total number of cells in the grid.
func (l *Level) GetTotalCells() int {
	return l.GetGridWidth() * l.GetGridHeight()
}

// GetOccupiedCells returns the total number of cells occupied by vines.
func (l *Level) GetOccupiedCells() int {
	total := 0
	for _, vine := range l.Vines {
		total += len(vine.OrderedPath)
	}
	return total
}

// IsCellVisible returns true if the cell at (x, y) is visible (not masked).
func (l *Level) IsCellVisible(x, y int) bool {
	if l.Mask == nil {
		return true
	}
	return !l.Mask.IsMasked(x, y)
}
