package model

// Vine represents a single game entity
type Vine struct {
	ID            string  `json:"id"`
	HeadDirection string  `json:"head_direction"` // "up", "down", "left", "right"
	OrderedPath   []Point `json:"ordered_path"`
	ColorIndex    int     `json:"color_index,omitempty"` // Index into Level.ColorScheme
}

// Length returns the number of segments in the vine's path.
func (v Vine) Length() int {
	return len(v.OrderedPath)
}
