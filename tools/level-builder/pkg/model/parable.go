package model

// Parable represents the narrative content unlocked at the end of a module
type Parable struct {
	Title           string `json:"title"`
	Scripture       string `json:"scripture"`
	Content         string `json:"content"`
	Reflection      string `json:"reflection"`
	BackgroundImage string `json:"background_image"`
}

// ModuleScripture is a scripture unlock trigger attached to a module
// (starter at the tutorial capstone, supporting micros at *_05/10/15/20).
type ModuleScripture struct {
	ID           string `json:"id"`
	TriggerLevel string `json:"trigger_level"`
	Reference    string `json:"reference"`
	Title        string `json:"title"`
	Type         string `json:"type"`
}
