package validator

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// KnownVineColors defines all valid vine_color keys from VineColorPalette
var KnownVineColors = map[string]bool{
	"default":      true,
	"red":          true,
	"orange":       true,
	"yellow":       true,
	"green":        true,
	"cyan":         true,
	"blue":         true,
	"purple":       true,
	"pink":         true,
	"brown":        true,
	"grey":         true,
	"light_green":  true,
	"light_blue":   true,
	"light_purple": true,
}

// StructuralError represents a validation error with context
type StructuralError struct {
	VineID  string
	Message string
}

func (e StructuralError) Error() string {
	if e.VineID != "" {
		return fmt.Sprintf("vine %s: %s", e.VineID, e.Message)
	}
	return e.Message
}

// ValidateStructural performs comprehensive structural validation on a level.
// Returns all validation errors found (does not stop at first error).
func ValidateStructural(lvl model.Level) []error {
	var errors []error

	// Note: vine_color validation skipped as it's not currently used in level files
	// and the Vine model doesn't have a VineColor field yet. When vine_color is
	// added to the JSON schema and model, uncomment this validation:
	//
	// for _, v := range lvl.Vines {
	//     if v.VineColor != "" && !KnownVineColors[v.VineColor] {
	//         errors = append(errors, StructuralError{
	//             VineID:  v.ID,
	//             Message: fmt.Sprintf("unknown vine_color '%s'", v.VineColor),
	//         })
	//     }
	// }

	// Build occupancy map and check overlaps/bounds/masked cells
	w, h := lvl.GridSize[0], lvl.GridSize[1]
	occupied := make(map[string]string) // "x,y" -> vineID

	for _, v := range lvl.Vines {
		for _, p := range v.OrderedPath {
			// Check bounds
			if p.X < 0 || p.X >= w || p.Y < 0 || p.Y >= h {
				errors = append(errors, StructuralError{
					VineID: v.ID,
					Message: fmt.Sprintf("cell (%d,%d) out of bounds (grid %dx%d)",
						p.X, p.Y, w, h),
				})
				continue
			}

			// Check masked cells
			if !isCellVisible(lvl, p.X, p.Y) {
				errors = append(errors, StructuralError{
					VineID: v.ID,
					Message: fmt.Sprintf("cell (%d,%d) is masked out but occupied",
						p.X, p.Y),
				})
			}

			// Check overlaps
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			if existingVine, exists := occupied[key]; exists {
				errors = append(errors, StructuralError{
					VineID: v.ID,
					Message: fmt.Sprintf("cell (%d,%d) overlaps with vine %s",
						p.X, p.Y, existingVine),
				})
			} else {
				occupied[key] = v.ID
			}
		}
	}

	// Validate each vine's structure
	for _, v := range lvl.Vines {
		// Check minimum length
		if len(v.OrderedPath) < 2 {
			errors = append(errors, StructuralError{
				VineID:  v.ID,
				Message: fmt.Sprintf("vine has only %d segments (minimum 2)", len(v.OrderedPath)),
			})
			continue
		}

		// Check head/neck orientation
		head := v.OrderedPath[0]
		neck := v.OrderedPath[1]
		dx := head.X - neck.X
		dy := head.Y - neck.Y

		expectedDx, expectedDy := 0, 0
		switch v.HeadDirection {
		case "right":
			expectedDx, expectedDy = 1, 0
		case "left":
			expectedDx, expectedDy = -1, 0
		case "up":
			expectedDx, expectedDy = 0, 1
		case "down":
			expectedDx, expectedDy = 0, -1
		default:
			errors = append(errors, StructuralError{
				VineID:  v.ID,
				Message: fmt.Sprintf("unknown head_direction '%s'", v.HeadDirection),
			})
			continue
		}

		if dx != expectedDx || dy != expectedDy {
			errors = append(errors, StructuralError{
				VineID: v.ID,
				Message: fmt.Sprintf("head/neck mismatch: head=(%d,%d) neck=(%d,%d) direction=%s (expected delta (%d,%d), got (%d,%d))",
					head.X, head.Y, neck.X, neck.Y, v.HeadDirection,
					expectedDx, expectedDy, dx, dy),
			})
		}

		// Check 4-connectivity (8-point connectivity = adjacent cells only)
		for i := 1; i < len(v.OrderedPath); i++ {
			prev := v.OrderedPath[i-1]
			curr := v.OrderedPath[i]
			dx := abs(curr.X - prev.X)
			dy := abs(curr.Y - prev.Y)
			manhattan := dx + dy

			if manhattan != 1 {
				errors = append(errors, StructuralError{
					VineID: v.ID,
					Message: fmt.Sprintf("segments %d->%d not adjacent: (%d,%d)->(%d,%d) (manhattan=%d)",
						i-1, i, prev.X, prev.Y, curr.X, curr.Y, manhattan),
				})
			}
		}
	}

	// Check for circular blocking (deadlock detection)
	if circularError := checkCircularBlocking(lvl); circularError != nil {
		errors = append(errors, circularError)
	}

	// Check for self-blocking vines (vine blocking its own exit path)
	if selfBlockingErrors := ValidateSelfBlocking(lvl); len(selfBlockingErrors) > 0 {
		errors = append(errors, selfBlockingErrors...)
	}

	return errors
}

