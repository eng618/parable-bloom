package model

// Parable represents the narrative content unlocked at the end of a module
type Parable struct {
	Title           string `json:"title"`
	Scripture       string `json:"scripture"`
	Content         string `json:"content"`
	Reflection      string `json:"reflection"`
	BackgroundImage string `json:"background_image"`
}
