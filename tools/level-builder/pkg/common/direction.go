package common

import (
	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// Direction constants for clarity
const (
	DirUp    = "up"
	DirDown  = "down"
	DirLeft  = "left"
	DirRight = "right"
)

// AllDirections returns all valid direction strings
var AllDirections = []string{DirUp, DirDown, DirLeft, DirRight}

// DeltaForDirection returns the (dx, dy) movement delta for a given direction
func DeltaForDirection(dir string) (int, int) {
	switch dir {
	case DirRight:
		return 1, 0
	case DirLeft:
		return -1, 0
	case DirUp:
		return 0, 1
	case DirDown:
		return 0, -1
	default:
		return 0, 0
	}
}

// OppositeDirection returns the opposite direction
func OppositeDirection(dir string) string {
	switch dir {
	case DirRight:
		return DirLeft
	case DirLeft:
		return DirRight
	case DirUp:
		return DirDown
	case DirDown:
		return DirUp
	default:
		return dir
	}
}

// deltaToDir maps (dx, dy) deltas to direction strings
var deltaToDir = map[[2]int]string{
	{1, 0}:  DirRight,
	{-1, 0}: DirLeft,
	{0, 1}:  DirUp,
	{0, -1}: DirDown,
}

// DirectionFromDelta returns the direction string for a given (dx, dy) delta
func DirectionFromDelta(dx, dy int) string {
	return deltaToDir[[2]int{dx, dy}]
}

// DirectionFromPoints returns the direction from point a to point b
func DirectionFromPoints(a, b model.Point) string {
	return DirectionFromDelta(b.X-a.X, b.Y-a.Y)
}

// ChooseExitDirection chooses the best direction for a vine to exit the grid.
// This biases heads toward the nearest edge to ensure vines can clear.
func ChooseExitDirection(pos model.Point, gridWidth, gridHeight int) string {
	// Calculate distances to each edge
	distLeft := pos.X
	distRight := gridWidth - 1 - pos.X
	distDown := pos.Y
	distUp := gridHeight - 1 - pos.Y

	// Find minimum distance and corresponding direction
	minDist := distLeft
	bestDir := DirLeft

	if distRight < minDist {
		minDist = distRight
		bestDir = DirRight
	}
	if distDown < minDist {
		minDist = distDown
		bestDir = DirDown
	}
	if distUp < minDist {
		bestDir = DirUp
	}

	return bestDir
}

// IsValidDirection returns true if the string is a valid direction
func IsValidDirection(dir string) bool {
	return dir == DirUp || dir == DirDown || dir == DirLeft || dir == DirRight
}

// PerpendicularDirections returns the two directions perpendicular to the given direction
func PerpendicularDirections(dir string) []string {
	switch dir {
	case DirUp, DirDown:
		return []string{DirLeft, DirRight}
	case DirLeft, DirRight:
		return []string{DirUp, DirDown}
	default:
		return AllDirections
	}
}
