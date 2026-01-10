package model

// Point represents a 2D coordinate
type Point struct {
	X int `json:"x"`
	Y int `json:"y"`
}

// Mask defines the visibility of the grid
type Mask struct {
	Mode   string  `json:"mode"`   // "hide", "show", "show-all"
	Points []Point `json:"points"` // Coordinates affected by the mask
}

// Vine represents a single game entity
type Vine struct {
	ID            string  `json:"id"`
	HeadDirection string  `json:"head_direction"` // "up", "down", "left", "right"
	OrderedPath   []Point `json:"ordered_path"`
	ColorIndex    int     `json:"color_index,omitempty"` // Index into Level.ColorScheme
}

// Level represents a single level (Tutorial or Standard)
type Level struct {
	// Tier A: Runtime-Critical
	ID          int      `json:"id"`
	GridSize    []int    `json:"grid_size"` // [width, height]
	Vines       []Vine   `json:"vines"`
	MaxMoves    int      `json:"max_moves"`
	Grace       int      `json:"grace"`
	ColorScheme []string `json:"color_scheme"`

	// Tier B: Design Metadata
	Name       string `json:"name,omitempty"`
	Difficulty string `json:"difficulty,omitempty"`
	Complexity string `json:"complexity,omitempty"`
	MinMoves   int    `json:"min_moves,omitempty"`
	Mask       *Mask  `json:"mask,omitempty"`
}

// Parable represents the narrative content unlocked at the end of a module
type Parable struct {
	Title           string `json:"title"`
	Scripture       string `json:"scripture"`
	Content         string `json:"content"`
	Reflection      string `json:"reflection"`
	BackgroundImage string `json:"background_image"`
}

// Module represents a group of levels
type Module struct {
	ID             int     `json:"id"`
	Name           string  `json:"name"`
	ThemeSeed      string  `json:"theme_seed"`
	Levels         []int   `json:"levels"`
	ChallengeLevel int     `json:"challenge_level"`
	Parable        Parable `json:"parable"`
	UnlockMessage  string  `json:"unlock_message"`
}

// ModuleRegistry represents the contents of modules.json
type ModuleRegistry struct {
	Version   string   `json:"version"`
	Tutorials []int    `json:"tutorials"`
	Modules   []Module `json:"modules"`
}
