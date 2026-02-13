package metrics

import (
	"fmt"

	"github.com/eng618/parable-bloom/tools/level-builder/pkg/model"
)

// CalculateCoverage computes the percentage of grid cells occupied by vines.
func CalculateCoverage(gridSize []int, vines []model.Vine) float64 {
	totalCells := gridSize[0] * gridSize[1]
	if totalCells == 0 {
		return 0
	}

	occupied := make(map[string]bool)
	for _, v := range vines {
		for _, p := range v.OrderedPath {
			key := fmt.Sprintf("%d,%d", p.X, p.Y)
			occupied[key] = true
		}
	}

	return float64(len(occupied)) / float64(totalCells)
}
