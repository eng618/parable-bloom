package model

// Mask defines the visibility of the grid
type Mask struct {
	Mode   string  `json:"mode"`   // "hide", "show", "show-all"
	Points []Point `json:"points"` // Coordinates affected by the mask
}

// IsMasked returns true if the given point should be masked (hidden) based on the mask mode.
func (m *Mask) IsMasked(x, y int) bool {
	if m == nil {
		return false
	}
	inMask := false
	for _, pt := range m.Points {
		if pt.X == x && pt.Y == y {
			inMask = true
			break
		}
	}
	switch m.Mode {
	case "hide":
		return inMask
	case "show":
		return !inMask
	case "show-all":
		return false
	default:
		return false
	}
}
