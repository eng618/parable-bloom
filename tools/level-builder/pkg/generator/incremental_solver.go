package generator

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// IsLikelySolvablePartial performs a cheap greedy simulation to test if the level
// can be cleared by repeatedly removing "movable" vines within maxSteps iterations.
// A vine is movable if its head's next cell (head + headDirection delta) is either
// outside the grid (immediate exit) or not occupied by another vine.
// This is not exhaustive but serves as an early filter before running the full solver.
func IsLikelySolvablePartial(vines []model.Vine, occupied map[string]string, w, h int, maxSteps int) bool {
	if len(vines) == 0 {
		return true
	}

	// Build maps: id -> vine, mutable occupied map
	vineMap := make(map[string]model.Vine)
	for _, v := range vines {
		vineMap[v.ID] = v
	}

	occ := make(map[string]string)
	for k, v := range occupied {
		occ[k] = v
	}

	// Greedy removal loop
	for step := 0; step < maxSteps; step++ {
		removedAny := false
		for id, v := range vineMap {
			if len(v.OrderedPath) == 0 {
				// treat as removable
				delete(vineMap, id)
				removedAny = true
				continue
			}
			head := v.OrderedPath[0]
			dx, dy := deltaForDirection(v.HeadDirection)
			tx := head.X + dx
			ty := head.Y + dy

			// If head would exit, it's movable
			if tx < 0 || tx >= w || ty < 0 || ty >= h {
				// remove this vine
				for _, p := range v.OrderedPath {
					key := fmtPoint(p)
					delete(occ, key)
				}
				delete(vineMap, id)
				removedAny = true
				continue
			}

			// If destination not occupied by another vine (or only by itself), movable
			key := fmtPointXY(tx, ty)
			if owner, ok := occ[key]; !ok || owner == v.ID {
				// remove this vine
				for _, p := range v.OrderedPath {
					k := fmtPoint(p)
					delete(occ, k)
				}
				delete(vineMap, id)
				removedAny = true
				continue
			}
		}

		if len(vineMap) == 0 {
			return true
		}

		if !removedAny {
			// No move possible within greedy policy
			return false
		}
	}

	// If we exhausted steps and still have vines, consider not likely solvable
	return false
}

func fmtPoint(p model.Point) string {
	return fmtPointXY(p.X, p.Y)
}

func fmtPointXY(x, y int) string {
	return fmt.Sprintf("%d,%d", x, y)
}
