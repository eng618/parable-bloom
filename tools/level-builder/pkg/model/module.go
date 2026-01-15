package model

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