// ValidateSelfBlocking checks if any vine blocks its own exit path.
// The "exit path" is the straight line from the vine's head in its HeadDirection to the grid edge.
// If any segment of the SAME vine occupies a cell on this path, the vine is self-blocking.
func ValidateSelfBlocking(lvl model.Level) []error {
	var errors []error
	w, h := lvl.GridSize[0], lvl.GridSize[1]

	for _, v := range lvl.Vines {
		if len(v.OrderedPath) < 1 {
			continue
		}

		head := v.OrderedPath[0]
		dx, dy := 0, 0
		switch v.HeadDirection {
		case "right":
			dx, dy = 1, 0
		case "left":
			dx, dy = -1, 0
		case "up":
			dx, dy = 0, 1
		case "down":
			dx, dy = 0, -1
		default:
			continue // Invalid direction handled elsewhere
		}

		// Calculate exit path points
		exitPath := make(map[string]bool)
		currX, currY := head.X+dx, head.Y+dy
		for currX >= 0 && currX < w && currY >= 0 && currY < h {
			exitPath[fmt.Sprintf("%d,%d", currX, currY)] = true
			currX += dx
			currY += dy
		}

		// Check if any segment of THIS vine intersects the exit path
		// Skip head (index 0) as it defines the start of the path
		for i := 1; i < len(v.OrderedPath); i++ {
			p := v.OrderedPath[i]
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			if exitPath[key] {
				errors = append(errors, StructuralError{
					VineID:  v.ID,
					Message: fmt.Sprintf("self-blocking: segment at (%d,%d) blocks head exit path", p.X, p.Y),
				})
				// Report once per vine
				break
			}
		}
	}

	return errors
}

// isCellVisible checks if a cell is visible based on the mask
func isCellVisible(lvl model.Level, x, y int) bool {
	if lvl.Mask == nil {
		return true // No mask = all visible
	}

	switch lvl.Mask.Mode {
	case "show-all", "":
		return true
	case "hide":
		// Specific cells hidden
		for _, p := range lvl.Mask.Points {
			if p.X == x && p.Y == y {
				return false
			}
		}
		return true
	case "show":
		// Only specific cells shown
		for _, p := range lvl.Mask.Points {
			if p.X == x && p.Y == y {
				return true
			}
		}
		return false
	default:
		return true
	}
}

// checkCircularBlocking detects circular dependencies in the blocking graph.
// Returns an error if a circular blocking pattern is detected (deadlock).
func checkCircularBlocking(lvl model.Level) error {
	// Build occupancy map
	occupied := make(map[string]string) // "x,y" -> vineID
	for _, v := range lvl.Vines {
		for _, p := range v.OrderedPath {
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			occupied[key] = v.ID
		}
	}

	// Build blocking graph: A -> B means "A blocks B"
	graph := make(map[string][]string)
	for _, v := range lvl.Vines {
		graph[v.ID] = []string{}
	}

	for i := range lvl.Vines {
		for j := range lvl.Vines {
			if i == j {
				continue
			}
			if vineBlocksVine(lvl.Vines[i], lvl.Vines[j], occupied) {
				graph[lvl.Vines[i].ID] = append(graph[lvl.Vines[i].ID], lvl.Vines[j].ID)
			}
		}
	}

	// Detect cycles using DFS
	visited := make(map[string]bool)
	recStack := make(map[string]bool)

	var hasCycle func(string) bool
	hasCycle = func(nodeID string) bool {
		if recStack[nodeID] {
			return true // Cycle detected
		}
		if visited[nodeID] {
			return false // Already processed
		}

		visited[nodeID] = true
		recStack[nodeID] = true

		for _, neighbor := range graph[nodeID] {
			if hasCycle(neighbor) {
				return true
			}
		}

		recStack[nodeID] = false
		return false
	}

	for _, v := range lvl.Vines {
		if hasCycle(v.ID) {
			return StructuralError{
				Message: "circular blocking detected (unsolvable deadlock)",
			}
		}
	}

	return nil
}

// vineBlocksVine checks if blocker prevents blocked from moving.
// Blocked vine is blocked if the cell it would move into is occupied by blocker.
func vineBlocksVine(blocker, blocked model.Vine, occupied map[string]string) bool {
	if len(blocked.OrderedPath) == 0 {
		return false
	}

	head := blocked.OrderedPath[0]
	targetX, targetY := head.X, head.Y

	// Calculate where blocked vine's head would move
	switch blocked.HeadDirection {
	case "right":
		targetX++
	case "left":
		targetX--
	case "up":
		targetY++
	case "down":
		targetY--
	default:
		return false
	}

	key := fmt.Sprintf("%d,%d", targetX, targetY)
	return occupied[key] == blocker.ID
}

func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
}
